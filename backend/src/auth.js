const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('./db');


const router = express.Router();

/**
 * Get JWT secret safely.
 */
function getJwtSecret() {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new Error('JWT_SECRET is not configured');
  }

  if (secret.length < 32 || secret === 'replace_with_a_long_random_secret' || secret.includes('YOUR_JWT_SECRET')) {
    throw new Error('JWT_SECRET must be at least 32 characters long and not use a default placeholder');
  }

  return secret;
}

/**
 * JWT authentication middleware.
 *
 * Reads:
 * Authorization: Bearer <token>
 */
function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';

    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const token = authHeader.substring(7).trim();

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Authentication token is missing',
      });
    }

    const decoded = jwt.verify(token, getJwtSecret());

    req.user = decoded;

    next();
  } catch (error) {
    console.error('Authentication error:', error.message);

    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Authentication token has expired',
      });
    }

    return res.status(401).json({
      success: false,
      message: 'Invalid authentication token',
    });
  }
}

/**
 * POST /api/auth/login
 */
router.post('/login', async (req, res) => {
  try {
    const { username, password, role } = req.body;

    if (
      !username ||
      !password ||
      !role ||
      String(username).trim().length > 100 ||
      String(password).length > 256
    ) {
      return res.status(400).json({
        success: false,
        message: 'Username, password and role are required',
      });
    }

    const result = await pool.query(
      `SELECT
         id,
         name,
         username,
         email,
         password_hash,
         role,
         is_active
       FROM users
       WHERE LOWER(username) = LOWER($1)
       LIMIT 1`,
      [username],
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid username or password',
      });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: 'User account is inactive',
      });
    }

    if (
      !user.role ||
      user.role.toLowerCase() !== role.toLowerCase()
    ) {
      return res.status(401).json({
        success: false,
        message: 'Invalid username, password or role',
      });
    }

    const passwordMatch = await bcrypt.compare(
      password,
      user.password_hash,
    );

    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid username or password',
      });
    }

    const token = jwt.sign(
      {
        userId: user.id,
        role: user.role,
      },
      getJwtSecret(),
      {
        expiresIn: process.env.JWT_EXPIRES_IN || '7d',
      },
    );

    return res.status(200).json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        name: user.name,
        username: user.username,
        email: user.email,
        role: user.role,
        isActive: user.is_active,
      },
    });
 } catch (error) {
    console.error('Login error:', error);

    return res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * GET /api/auth/me
 *
 * Verifies the JWT and returns the current user.
 */
router.get('/me', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Invalid authentication token',
      });
    }

    const result = await pool.query(
      `SELECT
         id,
         name,
         username,
         email,
         role,
         is_active
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [userId],
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'User not found',
      });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: 'User account is inactive',
      });
    }

    return res.status(200).json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        username: user.username,
        email: user.email,
        role: user.role,
        isActive: user.is_active,
      },
    });
  } catch (error) {
    console.error('Get current user error:', error);

    return res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});


router.put('/users/:id/password', authenticate, async (req, res) => {
  try {
    const requesterId = req.user.userId;
    const targetId = req.params.id;
    const newPassword = String(req.body?.newPassword || '');

    if (!newPassword || newPassword.length < 8 || newPassword.length > 128) {
      return res.status(400).json({
        success: false,
        message: 'Password must be between 8 and 128 characters',
      });
    }

    if (requesterId !== targetId && String(req.user.role).toLowerCase() !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to change this password',
      });
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);

    const result = await pool.query(
      `
      UPDATE users
      SET password_hash = $1, updated_at = NOW()
      WHERE id = $2 AND is_active = TRUE
      RETURNING id
      `,
      [passwordHash, targetId],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    return res.json({
      success: true,
      message: 'Password changed successfully',
    });
  } catch (error) {
    console.error('Change password error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Unable to change password',
    });
  }
});

/**
 * Export middleware as a property so it can be reused
 * by other backend route files later.
 */
router.authenticate = authenticate;

module.exports = router;