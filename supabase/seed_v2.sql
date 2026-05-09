-- =============================================
-- V2 시드 데이터
-- 출처: c:\Users\EVENTUS\Downloads\오늘까지_가계부_내용.txt
-- 기준월: 2026-05
-- 모호한 소유자는 기본값 가정 (UI 에서 수정 가능)
-- 재실행 안전: 모든 INSERT 가 비어있는 테이블 가정 → 처음 한 번만 실행
-- =============================================

BEGIN;

-- ---------------------------------------------
-- 1) accounts (자산/부채)
-- ---------------------------------------------

-- 재욱 자산
INSERT INTO accounts (name, type, owner, balance, sort_order, memo) VALUES
  ('서울전역 상품권', 'voucher',    '재욱',  1000000, 10, NULL),
  ('온누리 상품권',   'voucher',    '재욱',   700000, 11, NULL),
  ('예금1',          'savings',    '재욱',  6350000, 20, NULL),
  ('예금2',          'savings',    '재욱',  4350000, 21, NULL),
  ('적금',           'installment','재욱', 10500000, 30, NULL),
  ('주택청약(재욱)', 'housing',    '재욱',  2930000, 40, NULL),
  ('정기예금',       'savings',    '재욱', 15050000, 22, NULL),
  ('개인 IRP',       'irp',        '재욱',  1400000, 50, NULL);

-- 공주님 자산
INSERT INTO accounts (name, type, owner, balance, sort_order, memo) VALUES
  ('기업 예금1',       'savings', '공주님',  9000000, 20, NULL),
  ('우리 예금2',       'savings', '공주님',  6300000, 21, NULL),
  ('우리 예금3',       'savings', '공주님',  5000000, 22, NULL),
  ('우리 예금4',       'savings', '공주님',  2000000, 23, NULL),
  ('우리 예금5',       'savings', '공주님',  8000000, 24, NULL),
  ('주택청약(공주님)', 'housing', '공주님', 14450000, 40, NULL);

-- 공동 자산/부채
INSERT INTO accounts (name, type, owner, balance, is_liability, sort_order, memo) VALUES
  ('금',          'gold',    '공동',     700000, FALSE, 60, '매월 10만원씩 2026-07까지 적립'),
  ('임대 보증금', 'deposit', '공동',  118520000, FALSE, 70, NULL),
  ('대출',        'loan',    '공동',   90800000, TRUE,  80, NULL);

-- ---------------------------------------------
-- 2) recurring_items (매월 반복)
-- ---------------------------------------------

-- 수입
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('재욱 월급',   'income', 4000000, '재욱',   '2026-05', 10, '대충'),
  ('공주님 월급', 'income', 3000000, '공주님', '2026-05', 11, '대충');

-- 재욱 매월 이체/지출
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('부모님 통장',     'transfer',     500000, '재욱', '2026-05', 20, NULL),
  ('경조사비 통장',   'transfer',     300000, '재욱', '2026-05', 21, NULL),
  ('재욱 청년적금',   'transfer',     700000, '재욱', '2026-05', 22, NULL),
  ('재욱 퇴직연금',   'transfer',      50000, '재욱', '2026-05', 23, NULL),
  ('재욱 주택청약',   'transfer',      20000, '재욱', '2026-05', 24, NULL),
  ('재욱 용돈',       'expense',      600000, '재욱', '2026-05', 25, NULL);

-- 공주님 매월 이체/지출
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('공주님 주택청약', 'transfer',     100000, '공주님', '2026-05', 30, NULL),
  ('공주님 용돈',     'expense',      400000, '공주님', '2026-05', 31, NULL);

-- 대출 상환 (공동)
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('대출 상환', 'loan_payment', 200000, '공동', '2026-05', 40, NULL);

-- 공동 매월 지출 (생활비는 별도 봉투 시스템으로 관리 — living_budget 테이블)
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('임대료',  'expense', 308500,  '공동', '2026-05', 50, NULL),
  ('관리비',  'expense', 175000,  '공동', '2026-05', 52, '15~20만 평균'),
  ('금 적립','transfer', 100000,  '공동', '2026-05', 60, '2026-07 까지');

-- 금 적립의 종료월 설정
UPDATE recurring_items SET end_ym = '2026-07' WHERE name = '금 적립';

-- 보험 — 공주님
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('공주님 보험 1', 'insurance', 73130, '공주님', '2026-05', 70, NULL),
  ('공주님 보험 2', 'insurance', 30000, '공주님', '2026-05', 71, NULL),
  ('공주님 보험 3', 'insurance', 13860, '공주님', '2026-05', 72, NULL);

-- 보험 — 재욱
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('재욱 보험 1', 'insurance', 14220, '재욱', '2026-05', 80, NULL),
  ('재욱 보험 2', 'insurance', 45800, '재욱', '2026-05', 81, NULL),
  ('재욱 보험 3', 'insurance', 13860, '재욱', '2026-05', 82, NULL);

-- 보험 — 우주
INSERT INTO recurring_items (name, kind, amount, owner, start_ym, sort_order, memo) VALUES
  ('우주 보험', 'insurance', 38810, '우주', '2026-05', 90, NULL);

-- ---------------------------------------------
-- 3) balance_snapshots — 2026-05 시작 잔액 스냅샷
-- ---------------------------------------------
INSERT INTO balance_snapshots (account_id, year_month, balance)
SELECT id, '2026-05', balance FROM accounts;

COMMIT;

-- 확인용 쿼리
-- SELECT owner, COUNT(*) AS n, SUM(balance) AS total FROM accounts WHERE is_liability=FALSE GROUP BY owner ORDER BY owner;
-- SELECT kind,  SUM(amount) AS monthly FROM recurring_items WHERE active=TRUE GROUP BY kind;
