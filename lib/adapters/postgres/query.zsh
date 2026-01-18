# PostgreSQL adapter - Query operations
# query, tables, schema, sample, count, export, explain

adapter::query() {
  _pg::need || return 1
  psql "$DB_URL" -c "$1"
}

adapter::tables() {
  _pg::need || return 1
  psql "$DB_URL" -c '\dt'
}

adapter::tables_plain() {
  _pg::need || return 1
  psql "$DB_URL" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA'"
}

adapter::schema() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "\\d+ $1"
}

adapter::sample() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "SELECT * FROM $1 LIMIT ${2:-10}"
}

adapter::count() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -tAc "SELECT COUNT(*) FROM $1"
}

adapter::table_size() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "
    SELECT
      '$1' as table,
      pg_size_pretty(pg_total_relation_size('$1')) as total_size,
      pg_size_pretty(pg_relation_size('$1')) as data_size,
      pg_size_pretty(pg_indexes_size('$1')) as index_size,
      (SELECT reltuples::bigint FROM pg_class WHERE relname='$1') as est_rows,
      (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='$1' AND table_schema='$DB_SCHEMA') as columns,
      (SELECT COUNT(*) FROM pg_indexes WHERE tablename='$1' AND schemaname='$DB_SCHEMA') as indexes"
}

adapter::explain() {
  _pg::need || return 1
  psql "$DB_URL" -c "EXPLAIN ANALYZE $1"
}

adapter::export() {
  _pg::need || return 1
  local fmt="$1" sql="$2" out="${3:-export-$(date +%Y%m%d-%H%M%S).$fmt}"
  case "$fmt" in
    csv)  psql "$DB_URL" -c "COPY ($sql) TO STDOUT WITH CSV HEADER" > "$out" ;;
    json) psql "$DB_URL" -tAc "$sql" --json > "$out" ;;
    *)    db::err "format: csv or json"; return 1 ;;
  esac
  [[ -s "$out" ]] && db::ok "exported: $out" || { rm -f "$out"; db::err "empty result"; return 1; }
}

adapter::copy() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  psql "$DB_URL" -c "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}

adapter::truncate() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "TRUNCATE TABLE $1" && db::ok "truncated: $1"
}
