-- ============================================================
-- Farmer Management System
-- PostgreSQL Initial Schema
-- Migration: 001_initial_schema
-- ============================================================

BEGIN;

-- ============================================================
-- UUID SUPPORT
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- USERS
-- Authentication ko baad mein activate kar sakte hain.
-- Table abhi database architecture ka part rahegi.
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(150) NOT NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255),

    password_hash TEXT NOT NULL,

    role VARCHAR(50) NOT NULL DEFAULT 'admin',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_username
    ON users (username);

-- ============================================================
-- FARMERS
-- ============================================================

CREATE TABLE IF NOT EXISTS farmers (
    id UUID PRIMARY KEY,

    name VARCHAR(150) NOT NULL,
    father_name VARCHAR(150) NOT NULL DEFAULT '',

    phone VARCHAR(50) NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    cnic VARCHAR(30),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_farmers_name
    ON farmers (name);

CREATE INDEX IF NOT EXISTS idx_farmers_phone
    ON farmers (phone);

CREATE INDEX IF NOT EXISTS idx_farmers_active
    ON farmers (is_active);

-- ============================================================
-- FARMS
-- ============================================================

CREATE TABLE IF NOT EXISTS farms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    farmer_id UUID NOT NULL,

    farm_name VARCHAR(150) NOT NULL,
    location TEXT,
    area NUMERIC(14, 3) NOT NULL DEFAULT 0,
    area_unit VARCHAR(30) NOT NULL DEFAULT 'acre',
    crop_type VARCHAR(100),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_farms_farmer
        FOREIGN KEY (farmer_id)
        REFERENCES farmers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_farms_area
        CHECK (area >= 0)
);

CREATE INDEX IF NOT EXISTS idx_farms_farmer_id
    ON farms (farmer_id);

CREATE INDEX IF NOT EXISTS idx_farms_active
    ON farms (is_active);

-- ============================================================
-- PARTIES
-- ============================================================

CREATE TABLE IF NOT EXISTS parties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(150) NOT NULL,
    phone VARCHAR(50) NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',

    party_type VARCHAR(50) NOT NULL DEFAULT 'customer',

    opening_balance NUMERIC(18, 2) NOT NULL DEFAULT 0,
    opening_balance_type VARCHAR(50) NOT NULL DEFAULT 'You Give',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_parties_name
    ON parties (name);

CREATE INDEX IF NOT EXISTS idx_parties_active
    ON parties (is_active);

-- ============================================================
-- KHATA TRANSACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS khata_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    party_id UUID NOT NULL,

    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    description TEXT NOT NULL DEFAULT '',

    debit NUMERIC(18, 2) NOT NULL DEFAULT 0,
    credit NUMERIC(18, 2) NOT NULL DEFAULT 0,
    balance NUMERIC(18, 2) NOT NULL DEFAULT 0,

    reference VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_khata_party
        FOREIGN KEY (party_id)
        REFERENCES parties(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT chk_khata_debit
        CHECK (debit >= 0),

    CONSTRAINT chk_khata_credit
        CHECK (credit >= 0)
);

CREATE INDEX IF NOT EXISTS idx_khata_party_id
    ON khata_transactions (party_id);

CREATE INDEX IF NOT EXISTS idx_khata_date
    ON khata_transactions (date);

CREATE INDEX IF NOT EXISTS idx_khata_party_date
    ON khata_transactions (party_id, date DESC);

-- ============================================================
-- RICE TRANSACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS rice_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    farmer_id UUID,
    party_id UUID,

    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    quantity NUMERIC(18, 3) NOT NULL DEFAULT 0,
    rate NUMERIC(18, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    transaction_type VARCHAR(30) NOT NULL DEFAULT 'Purchase',

    paid_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    received_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    remaining_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    variety VARCHAR(150),
    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_rice_farmer
        FOREIGN KEY (farmer_id)
        REFERENCES farmers(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_rice_party
        FOREIGN KEY (party_id)
        REFERENCES parties(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_rice_quantity
        CHECK (quantity >= 0),

    CONSTRAINT chk_rice_rate
        CHECK (rate >= 0),

    CONSTRAINT chk_rice_total
        CHECK (total_amount >= 0),

    CONSTRAINT chk_rice_paid
        CHECK (paid_amount >= 0),

    CONSTRAINT chk_rice_received
        CHECK (received_amount >= 0),

    CONSTRAINT chk_rice_remaining
        CHECK (remaining_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_rice_farmer_id
    ON rice_transactions (farmer_id);

CREATE INDEX IF NOT EXISTS idx_rice_party_id
    ON rice_transactions (party_id);

CREATE INDEX IF NOT EXISTS idx_rice_date
    ON rice_transactions (date);

CREATE INDEX IF NOT EXISTS idx_rice_type
    ON rice_transactions (transaction_type);

-- ============================================================
-- WHEAT TRANSACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS wheat_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    farmer_id UUID,
    party_id UUID,

    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    quantity NUMERIC(18, 3) NOT NULL DEFAULT 0,
    rate NUMERIC(18, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    transaction_type VARCHAR(30) NOT NULL DEFAULT 'Purchase',

    paid_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    received_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    remaining_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    variety VARCHAR(150),
    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_wheat_farmer
        FOREIGN KEY (farmer_id)
        REFERENCES farmers(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_wheat_party
        FOREIGN KEY (party_id)
        REFERENCES parties(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_wheat_quantity
        CHECK (quantity >= 0),

    CONSTRAINT chk_wheat_rate
        CHECK (rate >= 0),

    CONSTRAINT chk_wheat_total
        CHECK (total_amount >= 0),

    CONSTRAINT chk_wheat_paid
        CHECK (paid_amount >= 0),

    CONSTRAINT chk_wheat_received
        CHECK (received_amount >= 0),

    CONSTRAINT chk_wheat_remaining
        CHECK (remaining_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_wheat_farmer_id
    ON wheat_transactions (farmer_id);

CREATE INDEX IF NOT EXISTS idx_wheat_party_id
    ON wheat_transactions (party_id);

CREATE INDEX IF NOT EXISTS idx_wheat_date
    ON wheat_transactions (date);

CREATE INDEX IF NOT EXISTS idx_wheat_type
    ON wheat_transactions (transaction_type);

-- ============================================================
-- STOCK
-- ============================================================

CREATE TABLE IF NOT EXISTS stock (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_name VARCHAR(150) NOT NULL,
    product_type VARCHAR(100) NOT NULL DEFAULT '',

    quantity NUMERIC(18, 3) NOT NULL DEFAULT 0,
    unit VARCHAR(30) NOT NULL DEFAULT 'kg',

    average_rate NUMERIC(18, 2) NOT NULL DEFAULT 0,
    total_value NUMERIC(18, 2) NOT NULL DEFAULT 0,

    warehouse VARCHAR(150),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_stock_quantity
        CHECK (quantity >= 0),

    CONSTRAINT chk_stock_average_rate
        CHECK (average_rate >= 0),

    CONSTRAINT chk_stock_total_value
        CHECK (total_value >= 0)
);

CREATE INDEX IF NOT EXISTS idx_stock_product_name
    ON stock (product_name);

CREATE INDEX IF NOT EXISTS idx_stock_product_type
    ON stock (product_type);

CREATE INDEX IF NOT EXISTS idx_stock_active
    ON stock (is_active);

-- ============================================================
-- STOCK MOVEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    stock_id UUID,

    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    movement_type VARCHAR(30) NOT NULL,

    quantity NUMERIC(18, 3) NOT NULL DEFAULT 0,
    rate NUMERIC(18, 2) NOT NULL DEFAULT 0,
    amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    source VARCHAR(100),
    reference VARCHAR(255),
    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_stock_movements_stock
        FOREIGN KEY (stock_id)
        REFERENCES stock(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_stock_movement_quantity
        CHECK (quantity >= 0),

    CONSTRAINT chk_stock_movement_rate
        CHECK (rate >= 0),

    CONSTRAINT chk_stock_movement_amount
        CHECK (amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_stock_id
    ON stock_movements (stock_id);

CREATE INDEX IF NOT EXISTS idx_stock_movements_date
    ON stock_movements (date);

-- ============================================================
-- ACCOUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(150) NOT NULL,
    account_type VARCHAR(50) NOT NULL DEFAULT 'cash',

    opening_balance NUMERIC(18, 2) NOT NULL DEFAULT 0,
    current_balance NUMERIC(18, 2) NOT NULL DEFAULT 0,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_accounts_name
    ON accounts (name);

CREATE INDEX IF NOT EXISTS idx_accounts_type
    ON accounts (account_type);

CREATE INDEX IF NOT EXISTS idx_accounts_active
    ON accounts (is_active);

-- ============================================================
-- ACCOUNT TRANSACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS account_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    account_id UUID,

    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    type VARCHAR(30) NOT NULL,
    amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    category VARCHAR(100),
    description TEXT,
    source VARCHAR(100),
    reference VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_account_transactions_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_account_transaction_amount
        CHECK (amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_account_transactions_account_id
    ON account_transactions (account_id);

CREATE INDEX IF NOT EXISTS idx_account_transactions_date
    ON account_transactions (date);

CREATE INDEX IF NOT EXISTS idx_account_transactions_type
    ON account_transactions (type);

-- ============================================================
-- PAYMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    party_id UUID,
    account_id UUID,

    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    payment_type VARCHAR(50) NOT NULL DEFAULT 'cash',

    description TEXT,
    reference VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_payments_party
        FOREIGN KEY (party_id)
        REFERENCES parties(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_payments_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_payment_amount
        CHECK (amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_payments_party_id
    ON payments (party_id);

CREATE INDEX IF NOT EXISTS idx_payments_account_id
    ON payments (account_id);

CREATE INDEX IF NOT EXISTS idx_payments_date
    ON payments (date);

-- ============================================================
-- MIGRATION RECORD
-- ============================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(100) PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO schema_migrations (version)
VALUES ('001_initial_schema')
ON CONFLICT (version) DO NOTHING;

COMMIT;