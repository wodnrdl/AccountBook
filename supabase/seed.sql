-- 카테고리 시드 데이터 (원본 DB 기준)
-- id를 명시적으로 지정 (원본과 동일한 category_id 유지)

INSERT INTO category (id, title) VALUES (2, '수입');
INSERT INTO category (id, title) VALUES (3, '저축/투자');
INSERT INTO category (id, title) VALUES (5, '고정지출');
INSERT INTO category (id, title) VALUES (6, '변동지출');
INSERT INTO category (id, title) VALUES (7, '생활비');
INSERT INTO category (id, title) VALUES (11, '기타수입');

-- 시퀀스를 최대 id 이후로 설정
SELECT setval('category_id_seq', (SELECT MAX(id) FROM category));

-- 카테고리 네비게이션 (그리드 컬럼 정의)
-- 수입 (category_id=2) - payType 없음
INSERT INTO category_nav (name, title, category_id, option) VALUES ('detailType', '항목', 2, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('amount', '금액', 2, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('update_at', '결제일', 2, NULL);
INSERT INTO category_nav (name, title, category_id, option) VALUES ('memo', '메모', 2, '[{"editor":"text"}]');

-- 저축/투자 (category_id=3) - payType 없음
INSERT INTO category_nav (name, title, category_id, option) VALUES ('detailType', '항목', 3, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('amount', '금액', 3, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('update_at', '결제일', 3, NULL);
INSERT INTO category_nav (name, title, category_id, option) VALUES ('memo', '메모', 3, '[{"editor":"text"}]');

-- 고정지출 (category_id=5) - payType 있음
INSERT INTO category_nav (name, title, category_id, option) VALUES ('detailType', '항목', 5, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('amount', '금액', 5, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('payType', '결제수단', 5, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('update_at', '결제일', 5, NULL);
INSERT INTO category_nav (name, title, category_id, option) VALUES ('memo', '메모', 5, '[{"editor":"text"}]');

-- 변동지출 (category_id=6) - payType 있음
INSERT INTO category_nav (name, title, category_id, option) VALUES ('detailType', '항목', 6, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('amount', '금액', 6, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('payType', '결제수단', 6, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('update_at', '결제일', 6, NULL);
INSERT INTO category_nav (name, title, category_id, option) VALUES ('memo', '메모', 6, '[{"editor":"text"}]');

-- 생활비 (category_id=7) - payType 없음
INSERT INTO category_nav (name, title, category_id, option) VALUES ('detailType', '항목', 7, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('amount', '금액', 7, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('update_at', '결제일', 7, NULL);
INSERT INTO category_nav (name, title, category_id, option) VALUES ('memo', '메모', 7, '[{"editor":"text"}]');

-- 기타수입 (category_id=11) - payType 없음
INSERT INTO category_nav (name, title, category_id, option) VALUES ('detailType', '항목', 11, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('amount', '금액', 11, '[{"editor":"text"}]');
INSERT INTO category_nav (name, title, category_id, option) VALUES ('update_at', '결제일', 11, NULL);
INSERT INTO category_nav (name, title, category_id, option) VALUES ('memo', '메모', 11, '[{"editor":"text"}]');
