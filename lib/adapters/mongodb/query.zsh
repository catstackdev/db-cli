# MongoDB adapter - Query operations

adapter::query() {
  _mongo::need || return 1
  mongosh "$DB_URL" --eval "$1"
}

adapter::tables() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "db.getCollectionNames().forEach(c => print(c))"
}

adapter::tables_plain() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "db.getCollectionNames().forEach(c => print(c))"
}

adapter::schema() {
  _mongo::need || return 1
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

adapter::sample() {
  _mongo::need || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.find().limit(${2:-10}).forEach(printjson)"
}

adapter::count() {
  _mongo::need || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.countDocuments()"
}

adapter::table_size() {
  _mongo::need || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "
    const stats = db.$1.stats();
    print('collection: ' + stats.ns);
    print('documents:  ' + stats.count);
    print('data_size:  ' + (stats.size / 1024 / 1024).toFixed(2) + ' MB');
    print('storage:    ' + (stats.storageSize / 1024 / 1024).toFixed(2) + ' MB');
    print('index_size: ' + (stats.totalIndexSize / 1024 / 1024).toFixed(2) + ' MB');
    print('indexes:    ' + stats.nindexes);
    print('avg_doc:    ' + stats.avgObjSize.toFixed(0) + ' bytes');"
}

adapter::explain() {
  db::err "use: db.collection.find().explain() in mongosh"
  return 1
}

adapter::export() {
  db::need mongoexport "brew install mongodb-database-tools" || return 1
  local collection="$1" out="${2:-export-$(date +%Y%m%d-%H%M%S).json}"
  mongoexport --uri="$DB_URL" --collection="$collection" --out="$out" && db::ok "exported: $out"
}

adapter::copy() {
  _mongo::need || return 1
  db::valid_id "$1" || return 1
  db::valid_id "$2" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.aggregate([{\$out: '$2'}])" && db::ok "copied: $1 -> $2"
}

adapter::truncate() {
  _mongo::need || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "db.$1.deleteMany({})" && db::ok "truncated: $1"
}
