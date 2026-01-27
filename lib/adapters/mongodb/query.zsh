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
  local collection="$1"
  _mongo::valid_collection "$collection" || return 1
  _mongo::eval_safe "$collection" "
    const doc = db.${collection}.findOne();
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
  local collection="$1"
  local limit="${2:-10}"
  _mongo::valid_collection "$collection" || return 1
  _mongo::eval_safe "$collection" "db.${collection}.find().limit($limit).forEach(printjson)"
}

adapter::count() {
  local collection="$1"
  _mongo::valid_collection "$collection" || return 1
  _mongo::eval_safe "$collection" "db.${collection}.countDocuments()"
}

adapter::table_size() {
  local collection="$1"
  _mongo::valid_collection "$collection" || return 1
  _mongo::eval_safe "$collection" "
    const stats = db.${collection}.stats();
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
  local source="$1"
  local dest="$2"
  _mongo::valid_collection "$source" || return 1
  _mongo::valid_collection "$dest" || return 1
  _mongo::eval_safe "$source" "db.${source}.aggregate([{\$out: '${dest}'}])" && db::ok "copied: $source -> $dest"
}

adapter::truncate() {
  local collection="$1"
  _mongo::valid_collection "$collection" || return 1
  _mongo::eval_safe "$collection" "db.${collection}.deleteMany({})" && db::ok "truncated: $collection"
}
