# db - Query commands
# @commands: query, explain, watch, edit, last, history

cmd::query() {
  [[ -z "$1" ]] && {
    echo "usage: db query <sql>"
    return 1
  }
  echo "[$(date '+%Y-%m-%d %H:%M')] $1" >>"$DB_HISTORY_FILE"
  # Trim history if too large
  if [[ -f "$DB_HISTORY_FILE" ]] && (($(wc -l <"$DB_HISTORY_FILE") > DB_HISTORY_SIZE)); then
    tail -n "$DB_HISTORY_SIZE" "$DB_HISTORY_FILE" >"${DB_HISTORY_FILE}.tmp" && mv "${DB_HISTORY_FILE}.tmp" "$DB_HISTORY_FILE"
  fi
  adapter::query "$1"
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
  local tmpfile=$(mktemp /tmp/db-query.XXXXXX.sql)
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

cmd::history() {
  local n="${1:-20}"
  [[ -f "$DB_HISTORY_FILE" ]] && tail -n "$n" "$DB_HISTORY_FILE" || echo "no history"
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

cmd::migrate() {
  if [[ -f package.json ]] && grep -q prisma package.json 2>/dev/null; then
    db::log "running prisma migrate..."
    command -v pnpm &>/dev/null && pnpm prisma migrate deploy || npx prisma migrate deploy
  elif [[ -f drizzle.config.ts || -f drizzle.config.js ]]; then
    db::log "running drizzle push..."
    command -v pnpm &>/dev/null && pnpm drizzle-kit push || npx drizzle-kit push
  elif [[ -d migrations ]]; then
    db::log "migrations/ found - run your tool manually"
    ls migrations/
  else
    db::err "no migration tool detected"
    return 1
  fi
}
