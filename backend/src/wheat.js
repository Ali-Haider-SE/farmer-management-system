const express = require('express');
const pool = require('./db');

const router = express.Router();

// =====================================================
// HELPERS
// =====================================================

// Recalculate all Khata balances for one party.
// Financial rule:
//   You Give    => positive opening balance
//   You Receive => negative opening balance
//
// Transaction balance:
//   previous balance + debit - credit
// =====================================================
async function recalculatePartyBalances(client, partyId) {
  const partyResult = await client.query(
    `
    SELECT
      opening_balance,
      opening_balance_type
    FROM parties
    WHERE id = $1
    FOR UPDATE
    `,
    [partyId],
  );

  if (partyResult.rows.length === 0) {
    return;
  }

  const party = partyResult.rows[0];

  let runningBalance = Number(party.opening_balance || 0);

  if (party.opening_balance_type === 'You Receive') {
    runningBalance = -runningBalance;
  }

  const transactionsResult = await client.query(
    `
    SELECT
      id,
      debit,
      credit
    FROM public.khata_transactions
    WHERE party_id = $1
    ORDER BY date ASC, created_at ASC, id ASC
    FOR UPDATE
    `,
    [partyId],
  );

  for (const transaction of transactionsResult.rows) {
    const debit = Number(transaction.debit || 0);
    const credit = Number(transaction.credit || 0);

    runningBalance += debit - credit;

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
// CREATE / UPDATE KHATA ENTRY FOR WHEAT
// =====================================================
async function syncWheatKhata(client, wheat) {
  if (!wheat.party_id) {
    return;
  }

  const transactionType = String(wheat.transaction_type || '')
    .trim()
    .toLowerCase();

  let debit = 0;
  let credit = 0;
  let description = 'Wheat Transaction';

  if (transactionType === 'sale') {
    debit = Number(wheat.total_amount || 0);
    credit = 0;
    description = 'Wheat Sale';
  } else if (transactionType === 'purchase') {
    debit = 0;
    credit = Number(wheat.total_amount || 0);
    description = 'Wheat Purchase';
  } else {
    throw new Error(
      `Unsupported wheat transaction type: ${wheat.transaction_type}`,
    );
  }

  const reference = `wheat:${wheat.id}`;

  // Check existing Khata entry.
  const existingResult = await client.query(
    `
    SELECT id
    FROM public.khata_transactions
    WHERE party_id = $1
      AND reference = $2
    FOR UPDATE
    `,
    [wheat.party_id, reference],
  );

  if (existingResult.rows.length > 0) {
    // Update existing entry instead of creating duplicate.
    await client.query(
      `
      UPDATE public.khata_transactions
      SET
        date = $1,
        description = $2,
        debit = $3,
        credit = $4
      WHERE id = $5
      `,
      [
        wheat.date,
        description,
        debit,
        credit,
        existingResult.rows[0].id,
      ],
    );
  } else {
    // Create new Khata entry.
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
        reference,
        created_at
      )
      VALUES (
        gen_random_uuid(),
        $1,
        $2,
        $3,
        $4,
        $5,
        0,
        $6,
        NOW()
      )
      `,
      [
        wheat.party_id,
        wheat.date,
        description,
        debit,
        credit,
        reference,
      ],
    );
  }

  await recalculatePartyBalances(client, wheat.party_id);
}

// =====================================================
// GET ALL WHEAT TRANSACTIONS
// GET /api/wheat
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
      FROM wheat_transactions
      ORDER BY date DESC, created_at DESC
    `);

    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

// =====================================================
// GET SINGLE WHEAT TRANSACTION
// GET /api/wheat/:id
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
      FROM wheat_transactions
      WHERE id = $1
      `,
      [req.params.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: 'Wheat transaction not found',
      });
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

// =====================================================
// CREATE WHEAT TRANSACTION
// POST /api/wheat
// =====================================================
router.post('/', async (req, res, next) => {
  const client = await pool.connect();

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

    await client.query('BEGIN');

    // -------------------------------------------------
    // If party is supplied, make sure it exists.
    // Locking the party prevents balance race conditions.
    // -------------------------------------------------
    if (party_id) {
      const partyResult = await client.query(
        `
        SELECT id
        FROM parties
        WHERE id = $1
        FOR UPDATE
        `,
        [party_id],
      );

      if (partyResult.rows.length === 0) {
        await client.query('ROLLBACK');

        return res.status(404).json({
          message: 'Party not found',
        });
      }
    }

    // -------------------------------------------------
    // Create Wheat transaction
    // -------------------------------------------------
    const result = await client.query(
      `
      INSERT INTO wheat_transactions (
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
        $1, $2, $3, $4, $5, $6,
        $7, $8, $9, $10, $11, $12
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
        farmer_id,
        party_id,
        date,
        quantity,
        rate,
        total_amount,
        transaction_type,
        paid_amount ?? 0,
        received_amount ?? 0,
        remaining_amount ?? 0,
        variety ?? null,
        notes ?? null,
      ],
    );

    const wheat = result.rows[0];

    // -------------------------------------------------
    // Sync Wheat -> Party -> Khata
    // -------------------------------------------------
    if (wheat.party_id) {
      await syncWheatKhata(client, wheat);
    }

    await client.query('COMMIT');

    // Keep original API response unchanged.
    res.status(201).json(wheat);
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      // Ignore rollback error.
    }

    next(error);
  } finally {
    client.release();
  }
});

// =====================================================
// UPDATE WHEAT TRANSACTION
// PUT /api/wheat/:id
// =====================================================
router.put('/:id', async (req, res, next) => {
  const client = await pool.connect();

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

    await client.query('BEGIN');

    // -------------------------------------------------
    // Get old Wheat transaction.
    // Lock it so another update cannot race with this one.
    // -------------------------------------------------
    const oldResult = await client.query(
      `
      SELECT
        id,
        party_id
      FROM wheat_transactions
      WHERE id = $1
      FOR UPDATE
      `,
      [req.params.id],
    );

    if (oldResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        message: 'Wheat transaction not found',
      });
    }

    const oldWheat = oldResult.rows[0];

    // -------------------------------------------------
    // Validate new party if supplied.
    // -------------------------------------------------
    if (party_id) {
      const partyResult = await client.query(
        `
        SELECT id
        FROM parties
        WHERE id = $1
        FOR UPDATE
        `,
        [party_id],
      );

      if (partyResult.rows.length === 0) {
        await client.query('ROLLBACK');

        return res.status(404).json({
          message: 'Party not found',
        });
      }
    }

    // -------------------------------------------------
    // If party changed, remove old Khata entry first.
    // -------------------------------------------------
    if (oldWheat.party_id && oldWheat.party_id !== party_id) {
      const oldReference = `wheat:${oldWheat.id}`;

      await client.query(
        `
        DELETE FROM public.khata_transactions
        WHERE party_id = $1
          AND reference = $2
        `,
        [oldWheat.party_id, oldReference],
      );

      await recalculatePartyBalances(client, oldWheat.party_id);
    }

    // -------------------------------------------------
    // Update Wheat transaction
    // -------------------------------------------------
    const result = await client.query(
      `
      UPDATE wheat_transactions
      SET
        farmer_id = $1,
        party_id = $2,
        date = $3,
        quantity = $4,
        rate = $5,
        total_amount = $6,
        transaction_type = $7,
        paid_amount = $8,
        received_amount = $9,
        remaining_amount = $10,
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
        farmer_id,
        party_id,
        date,
        quantity,
        rate,
        total_amount,
        transaction_type,
        paid_amount ?? 0,
        received_amount ?? 0,
        remaining_amount ?? 0,
        variety ?? null,
        notes ?? null,
        req.params.id,
      ],
    );

    const wheat = result.rows[0];

    // -------------------------------------------------
    // Sync updated Wheat -> Khata
    // -------------------------------------------------
    if (wheat.party_id) {
      await syncWheatKhata(client, wheat);
    }

    await client.query('COMMIT');

    // Keep original API response unchanged.
    res.json(wheat);
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      // Ignore rollback error.
    }

    next(error);
  } finally {
    client.release();
  }
});

// =====================================================
// DELETE WHEAT TRANSACTION
// DELETE /api/wheat/:id
// =====================================================
router.delete('/:id', async (req, res, next) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // -------------------------------------------------
    // Get Wheat transaction first.
    // -------------------------------------------------
    const wheatResult = await client.query(
      `
      SELECT
        id,
        party_id
      FROM wheat_transactions
      WHERE id = $1
      FOR UPDATE
      `,
      [req.params.id],
    );

    if (wheatResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        message: 'Wheat transaction not found',
      });
    }

    const wheat = wheatResult.rows[0];

    // -------------------------------------------------
    // Delete corresponding Khata transaction.
    // -------------------------------------------------
    if (wheat.party_id) {
      const reference = `wheat:${wheat.id}`;

      await client.query(
        `
        DELETE FROM public.khata_transactions
        WHERE party_id = $1
          AND reference = $2
        `,
        [wheat.party_id, reference],
      );

      await recalculatePartyBalances(client, wheat.party_id);
    }

    // -------------------------------------------------
    // Delete Wheat transaction.
    // -------------------------------------------------
    const result = await client.query(
      `
      DELETE FROM wheat_transactions
      WHERE id = $1
      RETURNING id
      `,
      [req.params.id],
    );

    await client.query('COMMIT');

    res.json({
      message: 'Wheat transaction deleted successfully',
      id: result.rows[0].id,
    });
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      // Ignore rollback error.
    }

    next(error);
  } finally {
    client.release();
  }
});

module.exports = router;