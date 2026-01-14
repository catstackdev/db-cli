# db

Universal database CLI with adapter-based architecture.

Supports **PostgreSQL**, **MySQL**, **SQLite**, **MongoDB**.

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
db schema users   # show table schema
db count users    # count rows
db stats          # database size & table count
db conn           # active connections
db dbs            # list databases
db dump           # backup → backup-YYYYMMDD-HHMMSS.sql
db restore file   # restore from backup
db x csv "SQL"    # export to csv
db x json "SQL"   # export to json
db cp src dest    # copy table
db explain "SQL"  # query plan
db hist           # query history
db watch "SQL" 5  # repeat query every 5s
db migrate        # run migrations (prisma/drizzle/knex)
db help           # show help
```

## Flags

```bash
--env=FILE    # custom env file (default: .env)
-v, --verbose # debug output
-q, --quiet   # no confirmations
```

## Examples

```bash
# Different env file
db --env=.env.local test

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
└── completions/_db         # zsh completion
```

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
