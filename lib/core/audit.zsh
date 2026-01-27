# db - Audit logging
# Track destructive operations for security and compliance

# Audit log file location
readonly DB_AUDIT_LOG="${XDG_DATA_HOME:-$HOME/.local/share}/db/audit.log"

# Initialize audit log with secure permissions
audit::init() {
  local audit_dir="$(dirname "$DB_AUDIT_LOG")"
  [[ -d "$audit_dir" ]] || mkdir -p "$audit_dir"
  chmod 700 "$audit_dir"
  
  if [[ ! -f "$DB_AUDIT_LOG" ]]; then
    touch "$DB_AUDIT_LOG"
    chmod 600 "$DB_AUDIT_LOG"
  fi
}

# Log destructive operation
# Usage: audit::log "operation" "target" "details"
audit::log() {
  local operation="$1"
  local target="$2"
  local details="${3:-}"
  
  # Skip if audit logging is disabled
  [[ "${DB_AUDIT_ENABLED:-true}" != "true" ]] && return 0
  
  # Ensure audit log exists
  audit::init
  
  # Log entry format: ISO8601_timestamp|user|db_type|db_name|operation|target|details
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local user="${USER:-unknown}"
  local db_name="${DB_NAME:-unknown}"
  
  echo "$timestamp|$user|$DB_TYPE|$db_name|$operation|$target|$details" >> "$DB_AUDIT_LOG"
  
  db::dbg "audit: $operation on $target"
}

# Show audit log (last N entries)
audit::show() {
  local limit="${1:-20}"
  
  [[ ! -f "$DB_AUDIT_LOG" ]] && {
    echo "No audit log found"
    return 0
  }
  
  echo "${C_BLUE}=== Audit Log (last $limit entries) ===${C_RESET}"
  echo "Timestamp|User|Type|Database|Operation|Target|Details"
  echo "---------|----|----|--------|---------|------|-------"
  tail -n "$limit" "$DB_AUDIT_LOG"
}

# Search audit log
audit::search() {
  local pattern="$1"
  
  [[ ! -f "$DB_AUDIT_LOG" ]] && {
    echo "No audit log found"
    return 0
  }
  
  echo "${C_BLUE}=== Audit Log Search: $pattern ===${C_RESET}"
  grep -i "$pattern" "$DB_AUDIT_LOG" | tail -20
}

# Filter audit log by operation type
audit::filter() {
  local operation="$1"
  
  [[ ! -f "$DB_AUDIT_LOG" ]] && {
    echo "No audit log found"
    return 0
  }
  
  echo "${C_BLUE}=== Audit Log: $operation operations ===${C_RESET}"
  awk -F'|' -v op="$operation" '$5 == op' "$DB_AUDIT_LOG" | tail -20
}

# Export audit log to JSON
audit::export_json() {
  [[ ! -f "$DB_AUDIT_LOG" ]] && {
    echo "[]"
    return 0
  }
  
  echo "["
  local first=true
  while IFS='|' read -r timestamp user db_type db_name operation target details; do
    [[ "$first" == "true" ]] && first=false || echo ","
    cat <<EOF
  {
    "timestamp": "$timestamp",
    "user": "$user",
    "db_type": "$db_type",
    "database": "$db_name",
    "operation": "$operation",
    "target": "$target",
    "details": "$details"
  }
EOF
  done < "$DB_AUDIT_LOG"
  echo "]"
}
