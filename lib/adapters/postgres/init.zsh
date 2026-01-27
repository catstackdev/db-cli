# PostgreSQL adapter - Core
# Connection, CLI, basic operations

# Helper: check psql is available
_pg::need() {
  db::need psql "brew install postgresql@16"
}

# Helper: execute psql safely (without exposing password in process list)
# Uses connection parameters instead of full URL when credentials present
_pg::exec() {
  _pg::need || return 1
  
  # Check if URL contains credentials
  if [[ "$DB_URL" =~ ://[^@]+:[^@]+@ ]]; then
    # Parse URL to avoid password exposure
    eval $(db::parse_url_safe "$DB_URL")
    
    # Build connection parameters
    local -a conn_params=()
    [[ -n "$DB_HOST" ]] && conn_params+=(-h "$DB_HOST")
    [[ -n "$DB_PORT" ]] && conn_params+=(-p "$DB_PORT")
    [[ -n "$DB_USER" ]] && conn_params+=(-U "$DB_USER")
    [[ -n "$DB_NAME" ]] && conn_params+=(-d "$DB_NAME")
    
    # Set password via environment variable (not visible in ps)
    PGPASSWORD="$DB_PASS" psql "${conn_params[@]}" "$@"
  else
    # No credentials in URL, use it directly
    psql "$DB_URL" "$@"
  fi
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
  _pg::exec "$@"
}

adapter::test() {
  # Capture error output for diagnostics
  local error_output=$(mktemp "$DB_TMP_DIR/db-test-error.XXXXXX")
  
  # Try connection with retry logic (3 attempts)
  if db::retry 3 _pg::exec -c "SELECT 1" 2>"$error_output" >/dev/null; then
    rm -f "$error_output"
    db::ok "connected"
    return 0
  else
    # Analyze error and provide diagnostics
    local error_text=$(cat "$error_output" 2>/dev/null)
    rm -f "$error_output"
    
    if [[ "$error_text" =~ "authentication failed" ]]; then
      db::err_diagnostic "authentication failed" \
        "Check username and password in DATABASE_URL" \
        "Verify pg_hba.conf allows connection from this host"
    elif [[ "$error_text" =~ "Connection refused" || "$error_text" =~ "could not connect" ]]; then
      db::err_diagnostic "connection refused" \
        "Database server may not be running" \
        "Check: pg_ctl status" \
        "Verify host and port are correct"
    elif [[ "$error_text" =~ "database.*does not exist" ]]; then
      db::err_diagnostic "database does not exist" \
        "Create database first: createdb <dbname>" \
        "Or update DATABASE_URL with correct database name"
    elif [[ "$error_text" =~ "role.*does not exist" ]]; then
      db::err_diagnostic "user/role does not exist" \
        "Create user first: createuser <username>" \
        "Or update DATABASE_URL with correct username"
    else
      db::err "connection failed after retries"
      [[ -n "$error_text" ]] && echo "${C_DIM}$error_text${C_RESET}" >&2
    fi
    return 1
  fi
}

adapter::dbs() {
  _pg::exec -c '\l'
}

adapter::stats() {
  _pg::exec -c "
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
  local limit="${1:-10}"
  _pg::exec -c "
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
  
  # Use safe connection parameters for pg_dump as well
  if [[ "$DB_URL" =~ ://[^@]+:[^@]+@ ]]; then
    eval $(db::parse_url_safe "$DB_URL")
    local -a conn_params=()
    [[ -n "$DB_HOST" ]] && conn_params+=(-h "$DB_HOST")
    [[ -n "$DB_PORT" ]] && conn_params+=(-p "$DB_PORT")
    [[ -n "$DB_USER" ]] && conn_params+=(-U "$DB_USER")
    [[ -n "$DB_NAME" ]] && conn_params+=(-d "$DB_NAME")
    if db::with_progress "Creating backup" sh -c "PGPASSWORD=\"$DB_PASS\" pg_dump ${conn_params[*]} > \"$out\""; then
      db::ok "saved: $out"
    else
      db::err "dump failed"
      return 1
    fi
  else
    if db::with_progress "Creating backup" pg_dump "$DB_URL" > "$out"; then
      db::ok "saved: $out"
    else
      db::err "dump failed"
      return 1
    fi
  fi
}

adapter::restore() {
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  if db::with_progress "Restoring database" sh -c "_pg::exec < \"$1\""; then
    db::ok "restored: $1"
  else
    db::err "restore failed"
    return 1
  fi
}

adapter::exec() {
  _pg::exec < "$1"
}

# Transaction support
adapter::tx_begin() {
  _pg::exec -c "BEGIN" >/dev/null
}

adapter::tx_commit() {
  _pg::exec -c "COMMIT" >/dev/null
}

adapter::tx_rollback() {
  _pg::exec -c "ROLLBACK" >/dev/null
}

# Load sub-modules
source "${0:A:h}/query.zsh"
source "${0:A:h}/schema.zsh"
source "${0:A:h}/maintenance.zsh"
source "${0:A:h}/data.zsh"
