# SQLite adapter - Data operations

adapter::agg() {
  _sqlite::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1

  if [[ -n "$col" ]]; then
    sqlite3 -header -column "$(_sqlite::path)" "
      SELECT
        COUNT(*) as count,
        COUNT(DISTINCT $col) as distinct_count,
        MIN($col) as min,
        MAX($col) as max
      FROM $table"
  else
    sqlite3 "$(_sqlite::path)" "SELECT COUNT(*) as total_rows FROM $table"
  fi
}

adapter::distinct() {
  _sqlite::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1
  sqlite3 -header -column "$(_sqlite::path)" "
    SELECT $col, COUNT(*) as count
    FROM $table
    GROUP BY $col
    ORDER BY count DESC
    LIMIT 50"
}

adapter::nulls() {
  _sqlite::need || return 1
  local table="$1"
  db::valid_id "$table" || return 1

  echo "${C_BLUE}=== NULL counts in $table ===${C_RESET}"
  
  # Build single query with COUNT(CASE WHEN ...) for each column
  local -a cols_arr
  IFS=$'\n' read -rA cols_arr < <(sqlite3 "$(_sqlite::path)" "PRAGMA table_info($table)" | cut -d'|' -f2)
  
  local cols=""
  local first=1
  for col in "${cols_arr[@]}"; do
    [[ $first -eq 0 ]] && cols+=", "
    cols+="COUNT(CASE WHEN \"$col\" IS NULL THEN 1 END) AS \"$col\""
    first=0
  done
  
  # Execute single query and parse results
  sqlite3 "$(_sqlite::path)" "SELECT $cols FROM $table" | {
    IFS='|' read -rA counts
    
    local i=1
    for col in "${cols_arr[@]}"; do
      local count="${counts[$i]}"
      [[ "$count" -gt 0 ]] && echo "$col: $count NULLs"
      ((i++))
    done
  }
}

adapter::dup() {
  _sqlite::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1
  sqlite3 -header -column "$(_sqlite::path)" "
    SELECT $col, COUNT(*) as count
    FROM $table
    GROUP BY $col
    HAVING COUNT(*) > 1
    ORDER BY count DESC
    LIMIT 20"
}

adapter::import() {
  _sqlite::need || return 1
  local format="$1" file="$2" table="$3"

  case "$format" in
    csv)
      sqlite3 "$(_sqlite::path)" ".mode csv" ".import $file $table" && \
        db::ok "imported $file to $table"
      ;;
    json)
      db::err "sqlite: json import not supported"
      return 1
      ;;
    *)
      db::err "format: csv"
      return 1
      ;;
  esac
}

adapter::er() {
  _sqlite::need || return 1

  echo "erDiagram"
  sqlite3 "$(_sqlite::path)" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'" | while read -r tbl; do
    [[ -n "$1" && "$tbl" != "$1" ]] && continue
    echo "    $tbl {"
    sqlite3 "$(_sqlite::path)" "PRAGMA table_info($tbl)" | while IFS='|' read -r _ name type _ _ _; do
      echo "        $name $type"
    done
    echo "    }"
  done

  # SQLite foreign keys
  sqlite3 "$(_sqlite::path)" "SELECT name FROM sqlite_master WHERE type='table'" | while read -r tbl; do
    sqlite3 "$(_sqlite::path)" "PRAGMA foreign_key_list($tbl)" | while IFS='|' read -r _ _ ref_table from to _ _ _; do
      [[ -n "$ref_table" ]] && echo "    $tbl }|--|| $ref_table : references"
    done
  done
}

adapter::tail() {
  _sqlite::need || return 1
  local table="$1" limit="${2:-10}"
  db::valid_id "$table" || return 1

  # Check for common ordering columns
  local order_col=""
  for col in created_at updated_at timestamp id rowid; do
    local exists=$(sqlite3 "$(_sqlite::path)" "SELECT COUNT(*) FROM pragma_table_info('$table') WHERE name='$col'")
    if [[ "$exists" -gt 0 || "$col" == "rowid" ]]; then
      order_col="$col"
      break
    fi
  done

  sqlite3 -header -column "$(_sqlite::path)" "SELECT * FROM $table ORDER BY $order_col DESC LIMIT $limit"
}

adapter::changes() {
  _sqlite::need || return 1
  local table="$1" hours="${2:-24}"
  db::valid_id "$table" || return 1

  # Find timestamp column
  local ts_col=""
  for col in created_at updated_at timestamp modified_at; do
    local exists=$(sqlite3 "$(_sqlite::path)" "SELECT COUNT(*) FROM pragma_table_info('$table') WHERE name='$col'")
    if [[ "$exists" -gt 0 ]]; then
      ts_col="$col"
      break
    fi
  done

  if [[ -z "$ts_col" ]]; then
    db::warn "no timestamp column found in $table"
    return 1
  fi

  echo "${C_BLUE}=== Changes in last ${hours}h (by $ts_col) ===${C_RESET}"
  sqlite3 -header -column "$(_sqlite::path)" "
    SELECT * FROM $table
    WHERE datetime($ts_col) > datetime('now', '-$hours hours')
    ORDER BY $ts_col DESC
    LIMIT 50"
}
