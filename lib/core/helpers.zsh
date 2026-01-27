# db - Helper utilities
# Common functions used across modules

# Output helpers
db::err()  { echo "${C_RED}error${C_RESET}: $*" >&2; }
db::warn() { echo "${C_YELLOW}warn${C_RESET}: $*" >&2; }
db::ok()   { [[ $DB_QUIET -eq 0 ]] && echo "${C_GREEN}ok${C_RESET}: $*"; }
db::log()  { [[ $DB_QUIET -eq 0 ]] && echo "$*"; }
db::dbg()  { [[ $DB_VERBOSE -eq 1 ]] && echo "${C_DIM}$*${C_RESET}"; }

# Enhanced error with diagnostic hints
db::err_diagnostic() {
  local error_msg="$1"
  shift
  
  db::err "$error_msg"
  
  # Show diagnostic hints
  for hint in "$@"; do
    echo "${C_DIM}  → $hint${C_RESET}" >&2
  done
}

# Get editor (runtime resolution)
db::editor() {
  # Priority: DB_EDITOR > VISUAL > EDITOR > nvim > vim
  if [[ -n "$DB_EDITOR" ]]; then
    echo "$DB_EDITOR"
  elif [[ -n "$VISUAL" ]]; then
    echo "$VISUAL"
  elif [[ -n "$EDITOR" ]]; then
    echo "$EDITOR"
  elif command -v nvim &>/dev/null; then
    echo "nvim"
  else
    echo "vim"
  fi
}

# Check tool availability
db::need() {
  local tool="$1" install="$2"
  command -v "$tool" &>/dev/null && return 0
  db::err "$tool not found. Install: $install"
  return 1
}

# Retry a command with exponential backoff
# Usage: db::retry <max_attempts> <command> [args...]
db::retry() {
  local max_attempts="$1"
  shift
  local attempt=1
  local delay=1
  
  while [[ $attempt -le $max_attempts ]]; do
    if "$@"; then
      return 0
    fi
    
    if [[ $attempt -lt $max_attempts ]]; then
      db::dbg "attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))  # Exponential backoff
      [[ $delay -gt 30 ]] && delay=30  # Cap at 30 seconds
    fi
    
    ((attempt++))
  done
  
  db::err "failed after $max_attempts attempts"
  return 1
}

# Mask password in URL
db::mask() {
  echo "$1" | sed -E 's|://([^:]+):([^@]+)@|://\1:***@|g'
}

# Parse database URL into components (prevents password exposure in process list)
# Usage: eval $(db::parse_url_safe "$DB_URL")
# Sets: DB_SCHEME, DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME
db::parse_url_safe() {
  local url="$1"
  
  # Extract scheme (postgres, mysql, sqlite, mongodb)
  local scheme="${url%%://*}"
  
  # Extract everything after scheme://
  local rest="${url#*://}"
  
  # Check for credentials
  local creds="" host_part=""
  if [[ "$rest" =~ @ ]]; then
    creds="${rest%%@*}"
    host_part="${rest#*@}"
  else
    host_part="$rest"
  fi
  
  # Parse credentials
  local user="" pass=""
  if [[ -n "$creds" ]]; then
    user="${creds%%:*}"
    pass="${creds#*:}"
  fi
  
  # Parse host:port/database
  local host="" port="" dbname=""
  local host_db="${host_part%%\?*}"  # Strip query params
  
  # For SQLite, path is the database
  if [[ "$scheme" == "sqlite" ]]; then
    dbname="${host_db#/}"
  else
    # Extract database name
    if [[ "$host_db" =~ / ]]; then
      dbname="${host_db##*/}"
      host_db="${host_db%/*}"
    fi
    
    # Extract host and port
    if [[ "$host_db" =~ : ]]; then
      host="${host_db%%:*}"
      port="${host_db##*:}"
    else
      host="$host_db"
    fi
  fi
  
  # Output as eval-able assignments
  echo "DB_SCHEME='$scheme'"
  echo "DB_USER='$user'"
  echo "DB_PASS='$pass'"
  echo "DB_HOST='$host'"
  echo "DB_PORT='$port'"
  echo "DB_NAME='$dbname'"
}

# Validate SQL identifier (prevents injection)
db::valid_id() {
  [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { db::err "invalid identifier: $1"; return 1; }
}

# Note: Numeric validation functions moved to base.zsh
# Use base::valid_num() and base::valid_range() instead
# Keeping these as aliases for backward compatibility
db::valid_num() { base::valid_num "$@"; }
db::valid_range() { base::valid_range "$@"; }

# FZF table picker (used when no table arg provided)
db::fzf_table() {
  command -v fzf &>/dev/null || return 1
  adapter::tables_plain 2>/dev/null | fzf --prompt="table> " --height=40%
}

# FZF profile picker
db::fzf_profile() {
  command -v fzf &>/dev/null || return 1
  [[ ${#DB_PROFILES[@]} -eq 0 ]] && return 1
  printf '%s\n' "${(k)DB_PROFILES[@]}" | fzf --prompt="profile> " --height=40%
}

# Time a command and optionally show duration
db::timed() {
  if [[ "$DB_SHOW_QUERY_TIME" == "true" ]]; then
    local start=$(date +%s%3N)
    "$@"
    local rc=$?
    local end=$(date +%s%3N)
    local ms=$((end - start))
    if ((ms >= 1000)); then
      echo "${C_DIM}($(printf '%.2f' $(echo "scale=2; $ms/1000" | bc))s)${C_RESET}"
    else
      echo "${C_DIM}(${ms}ms)${C_RESET}"
    fi
    return $rc
  else
    "$@"
  fi
}

# Show progress indicator for long-running operations
# Usage: db::progress "message" & pid=$!; <long_operation>; kill $pid 2>/dev/null
db::progress() {
  local message="${1:-Working}"
  [[ $DB_QUIET -eq 1 ]] && return
  
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local frame=0
  
  while true; do
    printf "\r${C_BLUE}${frames[$frame]}${C_RESET} $message..." >&2
    frame=$(( (frame + 1) % ${#frames[@]} ))
    sleep 0.1
  done
}

# Run command with progress indicator
# Usage: db::with_progress "Loading data" command arg1 arg2
db::with_progress() {
  local message="$1"
  shift
  
  if [[ $DB_QUIET -eq 1 ]] || [[ ! -t 2 ]]; then
    # No progress in quiet mode or non-terminal
    "$@"
    return $?
  fi
  
  db::progress "$message" & 
  local progress_pid=$!
  
  # Run the command
  "$@"
  local rc=$?
  
  # Stop progress indicator
  kill $progress_pid 2>/dev/null
  wait $progress_pid 2>/dev/null
  printf "\r\033[K" >&2  # Clear the progress line
  
  return $rc
}

# Dry-run mode: show what would be executed without doing it
db::dry_run() {
  local operation="$1"
  shift
  
  if [[ $DB_DRY_RUN -eq 1 ]]; then
    echo "${C_YELLOW}[DRY RUN]${C_RESET} Would execute: $operation"
    for arg in "$@"; do
      echo "${C_DIM}  → $arg${C_RESET}"
    done
    return 1  # Return non-zero to prevent actual execution
  fi
  return 0  # Continue with actual execution
}

# Require table argument with optional fzf fallback
db::require_table() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: ${2:-db <command> <table>}"
    return 1
  }
  echo "$table"
}

# Confirm destructive action
db::confirm() {
  local action="$1"
  
  # Skip confirmation in dry-run mode (just preview)
  [[ $DB_DRY_RUN -eq 1 ]] && return 0
  
  [[ "$DB_CONFIRM_DESTRUCTIVE" != "true" ]] && return 0
  [[ $DB_QUIET -eq 1 ]] && return 0
  echo -n "$action? [y/N] "
  read -r ans
  [[ "$ans" == [yY] ]]
}

# Lazy load a command module
db::load_module() {
  local module="$1"
  [[ -n "${DB_LOADED_MODULES[$module]}" ]] && return 0

  local module_file="$DB_COMMANDS_DIR/${module}.zsh"
  [[ ! -f "$module_file" ]] && { db::err "module not found: $module"; return 1; }

  source "$module_file"
  DB_LOADED_MODULES[$module]=1
  db::dbg "loaded module: $module"
}

# Query cancellation support
# Stores current backend PID for query cancellation
typeset -g DB_CURRENT_PID=""

# Setup SIGINT trap for query cancellation
db::setup_cancel_trap() {
  trap 'db::cancel_query' INT
}

# Cancel running query
db::cancel_query() {
  if [[ -n "$DB_CURRENT_PID" ]]; then
    db::warn "cancelling query (PID: $DB_CURRENT_PID)..."
    
    # Database-specific cancellation
    case "$DB_TYPE" in
      postgres|postgresql)
        # Use pg_cancel_backend for graceful cancellation
        _pg::exec -c "SELECT pg_cancel_backend($DB_CURRENT_PID)" &>/dev/null
        ;;
      mysql)
        # Use KILL QUERY for MySQL
        mysql "$DB_URL" -e "KILL QUERY $DB_CURRENT_PID" &>/dev/null
        ;;
      *)
        # Fallback: kill the process
        kill -INT "$DB_CURRENT_PID" 2>/dev/null
        ;;
    esac
    
    DB_CURRENT_PID=""
    echo ""  # New line after ^C
    return 130  # Standard exit code for SIGINT
  fi
}

# Load adapter for database type
db::load_adapter() {
  local type="$1"

  # Check for modular adapter first
  local adapter_init="$DB_ADAPTERS_DIR/${type}/init.zsh"
  if [[ -f "$adapter_init" ]]; then
    source "$adapter_init"
    return 0
  fi

  # Fall back to single-file adapter
  local adapter="$DB_ADAPTERS_DIR/${type}.zsh"
  [[ ! -f "$adapter" ]] && { db::err "no adapter for: $type"; return 1; }
  source "$adapter"
}

# Load plugins from plugins directory
db::load_plugins() {
  [[ ! -d "$DB_PLUGINS_DIR" ]] && return 0

  for plugin in "$DB_PLUGINS_DIR"/*.zsh(N); do
    db::dbg "loading plugin: ${plugin:t}"
    source "$plugin"
  done
}
