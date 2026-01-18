# PostgreSQL adapter - Schema operations
# indexes, fk, grants, users, rename, drop, comment, search, diff

adapter::indexes() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "
    SELECT
      indexname as index,
      indexdef as definition
    FROM pg_indexes
    WHERE schemaname='$DB_SCHEMA' AND tablename='$1'
    ORDER BY indexname"
}

adapter::fk() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "
    SELECT
      tc.constraint_name as constraint,
      kcu.column_name as column,
      ccu.table_name as references_table,
      ccu.column_name as references_column
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = '$DB_SCHEMA'
      AND tc.table_name = '$1'"
}

adapter::users() {
  _pg::need || return 1
  psql "$DB_URL" -c "
    SELECT
      rolname as role,
      rolsuper as superuser,
      rolcreaterole as create_role,
      rolcreatedb as create_db,
      rolcanlogin as can_login
    FROM pg_roles
    WHERE rolname NOT LIKE 'pg_%'
    ORDER BY rolname"
}

adapter::grants() {
  _pg::need || return 1
  db::valid_id "$1" || return 1
  psql "$DB_URL" -c "
    SELECT
      grantee,
      privilege_type,
      is_grantable
    FROM information_schema.table_privileges
    WHERE table_schema='$DB_SCHEMA' AND table_name='$1'
    ORDER BY grantee, privilege_type"
}

adapter::rename() {
  _pg::need || return 1
  psql "$DB_URL" -c "ALTER TABLE $1 RENAME TO $2" && db::ok "renamed: $1 -> $2"
}

adapter::drop() {
  _pg::need || return 1
  psql "$DB_URL" -c "DROP TABLE $1" && db::ok "dropped: $1"
}

adapter::comment() {
  _pg::need || return 1
  local table="$1" desc="$2"
  psql "$DB_URL" -c "COMMENT ON TABLE $table IS '$desc'" && db::ok "comment added"
}

adapter::get_comment() {
  _pg::need || return 1
  local table="$1"
  psql "$DB_URL" -tAc "
    SELECT obj_description('$DB_SCHEMA.$table'::regclass, 'pg_class')"
}

adapter::search() {
  _pg::need || return 1
  local pattern="$1"
  echo "${C_BLUE}=== Tables ===${C_RESET}"
  psql "$DB_URL" -c "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema='$DB_SCHEMA'
      AND table_name ILIKE '%$pattern%'
    ORDER BY table_name"
  echo "${C_BLUE}=== Columns ===${C_RESET}"
  psql "$DB_URL" -c "
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema='$DB_SCHEMA'
      AND column_name ILIKE '%$pattern%'
    ORDER BY table_name, column_name"
}

adapter::diff() {
  _pg::need || return 1
  local url1="$1" url2="$2" name1="$3" name2="$4"

  echo "${C_BLUE}=== Tables only in $name1 ===${C_RESET}"
  comm -23 \
    <(psql "$url1" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA' ORDER BY tablename") \
    <(psql "$url2" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA' ORDER BY tablename")

  echo "${C_BLUE}=== Tables only in $name2 ===${C_RESET}"
  comm -13 \
    <(psql "$url1" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA' ORDER BY tablename") \
    <(psql "$url2" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA' ORDER BY tablename")

  echo "${C_BLUE}=== Column differences ===${C_RESET}"
  local tables1=$(psql "$url1" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA' ORDER BY tablename")
  local tables2=$(psql "$url2" -tAc "SELECT tablename FROM pg_tables WHERE schemaname='$DB_SCHEMA' ORDER BY tablename")
  local common=$(comm -12 <(echo "$tables1") <(echo "$tables2"))

  for table in $common; do
    local cols1=$(psql "$url1" -tAc "SELECT column_name||':'||data_type FROM information_schema.columns WHERE table_schema='$DB_SCHEMA' AND table_name='$table' ORDER BY column_name")
    local cols2=$(psql "$url2" -tAc "SELECT column_name||':'||data_type FROM information_schema.columns WHERE table_schema='$DB_SCHEMA' AND table_name='$table' ORDER BY column_name")
    if [[ "$cols1" != "$cols2" ]]; then
      echo "${C_YELLOW}$table${C_RESET}:"
      diff <(echo "$cols1") <(echo "$cols2") | head -10
    fi
  done
}
