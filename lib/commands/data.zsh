# db - Data commands
# @commands: tables, schema, sample, count, size, top, stats, dbs, test

cmd::tables() {
  adapter::tables | db::pager
}

cmd::schema() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db schema <table>"
    return 1
  }
  adapter::schema "$table"
}

cmd::sample() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db sample <table> [limit]"
    return 1
  }
  adapter::sample "$table" "${2:-$DB_SAMPLE_LIMIT}" | db::table
}

cmd::count() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db count <table>"
    return 1
  }
  adapter::count "$table"
}

cmd::table_size() {
  local table="${1:-$(db::fzf_table)}"
  [[ -z "$table" ]] && {
    echo "usage: db size <table>"
    return 1
  }
  adapter::table_size "$table"
}

cmd::top() {
  adapter::top "${1:-10}" | db::pager
}

cmd::stats() {
  adapter::stats | db::pager
}

cmd::dbs() {
  adapter::dbs
}

cmd::test() {
  adapter::test
}

cmd::health() {
  adapter::health | db::pager
}

cmd::connections() {
  adapter::connections
}
