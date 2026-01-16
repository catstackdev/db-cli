# PostgreSQL adapter

adapter::cli() {
  if command -v pgcli &>/dev/null; then
    pgcli "$DB_URL"
  elif command -v psql &>/dev/null; then
    psql "$DB_URL"
  else
    db::err "install: brew install pgcli"
    return 1
  fi
}

adapter::native() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" "$@"
}

adapter::query() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c "$1"
}

adapter::tables() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c '\dt'
}

adapter::schema() {
  db::need psql "brew install postgresql@16" || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "\\d+ $1"
}

adapter::count() {
  db::need psql "brew install postgresql@16" || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -tAc "SELECT COUNT(*) FROM $1"
}

adapter::test() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c "SELECT 1" &>/dev/null && db::ok "connected" || { db::err "connection failed"; return 1; }
}

adapter::stats() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c "
    SELECT
      current_database() as database,
      '$DB_SCHEMA' as schema,
      pg_size_pretty(pg_database_size(current_database())) as size,
      (SELECT count(*) FROM information_schema.tables WHERE table_schema='$DB_SCHEMA') as tables,
      (SELECT count(*) FROM pg_indexes WHERE schemaname='$DB_SCHEMA') as indexes,
      (SELECT count(*) FROM pg_stat_activity WHERE datname=current_database()) as connections,
      version() as version"
}

adapter::top() {
  db::need psql "brew install postgresql@16" || return 1
  local limit="${1:-10}"
  psql "$DB_URL" -c "
    SELECT
      relname as table,
      pg_size_pretty(pg_total_relation_size(relid)) as total_size,
      pg_size_pretty(pg_relation_size(relid)) as data_size,
      pg_size_pretty(pg_indexes_size(relid)) as index_size,
      n_live_tup as rows
    FROM pg_stat_user_tables
    WHERE schemaname='$DB_SCHEMA'
    ORDER BY pg_total_relation_size(relid) DESC
    LIMIT $limit"
}

adapter::health() {
  db::need psql "brew install postgresql@16" || return 1
  echo "${C_BLUE}=== Cache ===${C_RESET}"
  psql "$DB_URL" -c "
    SELECT
      round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2) as cache_hit_pct
    FROM pg_stat_database WHERE datname=current_database()"
  echo "${C_BLUE}=== Vacuum ===${C_RESET}"
  psql "$DB_URL" -c "
    SELECT relname as table, n_dead_tup as dead_rows, last_vacuum, last_autovacuum
    FROM pg_stat_user_tables
    WHERE n_dead_tup > 0
    ORDER BY n_dead_tup DESC LIMIT 5"
  echo "${C_BLUE}=== Slow Tables (seq scans) ===${C_RESET}"
  psql "$DB_URL" -c "
    SELECT relname as table, seq_scan, idx_scan,
      round(100.0 * seq_scan / nullif(seq_scan + idx_scan, 0), 2) as seq_pct
    FROM pg_stat_user_tables
    WHERE seq_scan > 0
    ORDER BY seq_scan DESC LIMIT 5"
}

adapter::connections() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c "
    SELECT pid, usename, application_name, client_addr, state
    FROM pg_stat_activity WHERE datname = current_database()"
}

adapter::dump() {
  db::need pg_dump "brew install postgresql@16" || return 1
  [[ -d "$DB_BACKUP_DIR" ]] || mkdir -p "$DB_BACKUP_DIR"
  local out="$DB_BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"
  pg_dump "$DB_URL" > "$out" && db::ok "saved: $out" || { db::err "dump failed"; return 1; }
}

adapter::restore() {
  db::need psql "brew install postgresql@16" || return 1
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  psql "$DB_URL" < "$1" && db::ok "restored: $1"
}

adapter::explain() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c "EXPLAIN ANALYZE $1"
}

adapter::dbs() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c '\l'
}

adapter::export() {
  db::need psql "brew install postgresql@16" || return 1
  local fmt="$1" sql="$2" out="${3:-export-$(date +%Y%m%d-%H%M%S).$fmt}"
  case "$fmt" in
    csv)  psql "$DB_URL" -c "COPY ($sql) TO STDOUT WITH CSV HEADER" > "$out" ;;
    json) psql "$DB_URL" -tAc "$sql" --json > "$out" ;;
    *)    db::err "format: csv or json"; return 1 ;;
  esac
  [[ -s "$out" ]] && db::ok "exported: $out" || { rm -f "$out"; db::err "empty result"; return 1; }
}

adapter::copy() {
  db::need psql "brew install postgresql@16" || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  psql "$DB_URL" -c "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}

# New commands

adapter::tables_plain() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA'"
}

adapter::sample() {
  db::need psql "brew install postgresql@16" || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "SELECT * FROM $1 LIMIT ${2:-10}"
}

adapter::truncate() {
  db::need psql "brew install postgresql@16" || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "TRUNCATE TABLE $1" && db::ok "truncated: $1"
}

adapter::exec() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" < "$1"
}
