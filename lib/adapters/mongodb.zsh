# MongoDB adapter

adapter::cli() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL"
}

adapter::native() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" "$@"
}

adapter::query() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" --eval "$1"
}

adapter::tables() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" --quiet --eval "db.getCollectionNames().forEach(c => print(c))"
}

adapter::schema() {
  db::need mongosh "brew install mongosh" || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "
    const doc = db.$1.findOne();
    if (doc) {
      const schema = {};
      for (const [k, v] of Object.entries(doc)) {
        schema[k] = typeof v;
      }
      printjson(schema);
    } else {
      print('collection empty');
    }"
}

adapter::count() {
  db::need mongosh "brew install mongosh" || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.countDocuments()"
}

adapter::test() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" --eval "db.adminCommand('ping')" &>/dev/null && db::ok "connected" || { db::err "connection failed"; return 1; }
}

adapter::stats() {
  db::need mongosh "brew install mongosh" || return 1
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
  db::need mongosh "brew install mongosh" || return 1
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

adapter::health() {
  db::need mongosh "brew install mongosh" || return 1
  echo "${C_BLUE}=== Server Status ===${C_RESET}"
  mongosh "$DB_URL" --quiet --eval "
    const s = db.serverStatus();
    print('uptime:      ' + Math.floor(s.uptime / 3600) + ' hours');
    print('connections: ' + s.connections.current + '/' + s.connections.available);
    print('memory:      ' + (s.mem.resident) + ' MB resident');"
}

adapter::connections() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" --eval "db.currentOp()"
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

adapter::explain() {
  db::err "use: db.collection.find().explain() in mongosh"
  return 1
}

adapter::dbs() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" --eval "db.adminCommand('listDatabases')"
}

adapter::export() {
  db::need mongoexport "brew install mongodb-database-tools" || return 1
  local collection="$1" out="${2:-export-$(date +%Y%m%d-%H%M%S).json}"
  mongoexport --uri="$DB_URL" --collection="$collection" --out="$out" && db::ok "exported: $out"
}

adapter::copy() {
  db::need mongosh "brew install mongosh" || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.aggregate([{\$out: '$2'}])" && db::ok "copied: $1 -> $2"
}

# New commands

adapter::tables_plain() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" --quiet --eval "db.getCollectionNames().forEach(c => print(c))"
}

adapter::sample() {
  db::need mongosh "brew install mongosh" || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.find().limit(${2:-10}).forEach(printjson)"
}

adapter::truncate() {
  db::need mongosh "brew install mongosh" || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.deleteMany({})" && db::ok "truncated: $1"
}

adapter::exec() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" < "$1"
}
