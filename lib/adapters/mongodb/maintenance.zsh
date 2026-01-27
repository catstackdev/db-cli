# MongoDB adapter - Maintenance operations

adapter::health() {
  _mongo::need || return 1
  echo "${C_BLUE}=== Server Status ===${C_RESET}"
  mongosh "$DB_URL" --quiet --eval "
    const s = db.serverStatus();
    print('uptime:      ' + Math.floor(s.uptime / 3600) + ' hours');
    print('connections: ' + s.connections.current + '/' + s.connections.available);
    print('memory:      ' + (s.mem.resident) + ' MB resident');"
}

adapter::connections() {
  _mongo::need || return 1
  mongosh "$DB_URL" --eval "db.currentOp()"
}

adapter::locks() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "
    const ops = db.currentOp({ 'waitingForLock': true });
    if (ops.inprog.length === 0) {
      print('no operations waiting for locks');
    } else {
      ops.inprog.forEach(op => printjson(op));
    }"
}

adapter::kill() {
  _mongo::need || return 1
  mongosh "$DB_URL" --quiet --eval "db.killOp($1)" && db::ok "killed operation: $1"
}

adapter::slowlog() {
  _mongo::need || return 1
  local limit="${1:-10}"
  mongosh "$DB_URL" --quiet --eval "
    const profile = db.system.profile.find().sort({ ts: -1 }).limit($limit).toArray();
    if (profile.length === 0) {
      print('no slow queries found');
      print('enable profiling: db.setProfilingLevel(1, { slowms: 100 })');
    } else {
      profile.forEach(p => {
        print('time: ' + p.millis + 'ms');
        print('op: ' + p.op);
        print('ns: ' + p.ns);
        if (p.command) print('command: ' + JSON.stringify(p.command).substring(0, 100));
        print('---');
      });
    }"
}

adapter::vacuum() {
  _mongo::need || return 1
  if [[ -n "$1" ]]; then
    db::valid_id "$1" || return 1
    mongosh "$DB_URL" --quiet --eval "db.runCommand({ compact: '$1' })" && db::ok "compacted: $1"
  else
    mongosh "$DB_URL" --quiet --eval "
      const cols = db.getCollectionNames();
      cols.forEach(c => {
        print('compacting ' + c + '...');
        db.runCommand({ compact: c });
      });" && db::ok "compacted all collections"
  fi
}

adapter::analyze() {
  if [[ -n "$1" ]]; then
    local collection="$1"
    _mongo::valid_collection "$collection" || return 1
    _mongo::eval_safe "$collection" "db.${collection}.validate()" && db::ok "validated: $collection"
  else
    _mongo::need || return 1
    mongosh "$DB_URL" --quiet --eval "
      const cols = db.getCollectionNames();
      cols.forEach(c => {
        print('validating ' + c + '...');
        const result = db[c].validate();
        print('valid: ' + result.valid);
      });" && db::ok "validated all collections"
  fi
}
