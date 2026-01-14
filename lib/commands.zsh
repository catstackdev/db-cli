# db - Command implementations
# All commands delegate to adapter:: functions

readonly DB_HISTORY="$HOME/.db_history"

cmd::help() {
  cat << 'EOF'
db - universal database cli

usage: db [flags] <command> [args]

flags:
  --env=FILE    use custom .env (default: .env)
  -v, --verbose show debug info
  -q, --quiet   suppress output

commands:
  (none)        interactive cli (pgcli/mycli/litecli)
  psql, p       native client with args
  url, u        show connection url (masked)
  info          show type and url
  test          test connection
  q, query SQL  execute query
  t, tables     list tables
  schema TABLE  show table schema
  count TABLE   count rows
  dbs           list databases
  stats         show statistics
  conn          show connections
  dump          backup database
  restore FILE  restore backup
  x, export FMT QUERY [FILE]
                export to csv/json
  cp SRC DEST   copy table
  explain SQL   show query plan
  hist [N]      query history
  watch SQL [S] repeat query
  migrate       run migrations
  help          show this

examples:
  db                    open interactive cli
  db test               test connection
  db t                  list tables
  db q "SELECT 1"       run query
  db schema users       show users schema
  db x csv "SELECT *"   export to csv
  db dump               create backup
EOF
}

cmd::url() {
  db::mask "$DB_URL"
}

cmd::info() {
  echo "type: $DB_TYPE"
  echo "url:  $(db::mask "$DB_URL")"
}

cmd::query() {
  [[ -z "$1" ]] && { echo "usage: db query <sql>"; return 1; }
  echo "[$(date '+%Y-%m-%d %H:%M')] $1" >> "$DB_HISTORY"
  adapter::query "$1"
}

cmd::tables() {
  adapter::tables
}

cmd::schema() {
  [[ -z "$1" ]] && { echo "usage: db schema <table>"; return 1; }
  adapter::schema "$1"
}

cmd::count() {
  [[ -z "$1" ]] && { echo "usage: db count <table>"; return 1; }
  adapter::count "$1"
}

cmd::test() {
  adapter::test
}

cmd::stats() {
  adapter::stats
}

cmd::connections() {
  adapter::connections
}

cmd::dump() {
  adapter::dump
}

cmd::restore() {
  [[ -z "$1" ]] && { echo "usage: db restore <file>"; return 1; }
  if [[ $DB_QUIET -eq 0 ]]; then
    echo -n "restore from $1? [y/N] "
    read -r ans
    [[ "$ans" != [yY] ]] && { echo "cancelled"; return 1; }
  fi
  adapter::restore "$1"
}

cmd::export() {
  [[ -z "$1" || -z "$2" ]] && { echo "usage: db export <csv|json> <query> [file]"; return 1; }
  adapter::export "$1" "$2" "$3"
}

cmd::copy() {
  [[ -z "$1" || -z "$2" ]] && { echo "usage: db copy <src> <dest>"; return 1; }
  adapter::copy "$1" "$2"
}

cmd::explain() {
  [[ -z "$1" ]] && { echo "usage: db explain <sql>"; return 1; }
  adapter::explain "$1"
}

cmd::dbs() {
  adapter::dbs
}

cmd::history() {
  local n="${1:-20}"
  [[ -f "$DB_HISTORY" ]] && tail -n "$n" "$DB_HISTORY" || echo "no history"
}

cmd::watch() {
  [[ -z "$1" ]] && { echo "usage: db watch <sql> [interval]"; return 1; }
  local sql="$1" interval="${2:-2}"
  while true; do
    clear
    echo "${C_DIM}$sql | every ${interval}s | $(date '+%H:%M:%S')${C_RESET}"
    echo "---"
    adapter::query "$sql"
    sleep "$interval"
  done
}

cmd::migrate() {
  if [[ -f package.json ]] && grep -q prisma package.json 2>/dev/null; then
    db::log "running prisma migrate..."
    command -v pnpm &>/dev/null && pnpm prisma migrate deploy || npx prisma migrate deploy
  elif [[ -f drizzle.config.ts || -f drizzle.config.js ]]; then
    db::log "running drizzle push..."
    command -v pnpm &>/dev/null && pnpm drizzle-kit push || npx drizzle-kit push
  elif [[ -d migrations ]]; then
    db::log "migrations/ found - run your tool manually"
    ls migrations/
  else
    db::err "no migration tool detected"
    return 1
  fi
}

# Main dispatch
db::run() {
  case "$1" in
    "") adapter::cli ;;
    psql|p) shift; adapter::native "$@" ;;
    url|u) cmd::url ;;
    info) cmd::info ;;
    test|ping) cmd::test ;;
    q|query) cmd::query "$2" ;;
    t|tables) cmd::tables ;;
    schema) cmd::schema "$2" ;;
    count|c) cmd::count "$2" ;;
    dbs|list) cmd::dbs ;;
    stats|size) cmd::stats ;;
    conn|connections) cmd::connections ;;
    dump) cmd::dump ;;
    restore) cmd::restore "$2" ;;
    x|export) cmd::export "$2" "$3" "$4" ;;
    cp|copy) cmd::copy "$2" "$3" ;;
    explain) cmd::explain "$2" ;;
    hist|history) cmd::history "$2" ;;
    watch|w) cmd::watch "$2" "$3" ;;
    migrate|m) cmd::migrate ;;
    help|h|-h|--help) cmd::help ;;
    *) db::err "unknown: $1"; cmd::help; return 1 ;;
  esac
}
