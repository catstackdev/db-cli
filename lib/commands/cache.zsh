#!/usr/bin/env zsh
# db - Cache management commands
# @commands: cache-clear, cache-info, cache-stats, refresh-cache

cmd::cache_clear() {
  local pattern="$1"
  if [[ -n "$pattern" ]]; then
    db::cache_clear "$pattern"
  else
    db::cache_clear
  fi
}

cmd::cache_clear_all() {
  db::cache_clear_all
}

cmd::cache_info() {
  echo "${C_BLUE}=== Cache Configuration ===${C_RESET}"
  echo "Enabled:  $DB_CACHE_ENABLED"
  echo "TTL:      ${DB_CACHE_TTL}s"
  echo "Location: $DB_CACHE_DIR"
  
  if [[ -d "$DB_CACHE_DIR" ]]; then
    echo ""
    echo "${C_BLUE}=== Cache Stats ===${C_RESET}"
    local count=$(find "$DB_CACHE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    local size=$(du -sh "$DB_CACHE_DIR" 2>/dev/null | cut -f1)
    echo "Files: $count"
    echo "Size:  $size"
  fi
}

cmd::refresh_cache() {
  db::log "refreshing cache..."
  db::cache_clear
  
  # Pre-warm cache
  db::cache_tables >/dev/null 2>&1
  
  db::ok "cache refreshed"
}
