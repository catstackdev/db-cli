# db - Output formatting
# Pager, table formatting, truncation

# Pipe through pager if output is long
db::pager() {
  if [[ -t 1 ]] && [[ -n "$DB_PAGER" ]]; then
    eval "$DB_PAGER"
  else
    cat
  fi
}

# Truncate string to max length with ellipsis
db::truncate() {
  local str="$1" max="${2:-$DB_COL_WIDTH}"
  [[ $max -eq 0 ]] && { echo "$str"; return; }
  if [[ ${#str} -gt $max ]]; then
    echo "${str:0:$((max-2))}.."
  else
    echo "$str"
  fi
}

# Format table output with column truncation
# Usage: db::table [col_width] [max_cols]
db::table() {
  local col_width="${1:-$DB_COL_WIDTH}"
  local max_cols="${2:-$DB_MAX_COLS}"

  # If no truncation needed, just pass through
  [[ $col_width -eq 0 && $max_cols -eq 0 ]] && { cat; return; }

  local line_num=0
  local -a headers=()
  local visible_cols=0

  while IFS= read -r line; do
    ((line_num++))

    # Detect separator (pipe or tab)
    local sep="|"
    [[ "$line" != *"|"* ]] && sep=$'\t'

    # Split line into fields
    local -a fields=()
    if [[ "$sep" == "|" ]]; then
      IFS='|' read -rA fields <<< "$line"
    else
      IFS=$'\t' read -rA fields <<< "$line"
    fi

    # First line = headers, determine visible columns
    if [[ $line_num -eq 1 ]]; then
      headers=("${fields[@]}")
      visible_cols=${#fields[@]}
      [[ $max_cols -gt 0 && $max_cols -lt $visible_cols ]] && visible_cols=$max_cols
    fi

    # Skip separator lines (-----)
    [[ "$line" =~ ^[-+\|[:space:]]+$ ]] && { echo "$line"; continue; }

    # Build output line
    local out=""
    local i=0
    for field in "${fields[@]}"; do
      ((i++))
      [[ $max_cols -gt 0 && $i -gt $max_cols ]] && break

      # Trim whitespace
      field="${field## }"
      field="${field%% }"

      # Truncate if needed
      if [[ $col_width -gt 0 && ${#field} -gt $col_width ]]; then
        field="${field:0:$((col_width-2))}.."
      fi

      [[ -n "$out" ]] && out+=" $sep "
      out+="$field"
    done

    # Show indicator if columns were hidden
    if [[ $max_cols -gt 0 && ${#fields[@]} -gt $max_cols && $line_num -eq 1 ]]; then
      out+=" ${C_DIM}(+$((${#fields[@]} - max_cols)) cols)${C_RESET}"
    fi

    echo "$out"
  done
}

# Compact table format for sample output
db::compact() {
  local term_width=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}
  local col_width="${1:-$DB_COL_WIDTH}"
  local max_cols="${2:-$DB_MAX_COLS}"

  [[ $col_width -eq 0 ]] && col_width=30

  db::table "$col_width" "$max_cols"
}

# JSON output formatter
db::json() {
  if command -v jq &>/dev/null; then
    jq -C '.' 2>/dev/null || cat
  else
    cat
  fi
}

# CSV output (pass through)
db::csv() {
  cat
}

# Markdown table output
db::markdown() {
  awk 'BEGIN {FS="|"; OFS="|"}
    NR==1 {print; next}
    NR==2 {gsub(/-/, "-"); print; next}
    {print}'
}

# YAML-like output
db::yaml() {
  awk -F'|' 'NR>2 && NF>1 {
    gsub(/^[ \t]+|[ \t]+$/, "", $1)
    gsub(/^[ \t]+|[ \t]+$/, "", $2)
    if ($1 != "") print "  " $1 ": " $2
  }'
}

# Format output based on DB_FORMAT or --format flag
db::format() {
  local fmt="${1:-$DB_FORMAT}"
  case "$fmt" in
    json) db::json ;;
    csv)  db::csv ;;
    md|markdown) db::markdown ;;
    yaml|yml) db::yaml ;;
    *)    db::table ;;
  esac
}
