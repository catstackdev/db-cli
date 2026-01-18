# db

Universal database CLI with adapter-based architecture.

Supports **PostgreSQL**, **MySQL**, **SQLite**, **MongoDB**.

**v2.0.0** - Modular architecture, lazy loading, plugin system, improved performance.

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

### Connection & Info

```bash
db                # open interactive cli (pgcli/mycli/litecli)
db connect        # pick profile with fzf
db test           # test connection
db status         # full status overview
db info           # show type and url
db url            # show masked url
```

### Tables & Data

```bash
db t              # list tables
db schema users   # show table schema (fzf if no arg)
db sample users 5 # preview first 5 rows
db count users    # count rows (fzf if no arg)
db size users     # detailed table size info
db q "SELECT 1"   # run query
```

### High-Value Commands

```bash
db desc users           # table overview: schema + stats + sample
db select users id,name 10  # query specific columns
db where users email=foo@bar.com  # filter by conditions
db @user-count          # run bookmark (shorthand for db run)
db recent               # tables you've queried recently
db er                   # generate mermaid ER diagram
db er users             # ER diagram for specific table
```

### Data Helpers

```bash
db agg users            # count, null stats
db agg users age        # count, min, max, avg for column
db distinct users role  # distinct values with counts
db null users           # null counts per column
db dup users email      # find duplicate values
```

### Schema & Structure

```bash
db indexes users  # show indexes on table
db fk orders      # show foreign key relationships
db search user    # find tables/columns matching pattern
db diff local prod # compare schemas between profiles
db users          # list database roles/users
db grants users   # show table permissions
```

### Schema Management

```bash
db rename old_name new_name  # rename table (with confirm)
db drop users                # drop table (with confirm)
db comment users "User accounts"  # set table comment
db comment users             # show table comment
```

### Monitoring

```bash
db tail orders        # watch recent rows (live refresh)
db tail orders 20 5   # 20 rows, 5s refresh
db changes orders     # rows changed in last 24h
db changes orders 48  # rows changed in last 48h
```

### Database Overview

```bash
db stats          # database overview (size, tables, version)
db top            # largest tables by size
db top 20         # top 20 largest tables
db dbs            # list databases
```

### Maintenance

```bash
db health         # performance diagnostics
db conn           # active connections
db locks          # show current locks
db kill 12345     # terminate connection/query
db slowlog        # slow queries (requires pg_stat_statements)
db slowlog 20     # show top 20 slow queries
db vacuum users   # vacuum specific table
db vacuum         # vacuum all tables
db analyze users  # update statistics for table
db analyze        # update all statistics
```

### Backup & Data

```bash
db dump           # backup → backup-YYYYMMDD-HHMMSS.sql
db restore file   # restore from backup
db truncate users # clear table (with confirm)
db exec file.sql  # execute sql file
db x csv "SQL"    # export to csv
db x json "SQL"   # export to json
db import csv data.csv users  # import csv to table
db cp src dest    # copy table
```

### Query Tools

```bash
db explain "SQL"  # query plan
db hist           # query history
db last           # re-run last query
db edit           # edit & run query in $EDITOR
db watch "SQL" 5  # repeat query every 5s
db migrate        # run migrations (prisma/drizzle/knex)
```

### Config & Profiles

```bash
db init             # create .dbrc in current dir
db init global      # create ~/.config/db/.dbrc
db config           # show current config
db config set DB_SAMPLE_LIMIT 20
db config edit      # open .dbrc in editor
db profiles         # list all profiles
```

### Bookmarks

```bash
db save user-count "SELECT COUNT(*) FROM users"
db run user-count   # execute saved query
db @user-count      # shorthand for db run
db bookmarks        # list all
db rm user-count    # delete
```

## Flags

```bash
--env=FILE      # custom env file (default: .env)
--var=NAME      # env variable name (default: DATABASE_URL)
--url=URL       # use url directly (skip .env)
-p, --profile   # use named profile from .dbrc
--format=FMT    # output format (table/json/csv)
-w, --wide      # show all columns (no truncation)
--cols=N        # limit number of columns displayed
--col-width=N   # max column width (default: 30)
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

# === Behavior ===
DB_AUTO_DETECT=true           # auto-detect from Prisma, Drizzle
DB_CONFIRM_DESTRUCTIVE=true   # confirm truncate, restore, vacuum
DB_SHOW_QUERY_TIME=false      # show query execution time

# === Table Display ===
DB_COL_WIDTH=30               # max column width (0=unlimited)
DB_MAX_COLS=0                 # max columns to show (0=all)

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
db connect          # pick with fzf
db diff local prod  # compare schemas
```

## Features

- **Security**: SQL identifier validation prevents injection attacks
- **FZF Integration**: Interactive table/profile selection when no arg provided
- **Dynamic Completions**: Tab-complete table names and profiles
- **Flexible Config**: Custom env variable names via config or flags
- **Query Timing**: Optional execution time display
- **Auto-Detect**: Finds DATABASE_URL from Prisma, Drizzle, .env.local automatically
- **ER Diagrams**: Generate Mermaid diagrams of your schema

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

# Schema comparison
db diff local staging

# Find all user-related columns
db search user

# Check slow queries
db slowlog 20

# Maintenance
db vacuum users && db analyze users

# Table display options
db sample users              # default: 30 char columns
db sample users --wide       # show all columns, no truncation
db sample users --cols=5     # show only first 5 columns
db sample users --col-width=50  # wider columns
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
│   ├── core/              # core functionality
│   │   ├── init.zsh       # constants, colors, state
│   │   ├── config.zsh     # config management, profiles
│   │   ├── helpers.zsh    # utility functions
│   │   └── output.zsh     # output formatting
│   ├── commands/          # command modules (lazy loaded)
│   │   ├── data.zsh       # tables, schema, sample, count
│   │   ├── query.zsh      # query, explain, watch, edit
│   │   ├── helpers.zsh    # desc, select, where, agg
│   │   ├── backup.zsh     # dump, restore, export, import
│   │   ├── schema.zsh     # indexes, fk, search, diff
│   │   ├── maintenance.zsh # vacuum, analyze, locks
│   │   ├── monitoring.zsh # tail, changes
│   │   ├── bookmarks.zsh  # save, run bookmarks
│   │   ├── config.zsh     # init, config commands
│   │   └── meta.zsh       # help, version, info
│   ├── adapters/          # database adapters (modular)
│   │   ├── postgres/
│   │   │   ├── init.zsh       # core operations
│   │   │   ├── query.zsh      # query operations
│   │   │   ├── schema.zsh     # schema operations
│   │   │   ├── data.zsh       # data helpers
│   │   │   └── maintenance.zsh # maintenance
│   │   ├── mysql/         # same structure
│   │   ├── sqlite/        # same structure
│   │   └── mongodb/       # same structure
│   └── dispatch.zsh       # command routing
├── completions/_db        # zsh completion
├── plugins/               # custom plugins
├── example/
│   ├── .dbrc.global       # sample global config
│   └── .dbrc.project      # sample project config
├── AGENTS.md              # coding agent guidelines
└── README.md              # this file
```

Config locations:
- Global: `~/.config/db/.dbrc`
- Project: `.dbrc` (current directory)
- Plugins: `~/.config/db/plugins/`

## Development

For coding agent guidelines, code style, testing commands, and contribution guidelines, see [AGENTS.md](./AGENTS.md).

## Adding New Database

Create modular adapter in `lib/adapters/newdb/`:

```
lib/adapters/newdb/
├── init.zsh         # core operations (cli, native, test, stats)
├── query.zsh        # query operations (query, tables, schema)
├── schema.zsh       # schema operations (indexes, fk, search)
├── data.zsh         # data helpers (agg, distinct, nulls)
└── maintenance.zsh  # maintenance (vacuum, analyze, locks)
```

Each adapter must implement:

```bash
# Required
adapter::cli          # interactive client
adapter::native       # native client with args
adapter::query        # execute sql
adapter::tables       # list tables
adapter::tables_plain # list tables (plain, for fzf)
adapter::schema       # table schema
adapter::count        # row count
adapter::sample       # preview rows
adapter::test         # connection test
adapter::stats        # statistics
adapter::dump         # backup
adapter::restore      # restore
adapter::truncate     # clear table
adapter::exec         # execute file
adapter::explain      # query plan
adapter::dbs          # list databases
adapter::export       # export data
adapter::copy         # copy table
adapter::top          # largest tables
adapter::health       # performance diagnostics
adapter::connections  # active connections

# New in v1.4
adapter::indexes      # table indexes
adapter::fk           # foreign keys
adapter::locks        # current locks
adapter::kill         # terminate connection
adapter::slowlog      # slow queries
adapter::vacuum       # vacuum/optimize
adapter::analyze      # update statistics
adapter::search       # search tables/columns
adapter::diff         # compare schemas
adapter::table_size   # detailed table size
adapter::users        # list users/roles
adapter::grants       # table permissions

# New in v1.5
adapter::import       # import csv/json
adapter::er           # ER diagram (mermaid)
adapter::agg          # aggregate stats
adapter::distinct     # distinct values
adapter::nulls        # null counts
adapter::dup          # find duplicates
adapter::rename       # rename table
adapter::drop         # drop table
adapter::comment      # set table comment
adapter::get_comment  # get table comment
adapter::tail         # recent rows
adapter::changes      # rows changed in time window
```

Then add detection in `lib/core/config.zsh`:

```bash
db::detect() {
  case "$1" in
    newdb://*) echo "newdb" ;;
    ...
  esac
}
```

## Key Features

- **Modular Architecture**: Lazy-loaded command modules for fast startup
- **Plugin System**: Extend functionality with custom plugins in `~/.config/db/plugins/`
- **Adapter Pattern**: Consistent interface across all database types
- **Security First**: SQL identifier validation prevents injection attacks
- **Smart Defaults**: Auto-detect DATABASE_URL from Prisma, Drizzle, .env variants
- **Interactive**: FZF integration for table/profile selection
- **Developer Friendly**: Tab completion, query history, bookmarks
