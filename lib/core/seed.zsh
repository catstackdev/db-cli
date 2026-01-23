#!/usr/bin/env zsh
# db - Data generation and seeding

# Built-in data generators (no external dependencies)
typeset -ga FIRST_NAMES=(Alice Bob Carol Dave Eve Frank Grace Henry Ivy Jack Kate Leo Mary Nick Olivia Paul Quinn Rose Sam Tom Uma Vicky Will Xena Yuri Zoe)
typeset -ga LAST_NAMES=(Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Hernandez Lopez Gonzalez Wilson Anderson Thomas Taylor Moore Jackson Martin Lee)
typeset -ga DOMAINS=(example.com test.com demo.org sample.net)
typeset -ga CITIES=(Tokyo Delhi Shanghai Mumbai Beijing Cairo Mexico Osaka Seoul Jakarta)
typeset -ga COUNTRIES=(USA UK Canada Germany France Japan China India Brazil Australia)

# Generate random number in range
seed::random() {
  local min="${1:-1}"
  local max="${2:-100}"
  echo $(( RANDOM % (max - min + 1) + min ))
}

# Generate random name
seed::name() {
  local first=${FIRST_NAMES[$(( RANDOM % ${#FIRST_NAMES[@]} + 1 ))]}
  local last=${LAST_NAMES[$(( RANDOM % ${#LAST_NAMES[@]} + 1 ))]}
  echo "$first $last"
}

# Generate random email
seed::email() {
  local name=$(seed::name | tr '[:upper:] ' '[:lower:].')
  local domain=${DOMAINS[$(( RANDOM % ${#DOMAINS[@]} + 1 ))]}
  echo "${name}@${domain}"
}

# Generate random phone
seed::phone() {
  printf "%03d-%03d-%04d\n" $(seed::random 200 999) $(seed::random 200 999) $(seed::random 1000 9999)
}

# Generate random date
seed::date() {
  local days_ago="${1:-365}"
  local days=$(seed::random 1 $days_ago)
  date -v-${days}d +%Y-%m-%d 2>/dev/null || date -d "$days days ago" +%Y-%m-%d 2>/dev/null
}

# Generate random boolean
seed::bool() {
  [[ $(( RANDOM % 2 )) -eq 0 ]] && echo "true" || echo "false"
}

# Generate random status
seed::status() {
  local -a statuses=(active inactive pending blocked verified)
  echo ${statuses[$(( RANDOM % ${#statuses[@]} + 1 ))]}
}

# Generate random city
seed::city() {
  echo ${CITIES[$(( RANDOM % ${#CITIES[@]} + 1 ))]}
}

# Generate random country
seed::country() {
  echo ${COUNTRIES[$(( RANDOM % ${#COUNTRIES[@]} + 1 ))]}
}

# Generate lorem ipsum text
seed::text() {
  local words="${1:-10}"
  local lorem="Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua"
  local -a word_arr=(${(z)lorem})
  local result=""
  for ((i=1; i<=words; i++)); do
    result+="${word_arr[$(( RANDOM % ${#word_arr[@]} + 1 ))]} "
  done
  echo "${result% }"
}

seed::int() {
  local min="${1:-0}"
  local max="${2:-100}"
  echo $(( RANDOM % (max - min + 1) + min ))
}

# Parse and execute seed file
seed::run() {
  local file="$1"
  [[ ! -f "$file" ]] && { db::err "seed file not found: $file"; return 1; }
  
  db::log "running seed: ${file:t}"
  
  local table=""
  local count=0
  local -a columns=()
  local -a generators=()
  
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    
    # Parse table declaration
    if [[ "$line" =~ ^table:[[:space:]]*(.+) ]]; then
      table="${match[1]}"
      continue
    fi
    
    # Parse count
    if [[ "$line" =~ ^count:[[:space:]]*([0-9]+) ]]; then
      count="${match[1]}"
      continue
    fi
    
    # Parse column:generator pairs
    if [[ "$line" =~ ^([a-z_]+):[[:space:]]*(.+) ]]; then
      columns+=("${match[1]}")
      generators+=("${match[2]}")
    fi
  done < "$file"
  
  [[ -z "$table" ]] && { db::err "no table specified in seed file"; return 1; }
  [[ $count -eq 0 ]] && { db::err "no count specified in seed file"; return 1; }
  [[ ${#columns[@]} -eq 0 ]] && { db::err "no columns specified in seed file"; return 1; }
  
  db::log "seeding $count rows into $table"
  
  # Generate and insert data
  for ((i=1; i<=count; i++)); do
    local -a values=()
    
    for gen in $generators; do
      local val=$(seed::generate "$gen")
      values+=("'${val//\'/\'\'}'")  # Escape single quotes
    done
    
    local cols="${(j:,:)columns}"
    local vals="${(j:,:)values}"
    local sql="INSERT INTO $table ($cols) VALUES ($vals)"
    
    adapter::query "$sql" >/dev/null || { db::err "insert failed at row $i"; return 1; }
  done
  
  db::ok "seeded $count rows into $table"
}

# Generate value based on generator spec
seed::generate() {
  local spec="$1"
  
  case "$spec" in
    name) seed::name ;;
    email) seed::email ;;
    phone) seed::phone ;;
    date) seed::date ;;
    date:*) seed::date "${spec#date:}" ;;
    bool) seed::bool ;;
    status) seed::status ;;
    city) seed::city ;;
    country) seed::country ;;
    text) seed::text ;;
    text:*) seed::text "${spec#text:}" ;;
    int:*) 
      local range="${spec#int:}"
      local min="${range%%-*}"
      local max="${range##*-}"
      seed::random "$min" "$max"
      ;;
    *) echo "$spec" ;;  # Literal value
  esac
}

# Create seed template
seed::create() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && { db::err "usage: db seed create <table>"; return 1; }
  
  local file="seeds/${table}.seed"
  mkdir -p seeds
  
  cat > "$file" <<EOF
# Seed file for $table
# Format: column: generator

table: $table
count: 10

# Available generators:
# name, email, phone, date, date:N, bool, status
# city, country, text, text:N, int:MIN-MAX
# Or use literal values

# Example columns (edit as needed):
# name: name
# email: email
# created_at: date:30
# status: status
EOF
  
  db::ok "created seed template: $file"
  echo "${C_DIM}edit the file and run: db seed $file${C_RESET}"
}
