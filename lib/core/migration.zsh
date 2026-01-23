#!/usr/bin/env zsh
# db - Migration detection and management

# Detect migration tool
migrate::detect() {
  # Prisma
  if [[ -f package.json ]] && grep -q '"prisma"' package.json 2>/dev/null; then
    echo "prisma"
    return 0
  fi
  
  # Drizzle
  if [[ -f drizzle.config.ts || -f drizzle.config.js ]]; then
    echo "drizzle"
    return 0
  fi
  
  # Knex
  if [[ -f knexfile.js || -f knexfile.ts ]]; then
    echo "knex"
    return 0
  fi
  
  # Flyway
  if [[ -d sql ]] && ls sql/*.sql &>/dev/null; then
    echo "flyway"
    return 0
  fi
  
  # Liquibase
  if [[ -f liquibase.properties || -f changelog.xml ]]; then
    echo "liquibase"
    return 0
  fi
  
  # Generic migrations directory
  if [[ -d migrations ]] && ls migrations/*.sql &>/dev/null 2>/dev/null; then
    echo "generic"
    return 0
  fi
  
  echo "none"
  return 1
}

# Get migration status
migrate::status() {
  local tool=$(migrate::detect)
  
  case "$tool" in
    prisma)
      npx prisma migrate status 2>&1 || { db::err "prisma migrate failed (install: npm install prisma)"; return 1; }
      ;;
    drizzle)
      npx drizzle-kit studio --help >/dev/null 2>&1 && echo "Drizzle detected - use: npx drizzle-kit" || { db::err "drizzle-kit not available"; return 1; }
      ;;
    knex)
      npx knex migrate:status 2>&1 || { db::err "knex migrate failed (install: npm install knex)"; return 1; }
      ;;
    flyway)
      command -v flyway &>/dev/null || { db::err "flyway not found (install: brew install flyway)"; return 1; }
      flyway info
      ;;
    liquibase)
      command -v liquibase &>/dev/null || { db::err "liquibase not found (install: brew install liquibase)"; return 1; }
      liquibase status
      ;;
    generic)
      migrate::generic_status
      ;;
    none)
      db::err "no migration tool detected"
      return 1
      ;;
  esac
}

# Generic migration status (for plain SQL files)
migrate::generic_status() {
  echo "${C_BLUE}=== Migration Files ===${C_RESET}"
  
  if [[ ! -d migrations ]]; then
    echo "No migrations/ directory"
    return 1
  fi
  
  local -a files=(migrations/*.sql(N))
  [[ ${#files[@]} -eq 0 ]] && { echo "No migration files found"; return 1; }
  
  for file in $files; do
    echo "  ${file:t}"
  done
  
  echo ""
  echo "Total: ${#files[@]} migration(s)"
}

# Run migrations
migrate::up() {
  local tool=$(migrate::detect)
  
  case "$tool" in
    prisma)
      npx prisma migrate deploy
      ;;
    drizzle)
      npx drizzle-kit push
      ;;
    knex)
      npx knex migrate:latest
      ;;
    flyway)
      flyway migrate
      ;;
    liquibase)
      liquibase update
      ;;
    generic)
      migrate::generic_up
      ;;
    *)
      db::err "no migration tool detected"
      return 1
      ;;
  esac
}

# Rollback migrations
migrate::down() {
  local tool=$(migrate::detect)
  
  case "$tool" in
    prisma)
      db::warn "Prisma doesn't support rollback - use shadow database"
      return 1
      ;;
    drizzle)
      db::warn "Drizzle doesn't support automatic rollback"
      return 1
      ;;
    knex)
      npx knex migrate:rollback
      ;;
    flyway)
      flyway undo
      ;;
    liquibase)
      liquibase rollback-count 1
      ;;
    generic)
      db::err "generic migrations don't support rollback"
      return 1
      ;;
    *)
      db::err "no migration tool detected"
      return 1
      ;;
  esac
}

# Create new migration
migrate::create() {
  local name="$1"
  [[ -z "$name" ]] && { db::err "usage: migrate create <name>"; return 1; }
  
  local tool=$(migrate::detect)
  
  case "$tool" in
    prisma)
      npx prisma migrate dev --name "$name" --create-only
      ;;
    drizzle)
      npx drizzle-kit generate
      ;;
    knex)
      npx knex migrate:make "$name"
      ;;
    flyway|generic)
      migrate::create_generic "$name"
      ;;
    liquibase)
      db::warn "use liquibase directly to create changesets"
      return 1
      ;;
    *)
      db::err "no migration tool detected"
      return 1
      ;;
  esac
}

# Create generic migration file
migrate::create_generic() {
  local name="$1"
  local timestamp=$(date +%Y%m%d%H%M%S)
  local filename="migrations/${timestamp}_${name}.sql"
  
  mkdir -p migrations
  
  cat > "$filename" <<EOF
-- Migration: $name
-- Created: $(date '+%Y-%m-%d %H:%M:%S')

-- Add your SQL here

EOF
  
  db::ok "created: $filename"
}

# Generic up (execute all pending)
migrate::generic_up() {
  local -a files=(migrations/*.sql(N))
  [[ ${#files[@]} -eq 0 ]] && { db::err "no migration files"; return 1; }
  
  db::confirm "execute ${#files[@]} migration(s)" || return 1
  
  for file in $files; do
    echo "${C_BLUE}Running:${C_RESET} ${file:t}"
    adapter::exec "$file" || { db::err "failed: ${file:t}"; return 1; }
  done
  
  db::ok "all migrations completed"
}
