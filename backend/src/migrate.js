const fs = require('fs');
const path = require('path');
const pool = require('./db');

async function runMigration() {
  const migrationPath = path.join(
    __dirname,
    '..',
    'migrations',
    '001_initial_schema.sql',
  );

  if (!fs.existsSync(migrationPath)) {
    throw new Error(
      `Migration file not found: ${migrationPath}`,
    );
  }

  const sql = fs.readFileSync(migrationPath, 'utf8');

  const client = await pool.connect();

  try {
    console.log('==========================================');
    console.log(' Farmer Management Database Migration');
    console.log('==========================================');

    await client.query('BEGIN');

    await client.query(sql);

    await client.query('COMMIT');

    console.log('Migration completed successfully.');
  } catch (error) {
    await client.query('ROLLBACK');

    console.error('Migration failed.');
    console.error(error);

    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch((error) => {
  console.error('Migration startup failed.');
  console.error(error);

  process.exitCode = 1;
});