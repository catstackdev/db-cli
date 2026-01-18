# db - Config commands
# @commands: init, config, profiles, connect

cmd::init() {
  local target="${1:-.dbrc}"
  local type="${2:-project}"

  if [[ "$target" == "global" ]]; then
    target="$DB_GLOBAL_RC"
    mkdir -p "$(dirname "$target")"
  fi

  if [[ -f "$target" ]]; then
    db::warn "$target already exists"
    echo -n "overwrite? [y/N] "
    read -r ans
    [[ "$ans" != [yY] ]] && {
      echo "cancelled"
      return 1
    }
  fi

  cat >"$target" <<'DBRC'
# db config file
# Docs: db help config

# === Connection ===
DB_URL_VAR="DATABASE_URL"
DB_ENV_FILE=".env"

# === Output ===
DB_PAGER="less -S"
DB_SAMPLE_LIMIT=10
DB_FORMAT="table"
DB_SCHEMA="public"

# === History ===
DB_HISTORY_FILE="$HOME/.db_history"
DB_HISTORY_SIZE=1000

# === Backup ===
DB_BACKUP_DIR="."

# === Editor ===
DB_EDITOR="${EDITOR:-vim}"

# === Profiles (named connections) ===
# DB_PROFILES=(
#   [local]="postgres://localhost/mydb"
#   [staging]="postgres://staging-server/mydb"
#   [prod]="postgres://prod-server/mydb"
# )

# === Bookmarks ===
DB_BOOKMARKS_FILE="$HOME/.db_bookmarks"
DBRC

  db::ok "created: $target"
}

cmd::config() {
  local action="${1:-show}"
  local key="$2"
  local value="$3"

  case "$action" in
  show | list)
    echo "${C_BLUE}=== Current Config ===${C_RESET}"
    echo "DB_URL_VAR=$DB_URL_VAR"
    echo "DB_ENV_FILE=$DB_ENV_FILE"
    echo "DB_BACKUP_DIR=$DB_BACKUP_DIR"
    echo "DB_HISTORY_FILE=$DB_HISTORY_FILE"
    echo "DB_HISTORY_SIZE=$DB_HISTORY_SIZE"
    echo "DB_SAMPLE_LIMIT=$DB_SAMPLE_LIMIT"
    echo "DB_PAGER=$DB_PAGER"
    echo "DB_EDITOR=$DB_EDITOR"
    echo "DB_SCHEMA=$DB_SCHEMA"
    echo "DB_FORMAT=$DB_FORMAT"
    echo ""
    echo "${C_BLUE}=== Config Files ===${C_RESET}"
    echo "global:  $DB_GLOBAL_RC $([[ -f "$DB_GLOBAL_RC" ]] && echo '(exists)' || echo '(missing)')"
    echo "project: $DB_PROJECT_RC $([[ -f "$DB_PROJECT_RC" ]] && echo '(exists)' || echo '(missing)')"
    ;;
  get)
    [[ -z "$key" ]] && {
      echo "usage: db config get <key>"
      return 1
    }
    eval "echo \${$key}"
    ;;
  set)
    [[ -z "$key" || -z "$value" ]] && {
      echo "usage: db config set <key> <value>"
      return 1
    }
    local rc="${DB_PROJECT_RC}"
    [[ ! -f "$rc" ]] && cmd::init "$rc" >/dev/null
    if grep -q "^$key=" "$rc" 2>/dev/null; then
      sed -i '' "s|^$key=.*|$key=\"$value\"|" "$rc"
    else
      echo "$key=\"$value\"" >>"$rc"
    fi
    db::ok "set $key=$value in $rc"
    ;;
  edit)
    local rc="${2:-$DB_PROJECT_RC}"
    [[ "$rc" == "global" ]] && rc="$DB_GLOBAL_RC"
    [[ ! -f "$rc" ]] && cmd::init "$rc" >/dev/null
    "$(db::editor)" "$rc"
    ;;
  *)
    echo "usage: db config [show|get|set|edit] [key] [value]"
    ;;
  esac
}

cmd::profiles() {
  if [[ ${#DB_PROFILES[@]} -eq 0 ]]; then
    echo "no profiles configured"
    echo ""
    echo "add to .dbrc:"
    echo '  DB_PROFILES=('
    echo '    [local]="postgres://localhost/mydb"'
    echo '    [prod]="postgres://prod-server/mydb"'
    echo '  )'
    return 0
  fi
  echo "${C_BLUE}=== Profiles ===${C_RESET}"
  db::list_profiles
}

cmd::connect() {
  local profile=$(db::fzf_profile)
  [[ -z "$profile" ]] && {
    [[ ${#DB_PROFILES[@]} -eq 0 ]] && {
      echo "no profiles configured"
      echo ""
      echo "add to .dbrc:"
      echo '  DB_PROFILES=('
      echo '    [local]="postgres://localhost/mydb"'
      echo '  )'
      return 0
    }
    echo "cancelled"
    return 1
  }
  db::log "connecting to: $profile"
  DB_URL="${DB_PROFILES[$profile]}"
  DB_TYPE=$(db::detect "$DB_URL") || return 1
  db::load_adapter "$DB_TYPE" || return 1
  adapter::cli
}
