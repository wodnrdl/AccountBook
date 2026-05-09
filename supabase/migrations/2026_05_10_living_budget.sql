-- =============================================
-- 생활비 봉투 시스템
-- 적용일: 2026-05-10
-- 변경:
--   1) living_budget 테이블 (월 충전액 / 시작월 설정)
--   2) increment_account_balance RPC (거래 동기화용)
--   3) 기존 시드의 "생활비 100만 expense" 항목 제거
-- =============================================

BEGIN;

-- 1) 생활비 봉투 설정 (단일 행 운영)
CREATE TABLE IF NOT EXISTS living_budget (
  id              BIGSERIAL PRIMARY KEY,
  monthly_amount  BIGINT NOT NULL DEFAULT 1000000,
  start_ym        TEXT NOT NULL,                 -- 자동 등록 시작 월 'YYYY-MM'
  active          BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE living_budget ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all on living_budget" ON living_budget;
CREATE POLICY "Allow all on living_budget" ON living_budget FOR ALL USING (true) WITH CHECK (true);

-- 초기값 (이미 있으면 건너뜀)
INSERT INTO living_budget (monthly_amount, start_ym)
SELECT 1000000, '2026-05'
WHERE NOT EXISTS (SELECT 1 FROM living_budget);

-- 2) 잔액 원자적 증감 (거래 ↔ 계좌 동기화)
CREATE OR REPLACE FUNCTION increment_account_balance(p_account_id BIGINT, p_delta BIGINT)
RETURNS VOID AS $$
  UPDATE accounts
     SET balance = balance + p_delta,
         updated_at = NOW()
   WHERE id = p_account_id;
$$ LANGUAGE SQL;

-- 3) 기존 시드의 "생활비 100만 expense" 제거 (봉투 시스템으로 이관)
DELETE FROM recurring_items WHERE name = '생활비' AND kind = 'expense';

COMMIT;

-- 확인용
-- SELECT * FROM living_budget;
-- SELECT name FROM recurring_items WHERE name = '생활비';   -- 결과 없어야 함