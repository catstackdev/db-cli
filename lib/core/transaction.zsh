#!/usr/bin/env zsh
# db - Transaction management

readonly DB_TX_FILE="/tmp/db-tx-$$.state"
typeset -g DB_TX_ACTIVE=0

# Start transaction
tx::begin() {
  [[ $DB_TX_ACTIVE -eq 1 ]] && { db::warn "transaction already active"; return 1; }
  
  adapter::tx_begin || return $DB_ERR_DB
  
  echo "$(date +%s)" > "$DB_TX_FILE"
  DB_TX_ACTIVE=1
  
  # Set trap for cleanup on exit/interrupt
  trap 'tx::auto_rollback' INT TERM EXIT
  
  db::ok "transaction started"
}

# Commit transaction
tx::commit() {
  [[ $DB_TX_ACTIVE -eq 0 ]] && { db::err "no active transaction"; return 1; }
  
  adapter::tx_commit || return $DB_ERR_DB
  
  tx::cleanup
  db::ok "transaction committed"
}

# Rollback transaction
tx::rollback() {
  [[ $DB_TX_ACTIVE -eq 0 ]] && { db::err "no active transaction"; return 1; }
  
  adapter::tx_rollback || return $DB_ERR_DB
  
  tx::cleanup
  db::ok "transaction rolled back"
}

# Show transaction status
tx::status() {
  if [[ $DB_TX_ACTIVE -eq 1 ]]; then
    local start=$(cat "$DB_TX_FILE" 2>/dev/null || echo 0)
    local duration=$(($(date +%s) - start))
    echo "${C_GREEN}●${C_RESET} transaction active (${duration}s)"
  else
    echo "${C_DIM}○${C_RESET} no transaction"
  fi
}

# Auto-rollback on error or interrupt
tx::auto_rollback() {
  [[ $DB_TX_ACTIVE -eq 0 ]] && return 0
  
  db::warn "auto-rolling back transaction"
  adapter::tx_rollback 2>/dev/null
  tx::cleanup
}

# Cleanup transaction state
tx::cleanup() {
  rm -f "$DB_TX_FILE" 2>/dev/null
  DB_TX_ACTIVE=0
  trap - INT TERM EXIT
}

# Check if in transaction
tx::active() {
  [[ $DB_TX_ACTIVE -eq 1 ]]
}
