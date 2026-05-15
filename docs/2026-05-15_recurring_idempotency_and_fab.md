# 2026-05-15 — 자동거래 멱등 강화 + UX 개선 (스크롤·FAB)

## 배경
1. **자동거래 재생성 문제** — 매월 자동 생성된 고정지출 거래를 삭제해도, v2 페이지 진입 시 다시 들어오는 경우가 있다는 사용자 보고.
2. **저장 후 스크롤 튀는 문제** — 거래/고정지출/자산 페이지에서 항목 추가·수정 후 리스트가 맨 위로 점프.
3. **추가 버튼 접근성** — 상단 우측에 박혀 있어 모바일에서 닿기 불편.

---

## 1. 자동거래 멱등 강화 — `last_applied_ym` 도입

### 원인
기존 `applyRecurringTransfers` 는 멱등 판단을 **"transactions 테이블에 같은 `recurring_id` 의 행이 살아있느냐"** 로 했다.
→ 사용자가 자동거래를 손으로 삭제하면 다음 호출에서 그 월이 "미처리"로 보여 **재생성**됨.

### 변경
- `recurring_items` 테이블에 `last_applied_ym TEXT` 컬럼 추가 (YYYY-MM)
- `applyRecurringTransfers` 가 거래 테이블 대신 이 컬럼으로 멱등 판단
- 처리 완료 시점에 `last_applied_ym` 갱신 (DB + 인메모리)
- `updateRecurring` 호출 시 의도적 재처리를 위해 마커를 직전 달로 되돌림 (`rewindLastAppliedIfThisMonth`)

### 결과
- 자동거래를 수동 삭제해도 **재생성되지 않음** (의도된 삭제로 간주)
- 항목 편집·토글로 인한 의도적 재처리는 기존 UX 그대로 유지

### 파일
- `supabase/migrations/2026_05_15_recurring_last_applied.sql` — 컬럼 추가 + 기존 자동거래 기반 백필
- `supabase/schema_v2.sql` — `recurring_items` CREATE TABLE 정의에 컬럼 추가
- `src/lib/api_v2.js`
  - `nextYm()` 헬퍼 추가
  - `applyRecurringTransfers()` 재작성 — 마커 기반 멱등
  - `updateRecurring()` + `rewindLastAppliedIfThisMonth()` — 의도적 재처리 트리거

### 마이그레이션
배포 전 Supabase SQL Editor 에서 직접 실행 필요:
```sql
BEGIN;
ALTER TABLE recurring_items ADD COLUMN IF NOT EXISTS last_applied_ym TEXT;
UPDATE recurring_items r
SET last_applied_ym = sub.max_ym
FROM (
  SELECT recurring_id, TO_CHAR(MAX(date), 'YYYY-MM') AS max_ym
  FROM transactions WHERE recurring_id IS NOT NULL GROUP BY recurring_id
) sub
WHERE r.id = sub.recurring_id AND r.last_applied_ym IS NULL;
COMMIT;
```

---

## 2. 저장 후 스크롤 위치 보존

### 원인
`reload()` 가 `items.value = []` 로 리스트를 비우고 다시 fetch → 짧은 시간 동안 페이지 높이가 0 으로 줄어 스크롤이 맨 위로 점프.

### 변경
- `reload({ resetList = false })` 옵션 추가
- 저장·삭제·토글 후 `reload()` (resetList=false) — items 유지 → Vue 가 키 기반 diff 로 스크롤 보존
- 월 전환(`shiftMonth`) 만 `reload({ resetList: true })` 로 명시적 리셋
- `v-if="loading"` → `v-if="loading && !items.length"` 로 변경 (Transactions) — 첫 로딩 외엔 list 가 unmount 되지 않음

### 파일
- `src/views/v2/Transactions.vue`
- `src/views/v2/Recurring.vue`
- (`Assets.vue` 는 원래 비우지 않는 패턴이라 추가 변경 없음)

---

## 3. "추가" 버튼 → 우측 하단 플로팅 FAB

### 결정 과정
1. 1차 시도: 하단 **중앙** 알약 모양 FAB
2. 사용자 피드백: 삼성 인터넷 내장 "맨 위로" 버튼(중앙 하단)과 위치 충돌 → 우측으로 이동 요청
3. 일시적으로 자체 "맨 위로" FAB 추가했다가, 사용자가 "삼성 인터넷 고유 기능"임을 확인하고 제거
4. 최종: **추가 FAB 만 우측 하단**, 맨 위로 기능은 브라우저에 위임

### 변경
- `src/views/v2/components/FabAdd.vue` (신규) — 알약 모양 (`+` 아이콘 + 라벨), 우측 하단 고정, safe-area 반영
- 세 페이지 상단 우측 "추가" 버튼 제거 후 `<FabAdd>` 삽입
  - 거래: "거래 추가"
  - 고정지출: "항목 추가"
  - 자산: "계좌 추가"
- `src/assets/styles.css` — `.v2-page` 하단 패딩 `2rem → 5.5rem` 으로 확장 (FAB 가 마지막 항목 가리지 않게)

---

## 커밋 히스토리

```
a394d4a 추가 FAB 우측 하단으로 이동 + 스크롤-투-탑 제거
c9f1a4c 맨 위로 스크롤 버튼 추가 — 우측 하단 FAB        (이후 제거)
2f6f0ab 추가 버튼을 하단 중앙 플로팅(FAB) 으로 이동      (이후 우측으로)
f48013b 자동거래 멱등 강화 + 저장 후 스크롤 보존
```

---

## 검증 체크리스트
- [ ] 자동거래 하나를 Supabase 콘솔에서 직접 삭제 → 페이지 새로고침해도 다시 안 들어오는지
- [ ] 항목 편집 후 자동거래가 새 설정으로 재생성되는지 (기존 UX 유지)
- [ ] 거래/고정지출 페이지에서 스크롤 내린 뒤 추가·수정 → 스크롤 위치 유지되는지
- [ ] 모바일에서 우측 하단 추가 FAB 와 삼성 인터넷 "맨 위로" 버튼이 자리 겹치지 않는지
- [ ] iOS safe-area 적용된 기기에서 FAB 가 홈 인디케이터에 가리지 않는지
