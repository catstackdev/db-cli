#!/usr/bin/env zsh
# db - Schema versioning commands
# @commands: schema

cmd::schema_version() {
  local action="$1"
  
  case "$action" in
    save)
      shift
      schema::save "$@"
      ;;
    restore)
      shift
      schema::restore "$@"
      ;;
    diff|compare)
      shift
      schema::diff "$@"
      ;;
    list|ls|versions)
      schema::list
      ;;
    export)
      shift
      schema::export "$@"
      ;;
    delete|rm)
      shift
      schema::delete "$@"
      ;;
    *)
      echo "usage: db schema-version <command> [args]"
      echo ""
      echo "commands:"
      echo "  save VERSION       save current schema"
      echo "  restore VERSION    restore schema from version"
      echo "  diff V1 [V2]       compare schemas (V2 defaults to current)"
      echo "  list               list saved versions"
      echo "  export [FILE]      export schema to file"
      echo "  delete VERSION     delete saved version"
      echo ""
      echo "examples:"
      echo "  db schema-version save v1.0.0"
      echo "  db schema-version diff v1.0.0 current"
      echo "  db schema-version list"
      return 1
      ;;
  esac
}
