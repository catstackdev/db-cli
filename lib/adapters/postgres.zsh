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
  psql "$DB_URL" -c "\\d+ $1"
}

adapter::count() {
  db::need psql "brew install postgresql@16" || return 1
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
      pg_size_pretty(pg_database_size(current_database())) as size,
      (SELECT count(*) FROM information_schema.tables WHERE table_schema='public') as tables"
}

adapter::connections() {
  db::need psql "brew install postgresql@16" || return 1
  psql "$DB_URL" -c "
    SELECT pid, usename, application_name, client_addr, state
    FROM pg_stat_activity WHERE datname = current_database()"
}

adapter::dump() {
  db::need pg_dump "brew install postgresql@16" || return 1
  local out="backup-$(date +%Y%m%d-%H%M%S).sql"
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
  psql "$DB_URL" -c "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}
