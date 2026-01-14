# db - Core initialization
# Adapter-based architecture for clean database abstraction

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

# State (set by db::init)
typeset -g DB_URL=""
typeset -g DB_TYPE=""
typeset -g DB_VERBOSE=0
typeset -g DB_QUIET=0

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

# Parse DATABASE_URL from env file
db::parse_url() {
  local env_file="${1:-.env}"
  [[ ! -f "$env_file" ]] && { db::err "file not found: $env_file"; return 1; }

  local url=$(grep -E '^[^#]*DATABASE_URL=' "$env_file" 2>/dev/null | \
    head -1 | cut -d= -f2- | \
    sed 's/?schema=[^&]*//g;s/&schema=[^&]*//g' | \
    tr -d '"'"'")

  [[ -z "$url" ]] && { db::err "DATABASE_URL not found in $env_file"; return 1; }
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
#   adapter::cli        - Open interactive CLI
#   adapter::native     - Open native client with args
#   adapter::query      - Execute SQL
#   adapter::tables     - List tables
#   adapter::schema     - Show table schema
#   adapter::count      - Count rows
#   adapter::test       - Test connection
#   adapter::stats      - Show statistics
#   adapter::dump       - Backup database
#   adapter::restore    - Restore from backup
