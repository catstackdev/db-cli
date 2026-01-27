# MongoDB adapter - Core
# Connection, CLI, basic operations

# Helper: check mongosh is available
_mongo::need() {
  db::need mongosh "brew install mongosh"
}

# Helper: validate MongoDB collection name
_mongo::valid_collection() {
  local name="$1"
  # MongoDB collection names must not contain: $ or null character, cannot start with system.
  # Use same validation as SQL identifiers for safety
  [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || {
    db::err "invalid collection name: $name"
    db::err "collection names must start with letter/underscore, contain only alphanumeric/underscore"
    return 1
  }
  return 0
}

# Helper: execute mongosh with JavaScript file instead of --eval (safer)
# Usage: _mongo::eval_safe "collection_name" "javascript_code"
_mongo::eval_safe() {
  _mongo::need || return 1
  local collection="$1"
  local js_code="$2"
  
  # Validate collection name before injection into JavaScript
  _mongo::valid_collection "$collection" || return 1
  
  # Create temporary JavaScript file (more secure than --eval with string interpolation)
  local tmp_js="${DB_TMP_DIR:-${TMPDIR:-/tmp}}/mongo-query-$$.js"
  echo "$js_code" > "$tmp_js"
  mongosh "$DB_URL" --quiet "$tmp_js"
  local rc=$?
  rm -f "$tmp_js"
  return $rc
}

adapter::cli() {
  _mongo::need || return 1
  mongosh "$DB_URL"
}

adapter::native() {
  _mongo::need || return 1
  mongosh "$DB_URL" "$@"
}

adapter::test() {
  _mongo::need || return 1
  mongosh "$DB_URL" --eval "db.adminCommand('ping')" &>/dev/null && db::ok "connected" || { db::err "connection failed"; return 1; }
}

adapter::dbs() {
  _mongo::need || return 1
  mongosh "$DB_URL" --eval "db.adminCommand('listDatabases')"
}

adapter::stats() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "
    const stats = db.stats();
    print('database:    ' + stats.db);
    print('collections: ' + stats.collections);
    print('documents:   ' + stats.objects);
    print('data_size:   ' + (stats.dataSize / 1024 / 1024).toFixed(2) + ' MB');
    print('index_size:  ' + (stats.indexSize / 1024 / 1024).toFixed(2) + ' MB');
    print('storage:     ' + (stats.storageSize / 1024 / 1024).toFixed(2) + ' MB');
    print('avg_doc:     ' + stats.avgObjSize.toFixed(0) + ' bytes');"
  mongosh "$DB_URL" --quiet --eval "print('version:     ' + db.version())"
}

adapter::top() {
  _mongo::need || return 1
  local limit="${1:-10}"
  mongosh "$DB_URL" --quiet --eval "
    const cols = db.getCollectionNames();
    const stats = cols.map(c => {
      const s = db[c].stats();
      return { name: c, size: s.size, docs: s.count, indexSize: s.totalIndexSize };
    }).sort((a,b) => b.size - a.size).slice(0, $limit);
    print('collection | docs | size_mb | index_mb');
    print('-----------|------|---------|----------');
    stats.forEach(s => {
      print(s.name + ' | ' + s.docs + ' | ' + (s.size/1024/1024).toFixed(2) + ' | ' + (s.indexSize/1024/1024).toFixed(2));
    });"
}

adapter::dump() {
  db::need mongodump "brew install mongodb-database-tools" || return 1
  [[ -d "$DB_BACKUP_DIR" ]] || mkdir -p "$DB_BACKUP_DIR"
  local out="$DB_BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S)"
  mongodump --uri="$DB_URL" --out="$out" && db::ok "saved: $out/"
}

adapter::restore() {
  db::need mongorestore "brew install mongodb-database-tools" || return 1
  [[ -d "$1" ]] || { db::err "directory not found: $1"; return 1; }
  mongorestore --uri="$DB_URL" "$1" && db::ok "restored: $1"
}

adapter::exec() {
  _mongo::need || return 1
  mongosh "$DB_URL" < "$1"
}

# Transaction support (requires replica set)
adapter::tx_begin() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "session = db.getMongo().startSession(); session.startTransaction();" 2>/dev/null
}

adapter::tx_commit() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "session.commitTransaction(); session.endSession();" 2>/dev/null
}

adapter::tx_rollback() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "session.abortTransaction(); session.endSession();" 2>/dev/null
}

# Load sub-modules
source "${0:A:h}/query.zsh"
source "${0:A:h}/schema.zsh"
source "${0:A:h}/maintenance.zsh"
source "${0:A:h}/data.zsh"
