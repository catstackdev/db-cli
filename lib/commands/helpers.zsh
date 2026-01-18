# db - Data helper commands
# @commands: desc, select, where, agg, distinct, null, dup, recent

cmd::desc() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db desc <table>"
    return 1
  }
  echo "${C_BLUE}=== Schema ===${C_RESET}"
  adapter::schema "$table"
  echo ""
  echo "${C_BLUE}=== Stats ===${C_RESET}"
  adapter::table_size "$table" 2>/dev/null || adapter::count "$table"
  echo ""
  echo "${C_BLUE}=== Sample (3 rows) ===${C_RESET}"
  adapter::sample "$table" 3 | db::table
}

cmd::select() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db select <table> [col1,col2,...] [limit]"
    return 1
  }
  shift
  local cols="*"
  local limit="$DB_SAMPLE_LIMIT"

  # Parse remaining args
  for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      limit="$arg"
    else
      cols="$arg"
    fi
  done

  local sql="SELECT $cols FROM $table LIMIT $limit"
  db::dbg "query: $sql"
  adapter::query "$sql" | db::table
}

cmd::where() {
  [[ -z "$1" ]] && {
    echo "usage: db where <table> <col=val> [col2=val2] ..."
    echo "example: db where users email=test@example.com"
    return 1
  }
  local table="$1"
  shift
  db::valid_id "$table" || return 1

  local conditions=""
  for cond in "$@"; do
    local col="${cond%%=*}"
    local val="${cond#*=}"
    [[ -n "$conditions" ]] && conditions+=" AND "
    conditions+="$col = '$val'"
  done

  [[ -z "$conditions" ]] && {
    echo "usage: db where <table> <col=val>"
    return 1
  }

  local sql="SELECT * FROM $table WHERE $conditions LIMIT $DB_SAMPLE_LIMIT"
  db::dbg "query: $sql"
  adapter::query "$sql" | db::table
}

cmd::agg() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db agg <table> [column]"
    return 1
  }
  local col="$2"

  if [[ -n "$col" ]]; then
    adapter::agg "$table" "$col"
  else
    adapter::agg "$table"
  fi
}

cmd::distinct() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db distinct <table> <column>"
    return 1
  }
  local col="$2"
  [[ -z "$col" ]] && {
    echo "usage: db distinct <table> <column>"
    return 1
  }
  db::valid_id "$table" || return 1
  adapter::distinct "$table" "$col"
}

cmd::nulls() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db null <table>"
    return 1
  }
  adapter::nulls "$table"
}

cmd::dup() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db dup <table> <column>"
    return 1
  }
  local col="$2"
  [[ -z "$col" ]] && {
    echo "usage: db dup <table> <column>"
    return 1
  }
  adapter::dup "$table" "$col"
}

cmd::recent() {
  echo "${C_BLUE}=== Recent Tables ===${C_RESET}"
  if [[ -f "$DB_HISTORY_FILE" ]]; then
    grep -oE 'FROM [a-zA-Z_][a-zA-Z0-9_]*' "$DB_HISTORY_FILE" | \
      sed 's/FROM //' | sort | uniq -c | sort -rn | head -10 | \
      while read count table; do
        echo "$table ($count queries)"
      done
  else
    echo "(no history)"
  fi
}
