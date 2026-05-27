-- =============================================
-- 봉투 계좌(tx_default) 잔액 강제 동기화
-- 적용일: 2026-05-27
-- 배경:
--   기존 api_v2.js 의 shouldSkipBalanceSync 가 tx_default 계좌의
--   수동 expense 거래를 account.balance 에 반영하지 않아,
--   자산 페이지 잔액과 거래 페이지의 잔여(이월포함) 가 어긋났다.
--   잔액 수동 조정 등 다른 누락 원인도 있을 수 있어,
--   봉투 계좌의 balance 를 해당 계좌의 모든 거래 net 합으로 재설정한다.
--   (= 거래 페이지의 "잔여(이월포함)" 와 동일한 계산식)
-- 멱등:
--   여러 번 실행해도 같은 결과로 수렴 — 안전.
-- =============================================

-- 1) DRY-RUN: 적용 전 영향 확인
SELECT a.id, a.name,
       a.balance AS old_balance,
       COALESCE(SUM(CASE WHEN t.kind = 'income'  THEN t.amount
                         WHEN t.kind = 'expense' THEN -t.amount
                         ELSE 0 END), 0) AS new_balance,
       a.balance - COALESCE(SUM(CASE WHEN t.kind = 'income'  THEN t.amount
                                     WHEN t.kind = 'expense' THEN -t.amount
                                     ELSE 0 END), 0) AS diff
FROM accounts a
LEFT JOIN transactions t ON t.account_id = a.id
WHERE a.tx_default = TRUE
GROUP BY a.id, a.name, a.balance;

-- 2) 실제 반영
BEGIN;

UPDATE accounts a
SET balance = COALESCE(sub.net, 0),
    updated_at = NOW()
FROM (
  SELECT account_id,
         SUM(CASE WHEN kind = 'income'  THEN amount
                  WHEN kind = 'expense' THEN -amount
                  ELSE 0 END) AS net
  FROM transactions
  WHERE account_id IN (SELECT id FROM accounts WHERE tx_default = TRUE)
  GROUP BY account_id
) sub
WHERE a.id = sub.account_id;

COMMIT;

-- 3) 검증: 봉투 계좌의 balance 와 transactions net 이 동일한지
-- SELECT a.id, a.name, a.balance,
--        (SELECT COALESCE(SUM(CASE WHEN kind='income' THEN amount ELSE -amount END), 0)
--         FROM transactions WHERE account_id = a.id) AS tx_net
-- FROM accounts a WHERE a.tx_default = TRUE;
