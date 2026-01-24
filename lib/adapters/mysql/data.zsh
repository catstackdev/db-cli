# MySQL adapter - Data operations

adapter::agg() {
  _mysql::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1

  if [[ -n "$col" ]]; then
    mysql "$DB_URL" -e "
      SELECT
        COUNT(*) as count,
        COUNT(DISTINCT $col) as distinct_count,
        MIN($col) as min,
        MAX($col) as max
      FROM $table"
  else
    mysql "$DB_URL" -e "SELECT COUNT(*) as total_rows FROM $table"
  fi
}

adapter::distinct() {
  _mysql::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1
  mysql "$DB_URL" -e "
    SELECT $col, COUNT(*) as count
    FROM $table
    GROUP BY $col
    ORDER BY count DESC
    LIMIT 50"
}

adapter::nulls() {
  _mysql::need || return 1
  local table="$1"
  db::valid_id "$table" || return 1

  echo "${C_BLUE}=== NULL counts in $table ===${C_RESET}"
  
  # Build single query with COUNT(CASE WHEN ...) for each column
  local cols=$(mysql "$DB_URL" -sN -e "
    SELECT GROUP_CONCAT(
      CONCAT('COUNT(CASE WHEN \`', COLUMN_NAME, '\` IS NULL THEN 1 END) AS \`', COLUMN_NAME, '\`')
      SEPARATOR ', '
    )
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '$table'
    ORDER BY ORDINAL_POSITION
  ")
  
  # Execute single query and parse results
  mysql "$DB_URL" -sN -e "SELECT $cols FROM $table" | {
    IFS=$'\t' read -rA counts
    
    local -a column_names
    IFS=$'\n' read -rA column_names < <(mysql "$DB_URL" -sN -e "
      SELECT COLUMN_NAME
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '$table'
      ORDER BY ORDINAL_POSITION
    ")
    
    local i=1
    for col in "${column_names[@]}"; do
      local count="${counts[$i]}"
      [[ "$count" -gt 0 ]] && echo "$col: $count NULLs"
      ((i++))
    done
  }
}

adapter::dup() {
  _mysql::need || return 1
  local table="$1" col="$2"
  db::valid_id "$table" || return 1
  mysql "$DB_URL" -e "
    SELECT $col, COUNT(*) as count
    FROM $table
    GROUP BY $col
    HAVING COUNT(*) > 1
    ORDER BY count DESC
    LIMIT 20"
}

adapter::import() {
  _mysql::need || return 1
  local format="$1" file="$2" table="$3"

  case "$format" in
    csv)
      mysql "$DB_URL" -e "LOAD DATA LOCAL INFILE '$file' INTO TABLE $table
        FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n'
        IGNORE 1 ROWS" && db::ok "imported $file to $table"
      ;;
    *)
      db::err "mysql import supports csv only"
      return 1
      ;;
  esac
}

adapter::er() {
  _mysql::need || return 1

  echo "erDiagram"
  mysql "$DB_URL" -sN -e "SHOW TABLES" | while read -r tbl; do
    [[ -n "$1" && "$tbl" != "$1" ]] && continue
    echo "    $tbl {"
    mysql "$DB_URL" -sN -e "DESCRIBE $tbl" | while read -r col type rest; do
      echo "        $col $type"
    done
    echo "    }"
  done

  mysql "$DB_URL" -sN -e "
    SELECT TABLE_NAME, REFERENCED_TABLE_NAME
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL
  " | while read -r from to; do
    echo "    $from }|--|| $to : references"
  done
}

adapter::tail() {
  _mysql::need || return 1
  local table="$1" limit="${2:-10}"
  db::valid_id "$table" || return 1

  local order_col=$(mysql "$DB_URL" -sN -e "
    SELECT COLUMN_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '$table'
      AND COLUMN_NAME IN ('created_at', 'updated_at', 'timestamp', 'id')
    LIMIT 1
  ")

  if [[ -n "$order_col" ]]; then
    mysql "$DB_URL" -e "SELECT * FROM $table ORDER BY $order_col DESC LIMIT $limit"
  else
    mysql "$DB_URL" -e "SELECT * FROM $table LIMIT $limit"
  fi
}

adapter::changes() {
  _mysql::need || return 1
  local table="$1" hours="${2:-24}"
  db::valid_id "$table" || return 1

  local ts_col=$(mysql "$DB_URL" -sN -e "
    SELECT COLUMN_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '$table'
      AND COLUMN_NAME IN ('created_at', 'updated_at', 'timestamp', 'modified_at')
    LIMIT 1
  ")

  if [[ -z "$ts_col" ]]; then
    db::warn "no timestamp column found in $table"
    return 1
  fi

  echo "${C_BLUE}=== Changes in last ${hours}h (by $ts_col) ===${C_RESET}"
  mysql "$DB_URL" -e "
    SELECT * FROM $table
    WHERE $ts_col > DATE_SUB(NOW(), INTERVAL $hours HOUR)
    ORDER BY $ts_col DESC
    LIMIT 50"
}
