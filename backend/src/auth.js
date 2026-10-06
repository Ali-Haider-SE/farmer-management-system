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
 * POST /api/auth/social-login
 * Body: { idToken, role }
 * Used for both Google Sign-In and Phone OTP — Flutter sends the
 * Firebase ID token after the user signs in there.
 */
router.post('/social-login', async (req, res) => {
  try {
    const { idToken, role } = req.body;

    if (!idToken || !role) {
      return res.status(400).json({
        success: false,
        message: 'idToken and role are required',
      });
    }

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(idToken);
    } catch (err) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired Firebase token',
      });
    }

    const firebaseUid = decoded.uid;
    const email = decoded.email || null;
    const phoneNumber = decoded.phone_number || null;
    const name = decoded.name || email || phoneNumber || 'User';
    const provider = phoneNumber && !email ? 'phone' : 'google';

    // Try to find an existing user by firebase_uid, then by email/phone
    let result = await pool.query(
      `SELECT id, name, username, email, role, is_active, phone_number
       FROM users
       WHERE firebase_uid = $1
       LIMIT 1`,
      [firebaseUid],
    );

    let user = result.rows[0];

    if (!user) {
      // Link to an existing account with the same email/phone if present
      if (email) {
        result = await pool.query(
          `SELECT id, name, username, email, role, is_active, phone_number
           FROM users WHERE LOWER(email) = LOWER($1) LIMIT 1`,
          [email],
        );
        user = result.rows[0];
      }
      if (!user && phoneNumber) {
        result = await pool.query(
          `SELECT id, name, username, email, role, is_active, phone_number
           FROM users WHERE phone_number = $1 LIMIT 1`,
          [phoneNumber],
        );
        user = result.rows[0];
      }
    }

    if (user) {
      // Link firebase_uid to the existing account if not already linked
      await pool.query(
        `UPDATE users
         SET firebase_uid = $1, auth_provider = $2
         WHERE id = $3`,
        [firebaseUid, provider, user.id],
      );
    } else {
      // Brand-new user — create with the requested role.
      // NOTE: consider requiring admin approval for new roles in production.
      const insertResult = await pool.query(
        `INSERT INTO users
           (name, email, phone_number, role, is_active, firebase_uid, auth_provider)
         VALUES ($1, $2, $3, $4, TRUE, $5, $6)
         RETURNING id, name, username, email, role, is_active, phone_number`,
        [name, email, phoneNumber, role, firebaseUid, provider],
      );
      user = insertResult.rows[0];
    }

    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: 'User account is inactive',
      });
    }

    const token = jwt.sign(
      { userId: user.id, role: user.role },
      getJwtSecret(),
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
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
        phoneNumber: user.phone_number,
        role: user.role,
        isActive: user.is_active,
      },
    });
  } catch (error) {
    console.error('Social login error:', error);
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