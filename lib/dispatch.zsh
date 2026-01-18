# db - Command dispatcher with lazy loading
# Routes commands to appropriate modules

# Command to module mapping for lazy loading
typeset -gA DB_CMD_MODULE=(
  # meta.zsh
  [help]=meta [h]=meta [version]=meta [v]=meta
  [url]=meta [u]=meta [info]=meta [status]=meta

  # query.zsh
  [query]=query [q]=query [explain]=query [watch]=query [w]=query
  [edit]=query [history]=query [hist]=query [last]=query [l]=query
  [migrate]=query [m]=query

  # data.zsh
  [tables]=data [t]=data [schema]=data [sample]=data [s]=data
  [count]=data [c]=data [size]=data [top]=data [stats]=data
  [dbs]=data [list]=data [test]=data [ping]=data [health]=data
  [conn]=data [connections]=data

  # helpers.zsh
  [desc]=helpers [d]=helpers [select]=helpers [sel]=helpers
  [where]=helpers [agg]=helpers [distinct]=helpers [uniq]=helpers
  [null]=helpers [nulls]=helpers [dup]=helpers [dups]=helpers
  [recent]=helpers

  # backup.zsh
  [dump]=backup [restore]=backup [truncate]=backup
  [exec]=backup [e]=backup [export]=backup [x]=backup
  [copy]=backup [cp]=backup [import]=backup [er]=backup

  # schema.zsh
  [indexes]=schema [fk]=schema [search]=schema [diff]=schema
  [users]=schema [grants]=schema [rename]=schema [drop]=schema
  [comment]=schema

  # maintenance.zsh
  [vacuum]=maintenance [analyze]=maintenance [locks]=maintenance
  [kill]=maintenance [slowlog]=maintenance

  # monitoring.zsh
  [tail]=monitoring [changes]=monitoring

  # bookmarks.zsh
  [save]=bookmarks [run]=bookmarks [bookmarks]=bookmarks [bm]=bookmarks
  [rm]=bookmarks

  # config.zsh
  [init]=config [config]=config [profiles]=config [connect]=config
)

# Lazy load command module
db::ensure_module() {
  local cmd="$1"
  local module="${DB_CMD_MODULE[$cmd]}"

  [[ -z "$module" ]] && return 1

  # Check if already loaded
  [[ -n "${DB_LOADED_MODULES[$module]}" ]] && return 0

  # Load the module
  local module_file="$DB_COMMANDS_DIR/${module}.zsh"
  [[ ! -f "$module_file" ]] && { db::err "module not found: $module"; return 1; }

  source "$module_file"
  DB_LOADED_MODULES[$module]=1
  db::dbg "lazy loaded: $module"
  return 0
}

# Main dispatch
db::run() {
  local cmd="$1"

  # Handle @bookmark shorthand
  if [[ "$cmd" == @* ]]; then
    db::ensure_module "run" || return 1
    cmd::run_bookmark "${cmd#@}"
    return
  fi

  # Handle empty command (open interactive cli)
  if [[ -z "$cmd" ]]; then
    adapter::cli
    return
  fi

  # Try to load module for command
  if db::ensure_module "$cmd"; then
    # Dispatch to command function
    case "$cmd" in
      # Native client needs special handling
      psql|p)
        shift
        adapter::native "$@"
        return
        ;;
    esac

    # Map command aliases to functions
    case "$cmd" in
      # Meta
      help|h|-h|--help) cmd::help ;;
      version|v) cmd::version ;;
      url|u) cmd::url ;;
      info) cmd::info ;;
      status) cmd::status ;;

      # Query
      q|query) cmd::query "$2" ;;
      explain) cmd::explain "$2" ;;
      watch|w) cmd::watch "$2" "$3" ;;
      edit) cmd::edit ;;
      hist|history) cmd::history "$2" ;;
      last|l) cmd::last ;;
      migrate|m) cmd::migrate ;;

      # Data
      t|tables) cmd::tables ;;
      schema) cmd::schema "$2" ;;
      sample|s) cmd::sample "$2" "$3" ;;
      count|c) cmd::count "$2" ;;
      size) cmd::table_size "$2" ;;
      top) cmd::top "$2" ;;
      stats) cmd::stats ;;
      dbs|list) cmd::dbs ;;
      test|ping) cmd::test ;;
      health) cmd::health ;;
      conn|connections) cmd::connections ;;

      # Helpers
      desc|d) cmd::desc "$2" ;;
      select|sel) cmd::select "$2" "$3" "$4" ;;
      where) cmd::where "$2" "$3" "$4" "$5" "$6" ;;
      agg) cmd::agg "$2" "$3" ;;
      distinct|uniq) cmd::distinct "$2" "$3" ;;
      null|nulls) cmd::nulls "$2" ;;
      dup|dups) cmd::dup "$2" "$3" ;;
      recent) cmd::recent ;;

      # Backup
      dump) cmd::dump ;;
      restore) cmd::restore "$2" ;;
      truncate) cmd::truncate "$2" ;;
      exec|e) cmd::exec "$2" ;;
      x|export) cmd::export "$2" "$3" "$4" ;;
      cp|copy) cmd::copy "$2" "$3" ;;
      import) cmd::import "$2" "$3" "$4" ;;
      er) cmd::er "$2" ;;

      # Schema
      indexes) cmd::indexes "$2" ;;
      fk) cmd::fk "$2" ;;
      search) cmd::search "$2" ;;
      diff) cmd::diff "$2" "$3" ;;
      users) cmd::users ;;
      grants) cmd::grants "$2" ;;
      rename) cmd::rename "$2" "$3" ;;
      drop) cmd::drop "$2" ;;
      comment) cmd::comment "$2" "$3" ;;

      # Maintenance
      vacuum) cmd::vacuum "$2" ;;
      analyze) cmd::analyze "$2" ;;
      locks) cmd::locks ;;
      kill) cmd::kill "$2" ;;
      slowlog) cmd::slowlog "$2" ;;

      # Monitoring
      tail) cmd::tail "$2" "$3" "$4" ;;
      changes) cmd::changes "$2" "$3" ;;

      # Bookmarks
      save) cmd::save "$2" "$3" ;;
      run) cmd::run_bookmark "$2" ;;
      bookmarks|bm) cmd::bookmarks ;;
      rm) cmd::rm_bookmark "$2" ;;

      # Config
      init) cmd::init "$2" "$3" ;;
      config) cmd::config "$2" "$3" "$4" ;;
      profiles) cmd::profiles ;;
      connect) cmd::connect ;;

      *)
        db::err "unknown command: $cmd"
        db::ensure_module "help" && cmd::help
        return 1
        ;;
    esac
  else
    # Check if it's a plugin command
    if typeset -f "plugin::$cmd" &>/dev/null; then
      "plugin::$cmd" "${@:2}"
      return
    fi

    db::err "unknown: $cmd"
    db::ensure_module "help" && cmd::help
    return 1
  fi
}
