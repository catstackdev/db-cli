#!/usr/bin/env zsh
# db - Backup management commands
# @commands: backup

cmd::backup() {
  local action="${1:-create}"
  
  case "$action" in
    create|auto)
      shift
      backup::auto "$@"
      ;;
    list|ls)
      backup::list
      ;;
    cleanup|clean)
      shift
      backup::cleanup "$@"
      ;;
    verify)
      shift
      [[ -z "$1" ]] && { db::err "usage: db backup verify <file>"; return 1; }
      backup::verify "$1"
      ;;
    restore)
      shift
      [[ -z "$1" ]] && { db::err "usage: db backup restore <file>"; return 1; }
      backup::restore_from "$1"
      ;;
    cron)
      shift
      backup::cron_cmd "$@"
      ;;
    *)
      echo "usage: db backup <command> [args]"
      echo ""
      echo "commands:"
      echo "  create [NAME]   create backup with auto cleanup"
      echo "  list            list all backups"
      echo "  cleanup [N]     keep only N most recent (default: 7)"
      echo "  verify FILE     verify backup integrity"
      echo "  restore FILE    restore from backup"
      echo "  cron [SCHEDULE] show cron command for scheduling"
      echo ""
      echo "examples:"
      echo "  db backup              # create backup with auto cleanup"
      echo "  db backup cleanup 14   # keep last 14 backups"
      echo "  db backup cron         # show cron setup"
      return 1
      ;;
  esac
}
