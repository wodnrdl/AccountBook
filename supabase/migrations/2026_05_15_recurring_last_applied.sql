-- =============================================
-- 매월 자동 거래: last_applied_ym 컬럼 추가 (멱등 판단 전환)
-- 적용일: 2026-05-15
-- 배경:
--   기존 applyRecurringTransfers 는 "transactions 에 같은 recurring_id+월 의
--   행이 살아있느냐" 로 멱등 판단을 했음. 그래서 사용자가 자동거래를 손으로
--   지우면 다음 진입 시 재생성되는 문제가 있었음.
-- 변경:
--   1) recurring_items.last_applied_ym TEXT 추가 (YYYY-MM)
--   2) 기존 자동거래 기반으로 백필 (recurring_id 별 MAX(date)→YYYY-MM)
-- 동작:
--   - applyRecurringTransfers 는 이 컬럼으로 멱등 판단
--   - 자동거래를 수동 삭제해도 재생성되지 않음 (의도된 삭제로 간주)
--   - 의도적 재처리는 updateRecurring 경로에서 last_applied_ym 을 직전 달로
--     되돌리는 방식으로 트리거
-- =============================================

BEGIN;

ALTER TABLE recurring_items
  ADD COLUMN IF NOT EXISTS last_applied_ym TEXT;

UPDATE recurring_items r
SET last_applied_ym = sub.max_ym
FROM (
  SELECT recurring_id, TO_CHAR(MAX(date), 'YYYY-MM') AS max_ym
  FROM transactions
  WHERE recurring_id IS NOT NULL
  GROUP BY recurring_id
) sub
WHERE r.id = sub.recurring_id
  AND r.last_applied_ym IS NULL;

COMMIT;

-- 확인용
-- SELECT id, name, kind, start_ym, last_applied_ym FROM recurring_items ORDER BY kind, id;
