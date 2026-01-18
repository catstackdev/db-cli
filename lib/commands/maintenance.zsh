# db - Maintenance commands
# @commands: vacuum, analyze, locks, kill, slowlog

cmd::vacuum() {
  local table="$1"
  if [[ -n "$table" ]]; then
    db::valid_id "$table" || return 1
    db::confirm "vacuum $table" || { echo "cancelled"; return 1; }
  else
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
  db::confirm "kill connection $1" || { echo "cancelled"; return 1; }
  adapter::kill "$1"
}

cmd::slowlog() {
  adapter::slowlog "${1:-10}"
}
