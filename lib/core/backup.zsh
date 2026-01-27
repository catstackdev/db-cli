#!/usr/bin/env zsh
# db - Backup automation and management

typeset -g DB_BACKUP_KEEP="${DB_BACKUP_KEEP:-7}"  # Keep last N backups
typeset -g DB_BACKUP_DIR="${DB_BACKUP_DIR:-.}"

# Create backup with timestamp
backup::create() {
  local name="${1:-backup}"
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local filename="${name}-${timestamp}"
  
  # Create backup directory with secure permissions
  local old_umask=$(umask)
  umask 077
  mkdir -p "$DB_BACKUP_DIR"
  umask "$old_umask"
  
  db::log "creating backup: $filename"
  
  case "$DB_TYPE" in
    postgres)
      pg_dump "$DB_URL" > "$DB_BACKUP_DIR/${filename}.sql" 2>&1
      ;;
    mysql)
      mysqldump "$DB_URL" > "$DB_BACKUP_DIR/${filename}.sql" 2>&1
      ;;
    sqlite)
      local path=$(echo "$DB_URL" | sed 's|sqlite://||')
      sqlite3 "$path" ".backup '$DB_BACKUP_DIR/${filename}.db'"
      ;;
    mongodb)
      mongodump --uri="$DB_URL" --out="$DB_BACKUP_DIR/${filename}" 2>&1
      ;;
    *)
      db::err "unsupported database type: $DB_TYPE"
      return 1
      ;;
  esac
  
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    # Compress backup and secure permissions
    if [[ "$DB_TYPE" == "mongodb" ]]; then
      tar -czf "$DB_BACKUP_DIR/${filename}.tar.gz" -C "$DB_BACKUP_DIR" "$filename" 2>/dev/null
      rm -rf "$DB_BACKUP_DIR/$filename"
      chmod 600 "$DB_BACKUP_DIR/${filename}.tar.gz" 2>/dev/null
      echo "$filename.tar.gz"
    else
      gzip "$DB_BACKUP_DIR/${filename}.sql" 2>/dev/null || gzip "$DB_BACKUP_DIR/${filename}.db" 2>/dev/null
      if [[ -f "$DB_BACKUP_DIR/${filename}.sql.gz" ]]; then
        chmod 600 "$DB_BACKUP_DIR/${filename}.sql.gz"
        echo "${filename}.sql.gz"
      elif [[ -f "$DB_BACKUP_DIR/${filename}.db.gz" ]]; then
        chmod 600 "$DB_BACKUP_DIR/${filename}.db.gz"
        echo "${filename}.db.gz"
      fi
    fi
  else
    db::err "backup failed"
    return 1
  fi
}

# List backups
backup::list() {
  [[ ! -d "$DB_BACKUP_DIR" ]] && { echo "No backups found"; return 0; }
  
  echo "${C_BLUE}=== Backups ===${C_RESET}"
  
  local -a files=($DB_BACKUP_DIR/*.{sql.gz,db.gz,tar.gz}(N))
  [[ ${#files[@]} -eq 0 ]] && { echo "No backups found"; return 0; }
  
  for file in $files; do
    local size=$(du -h "$file" | cut -f1)
    local mtime=$(stat -f %Sm -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || stat -c %y "$file" 2>/dev/null | cut -d. -f1)
    echo "${file:t} | $size | $mtime"
  done | sort -r
}

# Clean old backups
backup::cleanup() {
  local keep="${1:-$DB_BACKUP_KEEP}"
  
  [[ ! -d "$DB_BACKUP_DIR" ]] && return 0
  
  local -a files=($DB_BACKUP_DIR/*.{sql.gz,db.gz,tar.gz}(N))
  local count=${#files[@]}
  
  [[ $count -le $keep ]] && { db::log "keeping all $count backup(s)"; return 0; }
  
  local delete=$((count - keep))
  db::log "keeping $keep most recent, deleting $delete old backup(s)"
  
  # Sort by modification time, keep newest
  local -a sorted=(${(f)"$(ls -t $DB_BACKUP_DIR/*.{sql.gz,db.gz,tar.gz} 2>/dev/null)"})
  
  local i=0
  for file in $sorted; do
    ((i++))
    if [[ $i -gt $keep ]]; then
      db::dbg "deleting: ${file:t}"
      rm -f "$file"
    fi
  done
  
  db::ok "cleaned up $delete backup(s)"
}

# Verify backup integrity
backup::verify() {
  local file="$1"
  
  [[ ! -f "$file" ]] && { db::err "file not found: $file"; return 1; }
  
  db::log "verifying: ${file:t}"
  
  case "${file:e}" in
    gz)
      if gzip -t "$file" 2>/dev/null; then
        db::ok "backup integrity OK"
        return 0
      else
        db::err "backup corrupted"
        return 1
      fi
      ;;
    sql|db)
      # Check if file is readable and has content
      [[ -r "$file" && -s "$file" ]] && db::ok "backup file OK" || { db::err "backup invalid"; return 1; }
      ;;
    *)
      db::warn "cannot verify file type: ${file:e}"
      return 1
      ;;
  esac
}

# Auto backup with rotation
backup::auto() {
  local name="${1:-auto}"
  
  db::log "starting auto backup..."
  
  local backup_file=$(backup::create "$name")
  [[ $? -ne 0 ]] && return 1
  
  db::ok "backup created: $backup_file"
  
  # Verify
  backup::verify "$DB_BACKUP_DIR/$backup_file" || db::warn "verification failed"
  
  # Cleanup old backups
  backup::cleanup "$DB_BACKUP_KEEP"
}

# Restore from backup
backup::restore_from() {
  local file="$1"
  
  [[ ! -f "$file" ]] && { db::err "file not found: $file"; return 1; }
  
  # Verify first
  backup::verify "$file" || { db::err "backup verification failed"; return 1; }
  
  db::warn "this will overwrite the current database"
  db::confirm "restore from: ${file:t}" || return 1
  
  db::log "restoring from: ${file:t}"
  
  # Decompress if needed
  local restore_file="$file"
  if [[ "${file:e}" == "gz" ]]; then
    local tmp=$(mktemp "$DB_TMP_DIR/db-restore.XXXXXX")
    gzip -dc "$file" > "$tmp"
    restore_file="$tmp"
  fi
  
  adapter::restore "$restore_file"
  local exit_code=$?
  
  # Cleanup temp file
  [[ "$restore_file" != "$file" ]] && rm -f "$restore_file"
  
  [[ $exit_code -eq 0 ]] && db::ok "restore completed" || db::err "restore failed"
  return $exit_code
}

# Generate cron command
backup::cron_cmd() {
  local schedule="${1:-0 2 * * *}"  # Default: 2 AM daily
  
  echo "${C_BLUE}=== Cron Setup ===${C_RESET}"
  echo "Add this to your crontab (crontab -e):"
  echo ""
  echo "$schedule cd $(pwd) && $(which db) --quiet backup auto"
  echo ""
  echo "Schedule examples:"
  echo "  0 2 * * *       Daily at 2 AM"
  echo "  0 */6 * * *     Every 6 hours"
  echo "  0 0 * * 0       Weekly (Sunday midnight)"
}
