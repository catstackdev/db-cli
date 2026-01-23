#!/usr/bin/env zsh
# db - Enhanced history commands
# @commands: hist, history

cmd::history() {
  local action="${1:-list}"
  
  case "$action" in
    search|s)
      [[ -z "$2" ]] && { echo "usage: db hist search <pattern>"; return 1; }
      history::search "$2"
      ;;
    slow)
      history::slow "${2:-1000}"
      ;;
    errors|err|failed)
      history::errors
      ;;
    stats|st)
      history::stats
      ;;
    export|x)
      history::export "$2"
      ;;
    clear|c)
      history::clear
      ;;
    migrate)
      history::migrate
      ;;
    list|l|*)
      if [[ -f "$DB_HISTORY_FILE" ]]; then
        tail -20 "$DB_HISTORY_FILE"
      else
        echo "no history"
      fi
      ;;
  esac
}

# Wrapper for query execution with timing
cmd::query_timed() {
  local query="$1"
  
  local start=$(date +%s%3N)
  local output=$(adapter::query "$query" 2>&1)
  local exit_code=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  local rows=$(echo "$output" | wc -l | tr -d ' ')
  local success=true
  [[ $exit_code -ne 0 ]] && success=false
  
  history::record "$query" "$duration" "$rows" "$success"
  
  echo "$output"
  
  if [[ "$DB_SHOW_QUERY_TIME" == "true" ]]; then
    if ((duration >= 1000)); then
      echo "${C_DIM}($(echo "scale=2; $duration/1000" | bc)s, $rows rows)${C_RESET}"
    else
      echo "${C_DIM}(${duration}ms, $rows rows)${C_RESET}"
    fi
  fi
  
  return $exit_code
}
