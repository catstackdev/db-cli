# Example db plugin
# Copy this file to ~/.config/db/plugins/myplugin.zsh
#
# Plugin commands are prefixed with plugin:: and can be called via:
#   db <command-name>
#
# The DB_CMD_MODULE array in dispatch.zsh doesn't need to be modified -
# plugins are discovered automatically if the function exists.

# === Example: Custom report command ===
# Usage: db daily-report
plugin::daily-report() {
  echo "${C_BLUE}=== Daily Report ===${C_RESET}"
  echo "Date: $(date '+%Y-%m-%d')"
  echo ""

  # Use existing adapter functions
  echo "${C_BLUE}=== Table Sizes ===${C_RESET}"
  adapter::top 5

  echo ""
  echo "${C_BLUE}=== Recent Activity ===${C_RESET}"
  if [[ -f "$DB_HISTORY_FILE" ]]; then
    echo "Queries today: $(grep -c "$(date '+%Y-%m-%d')" "$DB_HISTORY_FILE" 2>/dev/null || echo 0)"
  fi
}

# === Example: Quick backup with timestamp ===
# Usage: db quick-backup
plugin::quick-backup() {
  local timestamp=$(date '+%Y%m%d_%H%M%S')
  local backup_file="${DB_BACKUP_DIR}/backup_${timestamp}.sql"

  db::log "Creating backup: $backup_file"
  adapter::dump > "$backup_file" 2>/dev/null

  if [[ -f "$backup_file" ]]; then
    db::ok "Backup created: $backup_file ($(du -h "$backup_file" | cut -f1))"
  else
    db::err "Backup failed"
    return 1
  fi
}

# === Example: Environment info ===
# Usage: db env-info
plugin::env-info() {
  echo "${C_BLUE}=== Environment ===${C_RESET}"
  echo "DB_TYPE: $DB_TYPE"
  echo "DB_URL: $(db::mask "$DB_URL")"
  echo "DB_ENV_FILE: $DB_ENV_FILE"
  echo "DB_SCHEMA: $DB_SCHEMA"
  echo ""
  echo "${C_BLUE}=== Paths ===${C_RESET}"
  echo "DB_LIB_DIR: $DB_LIB_DIR"
  echo "DB_PLUGINS_DIR: $DB_PLUGINS_DIR"
  echo "DB_HISTORY_FILE: $DB_HISTORY_FILE"
  echo "DB_BOOKMARKS_FILE: $DB_BOOKMARKS_FILE"
  echo ""
  echo "${C_BLUE}=== Loaded Modules ===${C_RESET}"
  for mod in ${(k)DB_LOADED_MODULES}; do
    echo "  - $mod"
  done
}

# Register plugin commands for help/completion
# This is optional but recommended for discoverability
DB_PLUGIN_COMMANDS+=(
  "daily-report:generate daily database report"
  "quick-backup:create timestamped backup"
  "env-info:show environment and paths"
)
