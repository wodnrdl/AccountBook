-- =============================================
-- 매월 자동 이체 (저축/적금/대출상환) 자동화
-- 적용일: 2026-05-10
-- 변경:
--   1) recurring_items.source_account_id 추가 (출금 계좌)
--   2) transactions.recurring_id 추가 (자동 생성 거래 추적)
--   3) idx_transactions_recurring_id
-- 동작:
--   - transfer / loan_payment 항목 중 source/target 모두 지정된 활성 항목에 대해
--     매월 (start_ym ~ 현재월) 누락 분이 있으면 한 쌍의 거래를 자동 생성
--     · 출금: kind=expense, account=source, recurring_id=item
--     · 입금: kind=income,  account=target, recurring_id=item
--   - recurring_id IS NOT NULL 인 거래는 거래 페이지 요약에서 제외 (이중계상 방지)
-- =============================================

BEGIN;

ALTER TABLE recurring_items
  ADD COLUMN IF NOT EXISTS source_account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL;

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS recurring_id BIGINT REFERENCES recurring_items(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_recurring_id ON transactions(recurring_id);

COMMIT;

-- 확인용
-- SELECT id, name, kind, source_account_id, target_account_id FROM recurring_items
--   WHERE kind IN ('transfer','loan_payment');
-- SELECT recurring_id, COUNT(*) FROM transactions WHERE recurring_id IS NOT NULL GROUP BY 1;
