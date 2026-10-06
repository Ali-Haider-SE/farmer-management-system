
const express = require('express');
const router = express.Router();

function isValidUuid(value) {
  return typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function parseNonNegative(value, fieldName) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) {
    throw new Error(`${fieldName} must be a non-negative number`);
  }
  return number;
}
const pool = require('./db');

router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        f.id,
        f.farmer_id,
        f.farm_name,
        f.location,
        f.area,
        f.area_unit,
        f.crop_type,
        f.is_active,
        f.created_at,
        fr.name AS farmer_name
      FROM farms f
      INNER JOIN farmers fr ON fr.id = f.farmer_id
      ORDER BY f.created_at DESC
    `);

    res.json({
      success: true,
      farms: result.rows.map((farm) => ({
        id: farm.id,
        farmerId: farm.farmer_id,
        farmName: farm.farm_name,
        location: farm.location,
        area: Number(farm.area),
        areaUnit: farm.area_unit,
        cropType: farm.crop_type,
        isActive: farm.is_active,
        createdAt: farm.created_at,
        farmerName: farm.farmer_name,
      })),
    });
  } catch (error) {
    console.error('Get farms error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to load farms',
    });
  }
});

router.get('/:id', async (req, res) => {
  if (!isValidUuid(req.params.id)) return res.status(400).json({ success: false, message: 'Invalid farm ID' });
  try {
    const result = await pool.query(
      `
      SELECT
        f.id,
        f.farmer_id,
        f.farm_name,
        f.location,
        f.area,
        f.area_unit,
        f.crop_type,
        f.is_active,
        f.created_at,
        fr.name AS farmer_name
      FROM farms f
      INNER JOIN farmers fr ON fr.id = f.farmer_id
      WHERE f.id = $1
      `,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Farm not found',
      });
    }

    const farm = result.rows[0];

    res.json({
      success: true,
      farm: {
        id: farm.id,
        farmerId: farm.farmer_id,
        farmName: farm.farm_name,
        location: farm.location,
        area: Number(farm.area),
        areaUnit: farm.area_unit,
        cropType: farm.crop_type,
        isActive: farm.is_active,
        createdAt: farm.created_at,
        farmerName: farm.farmer_name,
      },
    });
  } catch (error) {
    console.error('Get farm error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to load farm',
    });
  }
});

router.post('/', async (req, res) => {
  try {
    const {
      farmerId,
      farmName,
      location,
      area,
      areaUnit,
      cropType,
      isActive,
    } = req.body;

    if (!farmerId) {
      return res.status(400).json({
        success: false,
        message: 'Farmer is required',
      });
    }

    if (!farmName || !farmName.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Farm name is required',
      });
    }

    if (!isValidUuid(farmerId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid farmer ID',
      });
    }

    let areaValue;
    try {
      areaValue = parseNonNegative(area ?? 0, 'area');
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }

    const farmerCheck = await pool.query(
      'SELECT id FROM farmers WHERE id = $1',
      [farmerId]
    );

    if (farmerCheck.rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Farmer not found',
      });
    }

    const result = await pool.query(
      `
      INSERT INTO farms
      (
        farmer_id,
        farm_name,
        location,
        area,
        area_unit,
        crop_type,
        is_active
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING
        id,
        farmer_id,
        farm_name,
        location,
        area,
        area_unit,
        crop_type,
        is_active,
        created_at
      `,
      [
        farmerId,
        farmName.trim(),
        location?.trim() || null,
        areaValue,
        areaUnit || 'acre',
        cropType?.trim() || null,
        isActive ?? true,
      ]
    );

    const farm = result.rows[0];

    const farmerResult = await pool.query(
      'SELECT name FROM farmers WHERE id = $1',
      [farmerId]
    );

    res.status(201).json({
      success: true,
      message: 'Farm created successfully',
      farm: {
        id: farm.id,
        farmerId: farm.farmer_id,
        farmName: farm.farm_name,
        location: farm.location,
        area: Number(farm.area),
        areaUnit: farm.area_unit,
        cropType: farm.crop_type,
        isActive: farm.is_active,
        createdAt: farm.created_at,
        farmerName: farmerResult.rows[0]?.name ?? '',
      },
    });
  } catch (error) {
    console.error('Create farm error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create farm',
    });
  }
});
router.put('/:id', async (req, res) => {
  if (!isValidUuid(req.params.id)) return res.status(400).json({ success: false, message: 'Invalid farm ID' });
  try {
    const {
      farmerId,
      farmName,
      location,
      area,
      areaUnit,
      cropType,
      isActive,
    } = req.body;

    if (!farmName || !farmName.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Farm name is required',
      });
    }

    let areaValue;
    try {
      areaValue = parseNonNegative(area ?? 0, 'area');
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }

    // If farmerId is not provided,
    // keep the existing farmer relationship.
    let updateFarmerId = farmerId;

    if (!updateFarmerId) {
      const existingFarm = await pool.query(
        'SELECT farmer_id FROM farms WHERE id = $1',
        [req.params.id]
      );

      if (existingFarm.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Farm not found',
        });
      }

      updateFarmerId = existingFarm.rows[0].farmer_id;
    }

    // Verify that the farmer exists.
    const farmerCheck = await pool.query(
      'SELECT id FROM farmers WHERE id = $1',
      [updateFarmerId]
    );

    if (farmerCheck.rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Farmer not found',
      });
    }

    const result = await pool.query(
      `
      UPDATE farms
      SET
        farmer_id = $1,
        farm_name = $2,
        location = $3,
        area = $4,
        area_unit = $5,
        crop_type = $6,
        is_active = $7
      WHERE id = $8
      RETURNING
        id,
        farmer_id,
        farm_name,
        location,
        area,
        area_unit,
        crop_type,
        is_active,
        created_at
      `,
      [
        updateFarmerId,
        farmName.trim(),
        location?.trim() || null,
        areaValue,
        areaUnit || 'acre',
        cropType?.trim() || null,
        isActive ?? true,
        req.params.id,
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Farm not found',
      });
    }

    const farm = result.rows[0];

    const farmerResult = await pool.query(
      'SELECT name FROM farmers WHERE id = $1',
      [updateFarmerId]
    );

    res.json({
      success: true,
      message: 'Farm updated successfully',
      farm: {
        id: farm.id,
        farmerId: farm.farmer_id,
        farmName: farm.farm_name,
        location: farm.location,
        area: Number(farm.area),
        areaUnit: farm.area_unit,
        cropType: farm.crop_type,
        isActive: farm.is_active,
        createdAt: farm.created_at,
        farmerName: farmerResult.rows[0]?.name ?? '',
      },
    });
  } catch (error) {
    console.error('Update farm error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update farm',
    });
  }
});

// =====================================================
// FARM ACTIVITIES (production / income / expense)
// =====================================================

function mapActivity(row) {
  return {
    id: row.id,
    farmId: row.farm_id,
    activityType: row.activity_type,
    category: row.category,
    quantity: Number(row.quantity || 0),
    unit: row.unit,
    rate: Number(row.rate || 0),
    amount: Number(row.amount || 0),
    date: row.date,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function validUuid(value) {
  return typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

router.get('/:farmId/activities', async (req, res, next) => {
  try {
    if (!validUuid(req.params.farmId)) {
      return res.status(400).json({ success: false, message: 'Invalid farm ID' });
    }

    const result = await pool.query(
      `
      SELECT *
      FROM farm_activities
      WHERE farm_id = $1
      ORDER BY date DESC, created_at DESC
      `,
      [req.params.farmId],
    );

    res.json({
      success: true,
      activities: result.rows.map(mapActivity),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/:farmId/activities', async (req, res, next) => {
  try {
    const farmId = req.params.farmId;
    if (!validUuid(farmId)) {
      return res.status(400).json({ success: false, message: 'Invalid farm ID' });
    }

    const {
      activityType,
      category,
      quantity = 0,
      unit = 'Maund',
      rate = 0,
      amount,
      date,
      notes,
    } = req.body;

    if (!['production', 'income', 'expense'].includes(String(activityType).toLowerCase())) {
      return res.status(400).json({
        success: false,
        message: 'activityType must be production, income or expense',
      });
    }

    const quantityValue = Number(quantity);
    const rateValue = Number(rate);
    const amountValue = amount === undefined
      ? quantityValue * rateValue
      : Number(amount);

    if (
      !Number.isFinite(quantityValue) || quantityValue < 0 ||
      !Number.isFinite(rateValue) || rateValue < 0 ||
      !Number.isFinite(amountValue) || amountValue < 0
    ) {
      return res.status(400).json({
        success: false,
        message: 'quantity, rate and amount must be non-negative numbers',
      });
    }

    const farm = await pool.query('SELECT id FROM farms WHERE id = $1', [farmId]);
    if (farm.rowCount === 0) {
      return res.status(404).json({ success: false, message: 'Farm not found' });
    }

    const result = await pool.query(
      `
      INSERT INTO farm_activities
        (farm_id, activity_type, category, quantity, unit, rate, amount, date, notes)
      VALUES ($1,$2,$3,$4,$5,$6,$7,COALESCE($8,NOW()),$9)
      RETURNING *
      `,
      [
        farmId,
        String(activityType).toLowerCase(),
        category || null,
        quantityValue,
        unit || 'Maund',
        rateValue,
        amountValue,
        date || null,
        notes || null,
      ],
    );

    res.status(201).json({
      success: true,
      activity: mapActivity(result.rows[0]),
    });
  } catch (error) {
    next(error);
  }
});

router.put('/:farmId/activities/:activityId', async (req, res, next) => {
  try {
    const { farmId, activityId } = req.params;
    if (!validUuid(farmId) || !validUuid(activityId)) {
      return res.status(400).json({ success: false, message: 'Invalid farm or activity ID' });
    }

    const current = await pool.query(
      `SELECT * FROM farm_activities WHERE id = $1 AND farm_id = $2`,
      [activityId, farmId],
    );

    if (current.rowCount === 0) {
      return res.status(404).json({ success: false, message: 'Farm activity not found' });
    }

    const row = current.rows[0];
    const activityType = req.body.activityType !== undefined
      ? String(req.body.activityType).toLowerCase()
      : row.activity_type;

    if (!['production', 'income', 'expense'].includes(activityType)) {
      return res.status(400).json({ success: false, message: 'Invalid activity type' });
    }

    const quantityValue = req.body.quantity === undefined ? Number(row.quantity) : Number(req.body.quantity);
    const rateValue = req.body.rate === undefined ? Number(row.rate) : Number(req.body.rate);
    const amountValue = req.body.amount === undefined ? quantityValue * rateValue : Number(req.body.amount);

    if (
      !Number.isFinite(quantityValue) || quantityValue < 0 ||
      !Number.isFinite(rateValue) || rateValue < 0 ||
      !Number.isFinite(amountValue) || amountValue < 0
    ) {
      return res.status(400).json({ success: false, message: 'Invalid activity values' });
    }

    const result = await pool.query(
      `
      UPDATE farm_activities
      SET activity_type = $1,
          category = $2,
          quantity = $3,
          unit = $4,
          rate = $5,
          amount = $6,
          date = COALESCE($7, date),
          notes = $8,
          updated_at = NOW()
      WHERE id = $9 AND farm_id = $10
      RETURNING *
      `,
      [
        activityType,
        req.body.category !== undefined ? req.body.category : row.category,
        quantityValue,
        req.body.unit !== undefined ? req.body.unit : row.unit,
        rateValue,
        amountValue,
        req.body.date || null,
        req.body.notes !== undefined ? req.body.notes : row.notes,
        activityId,
        farmId,
      ],
    );

    res.json({ success: true, activity: mapActivity(result.rows[0]) });
  } catch (error) {
    next(error);
  }
});

router.delete('/:farmId/activities/:activityId', async (req, res, next) => {
  try {
    const { farmId, activityId } = req.params;
    if (!validUuid(farmId) || !validUuid(activityId)) {
      return res.status(400).json({ success: false, message: 'Invalid farm or activity ID' });
    }

    const result = await pool.query(
      `DELETE FROM farm_activities WHERE id = $1 AND farm_id = $2 RETURNING id`,
      [activityId, farmId],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, message: 'Farm activity not found' });
    }

    res.json({ success: true, id: result.rows[0].id });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
