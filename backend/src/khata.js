const express = require('express');
const { randomUUID } = require('crypto');
const pool = require('./db');

const router = express.Router();

// =====================================================
// HELPERS
// =====================================================

function mapTransaction(transaction) {
  return {
    id: transaction.id,
    partyId: transaction.party_id,
    date: transaction.date,
    description: transaction.description,
    debit: Number(transaction.debit || 0),
    credit: Number(transaction.credit || 0),
    balance: Number(transaction.balance || 0),
    reference: transaction.reference || '',
    createdAt: transaction.created_at,
  };
}

function validateAmounts(debit, credit) {
  const debitAmount = Number(debit || 0);
  const creditAmount = Number(credit || 0);

  if (!Number.isFinite(debitAmount) || !Number.isFinite(creditAmount)) {
    return {
      valid: false,
      message: 'debit and credit must be valid numbers',
    };
  }

  if (debitAmount < 0 || creditAmount < 0) {
    return {
      valid: false,
      message: 'debit and credit cannot be negative',
    };
  }

  if (debitAmount > 0 && creditAmount > 0) {
    return {
      valid: false,
      message: 'A transaction cannot have both debit and credit',
    };
  }

  return {
    valid: true,
    debit: debitAmount,
    credit: creditAmount,
  };
}

// Recalculate all running balances for one party.
//
// Balance formula:
// previous balance + debit - credit
//
// Opening balance is also included when available.
async function recalculatePartyBalances(client, partyId) {
  const partyResult = await client.query(
    `
    SELECT
      opening_balance,
      opening_balance_type
    FROM parties
    WHERE id = $1
    `,
    [partyId],
  );

  if (partyResult.rowCount === 0) {
    throw new Error('Party not found');
  }

  const openingBalance = Number(
    partyResult.rows[0].opening_balance || 0,
  );

  const openingBalanceType =
    partyResult.rows[0].opening_balance_type || 'You Give';

  // Financial sign:
  //
  // You Give    => positive opening balance
  // You Receive => negative opening balance
  //
  // This matches:
  // debit  = money/value given by user
  // credit = money/value received by user
  let runningBalance =
    openingBalanceType === 'You Receive'
      ? -openingBalance
      : openingBalance;

  const transactionsResult = await client.query(
    `
    SELECT
      id,
      debit,
      credit
    FROM khata_transactions
    WHERE party_id = $1
    ORDER BY date ASC, created_at ASC, id ASC
    FOR UPDATE
    `,
    [partyId],
  );

  for (const transaction of transactionsResult.rows) {
    const debit = Number(transaction.debit || 0);
    const credit = Number(transaction.credit || 0);

    runningBalance = runningBalance + debit - credit;

    await client.query(
      `
      UPDATE khata_transactions
      SET balance = $1
      WHERE id = $2
      `,
      [runningBalance, transaction.id],
    );
  }

  return runningBalance;
}

// =====================================================
// GET ALL KHATA TRANSACTIONS
// =====================================================

router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        id,
        party_id,
        date,
        description,
        debit,
        credit,
        balance,
        reference,
        created_at
      FROM khata_transactions
      ORDER BY date DESC, created_at DESC
    `);

    return res.status(200).json({
      success: true,
      transactions: result.rows.map(mapTransaction),
    });
  } catch (error) {
    console.error('Get khata transactions error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// =====================================================
// GET KHATA BY PARTY
// =====================================================

router.get('/party/:partyId', async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        id,
        party_id,
        date,
        description,
        debit,
        credit,
        balance,
        reference,
        created_at
      FROM khata_transactions
      WHERE party_id = $1
      ORDER BY date DESC, created_at DESC
      `,
      [req.params.partyId],
    );

    return res.status(200).json({
      success: true,
      transactions: result.rows.map(mapTransaction),
    });
  } catch (error) {
    console.error('Get party khata error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// =====================================================
// POST KHATA TRANSACTION
// =====================================================

router.post('/', async (req, res) => {
  const client = await pool.connect();

  try {
    const {
      id,
      partyId,
      date,
      description,
      debit,
      credit,
      reference,
    } = req.body;

    if (!partyId) {
      return res.status(400).json({
        success: false,
        message: 'partyId is required',
      });
    }

    const amountValidation = validateAmounts(debit, credit);

    if (!amountValidation.valid) {
      return res.status(400).json({
        success: false,
        message: amountValidation.message,
      });
    }

    await client.query('BEGIN');

    // Verify party exists.
    const party = await client.query(
      `
      SELECT id
      FROM parties
      WHERE id = $1
      FOR UPDATE
      `,
      [partyId],
    );

    if (party.rowCount === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        success: false,
        message: 'Party not found',
      });
    }

    // IMPORTANT:
    // balance from the request is intentionally NOT used.
    const result = await client.query(
      `
      INSERT INTO khata_transactions (
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
        $1,
        $2,
        COALESCE($3, NOW()),
        COALESCE($4, ''),
        $5,
        $6,
        0,
        $7,
        NOW()
      )
      RETURNING
        id,
        party_id,
        date,
        description,
        debit,
        credit,
        balance,
        reference,
        created_at
      `,
      [
        id || randomUUID(),
        partyId,
        date || null,
        description,
        amountValidation.debit,
        amountValidation.credit,
        reference || null,
      ],
    );

    // Recalculate all balances for this party.
    await recalculatePartyBalances(client, partyId);

    // Read the newly inserted transaction again
    // so response contains the calculated balance.
    const updatedResult = await client.query(
      `
      SELECT
        id,
        party_id,
        date,
        description,
        debit,
        credit,
        balance,
        reference,
        created_at
      FROM khata_transactions
      WHERE id = $1
      `,
      [result.rows[0].id],
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      transaction: mapTransaction(updatedResult.rows[0]),
    });
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}

    console.error('Create khata transaction error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  } finally {
    client.release();
  }
});

// =====================================================
// PUT KHATA TRANSACTION
// =====================================================

router.put('/:id', async (req, res) => {
  const client = await pool.connect();

  try {
    const {
      partyId,
      date,
      description,
      debit,
      credit,
      reference,
    } = req.body;

    if (!partyId) {
      return res.status(400).json({
        success: false,
        message: 'partyId is required',
      });
    }

    const amountValidation = validateAmounts(debit, credit);

    if (!amountValidation.valid) {
      return res.status(400).json({
        success: false,
        message: amountValidation.message,
      });
    }

    await client.query('BEGIN');

    // Get existing transaction first.
    const existingResult = await client.query(
      `
      SELECT
        id,
        party_id
      FROM khata_transactions
      WHERE id = $1
      FOR UPDATE
      `,
      [req.params.id],
    );

    if (existingResult.rowCount === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        success: false,
        message: 'Khata transaction not found',
      });
    }

    const oldPartyId = existingResult.rows[0].party_id;

    // Verify new party exists.
    const partyResult = await client.query(
      `
      SELECT id
      FROM parties
      WHERE id = $1
      FOR UPDATE
      `,
      [partyId],
    );

    if (partyResult.rowCount === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        success: false,
        message: 'Party not found',
      });
    }

    // IMPORTANT:
    // balance from request is intentionally ignored.
    await client.query(
      `
      UPDATE khata_transactions
      SET
        party_id = $1,
        date = COALESCE($2, date),
        description = COALESCE($3, description),
        debit = $4,
        credit = $5,
        reference = $6
      WHERE id = $7
      `,
      [
        partyId,
        date || null,
        description,
        amountValidation.debit,
        amountValidation.credit,
        reference || null,
        req.params.id,
      ],
    );

    // If party changed, old party must also be recalculated.
    if (oldPartyId !== partyId) {
      await recalculatePartyBalances(client, oldPartyId);
    }

    // Recalculate new party.
    await recalculatePartyBalances(client, partyId);

    const result = await client.query(
      `
      SELECT
        id,
        party_id,
        date,
        description,
        debit,
        credit,
        balance,
        reference,
        created_at
      FROM khata_transactions
      WHERE id = $1
      `,
      [req.params.id],
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      transaction: mapTransaction(result.rows[0]),
    });
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}

    console.error('Update khata transaction error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  } finally {
    client.release();
  }
});

// =====================================================
// DELETE KHATA TRANSACTION
// =====================================================

router.delete('/:id', async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const existingResult = await client.query(
      `
      SELECT
        id,
        party_id
      FROM khata_transactions
      WHERE id = $1
      FOR UPDATE
      `,
      [req.params.id],
    );

    if (existingResult.rowCount === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        success: false,
        message: 'Khata transaction not found',
      });
    }

    const partyId = existingResult.rows[0].party_id;

    const deleteResult = await client.query(
      `
      DELETE FROM khata_transactions
      WHERE id = $1
      RETURNING id
      `,
      [req.params.id],
    );

    // Recalculate remaining transactions after deletion.
    await recalculatePartyBalances(client, partyId);

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      message: 'Khata transaction deleted successfully',
      id: deleteResult.rows[0].id,
    });
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}

    console.error('Delete khata transaction error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  } finally {
    client.release();
  }
});

module.exports = router;