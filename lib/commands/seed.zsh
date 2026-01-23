#!/usr/bin/env zsh
# db - Seed and data generation commands
# @commands: seed, generate

cmd::seed() {
  local action="${1:-run}"
  
  case "$action" in
    run|r)
      shift
      local file="${1:-seeds/*.seed}"
      if [[ "$file" == seeds/*.seed ]]; then
        # Run all seed files
        local -a files=(seeds/*.seed(N))
        [[ ${#files[@]} -eq 0 ]] && { db::err "no seed files found in seeds/"; return 1; }
        for f in $files; do
          seed::run "$f" || return 1
        done
      else
        seed::run "$file"
      fi
      ;;
    create|new)
      shift
      seed::create "$@"
      ;;
    list|ls)
      if [[ -d seeds ]]; then
        echo "${C_BLUE}=== Seed Files ===${C_RESET}"
        ls -1 seeds/*.seed 2>/dev/null || echo "No seed files found"
      else
        echo "No seeds/ directory"
      fi
      ;;
    *)
      echo "usage: db seed <command> [args]"
      echo ""
      echo "commands:"
      echo "  run [FILE]     run seed file(s) (default: all in seeds/)"
      echo "  create TABLE   create seed template for table"
      echo "  list           list all seed files"
      echo ""
      echo "examples:"
      echo "  db seed create users"
      echo "  db seed run seeds/users.seed"
      echo "  db seed              # run all seed files"
      return 1
      ;;
  esac
}

cmd::generate() {
  local what="${1:-help}"
  local count="${2:-10}"
  
  case "$what" in
    names|name)
      for ((i=1; i<=count; i++)); do seed::name; done
      ;;
    emails|email)
      for ((i=1; i<=count; i++)); do seed::email; done
      ;;
    phones|phone)
      for ((i=1; i<=count; i++)); do seed::phone; done
      ;;
    dates|date)
      for ((i=1; i<=count; i++)); do seed::date; done
      ;;
    bool|bools)
      for ((i=1; i<=count; i++)); do seed::bool; done
      ;;
    status|statuses)
      for ((i=1; i<=count; i++)); do seed::status; done
      ;;
    cities|city)
      for ((i=1; i<=count; i++)); do seed::city; done
      ;;
    countries|country)
      for ((i=1; i<=count; i++)); do seed::country; done
      ;;
    text|texts)
      for ((i=1; i<=count; i++)); do seed::text; done
      ;;
    int|ints)
      for ((i=1; i<=count; i++)); do seed::int; done
      ;;
    *)
      echo "usage: db generate <type> [count]"
      echo ""
      echo "types:"
      echo "  name       random first or last names"
      echo "  email      random email addresses"
      echo "  phone      random phone numbers"
      echo "  date       random dates (YYYY-MM-DD)"
      echo "  bool       random boolean (true/false)"
      echo "  status     random status values"
      echo "  city       random city names"
      echo "  country    random country names"
      echo "  text       random text (10-50 chars)"
      echo "  int        random integers (0-100)"
      echo ""
      echo "examples:"
      echo "  db generate name 5"
      echo "  db generate email 10"
      echo "  db generate city 3"
      return 1
      ;;
  esac
}
