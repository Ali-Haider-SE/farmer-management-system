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
    const args = process.argv.slice(2);
    const getArg = (name) => {
      const idx = args.indexOf(`--${name}`);
      if (idx !== -1 && args[idx + 1]) return args[idx + 1];
      return null;
    };

    const isNonInteractive =
      args.includes('--non-interactive') ||
      Boolean(process.env.SEED_ADMIN_PASSWORD || process.env.ADMIN_PASSWORD || getArg('password'));

    let name, username, email, password, role;

    if (isNonInteractive) {
      name = getArg('name') || process.env.SEED_ADMIN_NAME || 'Super Admin';
      username = getArg('username') || process.env.SEED_ADMIN_USERNAME || 'admin';
      email = getArg('email') || process.env.SEED_ADMIN_EMAIL || 'admin@example.com';
      password = getArg('password') || process.env.SEED_ADMIN_PASSWORD || process.env.ADMIN_PASSWORD || 'Admin@12345';
      role = (getArg('role') || process.env.SEED_ADMIN_ROLE || 'admin').trim().toLowerCase();
    } else {
      name = await ask('Name: ');
      username = await ask('Username: ');
      email = await ask('Email: ');
      password = await ask('Password: ');
      role = (await ask('Role (admin, farm manager, rice/wheat manager, accountant): ')).trim().toLowerCase();
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const result = await pool.query(
      `INSERT INTO users
        (name, username, email, password_hash, role)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (username) DO UPDATE
       SET name = EXCLUDED.name,
           email = EXCLUDED.email,
           password_hash = EXCLUDED.password_hash,
           role = EXCLUDED.role,
           updated_at = NOW()
       RETURNING id, name, username, email, role`,
      [
        name,
        username,
        email,
        passwordHash,
        role,
      ],
    );

    console.log('\nUser processed successfully:');
    console.log(result.rows[0]);
  } catch (error) {
    console.error('\nFailed to create user:', error.message);
  } finally {
    rl.close();
    await pool.end();
  }
}

main();
