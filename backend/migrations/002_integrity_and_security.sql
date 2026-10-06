-- Farmer Management System integrity constraints.
-- Existing rows are preserved; NOT VALID constraints enforce new writes
-- immediately while allowing a later controlled validation on clean data.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_parties_opening_balance'
  ) THEN
    ALTER TABLE parties
      ADD CONSTRAINT chk_parties_opening_balance
      CHECK (opening_balance >= 0) NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_parties_opening_balance_type'
  ) THEN
    ALTER TABLE parties
      ADD CONSTRAINT chk_parties_opening_balance_type
      CHECK (opening_balance_type IN ('You Give', 'You Take', 'You Receive', 'debit', 'credit'))
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_rice_transaction_type'
  ) THEN
    ALTER TABLE rice_transactions
      ADD CONSTRAINT chk_rice_transaction_type
      CHECK (transaction_type IN ('sale', 'purchase', 'Sale', 'Purchase'))
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_wheat_transaction_type'
  ) THEN
    ALTER TABLE wheat_transactions
      ADD CONSTRAINT chk_wheat_transaction_type
      CHECK (transaction_type IN ('sale', 'purchase', 'Sale', 'Purchase'))
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_account_type'
  ) THEN
    ALTER TABLE accounts
      ADD CONSTRAINT chk_account_type
      CHECK (account_type IN ('cash', 'bank', 'wallet', 'other'))
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_account_transaction_type'
  ) THEN
    ALTER TABLE account_transactions
      ADD CONSTRAINT chk_account_transaction_type
      CHECK (type IN ('Income', 'Expense'))
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_stock_movement_type'
  ) THEN
    ALTER TABLE stock_movements
      ADD CONSTRAINT chk_stock_movement_type
      CHECK (movement_type IN ('IN', 'OUT', 'ADJUSTMENT'))
      NOT VALID;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_rice_party_date
  ON rice_transactions (party_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_wheat_party_date
  ON wheat_transactions (party_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_account_transactions_account_date
  ON account_transactions (account_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_payments_party_date
  ON payments (party_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_payments_account_date
  ON payments (account_id, date DESC);
