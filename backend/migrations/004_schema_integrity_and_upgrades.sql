-- ============================================================
-- Farmer Management System
-- Database Schema Integrity & Upgrades
-- Migration: 004_schema_integrity_and_upgrades.sql
-- ============================================================

BEGIN;

-- 1. Ensure set_updated_at function exists
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Add updated_at trigger helper to all relevant tables
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'users',
            'farmers',
            'farms',
            'farm_activities',
            'parties',
            'khata_transactions',
            'rice_transactions',
            'wheat_transactions',
            'stock',
            'accounts'
        ])
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_set_updated_at ON %I;', tbl);
        EXECUTE format(
            'CREATE TRIGGER trg_set_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW
             EXECUTE FUNCTION set_updated_at();',
            tbl
        );
    END LOOP;
END $$;

-- 3. Users Table Integrity Upgrades
-- Add last_login_at column if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'last_login_at'
    ) THEN
        ALTER TABLE users ADD COLUMN last_login_at TIMESTAMPTZ;
    END IF;
END $$;

-- Enforce valid roles check constraint on users table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_role'
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT chk_users_role
            CHECK (role IN ('admin', 'farm manager', 'rice/wheat manager', 'accountant'))
            NOT VALID;
    END IF;
END $$;

-- 4. Khata Transactions Polymorphic Source Linking
-- Add source_type and source_id columns for traceable trades / settlements
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'khata_transactions' AND column_name = 'source_type'
    ) THEN
        ALTER TABLE khata_transactions ADD COLUMN source_type VARCHAR(50);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'khata_transactions' AND column_name = 'source_id'
    ) THEN
        ALTER TABLE khata_transactions ADD COLUMN source_id UUID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_khata_source
    ON khata_transactions (source_type, source_id);

-- 5. Crop Transactions Stock Linking
-- Add stock_id column to rice_transactions and wheat_transactions to tie trades to warehouse stock
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'rice_transactions' AND column_name = 'stock_id'
    ) THEN
        ALTER TABLE rice_transactions ADD COLUMN stock_id UUID;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_rice_stock'
    ) THEN
        ALTER TABLE rice_transactions
            ADD CONSTRAINT fk_rice_stock
            FOREIGN KEY (stock_id) REFERENCES stock(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'wheat_transactions' AND column_name = 'stock_id'
    ) THEN
        ALTER TABLE wheat_transactions ADD COLUMN stock_id UUID;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_wheat_stock'
    ) THEN
        ALTER TABLE wheat_transactions
            ADD CONSTRAINT fk_wheat_stock
            FOREIGN KEY (stock_id) REFERENCES stock(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_rice_stock_id ON rice_transactions(stock_id);
CREATE INDEX IF NOT EXISTS idx_wheat_stock_id ON wheat_transactions(stock_id);

-- 6. Normalize Existing transaction_type to lowercase in rice and wheat tables
UPDATE rice_transactions
SET transaction_type = LOWER(transaction_type)
WHERE transaction_type IS NOT NULL AND transaction_type != LOWER(transaction_type);

UPDATE wheat_transactions
SET transaction_type = LOWER(transaction_type)
WHERE transaction_type IS NOT NULL AND transaction_type != LOWER(transaction_type);

-- 7. Validate Existing Constraints from Migration 002
DO $$
DECLARE
    chk_name text;
BEGIN
    FOR chk_name IN
        SELECT unnest(ARRAY[
            'chk_parties_opening_balance',
            'chk_parties_opening_balance_type',
            'chk_rice_transaction_type',
            'chk_wheat_transaction_type',
            'chk_account_type',
            'chk_account_transaction_type',
            'chk_stock_movement_type'
        ])
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE parties VALIDATE CONSTRAINT %I;', chk_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN
            EXECUTE format('ALTER TABLE rice_transactions VALIDATE CONSTRAINT %I;', chk_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN
            EXECUTE format('ALTER TABLE wheat_transactions VALIDATE CONSTRAINT %I;', chk_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN
            EXECUTE format('ALTER TABLE accounts VALIDATE CONSTRAINT %I;', chk_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN
            EXECUTE format('ALTER TABLE account_transactions VALIDATE CONSTRAINT %I;', chk_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN
            EXECUTE format('ALTER TABLE stock_movements VALIDATE CONSTRAINT %I;', chk_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END $$;

COMMIT;
