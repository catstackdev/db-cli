# Agent Guidelines for db CLI

Universal database CLI with adapter-based architecture. Written in Zsh with modular design supporting PostgreSQL, MySQL, SQLite, and MongoDB.

## Build/Lint/Test Commands

### No Build System Required
This is a shell script project - no compilation needed.

### Testing
```bash
# Test database connection
db test

# Test specific command manually
db tables
db sample users 5
db stats

# Test adapter functions directly
source lib/adapters/postgres/init.zsh
adapter::test

# Test individual command modules
source lib/commands/data.zsh
cmd::tables
```

### Linting
```bash
# Check shell syntax
zsh -n bin/db
zsh -n lib/core/init.zsh

# Run shellcheck if available
shellcheck bin/db lib/**/*.zsh
```

### Integration Testing
```bash
# Test full workflow with test database
export DATABASE_URL="postgresql://localhost/test_db"
db test && db tables && db sample users 3
```

## Code Style Guidelines

### File Organization

#### Structure
```
lib/
├── core/          # Core functionality (init, config, helpers, output)
├── commands/      # Command modules (data, query, backup, etc.)
└── adapters/      # Database adapters (postgres, mysql, sqlite, mongodb)
    └── <type>/    # Modular adapter (init, query, schema, data, maintenance)
```

#### Naming Conventions
- **Shell scripts**: `snake_case.zsh` - `init.zsh`, `helpers.zsh`
- **Adapters**: `<dbtype>/init.zsh` - `postgres/query.zsh`
- **Commands**: Descriptive names - `data.zsh`, `backup.zsh`, `monitoring.zsh`

### Shell Script Style

#### Shebang
```bash
#!/usr/bin/env zsh
# db - description
```

#### Function Naming
```bash
# Core functions - db:: prefix
db::err()           # error output
db::mask()          # utility function
db::load_config()   # loader function

# Command functions - cmd:: prefix
cmd::tables()       # tables command
cmd::sample()       # sample command
cmd::help()         # help command

# Adapter functions - adapter:: prefix (implemented per database)
adapter::cli()      # interactive client
adapter::query()    # execute query
adapter::tables()   # list tables
adapter::sample()   # sample rows

# Private adapter functions - _<adapter>:: prefix
_pg::need()         # postgres private helper
_mysql::escape()    # mysql private helper
```

#### Variable Naming
```bash
# Global constants - UPPERCASE with readonly
readonly DB_VERSION="2.0.0"
readonly DB_ROOT="${0:A:h:h}"
readonly C_RED=$'\e[31m'

# Global configuration - DB_ prefix with typeset -g
typeset -g DB_URL=""
typeset -g DB_TYPE=""
typeset -g DB_VERBOSE=0

# Associative arrays - typeset -gA with _ARR suffix optional
typeset -gA DB_PROFILES=()
typeset -gA DB_LOADED_MODULES=()

# Local variables - lowercase
local table="$1"
local limit="${2:-10}"
local env_file=".env"
```

#### Declarations
```bash
# Global associative arrays
typeset -gA DB_PROFILES=()
typeset -gA DB_CMD_MODULE=(
  [help]=meta
  [query]=query
)

# Global strings/integers
typeset -g DB_URL=""
typeset -g DB_VERBOSE=0

# Local variables in functions
local table="${1:-$(db::fzf_table)}"
local limit="${2:-$DB_SAMPLE_LIMIT}"
```

#### Error Handling
```bash
# Check command availability
command -v psql &>/dev/null || { db::err "psql not found"; return 1; }

# Use helper functions
db::need psql "brew install postgresql@16" || return 1

# Validate identifiers (SQL injection prevention)
db::valid_id "$table" || return 1

# Check file existence
[[ -f "$file" ]] || { db::err "file not found: $file"; return 1; }

# Short-circuit with ||/&&
psql "$DB_URL" -c "SELECT 1" && db::ok "success" || { db::err "failed"; return 1; }
```

#### Comment Style
```bash
# Single-line comments with space after #
# Explain complex logic inline

# File headers with description
# db - Core initialization
# Constants, colors, state variables

# Module headers in command files
# db - Data commands
# @commands: tables, schema, sample, count, size, top, stats, dbs, test
```

### Output Functions

```bash
# Use standardized output helpers
db::err "error message"     # Red "error:" prefix, stderr
db::warn "warning"          # Yellow "warn:" prefix, stderr
db::ok "success message"    # Green "ok:" prefix (respects --quiet)
db::log "info message"      # Plain output (respects --quiet)
db::dbg "debug info"        # Gray dim output (only with --verbose)
```

### Modular Design Patterns

#### Lazy Loading
```bash
# Commands are lazy-loaded via dispatch.zsh
# Only load modules when needed to reduce startup time

db::ensure_module() {
  local module="$1"
  [[ -n "${DB_LOADED_MODULES[$module]}" ]] && return 0
  
  source "$DB_COMMANDS_DIR/${module}.zsh"
  DB_LOADED_MODULES[$module]=1
}
```

#### Adapter Pattern
```bash
# Each database type implements standard adapter:: functions
# Core functions in init.zsh, organized by category in submodules

# Adapter structure:
adapter/postgres/
├── init.zsh         # Core: cli, native, test, stats, dump, restore
├── query.zsh        # Query operations: query, tables, schema, sample, count
├── schema.zsh       # Schema operations: indexes, fk, search, diff
├── data.zsh         # Data helpers: agg, distinct, nulls, dup
└── maintenance.zsh  # Maintenance: vacuum, analyze, locks, kill

# Load submodules in init.zsh
source "${0:A:h}/query.zsh"
source "${0:A:h}/schema.zsh"
```

## Development Guidelines

1. **Follow modular structure** - Keep commands, core, adapters separate
2. **Use function prefixes** - `db::`, `cmd::`, `adapter::`, `_private::`
3. **Validate SQL identifiers** - Always use `db::valid_id()` before SQL
4. **Support FZF integration** - Allow interactive selection with fallback
5. **Respect flags** - Honor `--verbose`, `--quiet`, `DB_CONFIRM_DESTRUCTIVE`
6. **Lazy load modules** - Don't source all files at startup
7. **Implement full adapter** - All `adapter::` functions for new databases
8. **Add to dispatch.zsh** - Register commands in `DB_CMD_MODULE` map
9. **Update completions** - Add new commands to `completions/_db`
10. **Document in README** - Add usage examples for new features

## Adding New Features

### New Command
```bash
# 1. Create or edit command module in lib/commands/
# 2. Add cmd:: function
# 3. Register in lib/dispatch.zsh DB_CMD_MODULE
# 4. Add dispatcher case in db::run()
# 5. Update completions/_db
```

### New Adapter Function
```bash
# 1. Implement in all adapters: postgres, mysql, sqlite, mongodb
# 2. Follow naming: adapter::<function_name>
# 3. Add helper command in appropriate lib/commands/ module
# 4. Validate inputs and handle errors consistently
```

## No Cursor/Copilot Rules Found
No Cursor rules (`.cursor/rules/` or `.cursorrules`) found.
No Copilot rules (`.github/copilot-instructions.md`) found.
