#!/usr/bin/env zsh
# db - Migration commands
# @commands: migrate

cmd::migrate() {
  local action="${1:-up}"
  
  case "$action" in
    status|st)
      migrate::status
      ;;
    up|apply)
      migrate::up
      ;;
    down|rollback)
      migrate::down
      ;;
    create|new)
      shift
      migrate::create "$@"
      ;;
    detect)
      local tool=$(migrate::detect)
      echo "Detected: $tool"
      ;;
    *)
      # Default: run migrations (backward compat)
      if [[ -z "$1" ]]; then
        migrate::up
      else
        echo "usage: db migrate <status|up|down|create> [args]"
        echo ""
        echo "commands:"
        echo "  status    show migration status"
        echo "  up        apply pending migrations"
        echo "  down      rollback last migration"
        echo "  create N  create new migration"
        echo "  detect    detect migration tool"
        return 1
      fi
      ;;
  esac
}
