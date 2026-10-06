require('dotenv').config();
const pool = require('./src/db');

pool.query(
  'SELECT id, username, password_hash, role, is_active FROM users WHERE username = $1',
  ['ali']
)
  .then((r) => {
    console.table(r.rows);
    return pool.end();
  })
  .catch((e) => {
    console.error(e);
    return pool.end();
  });