# SQLite adapter - Schema operations

adapter::indexes() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  sqlite3 "$(_sqlite::path)" "
    SELECT name as index_name, sql as definition
    FROM sqlite_master
    WHERE type='index' AND tbl_name='$1'"
}

adapter::fk() {
  _sqlite::need || return 1
  db::valid_id "$1" || return 1
  sqlite3 -header -column "$(_sqlite::path)" "PRAGMA foreign_key_list($1)"
}

adapter::users() {
  db::log "sqlite: no user management (file permissions control access)"
  return 0
}

adapter::grants() {
  db::log "sqlite: no grant system (file permissions control access)"
  return 0
}

adapter::rename() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "ALTER TABLE $1 RENAME TO $2" && db::ok "renamed: $1 -> $2"
}

adapter::drop() {
  _sqlite::need || return 1
  sqlite3 "$(_sqlite::path)" "DROP TABLE $1" && db::ok "dropped: $1"
}

adapter::comment() {
  db::log "sqlite: table comments not supported"
  return 0
}

adapter::get_comment() {
  db::log "sqlite: table comments not supported"
  return 0
}

adapter::search() {
  _sqlite::need || return 1
  local pattern="$1"
  echo "${C_BLUE}=== Tables ===${C_RESET}"
  sqlite3 "$(_sqlite::path)" "
    SELECT name FROM sqlite_master
    WHERE type='table' AND name LIKE '%$pattern%'
    ORDER BY name"
  echo "${C_BLUE}=== Columns ===${C_RESET}"
  local tables=$(sqlite3 "$(_sqlite::path)" "SELECT name FROM sqlite_master WHERE type='table'")
  for table in $tables; do
    sqlite3 "$(_sqlite::path)" "PRAGMA table_info($table)" | while IFS='|' read -r _ name type _ _ _; do
      if [[ "$name" == *"$pattern"* ]]; then
        echo "$table | $name | $type"
      fi
    done
  done
}

adapter::diff() {
  _sqlite::need || return 1
  local url1="$1" url2="$2" name1="$3" name2="$4"
  local path1="${url1#sqlite://}" path2="${url2#sqlite://}"
  path1="${path1#file:}" path2="${path2#file:}"

  echo "${C_BLUE}=== Tables only in $name1 ===${C_RESET}"
  comm -23 \
    <(sqlite3 "$path1" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name") \
    <(sqlite3 "$path2" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")

  echo "${C_BLUE}=== Tables only in $name2 ===${C_RESET}"
  comm -13 \
    <(sqlite3 "$path1" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name") \
    <(sqlite3 "$path2" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")

  echo "${C_BLUE}=== Schema differences ===${C_RESET}"
  local common=$(comm -12 \
    <(sqlite3 "$path1" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name") \
    <(sqlite3 "$path2" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"))

  for table in $common; do
    local schema1=$(sqlite3 "$path1" ".schema $table")
    local schema2=$(sqlite3 "$path2" ".schema $table")
    if [[ "$schema1" != "$schema2" ]]; then
      echo "${C_YELLOW}$table${C_RESET}:"
      diff <(echo "$schema1") <(echo "$schema2") | head -10
    fi
  done
}
