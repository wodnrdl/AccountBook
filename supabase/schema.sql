-- Supabase SQL Editor에서 실행하세요

-- 카테고리 테이블
CREATE TABLE category (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  editor TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 카테고리 네비게이션 (그리드 컬럼 정의)
CREATE TABLE category_nav (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  category_id INTEGER REFERENCES category(id),
  option TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 가계부 데이터
CREATE TABLE row_data (
  id SERIAL PRIMARY KEY,
  amount INTEGER DEFAULT 0,
  category_id INTEGER REFERENCES category(id),
  row_key TEXT,
  update_at TIMESTAMPTZ,
  memo TEXT,
  pay_type TEXT,
  detail_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 데이터 로그
CREATE TABLE data_log (
  id SERIAL PRIMARY KEY,
  json_data TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_row_data_category ON row_data(category_id);
CREATE INDEX idx_row_data_update_at ON row_data(update_at);

-- RLS (Row Level Security) 비활성화 - 개인 프로젝트이므로
ALTER TABLE category ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_nav ENABLE ROW LEVEL SECURITY;
ALTER TABLE row_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_log ENABLE ROW LEVEL SECURITY;

-- 모든 사용자 접근 허용 정책 (anon key 사용)
CREATE POLICY "Allow all on category" ON category FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on category_nav" ON category_nav FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on row_data" ON row_data FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on data_log" ON data_log FOR ALL USING (true) WITH CHECK (true);
