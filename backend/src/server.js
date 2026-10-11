const dotenv = require('dotenv');

dotenv.config();

const express = require('express');
const cors = require('cors');
const pool = require('./db');
const authRouter = require('./auth');
const { authorizeRoles } = require('./authorization');

const app = express();

const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret || jwtSecret.length < 32 || jwtSecret === 'replace_with_a_long_random_secret' || jwtSecret.includes('YOUR_JWT_SECRET')) {
  throw new Error('FATAL: JWT_SECRET must be configured, at least 32 characters, and not use a placeholder.');
}

const PORT = Number(process.env.PORT) || 5000;

const partiesRouter = require('./parties');
const khataRouter = require('./khata');
const farmersRouter = require('./farmers');
const farmsRouter = require('./farms');
const riceRoutes = require('./rice');
const wheatRoutes = require('./wheat');
const stockRouter = require('./stock');
const accountsRouter = require('./accounts');

// -----------------------------------------------------------------------------
// MIDDLEWARE
// -----------------------------------------------------------------------------

const allowedOrigins = (process.env.CORS_ORIGINS || '*')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

if (process.env.NODE_ENV === 'production' && allowedOrigins.includes('*')) {
  throw new Error('CORS_ORIGINS must be explicitly configured in production');
}


app.disable('x-powered-by');

app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader("Content-Security-Policy", "default-src 'self'");
  if (req.path.startsWith('/api/')) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.setHeader('Pragma', 'no-cache');
  }
  next();
});

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('Origin not allowed by CORS'));
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);

app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// -----------------------------------------------------------------------------
// AUTHENTICATION
// -----------------------------------------------------------------------------
// Login route is public.
// /api/auth/me is protected internally by auth.js.
//
// All business APIs below require a valid JWT token.
// -----------------------------------------------------------------------------

const loginAttempts = new Map();
const loginWindowMs = 15 * 60 * 1000;
const loginLimit = Number(process.env.AUTH_RATE_LIMIT || 20);

// Cleanup expired rate-limit records periodically to prevent memory leaks
setInterval(() => {
  const now = Date.now();
  for (const [key, record] of loginAttempts.entries()) {
    if (now - record.startedAt >= loginWindowMs) {
      loginAttempts.delete(key);
    }
  }
}, 5 * 60 * 1000).unref();

function authRateLimit(req, res, next) {
  const key = req.ip || req.socket.remoteAddress || 'unknown';
  const now = Date.now();
  const record = loginAttempts.get(key);

  if (!record || now - record.startedAt >= loginWindowMs) {
    loginAttempts.set(key, { startedAt: now, count: 1 });
    return next();
  }

  if (record.count >= loginLimit) {
    return res.status(429).json({
      success: false,
      message: 'Too many authentication attempts. Please try again later.',
    });
  }

  record.count += 1;
  return next();
}

app.use('/api/auth/login', authRateLimit);
app.use('/api/auth/users/:id/password', authRateLimit);
app.use('/api/auth', authRouter);


const BACKUP_TABLES = [
  'farmers',
  'farms',
  'farm_activities',
  'parties',
  'khata_transactions',
  'rice_transactions',
  'wheat_transactions',
  'stock',
  'stock_movements',
  'accounts',
  'account_transactions',
  'payments',
];

app.get('/api/admin/backup', authRouter.authenticate, authorizeRoles('admin'), async (req, res) => {
  const client = await pool.connect();

  try {
    const data = {};
    for (const table of BACKUP_TABLES) {
      const result = await client.query(`SELECT * FROM ${table}`);
      data[table] = result.rows;
    }

    return res.json({
      success: true,
      version: '2.0.0',
      createdAt: new Date().toISOString(),
      tables: data,
    });
  } catch (error) {
    console.error('Database backup failed:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Database backup failed',
    });
  } finally {
    client.release();
  }
});

app.post(
  '/api/admin/restore',
  express.json({ limit: '20mb' }),
  authRouter.authenticate,
  authorizeRoles('admin'),
  async (req, res) => {
  const client = await pool.connect();

  try {
    const snapshot = req.body;

    if (
      !snapshot ||
      typeof snapshot !== 'object' ||
      snapshot.version !== '2.0.0' ||
      !snapshot.tables ||
      typeof snapshot.tables !== 'object'
    ) {
      return res.status(400).json({
        success: false,
        message: 'Invalid database backup format',
      });
    }

    await client.query('BEGIN');

    // Clear only application business tables. User accounts and passwords are
    // deliberately excluded so a restore cannot lock out the administrator.
    await client.query(`
      TRUNCATE TABLE
        farm_activities,
        stock_movements,
        account_transactions,
        khata_transactions,
        rice_transactions,
        wheat_transactions,
        payments,
        farms,
        farmers,
        stock,
        accounts,
        parties
      RESTART IDENTITY CASCADE
    `);

    const insertRows = async (table, columns, rows) => {
      if (!Array.isArray(rows) || rows.length === 0) return;

      const safeColumns = columns.map((column) => `"${column}"`).join(', ');
      for (const row of rows) {
        const values = columns.map((column) => row[column] ?? null);
        const placeholders = values.map((_, index) => `$${index + 1}`).join(', ');
        await client.query(
          `INSERT INTO ${table} (${safeColumns}) VALUES (${placeholders})`,
          values,
        );
      }
    };

    await insertRows('farmers',
      ['id','name','father_name','phone','address','cnic','is_active','created_at','updated_at'],
      snapshot.tables.farmers);
    await insertRows('farms',
      ['id','farmer_id','farm_name','location','area','area_unit','crop_type','is_active','created_at','updated_at'],
      snapshot.tables.farms);
    await insertRows('farm_activities',
      ['id','farm_id','activity_type','category','quantity','unit','rate','amount','date','notes','created_at','updated_at'],
      snapshot.tables.farm_activities);
    await insertRows('parties',
      ['id','name','phone','address','party_type','opening_balance','opening_balance_type','is_active','created_at','updated_at'],
      snapshot.tables.parties);
    await insertRows('khata_transactions',
      ['id','party_id','date','description','debit','credit','balance','reference','source_type','source_id','created_at','updated_at'],
      snapshot.tables.khata_transactions);
    await insertRows('rice_transactions',
      ['id','farmer_id','party_id','date','quantity','rate','total_amount','transaction_type','paid_amount','received_amount','remaining_amount','variety','notes','stock_id','created_at','updated_at'],
      snapshot.tables.rice_transactions);
    await insertRows('wheat_transactions',
      ['id','farmer_id','party_id','date','quantity','rate','total_amount','transaction_type','paid_amount','received_amount','remaining_amount','variety','notes','stock_id','created_at','updated_at'],
      snapshot.tables.wheat_transactions);
    await insertRows('stock',
      ['id','product_name','product_type','quantity','unit','average_rate','total_value','warehouse','is_active','created_at','updated_at'],
      snapshot.tables.stock);
    await insertRows('stock_movements',
      ['id','stock_id','date','movement_type','quantity','rate','amount','source','reference','notes','created_at'],
      snapshot.tables.stock_movements);
    await insertRows('accounts',
      ['id','name','account_type','opening_balance','current_balance','description','is_active','created_at','updated_at'],
      snapshot.tables.accounts);
    await insertRows('account_transactions',
      ['id','account_id','date','type','amount','category','description','source','reference','created_at'],
      snapshot.tables.account_transactions);
    await insertRows('payments',
      ['id','party_id','account_id','date','amount','payment_type','description','reference','created_at'],
      snapshot.tables.payments);

    await client.query('COMMIT');

    return res.json({
      success: true,
      message: 'Database backup restored successfully',
    });
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    console.error('Database restore failed:', error.message);
    return res.status(400).json({
      success: false,
      message: 'Database restore failed. The transaction was rolled back.',
    });
  } finally {
    client.release();
  }
});

app.get('/api/parties/lookup', authRouter.authenticate, authorizeRoles('admin', 'accountant', 'rice/wheat manager'), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, phone, party_type
       FROM parties
       WHERE is_active = TRUE
       ORDER BY name ASC`,
    );
    return res.status(200).json({
      success: true,
      parties: result.rows,
    });
  } catch (error) {
    console.error('Get parties lookup error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch party lookup list',
    });
  }
});

app.use('/api/parties', authRouter.authenticate, authorizeRoles('admin', 'accountant'), partiesRouter);
app.use('/api/khata', authRouter.authenticate, authorizeRoles('admin', 'accountant'), khataRouter);
app.use('/api/farmers', authRouter.authenticate, authorizeRoles('admin', 'farm manager'), farmersRouter);
app.use('/api/farms', authRouter.authenticate, authorizeRoles('admin', 'farm manager'), farmsRouter);
app.use('/api/rice', authRouter.authenticate, authorizeRoles('admin', 'rice/wheat manager'), riceRoutes);
app.use('/api/wheat', authRouter.authenticate, authorizeRoles('admin', 'rice/wheat manager'), wheatRoutes);
app.use('/api/stock', authRouter.authenticate, authorizeRoles('admin', 'farm manager', 'rice/wheat manager'), stockRouter);
app.use(
  '/api/accounts',
  authRouter.authenticate,
  authorizeRoles('admin', 'accountant'),
  accountsRouter
);

// -----------------------------------------------------------------------------
// ROLE-AWARE AGGREGATE SUMMARY ENDPOINTS
// -----------------------------------------------------------------------------

app.get('/api/dashboard/summary', authRouter.authenticate, async (req, res) => {
  try {
    const role = (req.user?.role || '').toLowerCase();
    const isAdmin = role === 'admin';
    const isFarm = isAdmin || role === 'farm manager';
    const isCrop = isAdmin || role === 'rice/wheat manager';
    const isAccountant = isAdmin || role === 'accountant';

    const summary = {
      role: req.user?.role,
    };

    if (isFarm) {
      const farmsRes = await pool.query(
        `SELECT COUNT(*)::int AS count, COALESCE(SUM(area), 0)::numeric(12,2) AS total_area FROM farms WHERE is_active = TRUE`
      );
      summary.farms = {
        count: farmsRes.rows[0].count,
        totalArea: Number(farmsRes.rows[0].total_area),
      };
    }

    if (isCrop) {
      const riceRes = await pool.query(`
        SELECT
          COALESCE(SUM(CASE WHEN transaction_type = 'purchase' THEN quantity ELSE 0 END), 0)::numeric(12,2) AS purchase_qty,
          COALESCE(SUM(CASE WHEN transaction_type = 'sale' THEN quantity ELSE 0 END), 0)::numeric(12,2) AS sale_qty,
          COALESCE(SUM(CASE WHEN transaction_type = 'purchase' THEN total_amount ELSE 0 END), 0)::numeric(14,2) AS purchase_amount,
          COALESCE(SUM(CASE WHEN transaction_type = 'sale' THEN total_amount ELSE 0 END), 0)::numeric(14,2) AS sale_amount
        FROM rice_transactions
      `);
      const wheatRes = await pool.query(`
        SELECT
          COALESCE(SUM(CASE WHEN transaction_type = 'purchase' THEN quantity ELSE 0 END), 0)::numeric(12,2) AS purchase_qty,
          COALESCE(SUM(CASE WHEN transaction_type = 'sale' THEN quantity ELSE 0 END), 0)::numeric(12,2) AS sale_qty,
          COALESCE(SUM(CASE WHEN transaction_type = 'purchase' THEN total_amount ELSE 0 END), 0)::numeric(14,2) AS purchase_amount,
          COALESCE(SUM(CASE WHEN transaction_type = 'sale' THEN total_amount ELSE 0 END), 0)::numeric(14,2) AS sale_amount
        FROM wheat_transactions
      `);
      summary.crops = {
        rice: {
          purchaseQty: Number(riceRes.rows[0].purchase_qty),
          saleQty: Number(riceRes.rows[0].sale_qty),
          purchaseAmount: Number(riceRes.rows[0].purchase_amount),
          saleAmount: Number(riceRes.rows[0].sale_amount),
        },
        wheat: {
          purchaseQty: Number(wheatRes.rows[0].purchase_qty),
          saleQty: Number(wheatRes.rows[0].sale_qty),
          purchaseAmount: Number(wheatRes.rows[0].purchase_amount),
          saleAmount: Number(wheatRes.rows[0].sale_amount),
        },
      };
    }

    if (isFarm || isCrop) {
      const stockRes = await pool.query(`
        SELECT
          COALESCE(SUM(CASE WHEN LOWER(product_name) LIKE '%rice%' THEN quantity ELSE 0 END), 0)::numeric(12,2) AS rice_stock,
          COALESCE(SUM(CASE WHEN LOWER(product_name) LIKE '%wheat%' THEN quantity ELSE 0 END), 0)::numeric(12,2) AS wheat_stock,
          COALESCE(SUM(total_value), 0)::numeric(14,2) AS total_value
        FROM stock
        WHERE is_active = TRUE
      `);
      summary.stock = {
        riceStock: Number(stockRes.rows[0].rice_stock),
        wheatStock: Number(stockRes.rows[0].wheat_stock),
        totalValue: Number(stockRes.rows[0].total_value),
      };
    }

    if (isAccountant) {
      const partiesRes = await pool.query(`
        SELECT
          COUNT(*)::int AS count,
          COALESCE(SUM(CASE WHEN opening_balance_type IN ('You Give', 'debit') THEN opening_balance ELSE 0 END), 0)::numeric(14,2) AS opening_receivable,
          COALESCE(SUM(CASE WHEN opening_balance_type IN ('You Take', 'You Receive', 'credit') THEN opening_balance ELSE 0 END), 0)::numeric(14,2) AS opening_payable
        FROM parties
        WHERE is_active = TRUE
      `);
      const accountsRes = await pool.query(`
        SELECT
          COUNT(*)::int AS count,
          COALESCE(SUM(current_balance), 0)::numeric(14,2) AS total_balance
        FROM accounts
        WHERE is_active = TRUE
      `);
      summary.accounts = {
        partiesCount: partiesRes.rows[0].count,
        accountsCount: accountsRes.rows[0].count,
        totalAccountBalance: Number(accountsRes.rows[0].total_balance),
      };
    }

    return res.status(200).json({
      success: true,
      data: summary,
    });
  } catch (err) {
    console.error('Dashboard summary error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to load dashboard summary',
    });
  }
});


// -----------------------------------------------------------------------------
// BASIC ROUTES
// -----------------------------------------------------------------------------

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Farmer Management API is running',
    version: '1.0.0',
  });
});

app.get('/api/health', async (req, res) => {
  let schemaVersion = 'unknown';
  try {
    const migRes = await pool.query(
      'SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1'
    );
    if (migRes.rows.length > 0) {
      schemaVersion = migRes.rows[0].version;
    }
  } catch (_) {
    // schema_migrations might not exist yet if unmigrated
  }

  res.status(200).json({
    success: true,
    message: 'API is healthy',
    service: 'Farmer Management API',
    schemaVersion,
    timestamp: new Date().toISOString(),
  });
});

// -----------------------------------------------------------------------------
// DATABASE HEALTH
// -----------------------------------------------------------------------------

app.get('/api/health/db', authRouter.authenticate, authorizeRoles('admin'), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT current_user, current_database()',
    );

    res.status(200).json({
      success: true,
      message: 'Database connection is healthy',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Database health check failed:', error);

    res.status(500).json({
      success: false,
      message: 'Database connection failed',
    });
  }
});

// -----------------------------------------------------------------------------
// 404 HANDLER
// -----------------------------------------------------------------------------

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

// -----------------------------------------------------------------------------
// ERROR HANDLER
// -----------------------------------------------------------------------------

app.use((err, req, res, next) => {
  console.error('API Error:', err);

  if (err.code === '23505') {
    return res.status(409).json({
      success: false,
      message: err.detail || 'A record with these details already exists.',
    });
  }

  if (err.code === '23503') {
    return res.status(400).json({
      success: false,
      message: err.detail || 'Referenced record does not exist or cannot be removed due to foreign key constraints.',
    });
  }

  if (err.code === '22P02') {
    return res.status(400).json({
      success: false,
      message: 'Invalid input syntax for number or date.',
    });
  }

  if (err.code === '23514') {
    return res.status(400).json({
      success: false,
      message: err.detail || 'A database check constraint was violated.',
    });
  }

  const statusCode = err.statusCode || 500;

  res.status(statusCode).json({
    success: false,
    message:
      statusCode === 500
        ? 'Internal server error'
        : err.message || 'Request failed',
  });
});

// -----------------------------------------------------------------------------
// SERVER
// -----------------------------------------------------------------------------

const server = app.listen(PORT, (err) => {
  if (err) {
    console.error(`Failed to start on port ${PORT}:`, err.message);
    process.exit(1);
  }
  console.log('==========================================');
  console.log(' Farmer Management API');
  console.log('==========================================');
  console.log(` Server running on port ${PORT}`);
  console.log(` Local URL: http://localhost:${PORT}`);
  console.log(` Health:    http://localhost:${PORT}/api/health`);
  console.log(` DB Health: http://localhost:${PORT}/api/health/db`);
  console.log('==========================================');
});

// -----------------------------------------------------------------------------
// GRACEFUL SHUTDOWN
// -----------------------------------------------------------------------------

const shutdown = (signal) => {
  console.log(`\n${signal} received. Shutting down server...`);

  server.close(() => {
    console.log('Server closed successfully.');
    process.exit(0);
  });
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));