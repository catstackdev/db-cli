# db - Data helper commands
# @commands: desc, select, where, agg, distinct, null, dup, recent

cmd::desc() {
  local table=$(db::require_table "$1" "db desc <table>") || return 1
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
  local table=$(db::require_table "$1" "db select <table> [col1,col2,...] [limit]") || return 1
  shift
  db::valid_id "$table" || return 1
  
  local cols="*"
  local limit="$DB_SAMPLE_LIMIT"

  # Parse remaining args
  for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      limit="$arg"
      db::valid_num "$limit" "limit" || return 1
    else
      cols="$arg"
    fi
  done

  # Validate column names if not *
  if [[ "$cols" != "*" ]]; then
    for col in ${(s:,:)cols}; do
      col="${col## }"
      col="${col%% }"
      db::valid_id "$col" || return 1
    done
  fi

  local sql="SELECT $cols FROM $table LIMIT $limit"
  db::dbg "query: $sql"
  adapter::query "$sql" | db::table
}

cmd::where() {
  [[ -z "$1" ]] && {
    echo "usage: db where <table> <col=val> [col2=val2] ..."
    echo "       db where <table> <col>operator<val> ..."
    echo ""
    echo "operators: = != > < >= <= ~~ (LIKE) !~~ (NOT LIKE)"
    echo ""
    echo "examples:"
    echo "  db where users email=test@example.com"
    echo "  db where users age>=18 status=active"
    echo "  db where users name~~'%john%'"
    return 1
  }
  local table="$1"
  shift
  db::valid_id "$table" || return 1

  local conditions=""
  for cond in "$@"; do
    # Parse condition with multiple operators
    local col="" op="" val=""
    
    # Try operators in order: >=, <=, !=, !~~, ~~, =, >, <
    if [[ "$cond" =~ '^([a-zA-Z_][a-zA-Z0-9_]*)(>=|<=|!=|!~~|~~|=|>|<)(.+)$' ]]; then
      col="${match[1]}"
      op="${match[2]}"
      val="${match[3]}"
    else
      db::err "invalid condition format: $cond"
      db::err "expected: column=value or column>=value etc."
      return 1
    fi
    
    # Validate column name to prevent SQL injection
    db::valid_id "$col" || return 1
    
    # Map operators to SQL
    case "$op" in
      "="|"!="|">"|"<"|">="|"<=") 
        # Standard comparison operators
        ;;
      "~~") 
        op="LIKE"
        ;;
      "!~~") 
        op="NOT LIKE"
        ;;
      *)
        db::err "unsupported operator: $op"
        return 1
        ;;
    esac
    
    # Escape single quotes in value (prevent quote breakout)
    val="${val//\'/\'\'}"
    
    # Detect if value should be numeric or string
    # Numeric: digits only, optionally with decimal point
    local sql_val
    if [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      # Numeric value - no quotes
      sql_val="$val"
    else
      # String value - quote it
      sql_val="'$val'"
    fi
    
    [[ -n "$conditions" ]] && conditions+=" AND "
    conditions+="$col $op $sql_val"
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
  local table=$(db::require_table "$1" "db agg <table> [column]") || return 1
  local col="$2"

  if [[ -n "$col" ]]; then
    adapter::agg "$table" "$col"
  else
    adapter::agg "$table"
  fi
}

cmd::distinct() {
  local table=$(db::require_table "$1" "db distinct <table> <column>") || return 1
  local col="$2"
  [[ -z "$col" ]] && {
    echo "usage: db distinct <table> <column>"
    return 1
  }
  db::valid_id "$table" || return 1
  adapter::distinct "$table" "$col"
}

cmd::nulls() {
  local table=$(db::require_table "$1" "db null <table>") || return 1
  adapter::nulls "$table"
}

cmd::dup() {
  local table=$(db::require_table "$1" "db dup <table> <column>") || return 1
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
