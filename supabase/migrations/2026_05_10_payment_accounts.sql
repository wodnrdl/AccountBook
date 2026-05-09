-- =============================================
-- 적용일: 2026-05-10
-- 변경:
--   1) 결제 계좌 표시 (거래 등록 시 선택 가능 여부 + 기본값)
--   2) 소유자 '우주' → '공주님' 으로 통합 (우주 옵션 제거)
-- Supabase SQL Editor 에서 한 번 실행
-- =============================================

BEGIN;

-- 1) 결제 계좌 컬럼
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS tx_enabled BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS tx_default BOOLEAN NOT NULL DEFAULT FALSE;

-- 기본 결제 계좌는 항상 1개 이하
CREATE UNIQUE INDEX IF NOT EXISTS uniq_one_tx_default_account
  ON accounts (tx_default) WHERE tx_default = TRUE;

CREATE INDEX IF NOT EXISTS idx_accounts_tx_enabled ON accounts(tx_enabled);

-- 2) 우주 → 공주님 통합
UPDATE accounts        SET owner = '공주님' WHERE owner = '우주';
UPDATE recurring_items SET owner = '공주님' WHERE owner = '우주';
UPDATE transactions    SET owner = '공주님' WHERE owner = '우주';

COMMIT;

-- 확인용
-- SELECT owner, COUNT(*) FROM accounts        GROUP BY owner;
-- SELECT owner, COUNT(*) FROM recurring_items GROUP BY owner;
