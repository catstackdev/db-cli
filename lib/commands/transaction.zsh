#!/usr/bin/env zsh
# db - Transaction commands
# @commands: tx

cmd::tx() {
  local action="$1"
  
  case "$action" in
    begin|start)
      tx::begin
      ;;
    commit|c)
      tx::commit
      ;;
    rollback|rb|abort)
      tx::rollback
      ;;
    status|st)
      tx::status
      ;;
    *)
      echo "usage: db tx <begin|commit|rollback|status>"
      echo ""
      echo "commands:"
      echo "  begin      - start transaction"
      echo "  commit     - commit transaction"
      echo "  rollback   - rollback transaction"
      echo "  status     - show transaction status"
      return 1
      ;;
  esac
}
