-- =============================================
-- 생활비 봉투 계좌 자동 생성 + v1 생활비 데이터 마이그레이션
-- 적용일: 2026-05-10
-- 동작:
--   1) 기존 tx_default 전부 해제
--   2) 가상 "생활비" 봉투 계좌(type=envelope, owner=공동) 생성 → tx_default=TRUE
--      이미 존재하면 그대로 두고 tx_default 만 보장
--   3) row_data category_id=7 (v1 생활비) → transactions(expense) INSERT
--      memo 에 '[v1] ' 프리픽스 → 멱등성
--   4) 마이그레이션 합계만큼 생활비 봉투 잔액 차감
--   5) living_budget.start_ym 을 가장 이른 v1 생활비 월로 당김
-- 후처리:
--   /v2 진입 시 applyLivingBudgetCharges 가 누락된 매월에 +100만 자동 충전
-- =============================================

BEGIN;

-- 1) 기존 default 모두 해제 (생활비만 default 로 둘 것)
UPDATE accounts SET tx_default = FALSE WHERE tx_default = TRUE;

-- 2) 생활비 봉투 계좌 (없을 때만 생성)
INSERT INTO accounts (name, type, owner, balance, is_liability, tx_enabled, tx_default, sort_order, memo)
SELECT '생활비', 'envelope', '공동', 0, FALSE, TRUE, TRUE, 1, '매월 자동 충전되는 가상 봉투'
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name = '생활비' AND type = 'envelope');

-- 3) 이미 있었으면 tx_enabled / tx_default 보장
UPDATE accounts
   SET tx_enabled = TRUE, tx_default = TRUE
 WHERE name = '생활비' AND type = 'envelope';

-- 3-1) 생활비 고정 이체 항목 (고정지출 리스트에 100만 기본값으로 노출)
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, target_account_id, sort_order, memo)
SELECT '생활비',
       'transfer',
       COALESCE((SELECT monthly_amount FROM living_budget LIMIT 1), 1000000),
       '공동',
       COALESCE((SELECT start_ym FROM living_budget LIMIT 1), '2026-05'),
       (SELECT id FROM accounts WHERE name = '생활비' AND type = 'envelope'),
       30,
       '매월 생활비 봉투로 자동 충전'
WHERE NOT EXISTS (
  SELECT 1 FROM recurring_items WHERE name = '생활비' AND kind = 'transfer'
);

-- 4) v1 → v2 마이그레이션 함수
CREATE OR REPLACE FUNCTION migrate_v1_living_expenses()
RETURNS TABLE(inserted_count INT, total_amount BIGINT, target_account TEXT, start_month TEXT) AS $$
DECLARE
  target_id   BIGINT;
  target_name TEXT;
  v_inserted  INT    := 0;
  v_total     BIGINT := 0;
  earliest_ym TEXT;
BEGIN
  SELECT id, name INTO target_id, target_name
    FROM accounts WHERE tx_default = TRUE LIMIT 1;

  IF target_id IS NULL THEN
    RAISE EXCEPTION '기본 결제 계좌(생활비)가 생성되지 않았습니다.';
  END IF;

  -- 멱등 INSERT
  WITH new_txs AS (
    INSERT INTO transactions (date, amount, kind, category, owner, account_id, memo, created_at)
    SELECT
      r.update_at::date,
      r.amount,
      'expense',
      COALESCE(NULLIF(r.detail_type, ''), '생활'),
      '공동',
      target_id,
      '[v1] ' || COALESCE(r.memo, ''),
      COALESCE(r.created_at, NOW())
    FROM row_data r
    WHERE r.category_id = 7 AND r.amount > 0
      AND NOT EXISTS (
        SELECT 1 FROM transactions t
        WHERE t.memo LIKE '[v1]%'
          AND t.date       = r.update_at::date
          AND t.amount     = r.amount
          AND t.account_id = target_id
          AND t.kind       = 'expense'
      )
    RETURNING amount
  )
  SELECT COUNT(*), COALESCE(SUM(amount), 0) INTO v_inserted, v_total FROM new_txs;

  -- 봉투 잔액 차감
  IF v_total > 0 THEN
    UPDATE accounts SET balance = balance - v_total WHERE id = target_id;
  END IF;

  -- start_ym 을 '2026-03' 으로 고정 (v1 의 실질 시작월)
  earliest_ym := '2026-03';
  UPDATE living_budget
     SET start_ym = earliest_ym, updated_at = NOW()
   WHERE start_ym <> earliest_ym;

  -- 생활비 recurring_item 도 start_ym 동기화
  UPDATE recurring_items
     SET start_ym = earliest_ym
   WHERE name = '생활비' AND kind = 'transfer'
     AND start_ym <> earliest_ym;

  RETURN QUERY SELECT v_inserted, v_total, target_name, earliest_ym;
END;
$$ LANGUAGE plpgsql;

-- 실행
SELECT * FROM migrate_v1_living_expenses();

COMMIT;

-- 확인용
-- SELECT name, type, owner, balance, tx_default FROM accounts WHERE tx_default;
-- SELECT MIN(date), MAX(date), COUNT(*), SUM(amount) FROM transactions WHERE memo LIKE '[v1]%';
-- SELECT * FROM living_budget;
