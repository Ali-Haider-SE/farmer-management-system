const readline = require('readline');
const bcrypt = require('bcryptjs');
const pool = require('./db');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const ask = (question) =>
  new Promise((resolve) => rl.question(question, resolve));

async function main() {
  try {
    const name = await ask('Name: ');
    const username = await ask('Username: ');
    const email = await ask('Email: ');
    const password = await ask('Password: ');

    const passwordHash = await bcrypt.hash(password, 12);

    const result = await pool.query(
      `INSERT INTO users
        (name, username, email, password_hash, role)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, username, email, role`,
      [name, username, email, passwordHash, 'admin'],
    );

    console.log('\nUser created successfully:');
    console.log(result.rows[0]);
  } catch (error) {
    console.error('\nFailed to create user:', error.message);
  } finally {
    rl.close();
    await pool.end();
  }
}

main();