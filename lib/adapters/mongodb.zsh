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
    print('size: ' + (stats.dataSize / 1024 / 1024).toFixed(2) + ' MB');
    print('collections: ' + stats.collections);"
}

adapter::connections() {
  db::need mongosh "brew install mongosh" || return 1
  mongosh "$DB_URL" --eval "db.currentOp()"
}

adapter::dump() {
  db::need mongodump "brew install mongodb-database-tools" || return 1
  local out="backup-$(date +%Y%m%d-%H%M%S)"
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
  mongosh "$DB_URL" --quiet --eval "db.$1.aggregate([{\$out: '$2'}])" && db::ok "copied: $1 -> $2"
}
