require('dotenv').config();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('./src/db');

async function main() {
  const result = await pool.query(
    'SELECT id, name, username, email, password_hash, role, is_active FROM users WHERE LOWER(username) = LOWER($1) LIMIT 1',
    ['alihaider']
  );
  console.log('DB ROWS:', result.rows.length);
  const u = result.rows[0];
  console.log('USER:', u.username, 'ROLE:', u.role, 'ACTIVE:', u.is_active);
  const match = await bcrypt.compare('5432', u.password_hash);
  console.log('PASSWORD MATCH:', match);
  const token = jwt.sign({ userId: u.id, role: u.role }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
  console.log('JWT OK:', !!token);
  await pool.end();
}

main().catch((e) => {
  console.error('AUTH TEST ERROR:', e);
  process.exit(1);
});
