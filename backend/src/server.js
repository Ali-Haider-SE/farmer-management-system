const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const pool = require('./db');
const authRouter = require('./auth');

dotenv.config();

const app = express();

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

app.use(
  cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);

app.use(express.json());

// -----------------------------------------------------------------------------
// AUTHENTICATION
// -----------------------------------------------------------------------------
// Login route is public.
// /api/auth/me is protected internally by auth.js.
//
// All business APIs below require a valid JWT token.
// -----------------------------------------------------------------------------

app.use('/api/auth', authRouter);

app.use('/api/parties', authRouter.authenticate, partiesRouter);
app.use('/api/khata', authRouter.authenticate, khataRouter);
app.use('/api/farmers', authRouter.authenticate, farmersRouter);
app.use('/api/farms', authRouter.authenticate, farmsRouter);
app.use('/api/rice', authRouter.authenticate, riceRoutes);
app.use('/api/wheat', authRouter.authenticate, wheatRoutes);
app.use('/api/stock', authRouter.authenticate, stockRouter);
app.use('/api/accounts', authRouter.authenticate, accountsRouter);

// -----------------------------------------------------------------------------
// KHATA TEST ROUTE
// -----------------------------------------------------------------------------

app.get('/api/khata-test', (req, res) => {
  res.json({
    success: true,
    message: 'Khata route is registered',
  });
});

app.use(express.urlencoded({ extended: true }));

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

app.get('/api/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'API is healthy',
    service: 'Farmer Management API',
    timestamp: new Date().toISOString(),
  });
});

// -----------------------------------------------------------------------------
// DATABASE HEALTH
// -----------------------------------------------------------------------------

app.get('/api/health/db', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT current_user, current_database()',
    );

    res.status(200).json({
      success: true,
      message: 'Database connection is healthy',
      database: result.rows[0].current_database,
      user: result.rows[0].current_user,
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

const server = app.listen(PORT, () => {
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