#!/usr/bin/env zsh
# db - Query history management

readonly DB_HISTORY_JSON="${DB_HISTORY_FILE}.json"

# Record query execution
history::record() {
  local query="$1"
  local duration="${2:-0}"
  local rows="${3:-0}"
  local success="${4:-true}"
  
  [[ -z "$query" ]] && return 0
  [[ "$query" == "BEGIN"* || "$query" == "COMMIT"* || "$query" == "ROLLBACK"* ]] && return 0
  
  local entry=$(cat <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","query":"${query//\"/\\\"}","duration_ms":$duration,"rows":$rows,"profile":"${DB_PROFILE:-default}","type":"$DB_TYPE","success":$success}
EOF
)
  
  # Ensure history files are created with secure permissions
  local old_umask=$(umask)
  umask 077
  
  echo "$entry" >> "$DB_HISTORY_JSON"
  echo "$query" >> "$DB_HISTORY_FILE"
  
  # Fix permissions on existing files
  [[ -f "$DB_HISTORY_JSON" ]] && chmod 600 "$DB_HISTORY_JSON"
  [[ -f "$DB_HISTORY_FILE" ]] && chmod 600 "$DB_HISTORY_FILE"
  
  umask "$old_umask"
}

# Search history
history::search() {
  local pattern="$1"
  [[ ! -f "$DB_HISTORY_JSON" ]] && { db::warn "no history"; return 1; }
  
  if command -v jq &>/dev/null; then
    jq -r --arg p "$pattern" 'select(.query | contains($p)) | 
      "\(.timestamp) | \(.duration_ms)ms | \(.query)"' "$DB_HISTORY_JSON" | tail -20
  else
    grep -i "$pattern" "$DB_HISTORY_FILE" | tail -20
  fi
}

# Get slow queries
history::slow() {
  local min_ms="${1:-1000}"
  [[ ! -f "$DB_HISTORY_JSON" ]] && { db::warn "no history"; return 1; }
  
  command -v jq &>/dev/null || { db::err "requires jq"; return 1; }
  
  echo "${C_BLUE}=== Slow Queries (>${min_ms}ms) ===${C_RESET}"
  jq -r --arg ms "$min_ms" 'select(.duration_ms > ($ms|tonumber)) | 
    "\(.duration_ms)ms | \(.timestamp) | \(.query)"' "$DB_HISTORY_JSON" | 
    sort -rn | head -20
}

# Get failed queries
history::errors() {
  [[ ! -f "$DB_HISTORY_JSON" ]] && { db::warn "no history"; return 1; }
  
  command -v jq &>/dev/null || { db::err "requires jq"; return 1; }
  
  echo "${C_BLUE}=== Failed Queries ===${C_RESET}"
  jq -r 'select(.success == false) | 
    "\(.timestamp) | \(.query)"' "$DB_HISTORY_JSON" | tail -20
}

# Get statistics
history::stats() {
  [[ ! -f "$DB_HISTORY_JSON" ]] && { db::warn "no history"; return 1; }
  
  command -v jq &>/dev/null || { db::err "requires jq"; return 1; }
  
  echo "${C_BLUE}=== Query Statistics ===${C_RESET}"
  
  local total=$(jq -s 'length' "$DB_HISTORY_JSON")
  local success=$(jq -s 'map(select(.success == true)) | length' "$DB_HISTORY_JSON")
  local failed=$(jq -s 'map(select(.success == false)) | length' "$DB_HISTORY_JSON")
  local avg_ms=$(jq -s 'map(.duration_ms) | add / length | floor' "$DB_HISTORY_JSON")
  
  echo "Total:     $total"
  echo "Success:   $success"
  echo "Failed:    $failed"
  echo "Avg time:  ${avg_ms}ms"
  
  echo ""
  echo "${C_BLUE}=== Top Tables ===${C_RESET}"
  jq -r '.query' "$DB_HISTORY_JSON" | 
    grep -oiE 'FROM [a-z_][a-z0-9_]*' | 
    awk '{print $2}' | sort | uniq -c | sort -rn | head -10 | 
    while read count table; do
      echo "$table: $count queries"
    done
}

# Export history
history::export() {
  local output="${1:-history-export-$(date +%Y%m%d-%H%M%S).json}"
  [[ ! -f "$DB_HISTORY_JSON" ]] && { db::warn "no history"; return 1; }
  
  cp "$DB_HISTORY_JSON" "$output"
  db::ok "exported to: $output"
}

# Clear history
history::clear() {
  db::confirm "clear all history" || return 1
  rm -f "$DB_HISTORY_JSON" "$DB_HISTORY_FILE"
  db::ok "history cleared"
}

# Migrate old history to JSON
history::migrate() {
  [[ ! -f "$DB_HISTORY_FILE" ]] && return 0
  [[ -f "$DB_HISTORY_JSON" ]] && return 0
  
  db::log "migrating history to JSON format..."
  
  while IFS= read -r query; do
    local entry=$(cat <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","query":"${query//\"/\\\"}","duration_ms":0,"rows":0,"profile":"unknown","type":"$DB_TYPE","success":true}
EOF
)
    echo "$entry" >> "$DB_HISTORY_JSON"
  done < "$DB_HISTORY_FILE"
  
  db::ok "migrated $(wc -l < "$DB_HISTORY_FILE" | tr -d ' ') entries"
}
