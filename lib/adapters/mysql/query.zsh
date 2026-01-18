# MySQL adapter - Query operations

adapter::query() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "$1"
}

adapter::tables() {
  _mysql::need || return 1
  mysql "$DB_URL" -e 'SHOW TABLES'
}

adapter::tables_plain() {
  _mysql::need || return 1
  mysql "$DB_URL" -sN -e "SHOW TABLES"
}

adapter::schema() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "DESCRIBE $1"
}

adapter::sample() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "SELECT * FROM $1 LIMIT ${2:-10}"
}

adapter::count() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -sN -e "SELECT COUNT(*) FROM $1"
}

adapter::table_size() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "
    SELECT
      TABLE_NAME as 'table',
      ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as total_mb,
      ROUND(DATA_LENGTH / 1024 / 1024, 2) as data_mb,
      ROUND(INDEX_LENGTH / 1024 / 1024, 2) as index_mb,
      TABLE_ROWS as est_rows,
      (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='$1') as columns,
      (SELECT COUNT(DISTINCT INDEX_NAME) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='$1') as indexes
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '$1'"
}

adapter::explain() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "EXPLAIN $1"
}

adapter::export() {
  _mysql::need || return 1
  local fmt="$1" sql="$2" out="${3:-export-$(date +%Y%m%d-%H%M%S).$fmt}"
  mysql "$DB_URL" -e "$sql" > "$out"
  [[ -s "$out" ]] && db::ok "exported: $out" || { rm -f "$out"; db::err "empty result"; return 1; }
}

adapter::copy() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  mysql "$DB_URL" -e "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}

adapter::truncate() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "TRUNCATE TABLE $1" && db::ok "truncated: $1"
}
