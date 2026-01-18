# MongoDB adapter - Data operations

adapter::agg() {
  _mongo::need || return 1
  local collection="$1" field="$2"
  db::valid_id "$collection" || return 1

  if [[ -n "$field" ]]; then
    mongosh "$DB_URL" --quiet --eval "
      const stats = db.$collection.aggregate([
        { \$group: {
          _id: null,
          count: { \$sum: 1 },
          distinctCount: { \$addToSet: '\$$field' },
          min: { \$min: '\$$field' },
          max: { \$max: '\$$field' }
        }}
      ]).toArray()[0];
      if (stats) {
        print('count: ' + stats.count);
        print('distinct: ' + stats.distinctCount.length);
        print('min: ' + stats.min);
        print('max: ' + stats.max);
      }"
  else
    mongosh "$DB_URL" --quiet --eval "print('total_docs: ' + db.$collection.countDocuments())"
  fi
}

adapter::distinct() {
  _mongo::need || return 1
  local collection="$1" field="$2"
  db::valid_id "$collection" || return 1
  mongosh "$DB_URL" --quiet --eval "
    const values = db.$collection.aggregate([
      { \$group: { _id: '\$$field', count: { \$sum: 1 } } },
      { \$sort: { count: -1 } },
      { \$limit: 50 }
    ]).toArray();
    values.forEach(v => print(v._id + ': ' + v.count));"
}

adapter::nulls() {
  _mongo::need || return 1
  local collection="$1"
  db::valid_id "$collection" || return 1

  echo "${C_BLUE}=== NULL/missing fields in $collection ===${C_RESET}"
  mongosh "$DB_URL" --quiet --eval "
    const doc = db.$collection.findOne();
    if (doc) {
      const fields = Object.keys(doc);
      fields.forEach(f => {
        const nullCount = db.$collection.countDocuments({ [f]: { \$in: [null, ''] } });
        const missingCount = db.$collection.countDocuments({ [f]: { \$exists: false } });
        if (nullCount > 0 || missingCount > 0) {
          print(f + ': ' + nullCount + ' null, ' + missingCount + ' missing');
        }
      });
    }"
}

adapter::dup() {
  _mongo::need || return 1
  local collection="$1" field="$2"
  db::valid_id "$collection" || return 1
  mongosh "$DB_URL" --quiet --eval "
    const dups = db.$collection.aggregate([
      { \$group: { _id: '\$$field', count: { \$sum: 1 } } },
      { \$match: { count: { \$gt: 1 } } },
      { \$sort: { count: -1 } },
      { \$limit: 20 }
    ]).toArray();
    if (dups.length === 0) {
      print('no duplicates found');
    } else {
      dups.forEach(d => print(d._id + ': ' + d.count + ' duplicates'));
    }"
}

adapter::import() {
  db::need mongoimport "brew install mongodb-database-tools" || return 1
  local format="$1" file="$2" collection="$3"

  case "$format" in
    csv)
      mongoimport --uri="$DB_URL" --collection="$collection" --type=csv --headerline --file="$file" && \
        db::ok "imported $file to $collection"
      ;;
    json)
      mongoimport --uri="$DB_URL" --collection="$collection" --file="$file" && \
        db::ok "imported $file to $collection"
      ;;
    *)
      db::err "format: csv or json"
      return 1
      ;;
  esac
}

adapter::er() {
  _mongo::need || return 1

  echo "erDiagram"
  mongosh "$DB_URL" --quiet --eval "
    const cols = db.getCollectionNames();
    cols.forEach(c => {
      print('    ' + c + ' {');
      const doc = db[c].findOne();
      if (doc) {
        Object.entries(doc).forEach(([k, v]) => {
          print('        ' + k + ' ' + typeof v);
        });
      }
      print('    }');
    });"
  echo "    %% MongoDB: no foreign key constraints"
}

adapter::tail() {
  _mongo::need || return 1
  local collection="$1" limit="${2:-10}"
  db::valid_id "$collection" || return 1

  mongosh "$DB_URL" --quiet --eval "
    // Try to find a timestamp field
    const doc = db.$collection.findOne();
    let sortField = '_id';
    if (doc) {
      const tsFields = ['createdAt', 'created_at', 'timestamp', 'updatedAt', 'updated_at'];
      for (const f of tsFields) {
        if (doc[f]) { sortField = f; break; }
      }
    }
    db.$collection.find().sort({ [sortField]: -1 }).limit($limit).forEach(printjson);"
}

adapter::changes() {
  _mongo::need || return 1
  local collection="$1" hours="${2:-24}"
  db::valid_id "$collection" || return 1

  mongosh "$DB_URL" --quiet --eval "
    const doc = db.$collection.findOne();
    let tsField = null;
    if (doc) {
      const tsFields = ['createdAt', 'created_at', 'timestamp', 'updatedAt', 'updated_at'];
      for (const f of tsFields) {
        if (doc[f] instanceof Date) { tsField = f; break; }
      }
    }
    if (!tsField) {
      print('no timestamp field found');
    } else {
      const cutoff = new Date(Date.now() - $hours * 60 * 60 * 1000);
      print('=== Changes in last ${hours}h (by ' + tsField + ') ===');
      db.$collection.find({ [tsField]: { \$gt: cutoff } })
        .sort({ [tsField]: -1 })
        .limit(50)
        .forEach(printjson);
    }"
}
