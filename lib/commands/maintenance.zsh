# db - Maintenance commands
# @commands: vacuum, analyze, locks, kill, slowlog

cmd::vacuum() {
  local table="$1"
  if [[ -n "$table" ]]; then
    db::valid_id "$table" || return 1
    
    if ! db::dry_run "VACUUM table" \
      "Table: $table" \
      "Reclaims storage and optimizes table"; then
      return 0
    fi
    
    db::confirm "vacuum $table" || { echo "cancelled"; return 1; }
  else
    if ! db::dry_run "VACUUM all tables" \
      "Reclaims storage across entire database" \
      "May take significant time on large databases"; then
      return 0
    fi
    
    db::confirm "vacuum all tables" || { echo "cancelled"; return 1; }
  fi
  adapter::vacuum "$table"
}

cmd::analyze() {
  local table="$1"
  if [[ -n "$table" ]]; then
    db::valid_id "$table" || return 1
  fi
  adapter::analyze "$table"
}

cmd::locks() {
  adapter::locks
}

cmd::kill() {
  [[ -z "$1" ]] && {
    echo "usage: db kill <pid>"
    return 1
  }
  
  if ! db::dry_run "KILL connection/query" \
    "PID: $1" \
    "Terminates the connection or running query"; then
    return 0
  fi
  
  db::confirm "kill connection $1" || { echo "cancelled"; return 1; }
  adapter::kill "$1"
}

cmd::slowlog() {
  adapter::slowlog "${1:-10}"
}
