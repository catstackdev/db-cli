# SQLite adapter

# Normalize path from various URL formats
_sqlite_path() {
  local p="${DB_URL#sqlite://}"
  p="${p#file:}"
  [[ "$p" != /* ]] && p="$(pwd)/$p"
  echo "$p"
}

adapter::cli() {
  local path=$(_sqlite_path)
  if command -v litecli &>/dev/null; then
    litecli "$path"
  elif command -v sqlite3 &>/dev/null; then
    sqlite3 "$path"
  else
    db::err "install: brew install litecli"
    return 1
  fi
}

adapter::native() {
  db::need sqlite3 "brew install sqlite" || return 1
  sqlite3 "$(_sqlite_path)" "$@"
}

adapter::query() {
  db::need sqlite3 "brew install sqlite" || return 1
  sqlite3 "$(_sqlite_path)" "$1"
}

adapter::tables() {
  db::need sqlite3 "brew install sqlite" || return 1
  sqlite3 "$(_sqlite_path)" '.tables'
}

adapter::schema() {
  db::need sqlite3 "brew install sqlite" || return 1
  db::valid_id "$1" || return 1
  sqlite3 "$(_sqlite_path)" ".schema $1"
}

adapter::count() {
  db::need sqlite3 "brew install sqlite" || return 1
  db::valid_id "$1" || return 1
  sqlite3 "$(_sqlite_path)" "SELECT COUNT(*) FROM $1"
}

adapter::test() {
  local path=$(_sqlite_path)
  [[ -f "$path" ]] && db::ok "exists: $path" || { db::err "not found: $path"; return 1; }
}

adapter::stats() {
  db::need sqlite3 "brew install sqlite" || return 1
  local path=$(_sqlite_path)
  local size=$(/usr/bin/du -h "$path" 2>/dev/null | /usr/bin/cut -f1)
  /usr/bin/sqlite3 "$path" "
    SELECT 'path:       ' || '$path';
    SELECT 'size:       ' || '$size';
    SELECT 'tables:     ' || COUNT(*) FROM sqlite_master WHERE type='table';
    SELECT 'indexes:    ' || COUNT(*) FROM sqlite_master WHERE type='index';
    SELECT 'page_size:  ' || page_size FROM pragma_page_size;
    SELECT 'page_count: ' || page_count FROM pragma_page_count;
  "
  echo "version:    $(/usr/bin/sqlite3 --version 2>/dev/null)"
}

adapter::top() {
  db::need sqlite3 "brew install sqlite" || return 1
  local limit="${1:-10}"
  echo "table | rows"
  echo "------|------"
  sqlite3 "$(_sqlite_path)" "
    SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
  " | while read table; do
    local count=$(sqlite3 "$(_sqlite_path)" "SELECT COUNT(*) FROM \"$table\"")
    echo "$table | $count"
  done | sort -t'|' -k2 -nr | head -n "$limit"
}

adapter::health() {
  db::need sqlite3 "brew install sqlite" || return 1
  echo "${C_BLUE}=== Integrity ===${C_RESET}"
  sqlite3 "$(_sqlite_path)" "PRAGMA integrity_check"
  echo "${C_BLUE}=== Freelist ===${C_RESET}"
  echo "free_pages: $(sqlite3 "$(_sqlite_path)" "PRAGMA freelist_count")"
}

adapter::connections() {
  db::log "sqlite: single-user, no connection pool"
}

adapter::dump() {
  db::need sqlite3 "brew install sqlite" || return 1
  [[ -d "$DB_BACKUP_DIR" ]] || mkdir -p "$DB_BACKUP_DIR"
  local out="$DB_BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).db"
  sqlite3 "$(_sqlite_path)" ".backup $out" && db::ok "saved: $out"
}

adapter::restore() {
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  cp "$1" "$(_sqlite_path)" && db::ok "restored: $1"
}

adapter::explain() {
  db::need sqlite3 "brew install sqlite" || return 1
  sqlite3 "$(_sqlite_path)" "EXPLAIN QUERY PLAN $1"
}

adapter::dbs() {
  db::log "sqlite: single-file database"
  db::log "path: $(_sqlite_path)"
}

adapter::export() {
  db::need sqlite3 "brew install sqlite" || return 1
  local fmt="$1" sql="$2" out="${3:-export-$(date +%Y%m%d-%H%M%S).$fmt}"
  case "$fmt" in
    csv)  sqlite3 -header -csv "$(_sqlite_path)" "$sql" > "$out" ;;
    json) sqlite3 -json "$(_sqlite_path)" "$sql" > "$out" ;;
    *)    db::err "format: csv or json"; return 1 ;;
  esac
  [[ -s "$out" ]] && db::ok "exported: $out" || { rm -f "$out"; db::err "empty result"; return 1; }
}

adapter::copy() {
  db::need sqlite3 "brew install sqlite" || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  sqlite3 "$(_sqlite_path)" "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}

# New commands

adapter::tables_plain() {
  db::need sqlite3 "brew install sqlite" || return 1
  sqlite3 "$(_sqlite_path)" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
}

adapter::sample() {
  db::need sqlite3 "brew install sqlite" || return 1
  db::valid_id "$1" || return 1
  sqlite3 -header -column "$(_sqlite_path)" "SELECT * FROM $1 LIMIT ${2:-10}"
}

adapter::truncate() {
  db::need sqlite3 "brew install sqlite" || return 1
  db::valid_id "$1" || return 1
  sqlite3 "$(_sqlite_path)" "DELETE FROM $1" && db::ok "truncated: $1"
}

adapter::exec() {
  db::need sqlite3 "brew install sqlite" || return 1
  sqlite3 "$(_sqlite_path)" < "$1"
}
