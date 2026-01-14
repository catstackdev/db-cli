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
  sqlite3 "$(_sqlite_path)" ".schema $1"
}

adapter::count() {
  db::need sqlite3 "brew install sqlite" || return 1
  sqlite3 "$(_sqlite_path)" "SELECT COUNT(*) FROM $1"
}

adapter::test() {
  local path=$(_sqlite_path)
  [[ -f "$path" ]] && db::ok "exists: $path" || { db::err "not found: $path"; return 1; }
}

adapter::stats() {
  db::need sqlite3 "brew install sqlite" || return 1
  local path=$(_sqlite_path)
  local size=$(du -h "$path" | cut -f1)
  local tables=$(sqlite3 "$path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table'")
  echo "size: $size"
  echo "tables: $tables"
}

adapter::connections() {
  db::log "sqlite: single-user, no connection pool"
}

adapter::dump() {
  db::need sqlite3 "brew install sqlite" || return 1
  local out="backup-$(date +%Y%m%d-%H%M%S).db"
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
  sqlite3 "$(_sqlite_path)" "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}
