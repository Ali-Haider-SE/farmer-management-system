
const express = require('express');
const pool = require('./db');

const router = express.Router();

// =====================================================
// HELPER: KHATA DEBIT / CREDIT
// =====================================================

function getKhataAmounts(transactionType, remainingAmount) {
  const amount = Number(remainingAmount) || 0;

  if (transactionType === 'sale') {
    return {
      debit: amount,
      credit: 0,
    };
  }

  if (transactionType === 'purchase') {
    return {
      debit: 0,
      credit: amount,
    };
  }

  return {
    debit: 0,
    credit: 0,
  };
}

// =====================================================
// HELPER: RECALCULATE PARTY KHATA BALANCES
// =====================================================

async function recalculatePartyBalances(client, partyId) {
  if (!partyId) return;

  const partyResult = await client.query(
    `
    SELECT opening_balance, opening_balance_type
    FROM public.parties
    WHERE id = $1
    `,
    [partyId],
  );

  if (partyResult.rows.length === 0) return;

  const party = partyResult.rows[0];

  let runningBalance = Number(party.opening_balance) || 0;

  if (party.opening_balance_type === 'credit') {
    runningBalance = -runningBalance;
  }

  const transactionsResult = await client.query(
    `
    SELECT id, debit, credit
    FROM public.khata_transactions
    WHERE party_id = $1
    ORDER BY date ASC, created_at ASC, id ASC
    `,
    [partyId],
  );

  for (const transaction of transactionsResult.rows) {
    const debit = Number(transaction.debit) || 0;
    const credit = Number(transaction.credit) || 0;

    runningBalance = runningBalance + debit - credit;

    await client.query(
      `
      UPDATE public.khata_transactions
      SET balance = $1
      WHERE id = $2
      `,
      [runningBalance, transaction.id],
    );
  }
}

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
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

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
      await client.query('ROLLBACK');

      return res.status(400).json({
        message: 'transaction_type is required',
      });
    }

    if (!['sale', 'purchase'].includes(transaction_type)) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        message: 'transaction_type must be sale or purchase',
      });
    }

    // -------------------------------------------------
    // INSERT RICE TRANSACTION
    // -------------------------------------------------

    const riceResult = await client.query(
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

    const rice = riceResult.rows[0];

    // -------------------------------------------------
    // CREATE KHATA TRANSACTION
    // -------------------------------------------------

    if (party_id && Number(remaining_amount || 0) > 0) {
      const { debit, credit } = getKhataAmounts(
        transaction_type,
        remaining_amount,
      );

      await client.query(
        `
        INSERT INTO public.khata_transactions (
          id,
          party_id,
          date,
          description,
          debit,
          credit,
          balance,
          reference
        )
        VALUES (
          gen_random_uuid(),
          $1,
          COALESCE($2, NOW()),
          $3,
          $4,
          $5,
          0,
          $6
        )
        `,
        [
          party_id,
          date || null,
          `Rice ${transaction_type}`,
          debit,
          credit,
          `rice:${rice.id}`,
        ],
      );

      await recalculatePartyBalances(client, party_id);
    }

    await client.query('COMMIT');

    res.status(201).json(rice);
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
});

// =====================================================
// UPDATE RICE TRANSACTION
// =====================================================

router.put('/:id', async (req, res, next) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const oldResult = await client.query(
      `
      SELECT
        id,
        party_id,
        date,
        transaction_type,
        remaining_amount
      FROM rice_transactions
      WHERE id = $1
      `,
      [req.params.id],
    );

    if (oldResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        message: 'Rice transaction not found',
      });
    }

    const oldRice = oldResult.rows[0];

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
      await client.query('ROLLBACK');

      return res.status(400).json({
        message: 'transaction_type is required',
      });
    }

    if (!['sale', 'purchase'].includes(transaction_type)) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        message: 'transaction_type must be sale or purchase',
      });
    }

    const result = await client.query(
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

    const rice = result.rows[0];

    // -------------------------------------------------
    // REMOVE OLD KHATA LINK
    // -------------------------------------------------

    await client.query(
      `
      DELETE FROM public.khata_transactions
      WHERE reference = $1
      `,
      [`rice:${req.params.id}`],
    );

    // -------------------------------------------------
    // CREATE UPDATED KHATA LINK
    // -------------------------------------------------

    if (party_id && Number(rice.remaining_amount || 0) > 0) {
      const { debit, credit } = getKhataAmounts(
        transaction_type,
        rice.remaining_amount,
      );

      await client.query(
        `
        INSERT INTO public.khata_transactions (
          id,
          party_id,
          date,
          description,
          debit,
          credit,
          balance,
          reference
        )
        VALUES (
          gen_random_uuid(),
          $1,
          COALESCE($2, NOW()),
          $3,
          $4,
          $5,
          0,
          $6
        )
        `,
        [
          party_id,
          date || null,
          `Rice ${transaction_type}`,
          debit,
          credit,
          `rice:${rice.id}`,
        ],
      );
    }

    // -------------------------------------------------
    // RECALCULATE AFFECTED PARTIES
    // -------------------------------------------------

    if (oldRice.party_id) {
      await recalculatePartyBalances(client, oldRice.party_id);
    }

    if (party_id && party_id !== oldRice.party_id) {
      await recalculatePartyBalances(client, party_id);
    }

    await client.query('COMMIT');

    res.json(rice);
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
});

// =====================================================
// DELETE RICE TRANSACTION
// =====================================================

router.delete('/:id', async (req, res, next) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const riceResult = await client.query(
      `
      SELECT id, party_id
      FROM rice_transactions
      WHERE id = $1
      `,
      [req.params.id],
    );

    if (riceResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        message: 'Rice transaction not found',
      });
    }

    const rice = riceResult.rows[0];

    // -------------------------------------------------
    // DELETE LINKED KHATA TRANSACTION
    // -------------------------------------------------

    await client.query(
      `
      DELETE FROM public.khata_transactions
      WHERE reference = $1
      `,
      [`rice:${rice.id}`],
    );

    // -------------------------------------------------
    // DELETE RICE TRANSACTION
    // -------------------------------------------------

    await client.query(
      `
      DELETE FROM rice_transactions
      WHERE id = $1
      `,
      [req.params.id],
    );

    // -------------------------------------------------
    // RECALCULATE PARTY BALANCE
    // -------------------------------------------------

    if (rice.party_id) {
      await recalculatePartyBalances(client, rice.party_id);
    }

    await client.query('COMMIT');

    res.json({
      message: 'Rice transaction deleted successfully',
      id: rice.id,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
});

module.exports = router;
