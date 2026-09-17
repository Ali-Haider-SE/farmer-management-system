const express = require('express');
const { randomUUID } = require('crypto');
const pool = require('./db');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        id,
        name,
        father_name,
        phone,
        address,
        cnic,
        is_active,
        created_at
      FROM farmers
      ORDER BY created_at DESC
    `);

    return res.status(200).json({
      success: true,
      farmers: result.rows.map((farmer) => ({
        id: farmer.id,
        name: farmer.name,
        fatherName: farmer.father_name,
        phone: farmer.phone || '',
        address: farmer.address || '',
        cnic: farmer.cnic || '',
        isActive: farmer.is_active,
        createdAt: farmer.created_at,
      })),
    });
  } catch (error) {
    console.error('Get farmers error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        id,
        name,
        father_name,
        phone,
        address,
        cnic,
        is_active,
        created_at
      FROM farmers
      WHERE id = $1
      `,
      [req.params.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Farmer not found',
      });
    }

    const farmer = result.rows[0];

    return res.status(200).json({
      success: true,
      farmer: {
        id: farmer.id,
        name: farmer.name,
        fatherName: farmer.father_name,
        phone: farmer.phone || '',
        address: farmer.address || '',
        cnic: farmer.cnic || '',
        isActive: farmer.is_active,
        createdAt: farmer.created_at,
      },
    });
  } catch (error) {
    console.error('Get farmer error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

router.post('/', async (req, res) => {
  try {
    const {
      id,
      name,
      fatherName,
      phone,
      address,
      cnic,
      isActive,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'name is required',
      });
    }

    const result = await pool.query(
      `
      INSERT INTO farmers (
        id,
        name,
        father_name,
        phone,
        address,
        cnic,
        is_active,
        created_at
      )
      VALUES (
        $1,
        $2,
        COALESCE($3, ''),
        $4,
        $5,
        $6,
        COALESCE($7, true),
        NOW()
      )
      RETURNING
        id,
        name,
        father_name,
        phone,
        address,
        cnic,
        is_active,
        created_at
      `,
      [
        id || randomUUID(),
        name.trim(),
        fatherName || null,
        phone || null,
        address || null,
        cnic || null,
        isActive,
      ],
    );

    const farmer = result.rows[0];

    return res.status(201).json({
      success: true,
      message: 'Farmer created successfully',
      farmer: {
        id: farmer.id,
        name: farmer.name,
        fatherName: farmer.father_name,
        phone: farmer.phone || '',
        address: farmer.address || '',
        cnic: farmer.cnic || '',
        isActive: farmer.is_active,
        createdAt: farmer.created_at,
      },
    });
  } catch (error) {
    console.error('Create farmer error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const {
      name,
      fatherName,
      phone,
      address,
      cnic,
      isActive,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'name is required',
      });
    }

    const result = await pool.query(
      `
      UPDATE farmers
      SET
        name = $1,
        father_name = COALESCE($2, father_name),
        phone = $3,
        address = $4,
        cnic = $5,
        is_active = COALESCE($6, is_active)
      WHERE id = $7
      RETURNING
        id,
        name,
        father_name,
        phone,
        address,
        cnic,
        is_active,
        created_at
      `,
      [
        name.trim(),
        fatherName || null,
        phone || null,
        address || null,
        cnic || null,
        isActive,
        req.params.id,
      ],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Farmer not found',
      });
    }

    const farmer = result.rows[0];

    return res.status(200).json({
      success: true,
      message: 'Farmer updated successfully',
      farmer: {
        id: farmer.id,
        name: farmer.name,
        fatherName: farmer.father_name,
        phone: farmer.phone || '',
        address: farmer.address || '',
        cnic: farmer.cnic || '',
        isActive: farmer.is_active,
        createdAt: farmer.created_at,
      },
    });
  } catch (error) {
    console.error('Update farmer error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      `
      DELETE FROM farmers
      WHERE id = $1
      RETURNING id
      `,
      [req.params.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Farmer not found',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Farmer deleted successfully',
      id: result.rows[0].id,
    });
  } catch (error) {
    console.error('Delete farmer error:', error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

module.exports = router;