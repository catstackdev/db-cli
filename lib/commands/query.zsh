# db - Query commands
# @commands: query, explain, watch, edit, last

cmd::query() {
  [[ -z "$1" ]] && {
    echo "usage: db query <sql>"
    return 1
  }
  
  # Use timed query with history recording if history module loaded
  if typeset -f history::record &>/dev/null; then
    cmd::query_timed "$1"
  else
    # Fallback to simple history
    echo "[$(date '+%Y-%m-%d %H:%M')] $1" >>"$DB_HISTORY_FILE"
    if [[ -f "$DB_HISTORY_FILE" ]] && (($(wc -l <"$DB_HISTORY_FILE") > DB_HISTORY_SIZE)); then
      tail -n "$DB_HISTORY_SIZE" "$DB_HISTORY_FILE" >"${DB_HISTORY_FILE}.tmp" && mv "${DB_HISTORY_FILE}.tmp" "$DB_HISTORY_FILE"
    fi
    adapter::query "$1"
  fi
}

cmd::explain() {
  [[ -z "$1" ]] && {
    echo "usage: db explain <sql>"
    return 1
  }
  adapter::explain "$1"
}

cmd::watch() {
  [[ -z "$1" ]] && {
    echo "usage: db watch <sql> [interval]"
    return 1
  }
  local sql="$1" interval="${2:-2}"
  while true; do
    clear
    echo "${C_DIM}$sql | every ${interval}s | $(date '+%H:%M:%S')${C_RESET}"
    echo "---"
    adapter::query "$sql"
    sleep "$interval"
  done
}

cmd::edit() {
  local tmpfile=$(mktemp "$DB_TMP_DIR/db-query.XXXXXX.sql")
  # Pre-fill with last query if exists
  if [[ -f "$DB_HISTORY_FILE" ]]; then
    tail -1 "$DB_HISTORY_FILE" | sed 's/^\[[^]]*\] //' >"$tmpfile"
  fi
  "$(db::editor)" "$tmpfile"
  if [[ -s "$tmpfile" ]]; then
    local sql=$(cat "$tmpfile")
    db::log "executing..."
    cmd::query "$sql"
  fi
  rm -f "$tmpfile"
}

cmd::last() {
  [[ ! -f "$DB_HISTORY_FILE" ]] && {
    db::err "no history"
    return 1
  }
  local sql=$(tail -1 "$DB_HISTORY_FILE" | sed 's/^\[[^]]*\] //')
  db::log "re-running: $sql"
  adapter::query "$sql"
}
