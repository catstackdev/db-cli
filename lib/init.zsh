# db - Core initialization
# Adapter-based architecture for clean database abstraction

readonly DB_VERSION="1.3.0"

# Colors (disable with NO_COLOR=1)
if [[ -z "${NO_COLOR:-}" ]]; then
  readonly C_RED=$'\e[31m'
  readonly C_GREEN=$'\e[32m'
  readonly C_YELLOW=$'\e[33m'
  readonly C_BLUE=$'\e[34m'
  readonly C_DIM=$'\e[2m'
  readonly C_RESET=$'\e[0m'
else
  readonly C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_DIM="" C_RESET=""
fi

# Paths
readonly DB_LIB_DIR="${0:A:h}"
readonly DB_ADAPTERS_DIR="$DB_LIB_DIR/adapters"
readonly DB_GLOBAL_RC="${XDG_CONFIG_HOME:-$HOME/.config}/db/.dbrc"
readonly DB_PROJECT_RC=".dbrc"

# State (set by db::init)
typeset -g DB_URL=""
typeset -g DB_TYPE=""
typeset -g DB_VERBOSE=0
typeset -g DB_QUIET=0

# Config defaults (can be overridden in .dbrc)
typeset -g DB_URL_VAR="DATABASE_URL"
typeset -g DB_ENV_FILE=".env"
typeset -g DB_BACKUP_DIR="."
typeset -g DB_HISTORY_FILE="$HOME/.db_history"
typeset -g DB_HISTORY_SIZE=1000
typeset -g DB_SAMPLE_LIMIT=10
typeset -g DB_PAGER="${PAGER:-less -S}"
# typeset -g DB_EDITOR="${EDITOR:-vim}"
typeset -g DB_EDITOR="${VISUAL:-${EDITOR:-nvim}}"
typeset -g DB_SCHEMA="public"
typeset -g DB_FORMAT="table"
typeset -g DB_BOOKMARKS_FILE="$HOME/.db_bookmarks"

# Profiles (named connections)
typeset -gA DB_PROFILES=()

# Load config: global first, then project (project overrides)
db::load_config() {
  [[ -f "$DB_GLOBAL_RC" ]] && source "$DB_GLOBAL_RC"
  [[ -f "$DB_PROJECT_RC" ]] && source "$DB_PROJECT_RC"
}

# Output helpers
db::err()  { echo "${C_RED}error${C_RESET}: $*" >&2; }
db::warn() { echo "${C_YELLOW}warn${C_RESET}: $*" >&2; }
db::ok()   { [[ $DB_QUIET -eq 0 ]] && echo "${C_GREEN}ok${C_RESET}: $*"; }
db::log()  { [[ $DB_QUIET -eq 0 ]] && echo "$*"; }
db::dbg()  { [[ $DB_VERBOSE -eq 1 ]] && echo "${C_DIM}$*${C_RESET}"; }

# Check tool availability
db::need() {
  local tool="$1" install="$2"
  command -v "$tool" &>/dev/null && return 0
  db::err "$tool not found. Install: $install"
  return 1
}

# Mask password in URL
db::mask() {
  echo "$1" | sed -E 's|://([^:]+):([^@]+)@|://\1:***@|g'
}

# Validate SQL identifier (prevents injection)
db::valid_id() {
  [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { db::err "invalid identifier: $1"; return 1; }
}

# FZF table picker (used when no table arg provided)
db::fzf_table() {
  command -v fzf &>/dev/null || return 1
  adapter::tables_plain 2>/dev/null | fzf --prompt="table> " --height=40%
}

# Pipe through pager if output is long
db::pager() {
  if [[ -t 1 ]] && [[ -n "$DB_PAGER" ]]; then
    eval "$DB_PAGER"
  else
    cat
  fi
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

# Parse URL from env file (uses DB_URL_VAR for variable name)
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

# Load adapter for database type
db::load_adapter() {
  local type="$1"
  local adapter="$DB_ADAPTERS_DIR/${type}.zsh"

  [[ ! -f "$adapter" ]] && { db::err "no adapter for: $type"; return 1; }
  source "$adapter"
}

# Adapter interface - these must be implemented by each adapter:
#
#   adapter::cli          - Open interactive CLI
#   adapter::native       - Open native client with args
#   adapter::query        - Execute SQL
#   adapter::tables       - List tables (formatted)
#   adapter::tables_plain - List tables (one per line, for fzf)
#   adapter::schema       - Show table schema
#   adapter::count        - Count rows
#   adapter::sample       - Preview first N rows
#   adapter::test         - Test connection
#   adapter::stats        - Show statistics
#   adapter::dump         - Backup database
#   adapter::restore      - Restore from backup
#   adapter::truncate     - Clear table data
#   adapter::exec         - Execute SQL file
