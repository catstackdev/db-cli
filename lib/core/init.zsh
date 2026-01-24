# db - Core initialization
# Constants, colors, state variables

readonly DB_VERSION="2.2.0"

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
readonly DB_LIB_DIR="${0:A:h:h}"
readonly DB_CORE_DIR="$DB_LIB_DIR/core"
readonly DB_COMMANDS_DIR="$DB_LIB_DIR/commands"
readonly DB_ADAPTERS_DIR="$DB_LIB_DIR/adapters"
readonly DB_GLOBAL_RC="${XDG_CONFIG_HOME:-$HOME/.config}/db/.dbrc"
readonly DB_PROJECT_RC=".dbrc"
readonly DB_PLUGINS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/db/plugins"

# State (set by db::init)
typeset -g DB_URL=""
typeset -g DB_TYPE=""
typeset -g DB_VERBOSE=0
typeset -g DB_QUIET=0
typeset -g DB_DRY_RUN=0

# Track loaded modules for lazy loading
typeset -gA DB_LOADED_MODULES=()

# Error codes (standardized)
readonly DB_ERR_SUCCESS=0
readonly DB_ERR_USER=1      # User error (bad input, missing args)
readonly DB_ERR_DB=2        # Database error (connection, query failed)
readonly DB_ERR_NOTFOUND=3  # Not found (table, column, etc)
