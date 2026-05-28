-- =============================================
-- V2 REDESIGN 스키마
-- 기존 schema.sql 의 테이블은 그대로 두고,
-- 아래 신규 테이블만 추가합니다.
-- Supabase SQL Editor 에서 그대로 실행하세요.
-- =============================================

-- 자산/부채 계좌
CREATE TABLE IF NOT EXISTS accounts (
  id           BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  type         TEXT NOT NULL,           -- savings/installment/housing/voucher/gold/irp/deposit/loan
  owner        TEXT NOT NULL,           -- 재욱/공주님/공동/우주
  balance      BIGINT NOT NULL DEFAULT 0,
  is_liability BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  memo         TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 월별 잔액 스냅샷 (추이용)
CREATE TABLE IF NOT EXISTS balance_snapshots (
  id          BIGSERIAL PRIMARY KEY,
  account_id  BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  year_month  TEXT NOT NULL,            -- 'YYYY-MM'
  balance     BIGINT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (account_id, year_month)
);

-- 매월 반복 항목
CREATE TABLE IF NOT EXISTS recurring_items (
  id                BIGSERIAL PRIMARY KEY,
  name              TEXT NOT NULL,
  kind              TEXT NOT NULL,        -- income/transfer/expense/insurance/loan_payment
  amount            BIGINT NOT NULL DEFAULT 0,
  owner             TEXT NOT NULL,        -- 재욱/공주님/공동/우주
  day_of_month      INTEGER,              -- 이체일(1~31), 미정이면 NULL
  start_ym          TEXT NOT NULL,        -- 'YYYY-MM'
  end_ym            TEXT,                 -- 종료월 (예: 2026-07), 무제한이면 NULL
  target_account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
  active            BOOLEAN NOT NULL DEFAULT TRUE,
  memo              TEXT,
  sort_order        INTEGER NOT NULL DEFAULT 0,
  last_applied_ym   TEXT,                 -- 마지막으로 자동거래를 생성한 월 (YYYY-MM). 멱등 판단용.
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 단발성 거래
CREATE TABLE IF NOT EXISTS transactions (
  id          BIGSERIAL PRIMARY KEY,
  date        DATE NOT NULL,
  amount      BIGINT NOT NULL,
  kind        TEXT NOT NULL,             -- income/expense
  category    TEXT,                       -- 식비/교통/...
  owner       TEXT NOT NULL,
  account_id  BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
  memo        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_accounts_owner          ON accounts(owner);
CREATE INDEX IF NOT EXISTS idx_accounts_type           ON accounts(type);
CREATE INDEX IF NOT EXISTS idx_balance_snapshots_ym    ON balance_snapshots(year_month);
CREATE INDEX IF NOT EXISTS idx_balance_snapshots_acc   ON balance_snapshots(account_id);
CREATE INDEX IF NOT EXISTS idx_recurring_items_kind    ON recurring_items(kind);
CREATE INDEX IF NOT EXISTS idx_recurring_items_owner   ON recurring_items(owner);
CREATE INDEX IF NOT EXISTS idx_recurring_items_active  ON recurring_items(active);
CREATE INDEX IF NOT EXISTS idx_transactions_date       ON transactions(date);
CREATE INDEX IF NOT EXISTS idx_transactions_owner      ON transactions(owner);
CREATE INDEX IF NOT EXISTS idx_transactions_kind       ON transactions(kind);

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_accounts_updated_at ON accounts;
CREATE TRIGGER trg_accounts_updated_at
  BEFORE UPDATE ON accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_recurring_items_updated_at ON recurring_items;
CREATE TRIGGER trg_recurring_items_updated_at
  BEFORE UPDATE ON recurring_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 거래 ↔ 계좌 잔액 동기화 (INSERT/UPDATE/DELETE 시 원자적 갱신)
CREATE OR REPLACE FUNCTION tx_apply_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.account_id IS NOT NULL THEN
    UPDATE accounts
       SET balance = balance + (CASE WHEN NEW.kind = 'income' THEN NEW.amount ELSE -NEW.amount END)
     WHERE id = NEW.account_id;
  END IF;
  IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND OLD.account_id IS NOT NULL THEN
    UPDATE accounts
       SET balance = balance - (CASE WHEN OLD.kind = 'income' THEN OLD.amount ELSE -OLD.amount END)
     WHERE id = OLD.account_id;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tx_apply_balance ON transactions;
CREATE TRIGGER trg_tx_apply_balance
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION tx_apply_balance();

-- RLS (기존 정책과 동일하게 anon 전체 허용)
ALTER TABLE accounts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE balance_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_items   ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions      ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all on accounts"          ON accounts;
DROP POLICY IF EXISTS "Allow all on balance_snapshots" ON balance_snapshots;
DROP POLICY IF EXISTS "Allow all on recurring_items"   ON recurring_items;
DROP POLICY IF EXISTS "Allow all on transactions"      ON transactions;

CREATE POLICY "Allow all on accounts"          ON accounts          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on balance_snapshots" ON balance_snapshots FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on recurring_items"   ON recurring_items   FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on transactions"      ON transactions      FOR ALL USING (true) WITH CHECK (true);
