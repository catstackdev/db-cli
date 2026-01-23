# PostgreSQL adapter - Core
# Connection, CLI, basic operations

# Helper: check psql is available
_pg::need() {
  db::need psql "brew install postgresql@16"
}

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
  _pg::need || return 1
  psql "$DB_URL" "$@"
}

adapter::test() {
  _pg::need || return 1
  psql "$DB_URL" -c "SELECT 1" &>/dev/null && db::ok "connected" || { db::err "connection failed"; return 1; }
}

adapter::dbs() {
  _pg::need || return 1
  psql "$DB_URL" -c '\l'
}

adapter::stats() {
  _pg::need || return 1
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
  _pg::need || return 1
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

adapter::dump() {
  db::need pg_dump "brew install postgresql@16" || return 1
  [[ -d "$DB_BACKUP_DIR" ]] || mkdir -p "$DB_BACKUP_DIR"
  local out="$DB_BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"
  pg_dump "$DB_URL" > "$out" && db::ok "saved: $out" || { db::err "dump failed"; return 1; }
}

adapter::restore() {
  _pg::need || return 1
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  psql "$DB_URL" < "$1" && db::ok "restored: $1"
}

adapter::exec() {
  _pg::need || return 1
  psql "$DB_URL" < "$1"
}

# Transaction support
adapter::tx_begin() {
  _pg::need || return 1
  psql "$DB_URL" -c "BEGIN" >/dev/null
}

adapter::tx_commit() {
  _pg::need || return 1
  psql "$DB_URL" -c "COMMIT" >/dev/null
}

adapter::tx_rollback() {
  _pg::need || return 1
  psql "$DB_URL" -c "ROLLBACK" >/dev/null
}

# Load sub-modules
source "${0:A:h}/query.zsh"
source "${0:A:h}/schema.zsh"
source "${0:A:h}/maintenance.zsh"
source "${0:A:h}/data.zsh"
