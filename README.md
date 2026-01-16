# db

Universal database CLI with adapter-based architecture.

Supports **PostgreSQL**, **MySQL**, **SQLite**, **MongoDB**.

**v1.2.0** - Config system, enhanced stats, health checks.

## Install

```bash
# Add to PATH (~/.zshrc)
export PATH="$HOME/.config/db/bin:$PATH"
fpath=($HOME/.config/db/completions $fpath)
```

## Usage

Requires `DATABASE_URL` in `.env` file:

```bash
# PostgreSQL
DATABASE_URL="postgresql://user:pass@localhost:5432/mydb"

# MySQL
DATABASE_URL="mysql://user:pass@localhost:3306/mydb"

# SQLite
DATABASE_URL="sqlite:///path/to/db.sqlite"

# MongoDB
DATABASE_URL="mongodb://user:pass@localhost:27017/mydb"
```

## Commands

```bash
db                # open interactive cli (pgcli/mycli/litecli)
db test           # test connection
db t              # list tables
db q "SELECT 1"   # run query
db schema users   # show table schema (fzf if no arg)
db sample users 5 # preview first 5 rows
db count users    # count rows (fzf if no arg)
db stats          # database overview (size, tables, version)
db top            # largest tables by size
db top 20         # top 20 largest tables
db health         # performance diagnostics
db conn           # active connections
db dbs            # list databases
db dump           # backup → backup-YYYYMMDD-HHMMSS.sql
db restore file   # restore from backup
db truncate users # clear table (with confirm)
db exec file.sql  # execute sql file
db x csv "SQL"    # export to csv
db x json "SQL"   # export to json
db cp src dest    # copy table
db explain "SQL"  # query plan
db hist           # query history
db last           # re-run last query
db edit           # edit & run query in $EDITOR
db watch "SQL" 5  # repeat query every 5s
db migrate        # run migrations (prisma/drizzle/knex)
db version        # show version
db help           # show help
```

## Flags

```bash
--env=FILE      # custom env file (default: .env)
--var=NAME      # env variable name (default: DATABASE_URL)
--url=URL       # use url directly (skip .env)
-p, --profile   # use named profile from .dbrc
--format=FMT    # output format (table/json/csv)
-v, --verbose   # debug output
-q, --quiet     # no confirmations
-V, --version   # show version
```

## Config File (.dbrc)

Two levels of config (project overrides global):

| Level | Location | Purpose |
|-------|----------|---------|
| Global | `~/.config/db/.dbrc` | User defaults |
| Project | `.dbrc` (cwd) | Project-specific |

### All Options

```bash
# === Connection ===
DB_URL_VAR="DATABASE_URL"     # env variable name
DB_ENV_FILE=".env"            # default env file

# === Output ===
DB_PAGER="less -S"            # pager for long output
DB_SAMPLE_LIMIT=10            # default rows for 'sample'
DB_SCHEMA="public"            # default schema (postgres)

# === History ===
DB_HISTORY_FILE="$HOME/.db_history"
DB_HISTORY_SIZE=1000          # max history entries

# === Backup ===
DB_BACKUP_DIR="."             # where to save dumps

# === Editor ===
DB_EDITOR="${EDITOR:-vim}"    # for 'db edit'

# === Profiles (named connections) ===
DB_PROFILES=(
  [local]="postgres://localhost/mydb"
  [staging]="postgres://staging-server/mydb"
  [prod]="postgres://prod-server/mydb"
)

# === Bookmarks ===
DB_BOOKMARKS_FILE="$HOME/.db_bookmarks"
```

## Profiles

Named database connections for quick switching:

```bash
# Add to .dbrc
DB_PROFILES=(
  [local]="postgres://localhost/mydb"
  [prod]="postgres://prod-server/mydb"
)

# Usage
db -p local tables
db -p prod stats
db profiles         # list all profiles
```

## Bookmarks

Save frequently used queries:

```bash
db save user-count "SELECT COUNT(*) FROM users"
db save active-users "SELECT * FROM users WHERE active=true"
db run user-count   # execute saved query
db bookmarks        # list all
db rm user-count    # delete
```

## Config Commands

```bash
db init             # create .dbrc in current dir
db init global      # create ~/.config/db/.dbrc
db config           # show current config
db config set DB_SAMPLE_LIMIT 20
db config edit      # open .dbrc in editor
db config edit global
```

## Features

- **Security**: SQL identifier validation prevents injection attacks
- **FZF Integration**: Interactive table selection when no arg provided
- **Dynamic Completions**: Tab-complete table names from your database
- **Flexible Config**: Custom env variable names via config or flags

## Examples

```bash
# Different env file
db --env=.env.local test

# Custom variable name (not DATABASE_URL)
db --var=POSTGRES_URL tables
db --var=MONGO_URI tables

# Direct URL (skip .env)
db --url="postgres://user:pass@localhost/mydb" tables

# Quick table check
db t && db count users

# Export users to csv
db x csv "SELECT * FROM users" users.csv

# Watch active orders
db watch "SELECT COUNT(*) FROM orders WHERE status='pending'" 10
```

## Requirements

```bash
# PostgreSQL
brew install postgresql@16 pgcli

# MySQL
brew install mysql-client mycli

# SQLite
brew install sqlite litecli

# MongoDB
brew install mongosh mongodb-database-tools
```

## Structure

```
db/
├── bin/db                  # entry point
├── lib/
│   ├── init.zsh            # core helpers
│   ├── commands.zsh        # command dispatch
│   └── adapters/
│       ├── postgres.zsh
│       ├── mysql.zsh
│       ├── sqlite.zsh
│       └── mongodb.zsh
├── completions/_db         # zsh completion
└── example/
    ├── .dbrc.global        # sample global config
    └── .dbrc.project       # sample project config
```

Config locations:
- Global: `~/.config/db/.dbrc`
- Project: `.dbrc` (current directory)

## Adding New Database

Create `lib/adapters/newdb.zsh` implementing:

```bash
adapter::cli        # interactive client
adapter::native     # native client with args
adapter::query      # execute sql
adapter::tables     # list tables
adapter::schema     # table schema
adapter::count      # row count
adapter::test       # connection test
adapter::stats      # statistics
adapter::dump       # backup
adapter::restore    # restore
adapter::explain    # query plan
adapter::dbs        # list databases
adapter::export     # export data
adapter::copy       # copy table
```

Then add detection in `lib/init.zsh`:

```bash
db::detect() {
  case "$1" in
    newdb://*) echo "newdb" ;;
    ...
  esac
}
```
