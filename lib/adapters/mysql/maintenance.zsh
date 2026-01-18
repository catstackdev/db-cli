# MySQL adapter - Maintenance operations

adapter::health() {
  _mysql::need || return 1
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
  _mysql::need || return 1
  mysql "$DB_URL" -e "SHOW PROCESSLIST"
}

adapter::locks() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "
    SELECT
      r.trx_id as waiting_trx,
      r.trx_mysql_thread_id as waiting_thread,
      r.trx_query as waiting_query,
      b.trx_id as blocking_trx,
      b.trx_mysql_thread_id as blocking_thread,
      b.trx_query as blocking_query
    FROM performance_schema.data_lock_waits w
    JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_engine_transaction_id
    JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_engine_transaction_id"
}

adapter::kill() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "KILL $1" && db::ok "terminated: $1"
}

adapter::slowlog() {
  _mysql::need || return 1
  local limit="${1:-10}"
  mysql "$DB_URL" -e "
    SELECT
      TRUNCATE(timer_wait/1000000000000, 3) as duration_sec,
      sql_text as query,
      rows_examined,
      rows_sent
    FROM performance_schema.events_statements_history_long
    ORDER BY timer_wait DESC
    LIMIT $limit" 2>/dev/null || {
    db::warn "performance_schema may not be enabled"
    echo "check slow query log instead: SHOW VARIABLES LIKE 'slow_query%'"
  }
}

adapter::vacuum() {
  _mysql::need || return 1
  if [[ -n "$1" ]]; then
    db::valid_id "$1" || return 1
    mysql "$DB_URL" -e "OPTIMIZE TABLE $1" && db::ok "optimized: $1"
  else
    local tables=$(mysql "$DB_URL" -sN -e "SHOW TABLES")
    for table in $tables; do
      mysql "$DB_URL" -e "OPTIMIZE TABLE $table"
    done
    db::ok "optimized all tables"
  fi
}

adapter::analyze() {
  _mysql::need || return 1
  if [[ -n "$1" ]]; then
    db::valid_id "$1" || return 1
    mysql "$DB_URL" -e "ANALYZE TABLE $1" && db::ok "analyzed: $1"
  else
    local tables=$(mysql "$DB_URL" -sN -e "SHOW TABLES")
    for table in $tables; do
      mysql "$DB_URL" -e "ANALYZE TABLE $table"
    done
    db::ok "analyzed all tables"
  fi
}
