# MongoDB adapter - Schema operations

adapter::indexes() {
  local collection="$1"
  _mongo::valid_collection "$collection" || return 1
  _mongo::eval_safe "$collection" "
    const indexes = db.${collection}.getIndexes();
    indexes.forEach(idx => {
      print('name: ' + idx.name);
      print('keys: ' + JSON.stringify(idx.key));
      if (idx.unique) print('unique: true');
      print('---');
    });"
}

adapter::fk() {
  db::log "mongodb: no foreign key constraints (document database)"
  db::log "use \$lookup aggregation for joins"
  return 0
}

adapter::users() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "
    const users = db.getUsers();
    if (users.users.length === 0) {
      print('no users in this database');
    } else {
      users.users.forEach(u => {
        print('user: ' + u.user);
        print('roles: ' + u.roles.map(r => r.role + '@' + r.db).join(', '));
        print('---');
      });
    }"
}

adapter::grants() {
  _mongo::need || return 1
  db::valid_id "$1" || return 1
  mongosh "$DB_URL" --quiet --eval "
    const users = db.getUsers();
    users.users.forEach(u => {
      const hasAccess = u.roles.some(r => r.db === db.getName() || r.db === 'admin');
      if (hasAccess) {
        print('user: ' + u.user);
        print('roles: ' + u.roles.map(r => r.role).join(', '));
        print('---');
      }
    });
    print('note: mongodb uses role-based access, not table-level grants');"
}

adapter::rename() {
  local old_name="$1"
  local new_name="$2"
  _mongo::valid_collection "$old_name" || return 1
  _mongo::valid_collection "$new_name" || return 1
  _mongo::eval_safe "$old_name" "db.${old_name}.renameCollection('${new_name}')" && db::ok "renamed: $old_name -> $new_name"
}

adapter::drop() {
  local collection="$1"
  _mongo::valid_collection "$collection" || return 1
  _mongo::eval_safe "$collection" "db.${collection}.drop()" && db::ok "dropped: $collection"
}

adapter::comment() {
  db::log "mongodb: collection comments not supported natively"
  db::log "consider using a metadata collection"
  return 0
}

adapter::get_comment() {
  db::log "mongodb: collection comments not supported natively"
  return 0
}

adapter::search() {
  _mongo::need || return 1
  local pattern="$1"
  echo "${C_BLUE}=== Collections ===${C_RESET}"
  mongosh "$DB_URL" --quiet --eval "
    const cols = db.getCollectionNames().filter(c => c.includes('$pattern'));
    cols.forEach(c => print(c));"
  echo "${C_BLUE}=== Fields (sampling first doc) ===${C_RESET}"
  mongosh "$DB_URL" --quiet --eval "
    const cols = db.getCollectionNames();
    cols.forEach(c => {
      const doc = db[c].findOne();
      if (doc) {
        Object.keys(doc).forEach(k => {
          if (k.includes('$pattern')) {
            print(c + ' | ' + k + ' | ' + typeof doc[k]);
          }
        });
      }
    });"
}

adapter::diff() {
  _mongo::need || return 1
  local url1="$1" url2="$2" name1="$3" name2="$4"

  echo "${C_BLUE}=== Collections only in $name1 ===${C_RESET}"
  comm -23 \
    <(mongosh "$url1" --quiet --eval "db.getCollectionNames().sort().forEach(c => print(c))") \
    <(mongosh "$url2" --quiet --eval "db.getCollectionNames().sort().forEach(c => print(c))")

  echo "${C_BLUE}=== Collections only in $name2 ===${C_RESET}"
  comm -13 \
    <(mongosh "$url1" --quiet --eval "db.getCollectionNames().sort().forEach(c => print(c))") \
    <(mongosh "$url2" --quiet --eval "db.getCollectionNames().sort().forEach(c => print(c))")

  echo "${C_BLUE}=== Index differences ===${C_RESET}"
  local common=$(comm -12 \
    <(mongosh "$url1" --quiet --eval "db.getCollectionNames().sort().forEach(c => print(c))") \
    <(mongosh "$url2" --quiet --eval "db.getCollectionNames().sort().forEach(c => print(c))"))

  for col in $common; do
    local idx1=$(mongosh "$url1" --quiet --eval "JSON.stringify(db.$col.getIndexes().map(i => i.name).sort())")
    local idx2=$(mongosh "$url2" --quiet --eval "JSON.stringify(db.$col.getIndexes().map(i => i.name).sort())")
    if [[ "$idx1" != "$idx2" ]]; then
      echo "${C_YELLOW}$col${C_RESET}:"
      echo "  $name1: $idx1"
      echo "  $name2: $idx2"
    fi
  done
}
