# MySQL adapter - Schema operations

adapter::indexes() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "SHOW INDEX FROM $1"
}

adapter::fk() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "
    SELECT
      CONSTRAINT_NAME as 'constraint',
      COLUMN_NAME as 'column',
      REFERENCED_TABLE_NAME as references_table,
      REFERENCED_COLUMN_NAME as references_column
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = '$1'
      AND REFERENCED_TABLE_NAME IS NOT NULL"
}

adapter::users() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "
    SELECT
      User as user,
      Host as host,
      IF(Super_priv='Y','Yes','No') as super,
      IF(Grant_priv='Y','Yes','No') as grant_option
    FROM mysql.user
    ORDER BY User"
}

adapter::grants() {
  _mysql::need || return 1
  db::valid_id "$1" || return 1
  mysql "$DB_URL" -e "
    SELECT
      GRANTEE as grantee,
      PRIVILEGE_TYPE as privilege,
      IS_GRANTABLE as grantable
    FROM information_schema.TABLE_PRIVILEGES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '$1'
    ORDER BY GRANTEE, PRIVILEGE_TYPE"
}

adapter::rename() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "RENAME TABLE $1 TO $2" && db::ok "renamed: $1 -> $2"
}

adapter::drop() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "DROP TABLE $1" && db::ok "dropped: $1"
}

adapter::comment() {
  _mysql::need || return 1
  local table="$1" desc="$2"
  mysql "$DB_URL" -e "ALTER TABLE $table COMMENT = '$desc'" && db::ok "comment added"
}

adapter::get_comment() {
  _mysql::need || return 1
  local table="$1"
  mysql "$DB_URL" -sN -e "
    SELECT TABLE_COMMENT FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '$table'"
}

adapter::search() {
  _mysql::need || return 1
  local pattern="$1"
  echo "${C_BLUE}=== Tables ===${C_RESET}"
  mysql "$DB_URL" -e "
    SELECT TABLE_NAME as table_name
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME LIKE '%$pattern%'
    ORDER BY TABLE_NAME"
  echo "${C_BLUE}=== Columns ===${C_RESET}"
  mysql "$DB_URL" -e "
    SELECT TABLE_NAME as table_name, COLUMN_NAME as column_name, DATA_TYPE as data_type
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND COLUMN_NAME LIKE '%$pattern%'
    ORDER BY TABLE_NAME, COLUMN_NAME"
}

adapter::diff() {
  _mysql::need || return 1
  local url1="$1" url2="$2" name1="$3" name2="$4"

  echo "${C_BLUE}=== Tables only in $name1 ===${C_RESET}"
  comm -23 \
    <(mysql "$url1" -sN -e "SHOW TABLES" | sort) \
    <(mysql "$url2" -sN -e "SHOW TABLES" | sort)

  echo "${C_BLUE}=== Tables only in $name2 ===${C_RESET}"
  comm -13 \
    <(mysql "$url1" -sN -e "SHOW TABLES" | sort) \
    <(mysql "$url2" -sN -e "SHOW TABLES" | sort)

  echo "${C_BLUE}=== Column differences ===${C_RESET}"
  local common=$(comm -12 \
    <(mysql "$url1" -sN -e "SHOW TABLES" | sort) \
    <(mysql "$url2" -sN -e "SHOW TABLES" | sort))

  for table in $common; do
    local cols1=$(mysql "$url1" -sN -e "SELECT CONCAT(COLUMN_NAME,':',DATA_TYPE) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='$table' ORDER BY COLUMN_NAME")
    local cols2=$(mysql "$url2" -sN -e "SELECT CONCAT(COLUMN_NAME,':',DATA_TYPE) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='$table' ORDER BY COLUMN_NAME")
    if [[ "$cols1" != "$cols2" ]]; then
      echo "${C_YELLOW}$table${C_RESET}:"
      diff <(echo "$cols1") <(echo "$cols2") | head -10
    fi
  done
}
