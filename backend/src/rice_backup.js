const express = require('express');
const pool = require('./db');

const router = express.Router();

// =====================================================
// GET ALL RICE TRANSACTIONS
// =====================================================

router.get('/', async (req, res, next) => {
  try {
    const result = await pool.query(`
      SELECT
        id,
        farmer_id,
        party_id,
        date,
        quantity,
        rate,
        total_amount,
        transaction_type,
        paid_amount,
        received_amount,
        remaining_amount,
        variety,
        notes,
        created_at
      FROM rice_transactions
      ORDER BY date DESC, created_at DESC
    `);

    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

// =====================================================
// GET ONE RICE TRANSACTION
// =====================================================

router.get('/:id', async (req, res, next) => {
  try {
    const result = await pool.query(
      `
      SELECT
        id,
        farmer_id,
        party_id,
        date,
        quantity,
        rate,
        total_amount,
        transaction_type,
        paid_amount,
        received_amount,
        remaining_amount,
        variety,
        notes,
        created_at
      FROM rice_transactions
      WHERE id = $1
      `,
      [req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: 'Rice transaction not found',
      });
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

// =====================================================
// CREATE RICE TRANSACTION
// =====================================================

router.post('/', async (req, res, next) => {
  try {
    const {
      farmer_id,
      party_id,
      date,
      quantity,
      rate,
      total_amount,
      transaction_type,
      paid_amount,
      received_amount,
      remaining_amount,
      variety,
      notes,
    } = req.body;

    if (!transaction_type) {
      return res.status(400).json({
        message: 'transaction_type is required',
      });
    }

    const result = await pool.query(
      `
      INSERT INTO rice_transactions (
        farmer_id,
        party_id,
        date,
        quantity,
        rate,
        total_amount,
        transaction_type,
        paid_amount,
        received_amount,
        remaining_amount,
        variety,
        notes
      )
      VALUES (
        $1,
        $2,
        COALESCE($3, NOW()),
        COALESCE($4, 0),
        COALESCE($5, 0),
        COALESCE($6, 0),
        $7,
        COALESCE($8, 0),
        COALESCE($9, 0),
        COALESCE($10, 0),
        $11,
        $12
      )
      RETURNING
        id,
        farmer_id,
        party_id,
        date,
        quantity,
        rate,
        total_amount,
        transaction_type,
        paid_amount,
        received_amount,
        remaining_amount,
        variety,
        notes,
        created_at
      `,
      [
        farmer_id || null,
        party_id || null,
        date || null,
        quantity ?? 0,
        rate ?? 0,
        total_amount ?? 0,
        transaction_type,
        paid_amount ?? 0,
        received_amount ?? 0,
        remaining_amount ?? 0,
        variety || null,
        notes || null,
      ],
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

// =====================================================
// UPDATE RICE TRANSACTION
// =====================================================

router.put('/:id', async (req, res, next) => {
  try {
    const {
      farmer_id,
      party_id,
      date,
      quantity,
      rate,
      total_amount,
      transaction_type,
      paid_amount,
      received_amount,
      remaining_amount,
      variety,
      notes,
    } = req.body;

    if (!transaction_type) {
      return res.status(400).json({
        message: 'transaction_type is required',
      });
    }

    const result = await pool.query(
      `
      UPDATE rice_transactions
      SET
        farmer_id = $1,
        party_id = $2,
        date = COALESCE($3, date),
        quantity = COALESCE($4, quantity),
        rate = COALESCE($5, rate),
        total_amount = COALESCE($6, total_amount),
        transaction_type = $7,
        paid_amount = COALESCE($8, paid_amount),
        received_amount = COALESCE($9, received_amount),
        remaining_amount = COALESCE($10, remaining_amount),
        variety = $11,
        notes = $12
      WHERE id = $13
      RETURNING
        id,
        farmer_id,
        party_id,
        date,
        quantity,
        rate,
        total_amount,
        transaction_type,
        paid_amount,
        received_amount,
        remaining_amount,
        variety,
        notes,
        created_at
      `,
      [
        farmer_id || null,
        party_id || null,
        date || null,
        quantity ?? null,
        rate ?? null,
        total_amount ?? null,
        transaction_type,
        paid_amount ?? null,
        received_amount ?? null,
        remaining_amount ?? null,
        variety || null,
        notes || null,
        req.params.id,
      ],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: 'Rice transaction not found',
      });
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

// =====================================================
// DELETE RICE TRANSACTION
// =====================================================

router.delete('/:id', async (req, res, next) => {
  try {
    const result = await pool.query(
      `
      DELETE FROM rice_transactions
      WHERE id = $1
      RETURNING id
      `,
      [req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: 'Rice transaction not found',
      });
    }

    res.json({
      message: 'Rice transaction deleted successfully',
      id: result.rows[0].id,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;