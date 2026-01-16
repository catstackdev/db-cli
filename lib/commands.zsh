# db - Command implementations
# All commands delegate to adapter:: functions

# DB_HISTORY_FILE set in init.zsh, can be overridden in .dbrc

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
  -v, --verbose   show debug info
  -q, --quiet     suppress output

commands:
  (none)        interactive cli (pgcli/mycli/litecli)
  psql, p       native client with args
  url, u        show connection url (masked)
  info          show type and url
  test          test connection
  q, query SQL  execute query
  t, tables     list tables
  schema TABLE  show table schema
  sample TABLE [N]
                preview first N rows (default 10)
  count TABLE   count rows
  dbs           list databases
  stats         database overview
  top [N]       largest tables (default 10)
  health        performance diagnostics
  conn          active connections
  dump          backup database
  restore FILE  restore backup
  truncate TABLE
                clear table (with confirm)
  exec FILE     execute sql file
  x, export FMT QUERY [FILE]
                export to csv/json
  cp SRC DEST   copy table
  explain SQL   show query plan
  hist [N]      query history
  last          re-run last query
  edit          edit & run query in $EDITOR
  watch SQL [S] repeat query
  migrate       run migrations

config:
  init [FILE]   create .dbrc config
  init global   create global config
  config        show current config
  config set K V set config value
  config edit   edit .dbrc in $EDITOR
  profiles      list named profiles

bookmarks:
  save NAME SQL save query as bookmark
  run NAME      run saved bookmark
  bookmarks     list all bookmarks
  rm NAME       remove bookmark

  version       show version
  help          show this

examples:
  db                    open interactive cli
  db test               test connection
  db t                  list tables
  db q "SELECT 1"       run query
  db schema users       show users schema
  db sample users 5     preview 5 rows
  db x csv "SELECT *"   export to csv
  db dump               create backup
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

cmd::query() {
  [[ -z "$1" ]] && {
    echo "usage: db query <sql>"
    return 1
  }
  echo "[$(date '+%Y-%m-%d %H:%M')] $1" >>"$DB_HISTORY_FILE"
  # Trim history if too large
  if [[ -f "$DB_HISTORY_FILE" ]] && (($(wc -l <"$DB_HISTORY_FILE") > DB_HISTORY_SIZE)); then
    tail -n "$DB_HISTORY_SIZE" "$DB_HISTORY_FILE" >"${DB_HISTORY_FILE}.tmp" && mv "${DB_HISTORY_FILE}.tmp" "$DB_HISTORY_FILE"
  fi
  adapter::query "$1"
}

cmd::tables() {
  adapter::tables | db::pager
}

cmd::schema() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db schema <table>"
    return 1
  }
  adapter::schema "$table"
}

cmd::sample() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db sample <table> [limit]"
    return 1
  }
  adapter::sample "$table" "${2:-$DB_SAMPLE_LIMIT}"
}

cmd::count() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db count <table>"
    return 1
  }
  adapter::count "$table"
}

cmd::test() {
  adapter::test
}

cmd::stats() {
  adapter::stats | db::pager
}

cmd::top() {
  adapter::top "${1:-10}" | db::pager
}

cmd::health() {
  adapter::health | db::pager
}

cmd::connections() {
  adapter::connections
}

cmd::dump() {
  adapter::dump
}

cmd::restore() {
  [[ -z "$1" ]] && {
    echo "usage: db restore <file>"
    return 1
  }
  if [[ $DB_QUIET -eq 0 ]]; then
    echo -n "restore from $1? [y/N] "
    read -r ans
    [[ "$ans" != [yY] ]] && {
      echo "cancelled"
      return 1
    }
  fi
  adapter::restore "$1"
}

cmd::truncate() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db truncate <table>"
    return 1
  }
  if [[ $DB_QUIET -eq 0 ]]; then
    echo -n "truncate $table? [y/N] "
    read -r ans
    [[ "$ans" != [yY] ]] && {
      echo "cancelled"
      return 1
    }
  fi
  adapter::truncate "$table"
}

cmd::exec() {
  [[ -z "$1" || ! -f "$1" ]] && {
    echo "usage: db exec <file.sql>"
    return 1
  }
  adapter::exec "$1"
}

cmd::export() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db export <csv|json> <query> [file]"
    return 1
  }
  adapter::export "$1" "$2" "$3"
}

cmd::copy() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db copy <src> <dest>"
    return 1
  }
  adapter::copy "$1" "$2"
}

cmd::explain() {
  [[ -z "$1" ]] && {
    echo "usage: db explain <sql>"
    return 1
  }
  adapter::explain "$1"
}

cmd::dbs() {
  adapter::dbs
}

cmd::history() {
  local n="${1:-20}"
  [[ -f "$DB_HISTORY_FILE" ]] && tail -n "$n" "$DB_HISTORY_FILE" || echo "no history"
}

cmd::last() {
  [[ ! -f "$DB_HISTORY_FILE" ]] && {
    db::err "no history"
    return 1
  }
  local sql=$(tail -1 "$DB_HISTORY_FILE" | sed 's/^\[[^]]*\] //')
  db::log "re-running: $sql"
  adapter::query "$sql"
}

cmd::edit() {
  local tmpfile=$(mktemp /tmp/db-query.XXXXXX.sql)
  # Pre-fill with last query if exists
  if [[ -f "$DB_HISTORY_FILE" ]]; then
    tail -1 "$DB_HISTORY_FILE" | sed 's/^\[[^]]*\] //' >"$tmpfile"
  fi
  "$DB_EDITOR" "$tmpfile"
  if [[ -s "$tmpfile" ]]; then
    local sql=$(cat "$tmpfile")
    db::log "executing..."
    cmd::query "$sql"
  fi
  rm -f "$tmpfile"
}

cmd::watch() {
  [[ -z "$1" ]] && {
    echo "usage: db watch <sql> [interval]"
    return 1
  }
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

# === Config & Init Commands ===

cmd::init() {
  local target="${1:-.dbrc}"
  local type="${2:-project}"

  if [[ "$target" == "global" ]]; then
    target="$DB_GLOBAL_RC"
    mkdir -p "$(dirname "$target")"
  fi

  if [[ -f "$target" ]]; then
    db::warn "$target already exists"
    echo -n "overwrite? [y/N] "
    read -r ans
    [[ "$ans" != [yY] ]] && {
      echo "cancelled"
      return 1
    }
  fi

  cat >"$target" <<'DBRC'
# db config file
# Docs: db help config

# === Connection ===
DB_URL_VAR="DATABASE_URL"
DB_ENV_FILE=".env"

# === Output ===
DB_PAGER="less -S"
DB_SAMPLE_LIMIT=10
DB_FORMAT="table"
DB_SCHEMA="public"

# === History ===
DB_HISTORY_FILE="$HOME/.db_history"
DB_HISTORY_SIZE=1000

# === Backup ===
DB_BACKUP_DIR="."

# === Editor ===
DB_EDITOR="${EDITOR:-vim}"

# === Profiles (named connections) ===
# DB_PROFILES=(
#   [local]="postgres://localhost/mydb"
#   [staging]="postgres://staging-server/mydb"
#   [prod]="postgres://prod-server/mydb"
# )

# === Bookmarks ===
DB_BOOKMARKS_FILE="$HOME/.db_bookmarks"
DBRC

  db::ok "created: $target"
}

cmd::config() {
  local action="${1:-show}"
  local key="$2"
  local value="$3"

  case "$action" in
  show | list)
    echo "${C_BLUE}=== Current Config ===${C_RESET}"
    echo "DB_URL_VAR=$DB_URL_VAR"
    echo "DB_ENV_FILE=$DB_ENV_FILE"
    echo "DB_BACKUP_DIR=$DB_BACKUP_DIR"
    echo "DB_HISTORY_FILE=$DB_HISTORY_FILE"
    echo "DB_HISTORY_SIZE=$DB_HISTORY_SIZE"
    echo "DB_SAMPLE_LIMIT=$DB_SAMPLE_LIMIT"
    echo "DB_PAGER=$DB_PAGER"
    echo "DB_EDITOR=$DB_EDITOR"
    echo "DB_SCHEMA=$DB_SCHEMA"
    echo "DB_FORMAT=$DB_FORMAT"
    echo ""
    echo "${C_BLUE}=== Config Files ===${C_RESET}"
    echo "global:  $DB_GLOBAL_RC $([[ -f "$DB_GLOBAL_RC" ]] && echo '(exists)' || echo '(missing)')"
    echo "project: $DB_PROJECT_RC $([[ -f "$DB_PROJECT_RC" ]] && echo '(exists)' || echo '(missing)')"
    ;;
  get)
    [[ -z "$key" ]] && {
      echo "usage: db config get <key>"
      return 1
    }
    eval "echo \${$key}"
    ;;
  set)
    [[ -z "$key" || -z "$value" ]] && {
      echo "usage: db config set <key> <value>"
      return 1
    }
    local rc="${DB_PROJECT_RC}"
    [[ ! -f "$rc" ]] && cmd::init "$rc" >/dev/null
    if grep -q "^$key=" "$rc" 2>/dev/null; then
      sed -i '' "s|^$key=.*|$key=\"$value\"|" "$rc"
    else
      echo "$key=\"$value\"" >>"$rc"
    fi
    db::ok "set $key=$value in $rc"
    ;;
  edit)
    local rc="${2:-$DB_PROJECT_RC}"
    [[ "$rc" == "global" ]] && rc="$DB_GLOBAL_RC"
    [[ ! -f "$rc" ]] && cmd::init "$rc" >/dev/null
    local editor="${DB_EDITOR:-${EDITOR:-vim}}"
    "$editor" "$rc"
    ;;
  *)
    echo "usage: db config [show|get|set|edit] [key] [value]"
    ;;
  esac
}

cmd::profiles() {
  if [[ ${#DB_PROFILES[@]} -eq 0 ]]; then
    echo "no profiles configured"
    echo ""
    echo "add to .dbrc:"
    echo '  DB_PROFILES=('
    echo '    [local]="postgres://localhost/mydb"'
    echo '    [prod]="postgres://prod-server/mydb"'
    echo '  )'
    return 0
  fi
  echo "${C_BLUE}=== Profiles ===${C_RESET}"
  db::list_profiles
}

# === Bookmark Commands ===

cmd::save() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db save <name> <sql>"
    return 1
  }
  local name="$1" sql="$2"
  mkdir -p "$(dirname "$DB_BOOKMARKS_FILE")"
  # Remove existing bookmark with same name
  if [[ -f "$DB_BOOKMARKS_FILE" ]]; then
    grep -v "^$name	" "$DB_BOOKMARKS_FILE" >"${DB_BOOKMARKS_FILE}.tmp" 2>/dev/null
    mv "${DB_BOOKMARKS_FILE}.tmp" "$DB_BOOKMARKS_FILE"
  fi
  echo "$name	$sql" >>"$DB_BOOKMARKS_FILE"
  db::ok "saved: $name"
}

cmd::run_bookmark() {
  [[ -z "$1" ]] && {
    echo "usage: db run <name>"
    return 1
  }
  local name="$1"
  [[ ! -f "$DB_BOOKMARKS_FILE" ]] && {
    db::err "no bookmarks"
    return 1
  }
  local sql=$(grep "^$name	" "$DB_BOOKMARKS_FILE" | cut -f2-)
  [[ -z "$sql" ]] && {
    db::err "bookmark not found: $name"
    return 1
  }
  db::log "running: $sql"
  adapter::query "$sql"
}

cmd::bookmarks() {
  [[ ! -f "$DB_BOOKMARKS_FILE" ]] && {
    echo "no bookmarks"
    return 0
  }
  echo "${C_BLUE}=== Bookmarks ===${C_RESET}"
  while IFS=$'\t' read -r name sql; do
    echo "${C_GREEN}$name${C_RESET}: $sql"
  done <"$DB_BOOKMARKS_FILE"
}

cmd::rm_bookmark() {
  [[ -z "$1" ]] && {
    echo "usage: db rm <name>"
    return 1
  }
  [[ ! -f "$DB_BOOKMARKS_FILE" ]] && {
    db::err "no bookmarks"
    return 1
  }
  grep -v "^$1	" "$DB_BOOKMARKS_FILE" >"${DB_BOOKMARKS_FILE}.tmp"
  mv "${DB_BOOKMARKS_FILE}.tmp" "$DB_BOOKMARKS_FILE"
  db::ok "removed: $1"
}

# Main dispatch
db::run() {
  case "$1" in
  "") adapter::cli ;;
  psql | p)
    shift
    adapter::native "$@"
    ;;
  url | u) cmd::url ;;
  info) cmd::info ;;
  test | ping) cmd::test ;;
  q | query) cmd::query "$2" ;;
  t | tables) cmd::tables ;;
  schema) cmd::schema "$2" ;;
  sample | s) cmd::sample "$2" "$3" ;;
  count | c) cmd::count "$2" ;;
  dbs | list) cmd::dbs ;;
  stats | size) cmd::stats ;;
  top) cmd::top "$2" ;;
  health) cmd::health ;;
  conn | connections) cmd::connections ;;
  dump) cmd::dump ;;
  restore) cmd::restore "$2" ;;
  truncate) cmd::truncate "$2" ;;
  exec | e) cmd::exec "$2" ;;
  x | export) cmd::export "$2" "$3" "$4" ;;
  cp | copy) cmd::copy "$2" "$3" ;;
  explain) cmd::explain "$2" ;;
  hist | history) cmd::history "$2" ;;
  last | l) cmd::last ;;
  edit) cmd::edit ;;
  watch | w) cmd::watch "$2" "$3" ;;
  migrate | m) cmd::migrate ;;
  init) cmd::init "$2" "$3" ;;
  config) cmd::config "$2" "$3" "$4" ;;
  profiles) cmd::profiles ;;
  save) cmd::save "$2" "$3" ;;
  run) cmd::run_bookmark "$2" ;;
  bookmarks | bm) cmd::bookmarks ;;
  rm) cmd::rm_bookmark "$2" ;;
  version | v) cmd::version ;;
  help | h | -h | --help) cmd::help ;;
  *)
    db::err "unknown: $1"
    cmd::help
    return 1
    ;;
  esac
}
