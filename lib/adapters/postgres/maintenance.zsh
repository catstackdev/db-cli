# PostgreSQL adapter - Maintenance operations
# vacuum, analyze, locks, kill, slowlog, health, connections

adapter::health() {
  _pg::need || return 1
  echo "${C_BLUE}=== Cache ===${C_RESET}"
  _pg::exec -c "
    SELECT
      round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2) as cache_hit_pct
    FROM pg_stat_database WHERE datname=current_database()"
  echo "${C_BLUE}=== Vacuum ===${C_RESET}"
  _pg::exec -c "
    SELECT relname as table, n_dead_tup as dead_rows, last_vacuum, last_autovacuum
    FROM pg_stat_user_tables
    WHERE n_dead_tup > 0
    ORDER BY n_dead_tup DESC LIMIT 5"
  echo "${C_BLUE}=== Slow Tables (seq scans) ===${C_RESET}"
  _pg::exec -c "
    SELECT relname as table, seq_scan, idx_scan,
      round(100.0 * seq_scan / nullif(seq_scan + idx_scan, 0), 2) as seq_pct
    FROM pg_stat_user_tables
    WHERE seq_scan > 0
    ORDER BY seq_scan DESC LIMIT 5"
}

adapter::connections() {
  _pg::need || return 1
  _pg::exec -c "
    SELECT pid, usename, application_name, client_addr, state
    FROM pg_stat_activity WHERE datname = current_database()"
}

adapter::locks() {
  _pg::need || return 1
  _pg::exec -c "
    SELECT
      l.pid,
      l.locktype,
      l.mode,
      l.granted,
      a.usename,
      a.query_start,
      left(a.query, 60) as query
    FROM pg_locks l
    JOIN pg_stat_activity a ON l.pid = a.pid
    WHERE a.datname = current_database()
    ORDER BY l.granted, a.query_start"
}

adapter::kill() {
  _pg::need || return 1
  _pg::exec -tAc "SELECT pg_terminate_backend($1)" | grep -q 't' && \
    db::ok "terminated: $1" || { db::err "failed to terminate: $1"; return 1; }
}

adapter::slowlog() {
  _pg::need || return 1
  local limit="${1:-10}"
  # Check if pg_stat_statements is available
  local has_stats=$(_pg::exec -tAc "SELECT 1 FROM pg_extension WHERE extname='pg_stat_statements'" 2>/dev/null)
  if [[ "$has_stats" != "1" ]]; then
    db::warn "pg_stat_statements not enabled"
    echo "enable with: CREATE EXTENSION pg_stat_statements;"
    return 1
  fi
  _pg::exec -c "
    SELECT
      round(total_exec_time::numeric, 2) as total_ms,
      calls,
      round(mean_exec_time::numeric, 2) as avg_ms,
      left(query, 80) as query
    FROM pg_stat_statements
    ORDER BY total_exec_time DESC
    LIMIT $limit"
}

adapter::vacuum() {
  _pg::need || return 1
  if [[ -n "$1" ]]; then
    db::valid_id "$1" || return 1
    _pg::exec -c "VACUUM ANALYZE $1" && db::ok "vacuumed: $1"
  else
    _pg::exec -c "VACUUM ANALYZE" && db::ok "vacuumed all tables"
  fi
}

adapter::analyze() {
  _pg::need || return 1
  if [[ -n "$1" ]]; then
    db::valid_id "$1" || return 1
    _pg::exec -c "ANALYZE $1" && db::ok "analyzed: $1"
  else
    _pg::exec -c "ANALYZE" && db::ok "analyzed all tables"
  fi
}
