
const express = require('express');
const router = express.Router();
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
        area ?? 0,
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
        area ?? 0,
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
module.exports = router;
