# db - Meta commands
# @commands: help, version

cmd::help() {
  cat <<'EOF'
db - universal database cli

usage: db [flags] <command> [args]

flags:
  --env=FILE      use custom .env (default: .env)
  --var=NAME      env variable name (default: DATABASE_URL)
  --url=URL       use url directly (skip .env)
  -p, --profile   use named profile from .dbrc
  --format=FMT    output format (table/json/csv)
  -w, --wide      show all columns (no truncation)
  --cols=N        max columns to display
  --col-width=N   max column width (default: 30)
  -v, --verbose   show debug info
  -q, --quiet     suppress confirmations

commands:
  (none)        interactive cli (pgcli/mycli/litecli)
  connect       interactive profile picker (fzf)
  psql, p       native client with args
  url, u        show connection url (masked)
  info          show type and url
  status        full status overview
  test          test connection
  q, query SQL  execute query
  t, tables     list tables
  schema TABLE  show table schema
  sample TABLE [N]
                preview first N rows (default 10)
  count TABLE   count rows
  size TABLE    detailed table size
  dbs           list databases
  stats         database overview
  top [N]       largest tables (default 10)
  health        performance diagnostics
  conn          active connections

high-value commands:
  desc TABLE    table overview (schema + stats + sample)
  select TABLE [COLS] [N]
                query table with specific columns
  where TABLE COL=VAL
                filter rows by conditions
  @NAME         run bookmark (shorthand for: db run NAME)
  recent        show recently queried tables
  er [TABLE]    generate mermaid ER diagram
  import FMT FILE TABLE
                import csv/json to table

data helpers:
  agg TABLE [COL]
                aggregate stats (count, min, max)
  distinct TABLE COL
                distinct values with counts
  null TABLE    null counts per column
  dup TABLE COL find duplicate values

schema & structure:
  indexes TABLE show indexes for table
  fk TABLE      show foreign key relationships
  search PAT    search tables/columns by pattern
  diff P1 P2    compare schemas between profiles
  users         list database roles/users
  grants TABLE  show table permissions

schema management:
  rename OLD NEW  rename table (with confirm)
  drop TABLE    drop table (with confirm)
  comment TABLE [DESC]
                set or get table comment

maintenance:
  vacuum [TABLE]   run vacuum (postgres/sqlite)
  analyze [TABLE]  update statistics
  locks         show current locks
  kill PID      terminate connection/query
  slowlog [N]   slow queries (requires pg_stat_statements)

monitoring:
  tail TABLE [N] [S]
                watch recent rows (live refresh)
  changes TABLE [H]
                rows changed in last H hours (default 24)

backup & data:
  dump          backup database
  restore FILE  restore backup
  truncate TABLE  clear table (with confirm)
  exec FILE     execute sql file
  x, export FMT QUERY [FILE]
                export to csv/json
  cp SRC DEST   copy table

query tools:
  explain SQL   show query plan
  hist [N]      query history
  last          re-run last query
  edit          edit & run query in $EDITOR
  watch SQL [S] repeat query every S seconds
  migrate       run migrations (prisma/drizzle)

config:
  init [FILE]   create .dbrc config
  init global   create global config
  config        show current config
  config set K V  set config value
  config edit   edit .dbrc in $EDITOR
  profiles      list named profiles

bookmarks:
  save NAME SQL save query as bookmark
  run NAME      run saved bookmark
  @NAME         run bookmark (shorthand)
  bookmarks     list all bookmarks
  rm NAME       remove bookmark

  version       show version
  help          show this

examples:
  db                    open interactive cli
  db connect            pick profile with fzf
  db desc users         table overview
  db select users id,name 10
  db where users status=active
  db @daily-report      run bookmark
  db agg orders amount  aggregate stats
  db distinct users role
  db tail orders 20 5   watch orders (20 rows, 5s)
  db er                 ER diagram of all tables
  db import csv data.csv users
  db rename old_table new_table
EOF
}

cmd::version() {
  echo "db $DB_VERSION"
}

cmd::url() {
  db::mask "$DB_URL"
}

cmd::info() {
  echo "type: $DB_TYPE"
  echo "url:  $(db::mask "$DB_URL")"
}

cmd::status() {
  echo "${C_BLUE}=== Connection ===${C_RESET}"
  echo "type:    $DB_TYPE"
  echo "url:     $(db::mask "$DB_URL")"
  echo ""
  echo "${C_BLUE}=== Config ===${C_RESET}"
  echo "env_file:   $DB_ENV_FILE"
  echo "url_var:    $DB_URL_VAR"
  echo "schema:     $DB_SCHEMA"
  echo "format:     $DB_FORMAT"
  echo "query_time: $DB_SHOW_QUERY_TIME"
  echo ""
  echo "${C_BLUE}=== Profiles ===${C_RESET}"
  if [[ ${#DB_PROFILES[@]} -eq 0 ]]; then
    echo "(none)"
  else
    db::list_profiles
  fi
  echo ""
  echo "${C_BLUE}=== Last Query ===${C_RESET}"
  if [[ -f "$DB_HISTORY_FILE" ]]; then
    tail -1 "$DB_HISTORY_FILE"
  else
    echo "(none)"
  fi
}
