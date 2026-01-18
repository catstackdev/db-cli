# SQLite adapter - Query operations

adapter::query() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "$1"
}

adapter::tables() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" '.tables'
}

adapter::tables_plain() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
}

adapter::schema() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  sqlite3 "$(_sqlite::path)" ".schema $1"
}

adapter::sample() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  sqlite3 -header -column "$(_sqlite::path)" "SELECT * FROM $1 LIMIT ${2:-10}"
}

adapter::count() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  sqlite3 "$(_sqlite::path)" "SELECT COUNT(*) FROM $1"
}

adapter::table_size() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  local path=$(_sqlite::path)
  local rows=$(sqlite3 "$path" "SELECT COUNT(*) FROM $1")
  local cols=$(sqlite3 "$path" "SELECT COUNT(*) FROM pragma_table_info('$1')")
  local indexes=$(sqlite3 "$path" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND tbl_name='$1'")
  echo "table:   $1"
  echo "rows:    $rows"
  echo "columns: $cols"
  echo "indexes: $indexes"
  echo ""
  echo "${C_DIM}note: sqlite doesn't track per-table size${C_RESET}"
}

adapter::explain() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "EXPLAIN QUERY PLAN $1"
}

adapter::export() {
  _sqlite::need || return 1
  local fmt="$1" sql="$2" out="${3:-export-$(date +%Y%m%d-%H%M%S).$fmt}"
  case "$fmt" in
    csv)  sqlite3 -header -csv "$(_sqlite::path)" "$sql" > "$out" ;;
    json) sqlite3 -json "$(_sqlite::path)" "$sql" > "$out" ;;
    *)    db::err "format: csv or json"; return 1 ;;
  esac
  [[ -s "$out" ]] && db::ok "exported: $out" || { rm -f "$out"; db::err "empty result"; return 1; }
}

adapter::copy() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  sqlite3 "$(_sqlite::path)" "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}

adapter::truncate() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  sqlite3 "$(_sqlite::path)" "DELETE FROM $1" && db::ok "truncated: $1"
}
