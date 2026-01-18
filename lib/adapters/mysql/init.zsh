# MySQL adapter - Core
# Connection, CLI, basic operations

# Helper: check mysql is available
_mysql::need() {
  db::need mysql "brew install mysql-client"
}

adapter::cli() {
  if command -v mycli &>/dev/null; then
    mycli "$DB_URL"
  elif command -v mysql &>/dev/null; then
    mysql "$DB_URL"
  else
    db::err "install: brew install mycli"
    return 1
  fi
}

adapter::native() {
  _mysql::need || return 1
  mysql "$DB_URL" "$@"
}

adapter::test() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "SELECT 1" &>/dev/null && db::ok "connected" || { db::err "connection failed"; return 1; }
}

adapter::dbs() {
  _mysql::need || return 1
  mysql "$DB_URL" -e 'SHOW DATABASES'
}

adapter::stats() {
  _mysql::need || return 1
  mysql "$DB_URL" -e "
    SELECT
      DATABASE() as db,
      ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb,
      ROUND(SUM(data_length) / 1024 / 1024, 2) AS data_mb,
      ROUND(SUM(index_length) / 1024 / 1024, 2) AS index_mb,
      COUNT(*) AS tables,
      SUM(table_rows) AS total_rows
    FROM information_schema.tables WHERE table_schema = DATABASE()"
  mysql "$DB_URL" -e "SELECT VERSION() as version"
}

adapter::top() {
  _mysql::need || return 1
  local limit="${1:-10}"
  mysql "$DB_URL" -e "
    SELECT
      table_name as 'table',
      ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb,
      ROUND(data_length / 1024 / 1024, 2) AS data_mb,
      ROUND(index_length / 1024 / 1024, 2) AS index_mb,
      table_rows as rows
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
    ORDER BY (data_length + index_length) DESC
    LIMIT $limit"
}

adapter::dump() {
  db::need mysqldump "brew install mysql-client" || return 1
  [[ -d "$DB_BACKUP_DIR" ]] || mkdir -p "$DB_BACKUP_DIR"
  local out="$DB_BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"
  mysqldump "$DB_URL" > "$out" && db::ok "saved: $out" || { db::err "dump failed"; return 1; }
}

adapter::restore() {
  _mysql::need || return 1
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  mysql "$DB_URL" < "$1" && db::ok "restored: $1"
}

adapter::exec() {
  _mysql::need || return 1
  mysql "$DB_URL" < "$1"
}

# Load sub-modules
source "${0:A:h}/query.zsh"
source "${0:A:h}/schema.zsh"
source "${0:A:h}/maintenance.zsh"
source "${0:A:h}/data.zsh"
