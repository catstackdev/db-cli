#!/usr/bin/env zsh
# db - Schema versioning and snapshots

readonly SCHEMA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/db/schemas"

# Get schema directory for current profile
schema::profile_dir() {
  local profile="${DB_PROFILE:-$(echo "$DB_URL" | shasum -a 256 | cut -d' ' -f1 | cut -c1-16)}"
  echo "$SCHEMA_DIR/$profile"
}

# Save current schema
schema::save() {
  local version="$1"
  [[ -z "$version" ]] && { db::err "usage: schema save <version>"; return 1; }
  
  local dir=$(schema::profile_dir)
  mkdir -p "$dir"
  
  local file="$dir/${version}.sql"
  [[ -f "$file" ]] && { db::err "version exists: $version"; return 1; }
  
  db::log "saving schema: $version"
  
  # Dump schema only (no data)
  case "$DB_TYPE" in
    postgres)
      pg_dump "$DB_URL" --schema-only > "$file"
      ;;
    mysql)
      mysqldump "$DB_URL" --no-data > "$file"
      ;;
    sqlite)
      sqlite3 "$(echo "$DB_URL" | sed 's|sqlite://||')" .schema > "$file"
      ;;
    mongodb)
      db::warn "MongoDB schema export not fully supported"
      echo "// MongoDB schema for: $(date)" > "$file"
      mongosh "$DB_URL" --quiet --eval "db.getCollectionNames().forEach(c => print(c))" >> "$file"
      ;;
    *)
      db::err "unsupported database type: $DB_TYPE"
      return 1
      ;;
  esac
  
  [[ -s "$file" ]] || { db::err "schema save failed"; rm -f "$file"; return 1; }
  
  # Save metadata
  cat > "${file}.meta" <<EOF
version=$version
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
db_type=$DB_TYPE
db_url=$(db::mask "$DB_URL")
tables=$(adapter::tables_plain 2>/dev/null | wc -l | tr -d ' ')
EOF
  
  db::ok "saved: $version"
  echo "${C_DIM}location: $file${C_RESET}"
}

# Restore schema from version
schema::restore() {
  local version="$1"
  [[ -z "$version" ]] && { db::err "usage: schema restore <version>"; return 1; }
  
  local dir=$(schema::profile_dir)
  local file="$dir/${version}.sql"
  
  [[ ! -f "$file" ]] && { db::err "version not found: $version"; return 1; }
  
  db::warn "this will DROP and recreate all tables"
  db::confirm "restore schema: $version" || return 1
  
  db::log "restoring schema: $version"
  adapter::exec "$file" && db::ok "restored: $version"
}

# Compare two schema versions
schema::diff() {
  local v1="$1"
  local v2="${2:-current}"
  
  [[ -z "$v1" ]] && { db::err "usage: schema diff <version1> [version2|current]"; return 1; }
  
  local dir=$(schema::profile_dir)
  local file1="$dir/${v1}.sql"
  
  [[ ! -f "$file1" ]] && { db::err "version not found: $v1"; return 1; }
  
  if [[ "$v2" == "current" ]]; then
    # Compare with current schema
    local tmp=$(mktemp "$DB_TMP_DIR/db-schema.XXXXXX.sql")
    
    case "$DB_TYPE" in
      postgres) pg_dump "$DB_URL" --schema-only > "$tmp" ;;
      mysql) mysqldump "$DB_URL" --no-data > "$tmp" ;;
      sqlite) sqlite3 "$(echo "$DB_URL" | sed 's|sqlite://||')" .schema > "$tmp" ;;
      *) db::err "unsupported: $DB_TYPE"; rm -f "$tmp"; return 1 ;;
    esac
    
    echo "${C_BLUE}=== Schema Diff: $v1 vs current ===${C_RESET}"
    diff -u "$file1" "$tmp" || true
    rm -f "$tmp"
  else
    # Compare two versions
    local file2="$dir/${v2}.sql"
    [[ ! -f "$file2" ]] && { db::err "version not found: $v2"; return 1; }
    
    echo "${C_BLUE}=== Schema Diff: $v1 vs $v2 ===${C_RESET}"
    diff -u "$file1" "$file2" || true
  fi
}

# List saved schema versions
schema::list() {
  local dir=$(schema::profile_dir)
  
  [[ ! -d "$dir" ]] && { echo "No schemas saved"; return 0; }
  
  local -a files=($dir/*.sql(N))
  [[ ${#files[@]} -eq 0 ]] && { echo "No schemas saved"; return 0; }
  
  echo "${C_BLUE}=== Saved Schema Versions ===${C_RESET}"
  
  for file in $files; do
    local version="${file:t:r}"
    local meta="${file}.meta"
    
    if [[ -f "$meta" ]]; then
      local timestamp=$(grep '^timestamp=' "$meta" | cut -d= -f2)
      local tables=$(grep '^tables=' "$meta" | cut -d= -f2)
      echo "$version | $timestamp | $tables tables"
    else
      echo "$version"
    fi
  done | sort -r
}

# Export schema to file
schema::export() {
  local output="${1:-schema-$(date +%Y%m%d-%H%M%S).sql}"
  
  db::log "exporting schema to: $output"
  
  case "$DB_TYPE" in
    postgres) pg_dump "$DB_URL" --schema-only > "$output" ;;
    mysql) mysqldump "$DB_URL" --no-data > "$output" ;;
    sqlite) sqlite3 "$(echo "$DB_URL" | sed 's|sqlite://||')" .schema > "$output" ;;
    *) db::err "unsupported: $DB_TYPE"; return 1 ;;
  esac
  
  [[ -s "$output" ]] && db::ok "exported: $output" || { db::err "export failed"; return 1; }
}

# Delete schema version
schema::delete() {
  local version="$1"
  [[ -z "$version" ]] && { db::err "usage: schema delete <version>"; return 1; }
  
  local dir=$(schema::profile_dir)
  local file="$dir/${version}.sql"
  
  [[ ! -f "$file" ]] && { db::err "version not found: $version"; return 1; }
  
  db::confirm "delete schema: $version" || return 1
  
  rm -f "$file" "${file}.meta"
  db::ok "deleted: $version"
}
