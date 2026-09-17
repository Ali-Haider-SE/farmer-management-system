const express = require('express');
const router = express.Router();
const pool = require('./db');

const ALLOWED_MOVEMENT_TYPES = ['IN', 'OUT', 'ADJUSTMENT'];

function isValidUuid(value) {
    return typeof value === 'string' &&
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function parseNumber(value, fieldName, options = {}) {
    if (value === undefined || value === null || value === '') {
        if (options.optional) return undefined;
        throw new Error(`${fieldName} is required`);
    }

    const number = Number(value);

    if (!Number.isFinite(number)) {
        throw new Error(`${fieldName} must be a valid number`);
    }

    if (options.min !== undefined && number < options.min) {
        throw new Error(`${fieldName} must be at least ${options.min}`);
    }

    if (options.positive && number <= 0) {
        throw new Error(`${fieldName} must be greater than 0`);
    }

    return number;
}

function normalizeMovementType(value) {
    if (!value) return 'IN';

    const type = String(value).trim().toUpperCase();

    if (!ALLOWED_MOVEMENT_TYPES.includes(type)) {
        throw new Error(
            `movementType must be one of: ${ALLOWED_MOVEMENT_TYPES.join(', ')}`
        );
    }

    return type;
}

function mapStock(row) {
    return {
        id: row.id,
        productName: row.product_name,
        productType: row.product_type,
        quantity: Number(row.quantity),
        unit: row.unit,
        averageRate: Number(row.average_rate),
        totalValue: Number(row.total_value),
        warehouse: row.warehouse,
        isActive: row.is_active,
        createdAt: row.created_at,
        updatedAt: row.updated_at
    };
}

function mapMovement(row) {
    return {
        id: row.id,
        stockId: row.stock_id,
        date: row.date,
        movementType: row.movement_type,
        quantity: Number(row.quantity),
        rate: Number(row.rate),
        amount: Number(row.amount),
        source: row.source,
        reference: row.reference,
        notes: row.notes,
        createdAt: row.created_at
    };
}

// GET ALL STOCK
router.get('/', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT *
            FROM stock
            ORDER BY product_name ASC, created_at DESC
        `);

        res.json({
            success: true,
            count: result.rows.length,
            stock: result.rows.map(mapStock)
        });
    } catch (error) {
        console.error('GET /api/stock error:', error);

        res.status(500).json({
            success: false,
            message: 'Failed to fetch stock'
        });
    }
});

// GET SINGLE STOCK + MOVEMENTS
router.get('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid stock ID'
        });
    }

    try {
        const stockResult = await pool.query(
            `SELECT * FROM stock WHERE id = $1`,
            [id]
        );

        if (stockResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Stock not found'
            });
        }

        const movementResult = await pool.query(
            `
            SELECT *
            FROM stock_movements
            WHERE stock_id = $1
            ORDER BY date DESC, created_at DESC
            `,
            [id]
        );

        res.json({
            success: true,
            stock: mapStock(stockResult.rows[0]),
            movements: movementResult.rows.map(mapMovement)
        });
    } catch (error) {
        console.error('GET /api/stock/:id error:', error);

        res.status(500).json({
            success: false,
            message: 'Failed to fetch stock'
        });
    }
});

// CREATE STOCK OR ADD MOVEMENT
router.post('/', async (req, res) => {
    const client = await pool.connect();

    try {
        const {
            stockId,
            productName,
            productType,
            quantity,
            unit,
            averageRate,
            warehouse,
            isActive,
            movementType,
            date,
            rate,
            source,
            reference,
            notes
        } = req.body;

        const type = normalizeMovementType(movementType);

        /*
         * CASE 1:
         * No stockId = create a new stock item.
         * New item can only start with IN.
         */
        if (!stockId) {
            if (type !== 'IN') {
                return res.status(400).json({
                    success: false,
                    message: 'A new stock item can only use movementType IN'
                });
            }

            if (!productName || !String(productName).trim()) {
                return res.status(400).json({
                    success: false,
                    message: 'productName is required'
                });
            }

            const qty = parseNumber(quantity, 'quantity', { min: 0 });

            const rateValue = parseNumber(
                averageRate !== undefined ? averageRate : rate,
                'averageRate',
                { min: 0 }
            );

            const productUnit = unit || 'kg';

            const totalValue = qty * rateValue;

            await client.query('BEGIN');

            const stockResult = await client.query(
                `
                INSERT INTO stock
                (
                    product_name,
                    product_type,
                    quantity,
                    unit,
                    average_rate,
                    total_value,
                    warehouse,
                    is_active
                )
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
                RETURNING *
                `,
                [
                    String(productName).trim(),
                    productType || null,
                    qty,
                    productUnit,
                    rateValue,
                    totalValue,
                    warehouse || null,
                    isActive !== undefined ? Boolean(isActive) : true
                ]
            );

            const stock = stockResult.rows[0];

            if (qty > 0) {
                await client.query(
                    `
                    INSERT INTO stock_movements
                    (
                        stock_id,
                        date,
                        movement_type,
                        quantity,
                        rate,
                        amount,
                        source,
                        reference,
                        notes
                    )
                    VALUES ($1,$2,'IN',$3,$4,$5,$6,$7,$8)
                    `,
                    [
                        stock.id,
                        date || new Date().toISOString().slice(0, 10),
                        qty,
                        rateValue,
                        totalValue,
                        source || null,
                        reference || null,
                        notes || null
                    ]
                );
            }

            await client.query('COMMIT');

            return res.status(201).json({
                success: true,
                message: 'Stock created successfully',
                stock: mapStock(stock)
            });
        }

        /*
         * CASE 2:
         * Existing stock movement.
         */
        if (!isValidUuid(stockId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid stockId'
            });
        }

        const qty = parseNumber(
            quantity,
            type === 'ADJUSTMENT' ? 'target quantity' : 'quantity',
            { min: 0 }
        );

        if (type !== 'ADJUSTMENT' && qty <= 0) {
            return res.status(400).json({
                success: false,
                message: 'quantity must be greater than 0'
            });
        }

        await client.query('BEGIN');

        const stockResult = await client.query(
            `SELECT * FROM stock WHERE id = $1 FOR UPDATE`,
            [stockId]
        );

        if (stockResult.rows.length === 0) {
            await client.query('ROLLBACK');

            return res.status(404).json({
                success: false,
                message: 'Stock not found'
            });
        }

        const current = stockResult.rows[0];

        const oldQuantity = Number(current.quantity);
        const oldRate = Number(current.average_rate);

        let newQuantity;
        let newRate = oldRate;
        let movementQuantity;
        let movementRate;
        let movementAmount;

        if (type === 'IN') {
            newQuantity = oldQuantity + qty;

            const incomingRate = parseNumber(
                rate !== undefined ? rate : oldRate,
                'rate',
                { min: 0 }
            );

            movementRate = incomingRate;
            movementQuantity = qty;
            movementAmount = qty * incomingRate;

            if (newQuantity > 0) {
                newRate =
                    ((oldQuantity * oldRate) + (qty * incomingRate)) /
                    newQuantity;
            }
        } else if (type === 'OUT') {
            if (qty > oldQuantity) {
                await client.query('ROLLBACK');

                return res.status(400).json({
                    success: false,
                    message: 'Insufficient stock quantity'
                });
            }

            newQuantity = oldQuantity - qty;

            movementRate = oldRate;
            movementQuantity = qty;
            movementAmount = qty * oldRate;
        } else {
            // ADJUSTMENT: quantity means target quantity.
            if (qty === oldQuantity) {
                await client.query('ROLLBACK');

                return res.status(400).json({
                    success: false,
                    message: 'Adjustment does not change quantity'
                });
            }

            newQuantity = qty;

            if (rate !== undefined) {
                newRate = parseNumber(rate, 'rate', { min: 0 });
            }

            movementQuantity = Math.abs(newQuantity - oldQuantity);
            movementRate = newRate;
            movementAmount = movementQuantity * movementRate;
        }

        const newTotalValue = newQuantity * newRate;

        const updatedResult = await client.query(
            `
            UPDATE stock
            SET
                quantity = $1,
                average_rate = $2,
                total_value = $3,
                updated_at = NOW()
            WHERE id = $4
            RETURNING *
            `,
            [
                newQuantity,
                newRate,
                newTotalValue,
                stockId
            ]
        );

        await client.query(
            `
            INSERT INTO stock_movements
            (
                stock_id,
                date,
                movement_type,
                quantity,
                rate,
                amount,
                source,
                reference,
                notes
            )
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
            `,
            [
                stockId,
                date || new Date().toISOString().slice(0, 10),
                type,
                movementQuantity,
                movementRate,
                movementAmount,
                source || null,
                reference || null,
                notes || null
            ]
        );

        await client.query('COMMIT');

        res.status(201).json({
            success: true,
            message: `Stock ${type} movement recorded successfully`,
            stock: mapStock(updatedResult.rows[0])
        });
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (_) {
            // Ignore rollback errors.
        }

        console.error('POST /api/stock error:', error);

        if (
            error.message &&
            (
                error.message.includes('required') ||
                error.message.includes('must be') ||
                error.message.includes('movementType')
            )
        ) {
            return res.status(400).json({
                success: false,
                message: error.message
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to process stock'
        });
    } finally {
        client.release();
    }
});

// UPDATE STOCK
router.put('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid stock ID'
        });
    }

    const client = await pool.connect();

    try {
        const {
            productName,
            productType,
            quantity,
            unit,
            averageRate,
            warehouse,
            isActive,
            source,
            reference,
            notes,
            date
        } = req.body;

        await client.query('BEGIN');

        const existingResult = await client.query(
            `SELECT * FROM stock WHERE id = $1 FOR UPDATE`,
            [id]
        );

        if (existingResult.rows.length === 0) {
            await client.query('ROLLBACK');

            return res.status(404).json({
                success: false,
                message: 'Stock not found'
            });
        }

        const existing = existingResult.rows[0];

        const oldQuantity = Number(existing.quantity);
        const oldRate = Number(existing.average_rate);

        const newProductName =
            productName !== undefined
                ? String(productName).trim()
                : existing.product_name;

        if (!newProductName) {
            await client.query('ROLLBACK');

            return res.status(400).json({
                success: false,
                message: 'productName cannot be empty'
            });
        }

        const newQuantity =
            quantity !== undefined
                ? parseNumber(quantity, 'quantity', { min: 0 })
                : oldQuantity;

        const newRate =
            averageRate !== undefined
                ? parseNumber(averageRate, 'averageRate', { min: 0 })
                : oldRate;

        if (quantity !== undefined && newQuantity !== oldQuantity) {
            const adjustmentQuantity = Math.abs(newQuantity - oldQuantity);

            await client.query(
                `
                INSERT INTO stock_movements
                (
                    stock_id,
                    date,
                    movement_type,
                    quantity,
                    rate,
                    amount,
                    source,
                    reference,
                    notes
                )
                VALUES ($1,$2,'ADJUSTMENT',$3,$4,$5,$6,$7,$8)
                `,
                [
                    id,
                    date || new Date().toISOString().slice(0, 10),
                    adjustmentQuantity,
                    newRate,
                    adjustmentQuantity * newRate,
                    source || 'STOCK_UPDATE',
                    reference || null,
                    notes || null
                ]
            );
        }

        const totalValue = newQuantity * newRate;

        const updatedResult = await client.query(
            `
            UPDATE stock
            SET
                product_name = $1,
                product_type = $2,
                quantity = $3,
                unit = $4,
                average_rate = $5,
                total_value = $6,
                warehouse = $7,
                is_active = $8,
                updated_at = NOW()
            WHERE id = $9
            RETURNING *
            `,
            [
                newProductName,
                productType !== undefined
                    ? productType
                    : existing.product_type,
                newQuantity,
                unit !== undefined ? unit : existing.unit,
                newRate,
                totalValue,
                warehouse !== undefined
                    ? warehouse
                    : existing.warehouse,
                isActive !== undefined
                    ? Boolean(isActive)
                    : existing.is_active,
                id
            ]
        );

        await client.query('COMMIT');

        res.json({
            success: true,
            message: 'Stock updated successfully',
            stock: mapStock(updatedResult.rows[0])
        });
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (_) {
            // Ignore rollback errors.
        }

        console.error('PUT /api/stock/:id error:', error);

        if (
            error.message &&
            (
                error.message.includes('required') ||
                error.message.includes('must be')
            )
        ) {
            return res.status(400).json({
                success: false,
                message: error.message
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to update stock'
        });
    } finally {
        client.release();
    }
});

// DELETE STOCK
router.delete('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isValidUuid(id)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid stock ID'
        });
    }

    try {
        const result = await pool.query(
            `
            DELETE FROM stock
            WHERE id = $1
            RETURNING id
            `,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Stock not found'
            });
        }

        res.json({
            success: true,
            message: 'Stock deleted successfully',
            id: result.rows[0].id
        });
    } catch (error) {
        console.error('DELETE /api/stock/:id error:', error);

        res.status(500).json({
            success: false,
            message: 'Failed to delete stock'
        });
    }
});

module.exports = router;