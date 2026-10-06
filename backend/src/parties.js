
const express = require('express');
const { randomUUID } = require('crypto');
const pool = require('./db');

const router = express.Router();

function isValidUuid(value) {
  return typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function normalizeOpeningBalanceType(value) {
  const normalized = String(value || 'You Give').trim();
  if (['You Give', 'You Take', 'You Receive'].includes(normalized)) {
    return normalized === 'You Take' ? 'You Receive' : normalized;
  }
  throw new Error('openingBalanceType must be You Give or You Receive');
}

function parseOpeningBalance(value) {
  const amount = Number(value ?? 0);
  if (!Number.isFinite(amount) || amount < 0) {
    throw new Error('openingBalance must be a non-negative number');
  }
  return amount;
}


// =====================================================
// HELPER — MAP KHATA TRANSACTION
// =====================================================
function mapTransaction(transaction) {
  return {
    id: transaction.id,
    partyId: transaction.party_id,
    date: transaction.date,
    description: transaction.description || '',
    debit: Number(transaction.debit || 0),
    credit: Number(transaction.credit || 0),
    balance: Number(transaction.balance || 0),
    reference: transaction.reference || '',
    createdAt: transaction.created_at,
  };
}

// =====================================================
// HELPER — GET PARTY TRANSACTIONS
// =====================================================
// =====================================================
// HELPER — GET PARTY TRANSACTIONS
// =====================================================
async function getPartyTransactions(partyId) {
  const result = await pool.query(
    `SELECT
      id,
      party_id,
      date,
      description,
      debit,
      credit,
      balance,
      reference,
      created_at
     FROM public.khata_transactions
     WHERE party_id = $1
     ORDER BY date ASC, created_at ASC, id ASC`,
    [partyId],
  );

  return result.rows.map(mapTransaction);
}

// =====================================================
// HELPER — MAP PARTY
// =====================================================
async function mapParty(party) {
  const transactions = await getPartyTransactions(party.id);

  return {
    id: party.id,
    name: party.name,
    phone: party.phone || '',
    address: party.address || '',
    partyType: party.party_type,
    openingBalance: Number(party.opening_balance || 0),
    openingBalanceType: party.opening_balance_type,
    isActive: party.is_active,
    createdAt: party.created_at,
    transactions,
  };
}


async function recalculatePartyBalances(client, partyId) {
  const partyResult = await client.query(
    `SELECT opening_balance, opening_balance_type FROM parties WHERE id = $1 FOR UPDATE`,
    [partyId],
  );

  if (partyResult.rowCount === 0) return;

  const party = partyResult.rows[0];
  let runningBalance = Number(party.opening_balance || 0);
  if (['You Receive', 'You Take', 'credit'].includes(party.opening_balance_type)) {
    runningBalance = -runningBalance;
  }

  const transactions = await client.query(
    `
    SELECT id, debit, credit
    FROM khata_transactions
    WHERE party_id = $1
    ORDER BY date ASC, created_at ASC, id ASC
    FOR UPDATE
    `,
    [partyId],
  );

  for (const transaction of transactions.rows) {
    runningBalance += Number(transaction.debit || 0) - Number(transaction.credit || 0);
    await client.query(
      `UPDATE khata_transactions SET balance = $1, updated_at = NOW() WHERE id = $2`,
      [runningBalance, transaction.id],
    );
  }
}

// =====================================================
// GET PARTIES LOOKUP (id, name, phone, party_type)
// =====================================================
router.get('/lookup', async (req, res) => {
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

// =====================================================
// GET ALL PARTIES
// =====================================================
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        id,
        name,
        phone,
        address,
        party_type,
        opening_balance,
        opening_balance_type,
        is_active,
        created_at
       FROM parties
       ORDER BY created_at DESC`,
    );

    const parties = await Promise.all(
      result.rows.map((party) => mapParty(party)),
    );

    return res.status(200).json({
      success: true,
      parties,
    });
  } catch (error) {
    console.error('Get parties error:', error);

    return res.status(500).json({
      success: false,
      message: 'Failed to process party request',
    });
  }
});

// =====================================================
// GET SINGLE PARTY
// =====================================================
router.get('/:id', async (req, res) => {
  if (!isValidUuid(req.params.id)) return res.status(400).json({ success: false, message: 'Invalid party ID' });
  try {
    const { id } = req.params;

    const result = await pool.query(
      `SELECT
        id,
        name,
        phone,
        address,
        party_type,
        opening_balance,
        opening_balance_type,
        is_active,
        created_at
       FROM parties
       WHERE id = $1`,
      [id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Party not found',
      });
    }

    const party = await mapParty(result.rows[0]);

    return res.status(200).json({
      success: true,
      party,
    });
  } catch (error) {
    console.error('Get single party error:', error);

    return res.status(500).json({
      success: false,
      message: 'Failed to process party request',
    });
  }
});

// =====================================================
// CREATE PARTY
// =====================================================
router.post('/', async (req, res) => {
  try {
    const {
      name,
      phone,
      address,
      partyType,
      openingBalance,
      openingBalanceType,
      isActive,
      createdAt,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Party name is required',
      });
    }

    let opening;
    let normalizedOpeningType;
    try {
      opening = parseOpeningBalance(openingBalance);
      normalizedOpeningType = normalizeOpeningBalanceType(openingBalanceType);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    const id = randomUUID();

    const result = await pool.query(
      `INSERT INTO parties (
        id,
        name,
        phone,
        address,
        party_type,
        opening_balance,
        opening_balance_type,
        is_active,
        created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, COALESCE($9, NOW()))
      RETURNING
        id,
        name,
        phone,
        address,
        party_type,
        opening_balance,
        opening_balance_type,
        is_active,
        created_at`,
      [
        id,
        name.trim(),
        phone || '',
        address || '',
        partyType || 'customer',
        parseOpeningBalance(openingBalance),
        normalizeOpeningBalanceType(openingBalanceType),
        isActive !== false,
        createdAt || null,
      ],
    );

    const party = await mapParty(result.rows[0]);

    return res.status(201).json({
      success: true,
      message: 'Party created successfully',
      party,
    });
  } catch (error) {
    console.error('Create party error:', error);

    return res.status(500).json({
      success: false,
      message: 'Failed to process party request',
    });
  }
});

// =====================================================
// UPDATE PARTY
// =====================================================
router.put('/:id', async (req, res) => {
  if (!isValidUuid(req.params.id)) return res.status(400).json({ success: false, message: 'Invalid party ID' });
  const client = await pool.connect();

  try {
    const { id } = req.params;
    const {
      name,
      phone,
      address,
      partyType,
      openingBalance,
      openingBalanceType,
      isActive,
    } = req.body;

    if (!name || !String(name).trim()) {
      return res.status(400).json({
        success: false,
        message: 'Party name is required',
      });
    }

    let opening;
    let normalizedOpeningType;
    try {
      opening = parseOpeningBalance(openingBalance);
      normalizedOpeningType = normalizeOpeningBalanceType(openingBalanceType);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    await client.query('BEGIN');

    const result = await client.query(
      `
      UPDATE parties
      SET
        name = $1,
        phone = $2,
        address = $3,
        party_type = $4,
        opening_balance = $5,
        opening_balance_type = $6,
        is_active = $7,
        updated_at = NOW()
      WHERE id = $8
      RETURNING id, name, phone, address, party_type, opening_balance,
                opening_balance_type, is_active, created_at
      `,
      [
        String(name).trim(),
        phone || '',
        address || '',
        partyType || 'customer',
        opening,
        normalizedOpeningType,
        isActive !== false,
        id,
      ],
    );

    if (result.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        message: 'Party not found',
      });
    }

    await recalculatePartyBalances(client, id);

    const partyResult = await client.query(
      `
      SELECT id, name, phone, address, party_type, opening_balance,
             opening_balance_type, is_active, created_at
      FROM parties
      WHERE id = $1
      `,
      [id],
    );

    await client.query('COMMIT');

    const party = await mapParty(partyResult.rows[0]);

    return res.status(200).json({
      success: true,
      message: 'Party updated successfully',
      party,
    });
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    console.error('Update party error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update party',
    });
  } finally {
    client.release();
  }
});

// =====================================================
// DELETE PARTY
// =====================================================
router.delete('/:id', async (req, res) => {
  if (!isValidUuid(req.params.id)) return res.status(400).json({ success: false, message: 'Invalid party ID' });
  try {
    const { id } = req.params;

    const result = await pool.query(
      `DELETE FROM parties
       WHERE id = $1
       RETURNING id`,
      [id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Party not found',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Party deleted successfully',
    });
  } catch (error) {
    console.error('Delete party error:', error);

    return res.status(500).json({
      success: false,
      message: 'Failed to process party request',
    });
  }
});

module.exports = router;