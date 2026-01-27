# PostgreSQL adapter - Data operations
# agg, distinct, nulls, dup, import, er, tail, changes

adapter::agg() {
  _pg::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1

  if [[ -n "$col" ]]; then
    _pg::exec -c "
      SELECT
        COUNT(*) as count,
        COUNT(DISTINCT $col) as distinct_count,
        MIN($col) as min,
        MAX($col) as max
      FROM $table"
  else
    _pg::exec -c "SELECT COUNT(*) as total_rows FROM $table"
  fi
}

adapter::distinct() {
  _pg::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1
  _pg::exec -c "
    SELECT $col, COUNT(*) as count
    FROM $table
    GROUP BY $col
    ORDER BY count DESC
    LIMIT 50"
}

adapter::nulls() {
  _pg::need || return 1
  local table="$1"
  db::valid_id "$table" || return 1

  echo "${C_BLUE}=== NULL counts in $table ===${C_RESET}"
  
  # Build single query with COUNT(CASE WHEN ...) for each column
  local cols=$(_pg::exec -tAc "
    SELECT string_agg(
      'COUNT(CASE WHEN ' || column_name || ' IS NULL THEN 1 END) as \"' || column_name || '\"',
      ', '
    )
    FROM information_schema.columns
    WHERE table_schema = '$DB_SCHEMA' AND table_name = '$table'
    ORDER BY ordinal_position
  ")
  
  # Execute single query and transpose results
  _pg::exec -tAc "SELECT $cols FROM $table" | {
    local -a counts
    IFS='|' read -rA counts
    
    local -a column_names
    IFS=$'\n' read -rA column_names < <(_pg::exec -tAc "
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = '$DB_SCHEMA' AND table_name = '$table'
      ORDER BY ordinal_position
    ")
    
    local i=1
    for col in "${column_names[@]}"; do
      local count="${counts[$i]## }"
      count="${count%% }"
      [[ "$count" -gt 0 ]] && echo "$col: $count NULLs"
      ((i++))
    done
  }
}

adapter::dup() {
  _pg::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1
  _pg::exec -c "
    SELECT $col, COUNT(*) as count
    FROM $table
    GROUP BY $col
    HAVING COUNT(*) > 1
    ORDER BY count DESC
    LIMIT 20"
}

adapter::import() {
  _pg::need || return 1
  local format="$1" file="$2" table="$3"

  case "$format" in
    csv)
      _pg::exec -c "\\copy $table FROM '$file' WITH CSV HEADER" && \
        db::ok "imported $file to $table"
      ;;
    json)
      local data=$(cat "$file")
      _pg::exec -c "
        INSERT INTO $table
        SELECT * FROM json_populate_recordset(null::$table, '$data'::json)
      " && db::ok "imported $file to $table"
      ;;
    *)
      db::err "format: csv or json"
      return 1
      ;;
  esac
}

adapter::er() {
  _pg::need || return 1
  local filter=""
  [[ -n "$1" ]] && filter="AND (tc.table_name = '$1' OR ccu.table_name = '$1')"

  echo "erDiagram"
  # Get tables and their columns
  _pg::exec -tAc "
    SELECT DISTINCT table_name
    FROM information_schema.tables
    WHERE table_schema = '$DB_SCHEMA' AND table_type = 'BASE TABLE'
    ORDER BY table_name
  " | while read -r tbl; do
    [[ -n "$1" && "$tbl" != "$1" ]] && continue
    echo "    $tbl {"
    _pg::exec -tAc "
      SELECT column_name || ' ' || data_type
      FROM information_schema.columns
      WHERE table_schema = '$DB_SCHEMA' AND table_name = '$tbl'
      ORDER BY ordinal_position
    " | while read -r col; do
      echo "        $col"
    done
    echo "    }"
  done

  # Get relationships
  _pg::exec -tAc "
    SELECT
      tc.table_name,
      ccu.table_name AS foreign_table
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = '$DB_SCHEMA'
      $filter
  " | while read -r rel; do
    local from=$(echo "$rel" | cut -d'|' -f1)
    local to=$(echo "$rel" | cut -d'|' -f2)
    echo "    $from }|--|| $to : references"
  done
}

adapter::tail() {
  _pg::need || return 1
  local table="$1" limit="${2:-10}"
  db::valid_id "$table" || return 1

  # Try to find a timestamp or id column for ordering
  local order_col=$(_pg::exec -tAc "
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = '$DB_SCHEMA' AND table_name = '$table'
      AND (column_name IN ('created_at', 'updated_at', 'timestamp', 'id', 'created', 'modified')
           OR data_type IN ('timestamp', 'timestamptz'))
    ORDER BY
      CASE column_name
        WHEN 'created_at' THEN 1
        WHEN 'updated_at' THEN 2
        WHEN 'timestamp' THEN 3
        WHEN 'id' THEN 4
        ELSE 5
      END
    LIMIT 1
  ")

  if [[ -n "$order_col" ]]; then
    _pg::exec -c "SELECT * FROM $table ORDER BY $order_col DESC LIMIT $limit"
  else
    _pg::exec -c "SELECT * FROM $table LIMIT $limit"
  fi
}

adapter::changes() {
  _pg::need || return 1
  local table="$1" hours="${2:-24}"
  db::valid_id "$table" || return 1

  # Find timestamp column
  local ts_col=$(_pg::exec -tAc "
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = '$DB_SCHEMA' AND table_name = '$table'
      AND (column_name IN ('created_at', 'updated_at', 'timestamp', 'modified_at')
           OR data_type IN ('timestamp', 'timestamptz'))
    LIMIT 1
  ")

  if [[ -z "$ts_col" ]]; then
    db::warn "no timestamp column found in $table"
    return 1
  fi

  echo "${C_BLUE}=== Changes in last ${hours}h (by $ts_col) ===${C_RESET}"
  _pg::exec -c "
    SELECT * FROM $table
    WHERE $ts_col > NOW() - INTERVAL '$hours hours'
    ORDER BY $ts_col DESC
    LIMIT 50"
}
