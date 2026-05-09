-- =============================================
-- v1 생활비 데이터 → v2 transactions 마이그레이션
-- 적용일: 2026-05-10
-- 동작:
--   1) row_data category_id=7 (v1 생활비) → transactions(expense) INSERT
--      memo 에 '[v1] ' 프리픽스 → 멱등성 보장 (재실행 안전)
--   2) account.balance 에서 마이그레이션한 합계만큼 차감
--   3) living_budget.start_ym 을 가장 이른 v1 생활비 월로 당김
-- 후처리:
--   사용자가 /v2 진입 시 applyLivingBudgetCharges 가 누락된 월에
--   +monthly_amount income 자동 INSERT (Feb/Mar/Apr 등)
-- 사전 조건:
--   accounts 에 tx_default = TRUE 인 행이 1개 있어야 함
-- =============================================

BEGIN;

CREATE OR REPLACE FUNCTION migrate_v1_living_expenses()
RETURNS TABLE(inserted_count INT, total_amount BIGINT, target_account TEXT, start_month TEXT) AS $$
DECLARE
  target_id   BIGINT;
  target_name TEXT;
  v_inserted  INT     := 0;
  v_total     BIGINT  := 0;
  earliest_ym TEXT;
BEGIN
  SELECT id, name INTO target_id, target_name
    FROM accounts WHERE tx_default = TRUE LIMIT 1;

  IF target_id IS NULL THEN
    RAISE EXCEPTION '기본 결제 계좌가 지정되지 않았습니다. 자산 관리에서 tx_default 를 설정한 후 다시 실행하세요.';
  END IF;

  -- 1) 멱등 INSERT: 같은 날짜/금액/계좌/[v1] 메모로 이미 들어간 행은 건너뜀
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
    WHERE r.category_id = 7
      AND r.amount > 0
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

  -- 2) 잔액 차감 (마이그레이션 분만큼)
  IF v_total > 0 THEN
    UPDATE accounts SET balance = balance - v_total WHERE id = target_id;
  END IF;

  -- 3) 가장 이른 생활비 월 (row_data 기준)
  SELECT TO_CHAR(MIN(update_at), 'YYYY-MM') INTO earliest_ym
    FROM row_data WHERE category_id = 7;

  -- 그보다 늦은 start_ym 이 설정되어 있으면 당김
  IF earliest_ym IS NOT NULL THEN
    UPDATE living_budget
       SET start_ym = earliest_ym, updated_at = NOW()
     WHERE start_ym > earliest_ym;
  END IF;

  RETURN QUERY SELECT v_inserted, v_total, target_name, earliest_ym;
END;
$$ LANGUAGE plpgsql;

-- 실행 (결과 표시)
SELECT * FROM migrate_v1_living_expenses();

COMMIT;

-- 확인용 쿼리 (마이그레이션 후 별도 실행)
-- SELECT date, amount, category, memo FROM transactions WHERE memo LIKE '[v1]%' ORDER BY date DESC LIMIT 20;
-- SELECT MIN(date), MAX(date), COUNT(*), SUM(amount) FROM transactions WHERE memo LIKE '[v1]%';
-- SELECT * FROM living_budget;
