# db - Configuration management
# Config defaults, loading, profiles

# Config defaults (can be overridden in .dbrc)
typeset -g DB_URL_VAR="DATABASE_URL"
typeset -g DB_ENV_FILE=".env"
typeset -g DB_BACKUP_DIR="."
typeset -g DB_HISTORY_FILE="$HOME/.db_history"
typeset -g DB_HISTORY_SIZE=1000
typeset -g DB_SAMPLE_LIMIT=10
typeset -g DB_PAGER="${PAGER:-less -S}"
# DB_EDITOR is resolved at runtime via db::editor function
typeset -g DB_EDITOR=""
typeset -g DB_SCHEMA="public"
typeset -g DB_FORMAT="table"
typeset -g DB_BOOKMARKS_FILE="$HOME/.db_bookmarks"

# Advanced config
typeset -g DB_AUTO_DETECT=true
typeset -g DB_CONFIRM_DESTRUCTIVE=true
typeset -g DB_SHOW_QUERY_TIME=false
typeset -g DB_COL_WIDTH=25
typeset -g DB_MAX_COLS=6

# Profiles (named connections)
typeset -gA DB_PROFILES=()

# Load config: global first, then project (project overrides)
db::load_config() {
  [[ -f "$DB_GLOBAL_RC" ]] && source "$DB_GLOBAL_RC"
  [[ -f "$DB_PROJECT_RC" ]] && source "$DB_PROJECT_RC"
}

# Get profile URL
db::get_profile() {
  local name="$1"
  [[ -n "${DB_PROFILES[$name]}" ]] && echo "${DB_PROFILES[$name]}" && return 0
  return 1
}

# List profiles
db::list_profiles() {
  for name in ${(k)DB_PROFILES}; do
    echo "$name: $(db::mask "${DB_PROFILES[$name]}")"
  done
}

# Parse URL from env file
db::parse_url() {
  local env_file="${1:-.env}"
  local var_name="${DB_URL_VAR:-DATABASE_URL}"

  [[ ! -f "$env_file" ]] && { db::err "file not found: $env_file"; return 1; }

  local url=$(grep -E "^[^#]*${var_name}=" "$env_file" 2>/dev/null | \
    head -1 | cut -d= -f2- | \
    sed 's/?schema=[^&]*//g;s/&schema=[^&]*//g' | \
    tr -d '"'"'")

  [[ -z "$url" ]] && { db::err "$var_name not found in $env_file"; return 1; }
  echo "$url"
}

# Auto-detect DATABASE_URL from common project files
db::auto_detect() {
  [[ "$DB_AUTO_DETECT" != "true" ]] && return 1

  # Try .env first
  [[ -f ".env" ]] && return 1  # Let normal flow handle it

  # Try .env.local
  if [[ -f ".env.local" ]]; then
    db::dbg "auto-detect: found .env.local"
    DB_ENV_FILE=".env.local"
    return 0
  fi

  # Try Prisma schema
  if [[ -f "prisma/schema.prisma" ]]; then
    local prisma_env=$(grep -oP 'env\("\K[^"]+' prisma/schema.prisma 2>/dev/null | head -1)
    if [[ -n "$prisma_env" ]]; then
      db::dbg "auto-detect: prisma uses env($prisma_env)"
      DB_URL_VAR="$prisma_env"
      for f in .env.local .env.development .env.dev; do
        if [[ -f "$f" ]]; then
          DB_ENV_FILE="$f"
          return 0
        fi
      done
    fi
  fi

  # Try Drizzle config
  for drizzle_conf in drizzle.config.ts drizzle.config.js drizzle.config.mjs; do
    if [[ -f "$drizzle_conf" ]]; then
      db::dbg "auto-detect: found $drizzle_conf"
      local env_var=$(grep -oE 'process\.env\.[A-Z_]+' "$drizzle_conf" 2>/dev/null | head -1 | sed 's/process.env.//')
      if [[ -n "$env_var" ]]; then
        DB_URL_VAR="$env_var"
        for f in .env.local .env.development .env; do
          if [[ -f "$f" ]]; then
            DB_ENV_FILE="$f"
            return 0
          fi
        done
      fi
    fi
  done

  # Try package.json scripts for hints
  if [[ -f "package.json" ]]; then
    for f in .env.local .env.development .env.dev .env.test; do
      if [[ -f "$f" ]]; then
        DB_ENV_FILE="$f"
        return 0
      fi
    done
  fi

  return 1
}

# Detect database type from URL
db::detect() {
  case "$1" in
    postgres://*|postgresql://*) echo "postgres" ;;
    mysql://*)                   echo "mysql" ;;
    sqlite://*|file:*|*.db)      echo "sqlite" ;;
    mongodb://*)                 echo "mongodb" ;;
    *) db::err "unknown database type"; return 1 ;;
  esac
}
