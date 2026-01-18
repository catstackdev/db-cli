# MongoDB adapter - Core
# Connection, CLI, basic operations

# Helper: check mongosh is available
_mongo::need() {
  db::need mongosh "brew install mongosh"
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

# Load sub-modules
source "${0:A:h}/query.zsh"
source "${0:A:h}/schema.zsh"
source "${0:A:h}/maintenance.zsh"
source "${0:A:h}/data.zsh"
