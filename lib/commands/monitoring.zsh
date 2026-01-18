# db - Monitoring commands
# @commands: tail, changes

cmd::tail() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db tail <table> [limit] [interval]"
    return 1
  }
  local limit="${2:-10}"
  local interval="${3:-2}"

  db::log "watching $table (${interval}s refresh, Ctrl+C to stop)"
  while true; do
    clear
    echo "${C_DIM}$table | $(date '+%H:%M:%S') | every ${interval}s${C_RESET}"
    echo "---"
    adapter::tail "$table" "$limit" | db::table
    sleep "$interval"
  done
}

cmd::changes() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db changes <table> [hours]"
    return 1
  }
  local hours="${2:-24}"
  adapter::changes "$table" "$hours"
}
