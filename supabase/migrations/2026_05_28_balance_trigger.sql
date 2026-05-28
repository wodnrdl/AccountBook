-- =============================================
-- 거래 ↔ 계좌 잔액 동기화를 DB 트리거로 이관
-- 적용일: 2026-05-28
-- 배경:
--   기존엔 클라이언트(api_v2.js)가 거래 저장 시 increment_account_balance RPC 를
--   호출해 accounts.balance 를 ± 했다. RPC 호출이 한 번이라도 실패/누락되면
--   accounts.balance 가 실제 거래 합계와 영구히 어긋난다(드리프트).
--   실제로 계좌18(생활비)에서 거래 174 '포도청 삼계탕' 55,000 차감이 누락돼
--   저장잔액 102,187 vs 거래합계 47,187 로 어긋난 사례 발생.
--   → 잔액 갱신을 거래 INSERT/UPDATE/DELETE 트리거로 옮겨 원자적으로 보장한다.
-- 주의:
--   반드시 새 코드(클라이언트 잔액 RPC 제거)와 함께 배포해야 한다.
--   구 코드 + 이 트리거가 동시에 살아있으면 이중 차감된다.
-- =============================================

BEGIN;

CREATE OR REPLACE FUNCTION tx_apply_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- 신규/수정: 새 거래 효과 반영 (income +amount, expense -amount)
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.account_id IS NOT NULL THEN
    UPDATE accounts
       SET balance = balance + (CASE WHEN NEW.kind = 'income' THEN NEW.amount ELSE -NEW.amount END)
     WHERE id = NEW.account_id;
  END IF;

  -- 삭제/수정: 이전 거래 효과 되돌림
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

COMMIT;

-- 드리프트 1회 교정 (이미 별도로 적용했으면 재실행 금지 — 이후 거래가 반영된 절대값을 덮어씀):
--   생활비(가상 봉투, id=18)는 잔액 = 거래합계 여야 함.
--   UPDATE accounts SET balance = 47187 WHERE id = 18;
-- 봉투 외 일반 계좌는 초기잔액이 거래합계와 별개라 일괄 보정하지 않는다.
