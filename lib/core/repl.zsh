#!/usr/bin/env zsh
# db - Interactive REPL

readonly REPL_HISTORY="${XDG_CACHE_HOME:-$HOME/.cache}/db/repl_history"
typeset -g REPL_BUFFER=""
typeset -g REPL_MULTILINE=0

# Initialize REPL
repl::init() {
  mkdir -p "$(dirname "$REPL_HISTORY")" 2>/dev/null
  
  # Setup readline if available
  if command -v rlwrap &>/dev/null; then
    export RLWRAP_HISTFILE="$REPL_HISTORY"
  fi
  
  echo "${C_BLUE}db repl${C_RESET} v$DB_VERSION - Interactive mode"
  echo "Type ${C_DIM}:help${C_RESET} for commands, ${C_DIM}:exit${C_RESET} to quit"
  echo "Connected: ${C_GREEN}$DB_TYPE${C_RESET} - $(db::mask "$DB_URL")"
  echo ""
}

# Main REPL loop
repl::run() {
  repl::init
  
  while true; do
    local prompt="db> "
    [[ $REPL_MULTILINE -eq 1 ]] && prompt="  -> "
    
    # Read input
    echo -n "$prompt"
    local line
    read -r line || break
    
    # Trim whitespace
    line="${line## }"
    line="${line%% }"
    
    # Skip empty lines
    [[ -z "$line" ]] && continue
    
    # Handle special commands
    if [[ "$line" == :* ]]; then
      repl::command "${line#:}"
      continue
    fi
    
    # Build query buffer
    REPL_BUFFER+="$line "
    
    # Check if statement complete (ends with semicolon)
    if [[ "$line" == *\; ]]; then
      repl::execute "$REPL_BUFFER"
      REPL_BUFFER=""
      REPL_MULTILINE=0
    else
      REPL_MULTILINE=1
    fi
  done
  
  echo ""
  echo "Goodbye!"
}

# Execute query
repl::execute() {
  local query="$1"
  query="${query%;}"  # Remove trailing semicolon
  
  [[ -z "$query" ]] && return 0
  
  # Save to history
  echo "$query" >> "$REPL_HISTORY"
  
  # Execute with timing
  local start=$(date +%s%3N)
  local output=$(adapter::query "$query" 2>&1)
  local exit_code=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  echo "$output"
  
  if [[ $exit_code -eq 0 ]]; then
    local rows=$(echo "$output" | wc -l | tr -d ' ')
    if ((duration >= 1000)); then
      echo "${C_DIM}($(echo "scale=2; $duration/1000" | bc)s, $rows rows)${C_RESET}"
    else
      echo "${C_DIM}(${duration}ms, $rows rows)${C_RESET}"
    fi
  fi
  echo ""
}

# Handle special commands
repl::command() {
  local cmd="$1"
  
  case "$cmd" in
    help|h)
      repl::help
      ;;
    tables|t)
      adapter::tables
      echo ""
      ;;
    exit|quit|q)
      exit 0
      ;;
    clear|c)
      clear
      repl::init
      ;;
    save)
      repl::save
      ;;
    history|hist)
      tail -20 "$REPL_HISTORY"
      echo ""
      ;;
    *)
      echo "Unknown command: :$cmd (try :help)"
      echo ""
      ;;
  esac
}

# Show REPL help
repl::help() {
  cat <<EOF
${C_BLUE}=== REPL Commands ===${C_RESET}

  :help, :h        Show this help
  :tables, :t      List tables
  :clear, :c       Clear screen
  :save            Save current buffer as bookmark
  :history, :hist  Show command history
  :exit, :quit, :q Exit REPL

${C_BLUE}=== SQL Editing ===${C_RESET}

  - Multi-line: press Enter without semicolon
  - Execute: end statement with semicolon
  - Cancel: Ctrl+C

${C_BLUE}=== Examples ===${C_RESET}

  SELECT * FROM users;
  SELECT id, name
    FROM users
    WHERE status = 'active';

EOF
}

# Save buffer as bookmark
repl::save() {
  [[ -z "$REPL_BUFFER" ]] && { echo "Buffer empty"; echo ""; return 1; }
  
  echo -n "Bookmark name: "
  local name
  read -r name
  
  [[ -z "$name" ]] && { echo "Cancelled"; echo ""; return 1; }
  
  echo "$name|$REPL_BUFFER" >> "$DB_BOOKMARKS_FILE"
  echo "${C_GREEN}Saved:${C_RESET} $name"
  echo ""
  
  REPL_BUFFER=""
  REPL_MULTILINE=0
}
