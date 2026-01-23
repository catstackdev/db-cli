# db - Helper utilities
# Common functions used across modules

# Output helpers
db::err()  { echo "${C_RED}error${C_RESET}: $*" >&2; }
db::warn() { echo "${C_YELLOW}warn${C_RESET}: $*" >&2; }
db::ok()   { [[ $DB_QUIET -eq 0 ]] && echo "${C_GREEN}ok${C_RESET}: $*"; }
db::log()  { [[ $DB_QUIET -eq 0 ]] && echo "$*"; }
db::dbg()  { [[ $DB_VERBOSE -eq 1 ]] && echo "${C_DIM}$*${C_RESET}"; }

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

# Mask password in URL
db::mask() {
  echo "$1" | sed -E 's|://([^:]+):([^@]+)@|://\1:***@|g'
}

# Validate SQL identifier (prevents injection)
db::valid_id() {
  [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { db::err "invalid identifier: $1"; return 1; }
}

# Validate numeric input
db::valid_num() {
  local num="$1"
  local name="${2:-number}"
  [[ "$num" =~ ^[0-9]+$ ]] || { db::err "invalid $name: $num"; return 1; }
}

# Validate positive number with range
db::valid_range() {
  local num="$1" min="${2:-1}" max="${3:-}"
  db::valid_num "$num" || return $?
  [[ $num -ge $min ]] || { db::err "must be >= $min"; return 1; }
  [[ -z "$max" || $num -le $max ]] || { db::err "must be <= $max"; return 1; }
}

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

# Confirm destructive action
db::confirm() {
  local action="$1"
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
