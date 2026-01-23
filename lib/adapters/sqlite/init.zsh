# SQLite adapter - Core
# Connection, CLI, basic operations

# Normalize path from various URL formats
_sqlite::path() {
  local p="${DB_URL#sqlite://}"
  p="${p#file:}"
  [[ "$p" != /* ]] && p="$(pwd)/$p"
  echo "$p"
}

# Helper: check sqlite3 is available
_sqlite::need() {
  db::need sqlite3 "brew install sqlite"
}

adapter::cli() {
  local path=$(_sqlite::path)
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
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "$@"
}

adapter::test() {
  local path=$(_sqlite::path)
  [[ -f "$path" ]] && db::ok "exists: $path" || { db::err "not found: $path"; return 1; }
}

adapter::dbs() {
  db::log "sqlite: single-file database"
  db::log "path: $(_sqlite::path)"
}

adapter::stats() {
  _sqlite::need || return 1
  local path=$(_sqlite::path)
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
  _sqlite::need || return 1
  local limit="${1:-10}"
  echo "table | rows"
  echo "------|------"
  sqlite3 "$(_sqlite::path)" "
    SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
  " | while read table; do
    local count=$(sqlite3 "$(_sqlite::path)" "SELECT COUNT(*) FROM \"$table\"")
    echo "$table | $count"
  done | sort -t'|' -k2 -nr | head -n "$limit"
}

adapter::dump() {
  _sqlite::need || return 1
  [[ -d "$DB_BACKUP_DIR" ]] || mkdir -p "$DB_BACKUP_DIR"
  local out="$DB_BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).db"
  sqlite3 "$(_sqlite::path)" ".backup $out" && db::ok "saved: $out"
}

adapter::restore() {
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  cp "$1" "$(_sqlite::path)" && db::ok "restored: $1"
}

adapter::exec() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" < "$1"
}

# Transaction support
adapter::tx_begin() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "BEGIN TRANSACTION" 2>/dev/null
}

adapter::tx_commit() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "COMMIT" 2>/dev/null
}

adapter::tx_rollback() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "ROLLBACK" 2>/dev/null
}

# Load sub-modules
source "${0:A:h}/query.zsh"
source "${0:A:h}/schema.zsh"
source "${0:A:h}/maintenance.zsh"
source "${0:A:h}/data.zsh"
