CREATE TABLE IF NOT EXISTS farm_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id UUID NOT NULL,
  activity_type VARCHAR(30) NOT NULL,
  category VARCHAR(100),
  quantity NUMERIC(18,3) NOT NULL DEFAULT 0,
  unit VARCHAR(30) NOT NULL DEFAULT 'Maund',
  rate NUMERIC(18,2) NOT NULL DEFAULT 0,
  amount NUMERIC(18,2) NOT NULL DEFAULT 0,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_farm_activity_farm
    FOREIGN KEY (farm_id) REFERENCES farms(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT chk_farm_activity_type
    CHECK (activity_type IN ('production', 'income', 'expense')),
  CONSTRAINT chk_farm_activity_quantity
    CHECK (quantity >= 0),
  CONSTRAINT chk_farm_activity_rate
    CHECK (rate >= 0),
  CONSTRAINT chk_farm_activity_amount
    CHECK (amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_farm_activities_farm_date
  ON farm_activities (farm_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_farm_activities_type
  ON farm_activities (activity_type);
