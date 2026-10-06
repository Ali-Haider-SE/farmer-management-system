require('dotenv').config();
const pool = require('./src/db');

async function run() {
    try {
        await pool.query(`
            ALTER TABLE public.stock
            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        `);

        console.log('SUCCESS: updated_at column added/exists');

        const result = await pool.query(`
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'stock'
            ORDER BY ordinal_position
        `);

        console.table(result.rows);
    } catch (error) {
        console.error('ERROR:', error.message);
    } finally {
        await pool.end();
    }
}

run();
