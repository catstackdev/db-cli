# db - Schema & structure commands
# @commands: indexes, fk, search, diff, users, grants, rename, drop, comment

cmd::indexes() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db indexes <table>"
    return 1
  }
  adapter::indexes "$table"
}

cmd::fk() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db fk <table>"
    return 1
  }
  adapter::fk "$table"
}

cmd::search() {
  [[ -z "$1" ]] && {
    echo "usage: db search <pattern>"
    return 1
  }
  adapter::search "$1"
}

cmd::diff() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db diff <profile1> <profile2>"
    return 1
  }
  local url1=$(db::get_profile "$1") || { db::err "unknown profile: $1"; return 1; }
  local url2=$(db::get_profile "$2") || { db::err "unknown profile: $2"; return 1; }
  adapter::diff "$url1" "$url2" "$1" "$2"
}

cmd::users() {
  adapter::users
}

cmd::grants() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db grants <table>"
    return 1
  }
  adapter::grants "$table"
}

cmd::rename() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db rename <old_name> <new_name>"
    return 1
  }
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  
  if ! db::dry_run "RENAME table" \
    "From: $1" \
    "To: $2" \
    "SQL: ALTER TABLE $1 RENAME TO $2"; then
    return 0
  fi
  
  db::confirm "rename $1 to $2" || { echo "cancelled"; return 1; }
  adapter::rename "$1" "$2"
}

cmd::drop() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db drop <table>"
    return 1
  }
  db::valid_id "$table" || return 1

  # Get row count only if not in dry-run mode
  local row_count=""
  if [[ $DB_DRY_RUN -eq 0 ]]; then
    row_count=$(adapter::count "$table" 2>/dev/null | tail -1 | tr -d ' ')
  fi
  
  if ! db::dry_run "DROP TABLE (PERMANENT)" \
    "Table: $table" \
    "Rows: ${row_count:-unknown}" \
    "SQL: DROP TABLE $table" \
    "⚠️  This cannot be undone!"; then
    return 0
  fi

  echo "${C_YELLOW}Table: $table${C_RESET}"
  [[ -n "$row_count" ]] && echo "Rows: $row_count" && echo ""

  db::confirm "DROP TABLE $table (cannot be undone)" || { echo "cancelled"; return 1; }
  
  # Audit log before drop
  audit::log "DROP" "$table" "rows: ${row_count:-unknown}"
  
  adapter::drop "$table"
}

cmd::comment() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db comment <table> <description>"
    return 1
  }
  local desc="$2"
  [[ -z "$desc" ]] && {
    # Show existing comment
    adapter::get_comment "$table"
    return
  }
  adapter::comment "$table" "$desc"
}
