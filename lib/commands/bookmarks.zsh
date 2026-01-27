# db - Bookmark commands
# @commands: save, run, bookmarks, rm

cmd::save() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db save <name> <sql>"
    return 1
  }
  local name="$1" sql="$2"
  
  # Validate bookmark name (prevent path traversal and injection)
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    db::err "invalid bookmark name: $name"
    db::err "bookmark names must contain only alphanumeric, underscore, and hyphen"
    return 1
  fi
  
  # Create directory and set secure permissions
  local old_umask=$(umask)
  umask 077
  mkdir -p "$(dirname "$DB_BOOKMARKS_FILE")"
  
  # Remove existing bookmark with same name
  if [[ -f "$DB_BOOKMARKS_FILE" ]]; then
    grep -v "^$name	" "$DB_BOOKMARKS_FILE" >"${DB_BOOKMARKS_FILE}.tmp" 2>/dev/null
    mv "${DB_BOOKMARKS_FILE}.tmp" "$DB_BOOKMARKS_FILE"
  fi
  
  echo "$name	$sql" >>"$DB_BOOKMARKS_FILE"
  chmod 600 "$DB_BOOKMARKS_FILE"
  
  umask "$old_umask"
  db::ok "saved: $name"
}

cmd::run_bookmark() {
  [[ -z "$1" ]] && {
    echo "usage: db run <name>"
    return 1
  }
  local name="$1"
  
  # Validate bookmark name before using in grep
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    db::err "invalid bookmark name: $name"
    return 1
  fi
  
  [[ ! -f "$DB_BOOKMARKS_FILE" ]] && {
    db::err "no bookmarks"
    return 1
  }
  local sql=$(grep "^$name	" "$DB_BOOKMARKS_FILE" | cut -f2-)
  [[ -z "$sql" ]] && {
    db::err "bookmark not found: $name"
    return 1
  }
  db::log "running: $sql"
  adapter::query "$sql"
}

cmd::bookmarks() {
  [[ ! -f "$DB_BOOKMARKS_FILE" ]] && {
    echo "no bookmarks"
    return 0
  }
  echo "${C_BLUE}=== Bookmarks ===${C_RESET}"
  while IFS=$'\t' read -r name sql; do
    echo "${C_GREEN}$name${C_RESET}: $sql"
  done <"$DB_BOOKMARKS_FILE"
}

cmd::rm_bookmark() {
  [[ -z "$1" ]] && {
    echo "usage: db rm <name>"
    return 1
  }
  local name="$1"
  
  # Validate bookmark name before using in grep
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    db::err "invalid bookmark name: $name"
    return 1
  fi
  
  [[ ! -f "$DB_BOOKMARKS_FILE" ]] && {
    db::err "no bookmarks"
    return 1
  }
  grep -v "^$name	" "$DB_BOOKMARKS_FILE" >"${DB_BOOKMARKS_FILE}.tmp"
  mv "${DB_BOOKMARKS_FILE}.tmp" "$DB_BOOKMARKS_FILE"
  db::ok "removed: $name"
}
