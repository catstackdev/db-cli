# MySQL adapter

adapter::cli() {
  if command -v mycli &>/dev/null; then
    mycli "$DB_URL"
  elif command -v mysql &>/dev/null; then
    mysql "$DB_URL"
  else
    db::err "install: brew install mycli"
    return 1
  fi
}

adapter::native() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" "$@"
}

adapter::query() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "$1"
}

adapter::tables() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e 'SHOW TABLES'
}

adapter::schema() {
  db::need mysql "brew install mysql-client" || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "DESCRIBE $1"
}

adapter::count() {
  db::need mysql "brew install mysql-client" || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -sN -e "SELECT COUNT(*) FROM $1"
}

adapter::test() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "SELECT 1" &>/dev/null && db::ok "connected" || { db::err "connection failed"; return 1; }
}

adapter::stats() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "
    SELECT
      DATABASE() as db,
      ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb,
      ROUND(SUM(data_length) / 1024 / 1024, 2) AS data_mb,
      ROUND(SUM(index_length) / 1024 / 1024, 2) AS index_mb,
      COUNT(*) AS tables,
      SUM(table_rows) AS total_rows
    FROM information_schema.tables WHERE table_schema = DATABASE()"
  mysql "$DB_URL" -e "SELECT VERSION() as version"
}

adapter::top() {
  db::need mysql "brew install mysql-client" || return 1
  local limit="${1:-10}"
  mysql "$DB_URL" -e "
    SELECT
      table_name as 'table',
      ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb,
      ROUND(data_length / 1024 / 1024, 2) AS data_mb,
      ROUND(index_length / 1024 / 1024, 2) AS index_mb,
      table_rows as rows
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
    ORDER BY (data_length + index_length) DESC
    LIMIT $limit"
}

adapter::health() {
  db::need mysql "brew install mysql-client" || return 1
  echo "${C_BLUE}=== InnoDB Buffer Pool ===${C_RESET}"
  mysql "$DB_URL" -e "
    SELECT
      ROUND(@@innodb_buffer_pool_size / 1024 / 1024, 2) as buffer_pool_mb,
      (SELECT ROUND(100 * (1 - (
        (SELECT variable_value FROM performance_schema.global_status WHERE variable_name='Innodb_buffer_pool_reads') /
        (SELECT variable_value FROM performance_schema.global_status WHERE variable_name='Innodb_buffer_pool_read_requests')
      )), 2)) as hit_rate_pct"
  echo "${C_BLUE}=== Connections ===${C_RESET}"
  mysql "$DB_URL" -e "SHOW STATUS LIKE 'Threads_connected'"
}

adapter::connections() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "SHOW PROCESSLIST"
}

adapter::dump() {
  db::need mysqldump "brew install mysql-client" || return 1
  [[ -d "$DB_BACKUP_DIR" ]] || mkdir -p "$DB_BACKUP_DIR"
  local out="$DB_BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"
  mysqldump "$DB_URL" > "$out" && db::ok "saved: $out" || { db::err "dump failed"; return 1; }
}

adapter::restore() {
  db::need mysql "brew install mysql-client" || return 1
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  mysql "$DB_URL" < "$1" && db::ok "restored: $1"
}

adapter::explain() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "EXPLAIN $1"
}

adapter::dbs() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e 'SHOW DATABASES'
}

adapter::export() {
  db::need mysql "brew install mysql-client" || return 1
  local fmt="$1" sql="$2" out="${3:-export-$(date +%Y%m%d-%H%M%S).$fmt}"
  mysql "$DB_URL" -e "$sql" > "$out"
  [[ -s "$out" ]] && db::ok "exported: $out" || { rm -f "$out"; db::err "empty result"; return 1; }
}

adapter::copy() {
  db::need mysql "brew install mysql-client" || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  mysql "$DB_URL" -e "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}

# New commands

adapter::tables_plain() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -sN -e "SHOW TABLES"
}

adapter::sample() {
  db::need mysql "brew install mysql-client" || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "SELECT * FROM $1 LIMIT ${2:-10}"
}

adapter::truncate() {
  db::need mysql "brew install mysql-client" || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "TRUNCATE TABLE $1" && db::ok "truncated: $1"
}

adapter::exec() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" < "$1"
}
