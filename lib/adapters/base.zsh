#!/usr/bin/env zsh
# db - Base adapter with common functions
# Shared functionality for all database adapters

# === Common Validation ===

# Validate numeric input
base::valid_num() {
  local num="$1"
  local name="${2:-number}"
  [[ "$num" =~ ^[0-9]+$ ]] || { db::err "invalid $name: $num"; return $DB_ERR_USER; }
  return $DB_ERR_SUCCESS
}

# Validate positive number with optional max
base::valid_range() {
  local num="$1"
  local min="${2:-1}"
  local max="${3:-}"
  base::valid_num "$num" || return $?
  [[ $num -ge $min ]] || { db::err "must be >= $min"; return $DB_ERR_USER; }
  [[ -z "$max" || $num -le $max ]] || { db::err "must be <= $max"; return $DB_ERR_USER; }
  return $DB_ERR_SUCCESS
}

# === Query Wrapping ===

# Log query if verbose, execute via adapter
base::safe_query() {
  local sql="$1"
  [[ -z "$sql" ]] && { db::err "empty query"; return $DB_ERR_USER; }
  db::dbg "sql: $sql"
  adapter::query "$sql"
  local exit_code=$?
  [[ $exit_code -ne 0 ]] && db::err "query failed" && return $DB_ERR_DB
  return $DB_ERR_SUCCESS
}

# === Common Operations ===

# Generic table size query (override per adapter if needed)
base::generic_size() {
  local table="$1"
  db::valid_id "$table" || return $DB_ERR_USER
  echo "Table: $table"
  adapter::count "$table"
}

# Generic export handler
base::export_handler() {
  local format="$1"
  local query="$2"
  local output="${3:-}"
  
  case "$format" in
    csv) adapter::export_csv "$query" "$output" ;;
    json) adapter::export_json "$query" "$output" ;;
    *) db::err "unsupported format: $format"; return $DB_ERR_USER ;;
  esac
}

# === Helper Functions ===

# Check if table exists (override per adapter)
base::table_exists() {
  local table="$1"
  adapter::tables_plain | grep -qx "$table"
}

# Get column names for table (override per adapter)
base::columns() {
  local table="$1"
  db::valid_id "$table" || return $DB_ERR_USER
  adapter::schema "$table" | awk 'NR>2 {print $1}' | grep -v '^-' | grep -v '^$'
}

# === File Operations ===

# Check if command exists with helpful error
base::need_cmd() {
  local cmd="$1"
  local install_hint="${2:-}"
  command -v "$cmd" &>/dev/null && return $DB_ERR_SUCCESS
  db::err "$cmd not found"
  [[ -n "$install_hint" ]] && echo "${C_DIM}install: $install_hint${C_RESET}" >&2
  return $DB_ERR_USER
}

# Validate file exists and is readable
base::check_file() {
  local file="$1"
  local desc="${2:-file}"
  [[ -f "$file" ]] || { db::err "$desc not found: $file"; return $DB_ERR_NOTFOUND; }
  [[ -r "$file" ]] || { db::err "$desc not readable: $file"; return $DB_ERR_USER; }
  return $DB_ERR_SUCCESS
}

# Create directory if missing
base::ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] && return $DB_ERR_SUCCESS
  mkdir -p "$dir" 2>/dev/null || { db::err "cannot create: $dir"; return $DB_ERR_USER; }
  return $DB_ERR_SUCCESS
}

# === Transaction Support ===

# Default transaction implementations (override in adapters if needed)
base::tx_begin() {
  adapter::query "BEGIN" >/dev/null
}

base::tx_commit() {
  adapter::query "COMMIT" >/dev/null
}

base::tx_rollback() {
  adapter::query "ROLLBACK" >/dev/null
}
