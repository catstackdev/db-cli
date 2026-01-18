# SQLite adapter - Maintenance operations

adapter::health() {
  _sqlite::need || return 1
  echo "${C_BLUE}=== Integrity ===${C_RESET}"
  sqlite3 "$(_sqlite::path)" "PRAGMA integrity_check"
  echo "${C_BLUE}=== Freelist ===${C_RESET}"
  echo "free_pages: $(sqlite3 "$(_sqlite::path)" "PRAGMA freelist_count")"
}

adapter::connections() {
  db::log "sqlite: single-user, no connection pool"
}

adapter::locks() {
  db::log "sqlite: file-based locking, no lock table"
  if sqlite3 "$(_sqlite::path)" "SELECT 1" &>/dev/null; then
    db::ok "database is not locked"
  else
    db::warn "database may be locked by another process"
  fi
}

adapter::kill() {
  db::log "sqlite: single-user database, no connections to kill"
  return 1
}

adapter::slowlog() {
  db::log "sqlite: no slow query log available"
  db::log "use EXPLAIN QUERY PLAN to analyze queries"
  return 1
}

adapter::vacuum() {
  _sqlite::need || return 1
  if [[ -n "$1" ]]; then
    db::log "sqlite: VACUUM operates on entire database"
  fi
  sqlite3 "$(_sqlite::path)" "VACUUM" && db::ok "vacuumed database"
}

adapter::analyze() {
  _sqlite::need || return 1
  if [[ -n "$1" ]]; then
    db::valid_id "$1" || return 1
    sqlite3 "$(_sqlite::path)" "ANALYZE $1" && db::ok "analyzed: $1"
  else
    sqlite3 "$(_sqlite::path)" "ANALYZE" && db::ok "analyzed all tables"
  fi
}
