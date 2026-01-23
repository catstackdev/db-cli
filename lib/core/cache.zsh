#!/usr/bin/env zsh
# db - Cache system for performance optimization

# Cache directory (created on demand)
readonly DB_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/db"
typeset -g DB_CACHE_ENABLED="${DB_CACHE_ENABLED:-true}"
typeset -g DB_CACHE_TTL="${DB_CACHE_TTL:-300}"  # 5 minutes default

# Get cache key for current connection
db::cache_key() {
  local suffix="$1"
  local url_hash=$(echo "$DB_URL" | shasum -a 256 | cut -d' ' -f1 | cut -c1-16)
  echo "${DB_TYPE}_${url_hash}_${suffix}"
}

# Get cache file path
db::cache_file() {
  local key=$(db::cache_key "$1")
  echo "$DB_CACHE_DIR/$key"
}

# Check if cache exists and is fresh
db::cache_valid() {
  [[ "$DB_CACHE_ENABLED" != "true" ]] && return 1
  local file=$(db::cache_file "$1")
  [[ ! -f "$file" ]] && return 1
  
  local age=$(($(date +%s) - $(stat -f %m "$file" 2>/dev/null || echo 0)))
  [[ $age -lt $DB_CACHE_TTL ]]
}

# Get cached value
db::cache_get() {
  local key="$1"
  db::cache_valid "$key" || return 1
  cat "$(db::cache_file "$key")"
}

# Set cached value
db::cache_set() {
  local key="$1"
  [[ "$DB_CACHE_ENABLED" != "true" ]] && return 0
  mkdir -p "$DB_CACHE_DIR" 2>/dev/null || return 1
  cat > "$(db::cache_file "$key")"
}

# Clear cache for current connection
db::cache_clear() {
  local pattern="$1"
  if [[ -n "$pattern" ]]; then
    local key=$(db::cache_key "$pattern")
    rm -f "$DB_CACHE_DIR/$key"* 2>/dev/null
  elif [[ -n "$DB_URL" ]]; then
    local url_hash=$(echo "$DB_URL" | shasum -a 256 | cut -d' ' -f1 | cut -c1-16)
    rm -f "$DB_CACHE_DIR/${DB_TYPE}_${url_hash}_"* 2>/dev/null
  else
    # No DB_URL, clear all cache
    rm -f "$DB_CACHE_DIR"/* 2>/dev/null
  fi
  db::ok "cache cleared"
}

# Clear all cache
db::cache_clear_all() {
  rm -rf "$DB_CACHE_DIR" 2>/dev/null
  db::ok "all cache cleared"
}

# Cached table list
db::cache_tables() {
  local cache="tables"
  if db::cache_valid "$cache"; then
    db::cache_get "$cache"
  else
    adapter::tables_plain | db::cache_set "$cache"
    db::cache_get "$cache"
  fi
}

# Cached schema
db::cache_schema() {
  local table="$1"
  local cache="schema_$table"
  if db::cache_valid "$cache"; then
    db::cache_get "$cache"
  else
    adapter::schema "$table" | db::cache_set "$cache"
    db::cache_get "$cache"
  fi
}
