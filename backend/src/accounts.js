
const express = require('express');
const router = express.Router();
const pool = require('./db');

const ALLOWED_ACCOUNT_TYPES = [
    'cash',
    'bank',
    'wallet',
    'other',
];

const ALLOWED_TRANSACTION_TYPES = [
    'Income',
    'Expense',
];

function isValidUuid(value) {
    return (
        typeof value === 'string' &&
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    );
}

function parseAmount(value, fieldName = 'amount', allowZero = true) {
    if (value === undefined || value === null || value === '') {
        throw new Error(`${fieldName} is required`);
    }

    const amount = Number(value);

    if (!Number.isFinite(amount)) {
        throw new Error(`${fieldName} must be a valid number`);
    }

    if (allowZero ? amount < 0 : amount <= 0) {
        throw new Error(
            allowZero
                ? `${fieldName} cannot be negative`
                : `${fieldName} must be greater than 0`
        );
    }

    return amount;
}

function normalizeAccountType(value) {
    if (!value) {
        return 'cash';
    }

    const type = String(value).trim().toLowerCase();

    if (!ALLOWED_ACCOUNT_TYPES.includes(type)) {
        throw new Error(
            `accountType must be one of: ${ALLOWED_ACCOUNT_TYPES.join(', ')}`
        );
    }

    return type;
}

function normalizeTransactionType(value) {
    if (!value) {
        throw new Error('type is required');
    }

    const valueString = String(value).trim().toLowerCase();

    if (valueString === 'income') {
        return 'Income';
    }

    if (valueString === 'expense') {
        return 'Expense';
    }

    throw new Error(
        `type must be one of: ${ALLOWED_TRANSACTION_TYPES.join(', ')}`
    );
}

function mapAccount(row) {
    return {
        id: row.id,
        name: row.name,
        accountType: row.account_type,
        openingBalance: Number(row.opening_balance),
        currentBalance: Number(row.current_balance),
        description: row.description,
        isActive: row.is_active,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
    };
}

function mapTransaction(row) {
    return {
        id: row.id,
        accountId: row.account_id,
        date: row.date,
        type: row.type,
        amount: Number(row.amount),
        category: row.category,
        description: row.description,
        source: row.source,
        reference: row.reference,
        createdAt: row.created_at,
    };
}

async function calculateCurrentBalance(client, accountId) {
    const result = await client.query(
        `
        SELECT
            a.opening_balance,
            COALESCE(
                SUM(
                    CASE
                        WHEN LOWER(t.type) = 'income'
                            THEN t.amount
                        WHEN LOWER(t.type) = 'expense'
                            THEN -t.amount
                        ELSE 0
                    END
                ),
                0
            ) AS movement_balance
        FROM accounts a
        LEFT JOIN account_transactions t
            ON t.account_id = a.id
        WHERE a.id = $1
        GROUP BY a.id, a.opening_balance
        `,
        [accountId]
    );

    if (result.rows.length === 0) {
        throw new Error('Account not found');
    }

    const openingBalance = Number(result.rows[0].opening_balance);
    const movementBalance = Number(result.rows[0].movement_balance);

    const currentBalance = openingBalance + movementBalance;

    await client.query(
        `
        UPDATE accounts
        SET
            current_balance = $1,
            updated_at = NOW()
        WHERE id = $2
        `,
        [currentBalance, accountId]
    );

    return currentBalance;
}

// ============================================================
// GET ALL ACCOUNTS
// ============================================================

router.get('/', async (req, res) => {
    try {
        const result = await pool.query(
            `
            SELECT *
            FROM accounts
            ORDER BY is_active DESC, name ASC
            `
        );

        res.json({
            success: true,
            count: result.rows.length,
            accounts: result.rows.map(mapAccount),
        });
    } catch (error) {
        console.error('GET /api/accounts error:', error);

        res.status(500).json({
            success: false,
            message: 'Failed to fetch accounts',
        });
    }
});

// ============================================================
// ACCOUNT SUMMARY
// IMPORTANT: This route MUST be before /:id
// ============================================================

router.get('/summary', async (req, res) => {
    try {
        const result = await pool.query(
            `
            SELECT
                COUNT(*)::int AS account_count,
                COALESCE(SUM(opening_balance), 0) AS opening_balance,
                COALESCE(SUM(current_balance), 0) AS current_balance
            FROM accounts
            WHERE is_active = TRUE
            `
        );

        const transactionResult = await pool.query(
            `
            SELECT
                COALESCE(
                    SUM(
                        CASE
                            WHEN LOWER(type) = 'income'
                                THEN amount
                            ELSE 0
                        END
                    ),
                    0
                ) AS total_income,

                COALESCE(
                    SUM(
                        CASE
                            WHEN LOWER(type) = 'expense'
                                THEN amount
                            ELSE 0
                        END
                    ),
                    0
                ) AS total_expense
            FROM account_transactions
            WHERE account_id IN (
                SELECT id
                FROM accounts
                WHERE is_active = TRUE
            )
            `
        );

        const row = result.rows[0];
        const transactionRow = transactionResult.rows[0];

        const totalIncome = Number(transactionRow.total_income);
        const totalExpense = Number(transactionRow.total_expense);

        res.json({
            success: true,
            summary: {
                accountCount: Number(row.account_count),
                openingBalance: Number(row.opening_balance),
                currentBalance: Number(row.current_balance),
                totalIncome,
                totalExpense,
                netTransactionBalance: totalIncome - totalExpense,
            },
        });
    } catch (error) {
        console.error('GET /api/accounts/summary error:', error);

        res.status(500).json({
            success: false,
            message: 'Failed to calculate account summary',
        });
    }
});

// ============================================================
// GET SINGLE ACCOUNT + TRANSACTIONS
// ============================================================

router.get('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid account ID',
        });
    }

    try {
        const accountResult = await pool.query(
            `
            SELECT *
            FROM accounts
            WHERE id = $1
            `,
            [id]
        );

        if (accountResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Account not found',
            });
        }

        const transactionResult = await pool.query(
            `
            SELECT *
            FROM account_transactions
            WHERE account_id = $1
            ORDER BY date DESC, created_at DESC
            `,
            [id]
        );

        res.json({
            success: true,
            account: mapAccount(accountResult.rows[0]),
            transactions: transactionResult.rows.map(mapTransaction),
        });
    } catch (error) {
        console.error('GET /api/accounts/:id error:', error);

        res.status(500).json({
            success: false,
            message: 'Failed to fetch account',
        });
    }
});

// ============================================================
// CREATE ACCOUNT
// ============================================================

router.post('/', async (req, res) => {
    try {
        const {
            name,
            accountType,
            openingBalance,
            description,
            isActive,
        } = req.body;

        if (!name || !String(name).trim()) {
            return res.status(400).json({
                success: false,
                message: 'name is required',
            });
        }

        const type = normalizeAccountType(accountType);

        const opening = parseAmount(
            openingBalance === undefined ? 0 : openingBalance,
            'openingBalance'
        );

        const result = await pool.query(
            `
            INSERT INTO accounts
            (
                name,
                account_type,
                opening_balance,
                current_balance,
                description,
                is_active
            )
            VALUES ($1, $2, $3, $3, $4, $5)
            RETURNING *
            `,
            [
                String(name).trim(),
                type,
                opening,
                description || null,
                isActive !== undefined ? Boolean(isActive) : true,
            ]
        );

        res.status(201).json({
            success: true,
            message: 'Account created successfully',
            account: mapAccount(result.rows[0]),
        });
    } catch (error) {
        console.error('POST /api/accounts error:', error);

        if (
            error.message &&
            (
                error.message.includes('required') ||
                error.message.includes('must be') ||
                error.message.includes('cannot be') ||
                error.message.includes('one of:')
            )
        ) {
            return res.status(400).json({
                success: false,
                message: error.message,
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to create account',
        });
    }
});

// ============================================================
// UPDATE ACCOUNT
// ============================================================

router.put('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid account ID',
        });
    }

    try {
        const {
            name,
            accountType,
            openingBalance,
            description,
            isActive,
        } = req.body;

        const existing = await pool.query(
            `
            SELECT *
            FROM accounts
            WHERE id = $1
            `,
            [id]
        );

        if (existing.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Account not found',
            });
        }

        const old = existing.rows[0];

        const newName =
            name !== undefined
                ? String(name).trim()
                : old.name;

        if (!newName) {
            return res.status(400).json({
                success: false,
                message: 'name cannot be empty',
            });
        }

        const newType =
            accountType !== undefined
                ? normalizeAccountType(accountType)
                : old.account_type;

        const newOpening =
            openingBalance !== undefined
                ? parseAmount(openingBalance, 'openingBalance')
                : Number(old.opening_balance);

        const newDescription =
            description !== undefined
                ? description
                : old.description;

        const newIsActive =
            isActive !== undefined
                ? Boolean(isActive)
                : old.is_active;

        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            await client.query(
                `
                UPDATE accounts
                SET
                    name = $1,
                    account_type = $2,
                    opening_balance = $3,
                    description = $4,
                    is_active = $5,
                    updated_at = NOW()
                WHERE id = $6
                `,
                [
                    newName,
                    newType,
                    newOpening,
                    newDescription || null,
                    newIsActive,
                    id,
                ]
            );

            await calculateCurrentBalance(client, id);

            const result = await client.query(
                `
                SELECT *
                FROM accounts
                WHERE id = $1
                `,
                [id]
            );

            await client.query('COMMIT');

            res.json({
                success: true,
                message: 'Account updated successfully',
                account: mapAccount(result.rows[0]),
            });
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    } catch (error) {
        console.error('PUT /api/accounts/:id error:', error);

        if (
            error.message &&
            (
                error.message.includes('required') ||
                error.message.includes('must be') ||
                error.message.includes('cannot be') ||
                error.message.includes('one of:')
            )
        ) {
            return res.status(400).json({
                success: false,
                message: error.message,
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to update account',
        });
    }
});

// ============================================================
// DELETE ACCOUNT
// ============================================================

router.delete('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid account ID',
        });
    }

    try {
        const result = await pool.query(
            `
            DELETE FROM accounts
            WHERE id = $1
            RETURNING id
            `,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Account not found',
            });
        }

        res.json({
            success: true,
            message: 'Account deleted successfully',
            id: result.rows[0].id,
        });
    } catch (error) {
        console.error('DELETE /api/accounts/:id error:', error);

        res.status(500).json({
            success: false,
            message: 'Failed to delete account',
        });
    }
});

// ============================================================
// GET ACCOUNT TRANSACTIONS
// ============================================================

router.get('/:id/transactions', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid account ID',
        });
    }

    try {
        const accountResult = await pool.query(
            `
            SELECT id
            FROM accounts
            WHERE id = $1
            `,
            [id]
        );

        if (accountResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Account not found',
            });
        }

        const result = await pool.query(
            `
            SELECT *
            FROM account_transactions
            WHERE account_id = $1
            ORDER BY date DESC, created_at DESC
            `,
            [id]
        );

        res.json({
            success: true,
            count: result.rows.length,
            transactions: result.rows.map(mapTransaction),
        });
    } catch (error) {
        console.error(
            'GET /api/accounts/:id/transactions error:',
            error
        );

        res.status(500).json({
            success: false,
            message: 'Failed to fetch account transactions',
        });
    }
});

// ============================================================
// ADD ACCOUNT TRANSACTION
// ============================================================

router.post('/:id/transactions', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid account ID',
        });
    }

    const client = await pool.connect();

    try {
        const {
            date,
            type,
            amount,
            category,
            description,
            note,
            source,
            reference,
        } = req.body;

        const normalizedType = normalizeTransactionType(type);

        const transactionAmount = parseAmount(
            amount,
            'amount',
            false
        );

        await client.query('BEGIN');

        const accountResult = await client.query(
            `
            SELECT id
            FROM accounts
            WHERE id = $1
            FOR UPDATE
            `,
            [id]
        );

        if (accountResult.rows.length === 0) {
            await client.query('ROLLBACK');

            return res.status(404).json({
                success: false,
                message: 'Account not found',
            });
        }

        const transactionResult = await client.query(
            `
            INSERT INTO account_transactions
            (
                account_id,
                date,
                type,
                amount,
                category,
                description,
                source,
                reference
            )
            VALUES
            (
                $1,
                COALESCE($2, NOW()),
                $3,
                $4,
                $5,
                $6,
                $7,
                $8
            )
            RETURNING *
            `,
            [
                id,
                date || null,
                normalizedType,
                transactionAmount,
                category || null,
                description !== undefined
                    ? description
                    : note || null,
                source || null,
                reference || null,
            ]
        );

        const currentBalance = await calculateCurrentBalance(
            client,
            id
        );

        await client.query('COMMIT');

        res.status(201).json({
            success: true,
            message: 'Account transaction created successfully',
            transaction: mapTransaction(
                transactionResult.rows[0]
            ),
            currentBalance,
        });
    } catch (error) {
        await client.query('ROLLBACK');

        console.error(
            'POST /api/accounts/:id/transactions error:',
            error
        );

        if (
            error.message &&
            (
                error.message.includes('required') ||
                error.message.includes('must be') ||
                error.message.includes('cannot be') ||
                error.message.includes('one of:')
            )
        ) {
            return res.status(400).json({
                success: false,
                message: error.message,
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to create account transaction',
        });
    } finally {
        client.release();
    }
});


// UPDATE ACCOUNT TRANSACTION
router.put('/:id/transactions/:transactionId', async (req, res) => {
    const { id, transactionId } = req.params;

    if (!isValidUuid(id) || !isValidUuid(transactionId)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid account or transaction ID',
        });
    }

    const client = await pool.connect();

    try {
        const {
            date,
            type,
            amount,
            category,
            description,
            note,
            source,
            reference,
        } = req.body;

        const normalizedType = normalizeTransactionType(type);
        const transactionAmount = parseAmount(amount, 'amount', false);

        await client.query('BEGIN');

        const existing = await client.query(
            `
            SELECT id
            FROM account_transactions
            WHERE id = $1 AND account_id = $2
            FOR UPDATE
            `,
            [transactionId, id],
        );

        if (existing.rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({
                success: false,
                message: 'Account transaction not found',
            });
        }

        const result = await client.query(
            `
            UPDATE account_transactions
            SET
                date = COALESCE($1, date),
                type = $2,
                amount = $3,
                category = $4,
                description = $5,
                source = $6,
                reference = $7
            WHERE id = $8 AND account_id = $9
            RETURNING *
            `,
            [
                date || null,
                normalizedType,
                transactionAmount,
                category || null,
                description !== undefined ? description : note || null,
                source || null,
                reference || null,
                transactionId,
                id,
            ],
        );

        const currentBalance = await calculateCurrentBalance(client, id);
        await client.query('COMMIT');

        res.json({
            success: true,
            message: 'Account transaction updated successfully',
            transaction: mapTransaction(result.rows[0]),
            currentBalance,
        });
    } catch (error) {
        try { await client.query('ROLLBACK'); } catch (_) {}
        console.error('PUT account transaction error:', error.message);
        return res.status(400).json({
            success: false,
            message: error.message.includes('required') ||
                error.message.includes('must be') ||
                error.message.includes('cannot be') ||
                error.message.includes('one of:')
                ? error.message
                : 'Failed to update account transaction',
        });
    } finally {
        client.release();
    }
});

// ============================================================
// DELETE ACCOUNT TRANSACTION
// ============================================================

router.delete('/:id/transactions/:transactionId', async (req, res) => {
    const { id, transactionId } = req.params;

    if (!isValidUuid(id) || !isValidUuid(transactionId)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid account or transaction ID',
        });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const result = await client.query(
            `
            DELETE FROM account_transactions
            WHERE id = $1
              AND account_id = $2
            RETURNING id
            `,
            [transactionId, id]
        );

        if (result.rows.length === 0) {
            await client.query('ROLLBACK');

            return res.status(404).json({
                success: false,
                message: 'Account transaction not found',
            });
        }

        const currentBalance = await calculateCurrentBalance(
            client,
            id
        );

        await client.query('COMMIT');

        res.json({
            success: true,
            message: 'Account transaction deleted successfully',
            id: transactionId,
            currentBalance,
        });
    } catch (error) {
        await client.query('ROLLBACK');

        console.error(
            'DELETE account transaction error:',
            error
        );

        res.status(500).json({
            success: false,
            message: 'Failed to delete account transaction',
        });
    } finally {
        client.release();
    }
});

module.exports = router;
