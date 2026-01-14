# MySQL adapter

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
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" "$@"
}

adapter::query() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "$1"
}

adapter::tables() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e 'SHOW TABLES'
}

adapter::schema() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "DESCRIBE $1"
}

adapter::count() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -sN -e "SELECT COUNT(*) FROM $1"
}

adapter::test() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "SELECT 1" &>/dev/null && db::ok "connected" || { db::err "connection failed"; return 1; }
}

adapter::stats() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "
    SELECT
      ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'size_mb',
      COUNT(*) AS 'tables'
    FROM information_schema.tables WHERE table_schema = DATABASE()"
}

adapter::connections() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "SHOW PROCESSLIST"
}

adapter::dump() {
  db::need mysqldump "brew install mysql-client" || return 1
  local out="backup-$(date +%Y%m%d-%H%M%S).sql"
  mysqldump "$DB_URL" > "$out" && db::ok "saved: $out" || { db::err "dump failed"; return 1; }
}

adapter::restore() {
  db::need mysql "brew install mysql-client" || return 1
  [[ -f "$1" ]] || { db::err "file not found: $1"; return 1; }
  mysql "$DB_URL" < "$1" && db::ok "restored: $1"
}

adapter::explain() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "EXPLAIN $1"
}

adapter::dbs() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e 'SHOW DATABASES'
}

adapter::export() {
  db::need mysql "brew install mysql-client" || return 1
  local fmt="$1" sql="$2" out="${3:-export-$(date +%Y%m%d-%H%M%S).$fmt}"
  mysql "$DB_URL" -e "$sql" > "$out"
  [[ -s "$out" ]] && db::ok "exported: $out" || { rm -f "$out"; db::err "empty result"; return 1; }
}

adapter::copy() {
  db::need mysql "brew install mysql-client" || return 1
  mysql "$DB_URL" -e "CREATE TABLE $2 AS SELECT * FROM $1" && db::ok "copied: $1 -> $2"
}
