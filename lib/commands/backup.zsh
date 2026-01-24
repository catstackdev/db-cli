# db - Backup & data commands
# @commands: dump, restore, truncate, exec, export, copy, import

cmd::dump() {
  adapter::dump
}

cmd::restore() {
  [[ -z "$1" ]] && {
    echo "usage: db restore <file>"
    return 1
  }
  
  if ! db::dry_run "RESTORE database from backup" \
    "File: $1" \
    "This will overwrite current database"; then
    return 0
  fi
  
  if [[ $DB_QUIET -eq 0 ]]; then
    echo -n "restore from $1? [y/N] "
    read -r ans
    [[ "$ans" != [yY] ]] && {
      echo "cancelled"
      return 1
    }
  fi
  adapter::restore "$1"
}

cmd::truncate() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db truncate <table>"
    return 1
  }
  
  if ! db::dry_run "TRUNCATE table" \
    "Table: $table" \
    "All rows will be deleted (structure remains)"; then
    return 0
  fi
  
  if [[ $DB_QUIET -eq 0 ]]; then
    echo -n "truncate $table? [y/N] "
    read -r ans
    [[ "$ans" != [yY] ]] && {
      echo "cancelled"
      return 1
    }
  fi
  adapter::truncate "$table"
}

cmd::exec() {
  [[ -z "$1" || ! -f "$1" ]] && {
    echo "usage: db exec <file.sql>"
    return 1
  }
  
  local lines=$(wc -l < "$1" | tr -d ' ')
  if ! db::dry_run "EXECUTE SQL file" \
    "File: $1" \
    "Lines: $lines" \
    "Preview: $(head -3 "$1" | sed 's/^/  /')"; then
    return 0
  fi
  
  adapter::exec "$1"
}

cmd::export() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db export <csv|json> <query> [file]"
    return 1
  }
  adapter::export "$1" "$2" "$3"
}

cmd::copy() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "usage: db copy <src> <dest>"
    return 1
  }
  adapter::copy "$1" "$2"
}

cmd::import() {
  local format="$1"
  local file="$2"
  local table="$3"

  [[ -z "$format" || -z "$file" || -z "$table" ]] && {
    echo "usage: db import <csv|json> <file> <table>"
    return 1
  }
  [[ ! -f "$file" ]] && {
    db::err "file not found: $file"
    return 1
  }
  db::valid_id "$table" || return 1

  local lines=$(wc -l < "$file" | tr -d ' ')
  if ! db::dry_run "IMPORT data into table" \
    "Format: $format" \
    "File: $file" \
    "Table: $table" \
    "Rows: ~$lines"; then
    return 0
  fi

  adapter::import "$format" "$file" "$table"
}

cmd::er() {
  local table="$1"
  adapter::er "$table"
}
