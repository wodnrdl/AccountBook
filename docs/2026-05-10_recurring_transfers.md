# 2026-05-10 — v2 리뉴얼 후속 작업

## 1. 로그인 후 진입 경로 수정
- `src/views/LoginView.vue:66`
- 로그인 성공 시 `router.push('/home')` → `router.push('/v2')`
- Phase 7 에서 `/` redirect 와 사이드바는 `/v2` 로 바꿨으나 로그인 핸들러는 `/home` 그대로였던 누락 보완

## 2. 거래 페이지 행 UI 개편
- `src/views/v2/Transactions.vue`
- 메인 행: `● 카테고리 / 금액 / 수정 / 삭제 / ⌄` 한 줄 고정
  - 카테고리만 ellipsis 처리, 금액·버튼은 `flex-shrink: 0` 으로 풀사이즈 유지
- 행 클릭 시 드롭다운 펼침: 소유자 / 계좌 / 메모
  - `expandedId` ref + `toggleExpand(id)`
  - 한 번에 한 행만 펼쳐짐
  - 수정/삭제 버튼은 `@click.stop` 으로 펼침 방지
- 모바일에서 폰트·아이콘 크기 살짝 축소

## 3. 매월 자동 이체 (저축/적금/대출상환) 자동화 — B안

### 동기
- 매월 정해진 금액으로 자동이체되는 적금·저축을 사용자가 수동으로 자산 잔액에 더해주는 게 비효율적
- 양방향 자동(출금 -X / 입금 +X) 으로 가계부 정합성 유지

### DB 마이그레이션
파일: `supabase/migrations/2026_05_10_recurring_transfers.sql`

- `recurring_items.source_account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL`
  - 출금 계좌 (예: 월급 통장)
- `transactions.recurring_id BIGINT REFERENCES recurring_items(id) ON DELETE SET NULL`
  - 자동 생성된 거래 추적용
- `idx_transactions_recurring_id` 인덱스
- ⚠️ Supabase SQL Editor 에서 직접 실행 필요

### API 변경 (`src/lib/api_v2.js`)

**`applyRecurringTransfers(uptoYm)` (신규)**
- 활성 `transfer` / `loan_payment` 항목 중 source/target 둘 다 지정된 항목만 처리
- 각 월(`max(start_ym, '2026-05')` ~ `min(uptoYm, 현재월)`)에 대해 멱등 처리
  - `recurring_id` 로 중복 체크 → 한 항목당 한 달에 한 번만 생성
  - `end_ym` 지난 월 스킵
  - `day_of_month` 가 그 달 말일 초과면 말일로 클램프
- 각 실행마다 한 쌍의 거래 생성:
  - 출금: `kind='expense'`, `account=source`, `recurring_id=item.id`
  - 입금: `kind='income'`,  `account=target`, `recurring_id=item.id`
- `createTransaction` 가 `adjustAccountBalance` 호출 → 양쪽 잔액 자동 동기화
- `FEATURE_START = '2026-05'` 상한선으로 과거 백필 방지 (기존 자산 잔액 보호)

**`listTransactions` 변경**
- `includeRecurring` 옵션 추가 (기본 `false`)
- 기본 호출 시 `recurring_id IS NOT NULL` 거래는 결과에서 제외
- 거래 페이지·대시보드 요약에 자동이체가 이중계상되지 않도록 함

### Recurring.vue (`src/views/v2/Recurring.vue`)

- 모달: `transfer`/`loan_payment` 종류일 때 **출금 계좌** + **입금 계좌** 둘 다 선택
  - `needsTargetAccount` → `needsTransferAccounts` 로 이름 변경
  - 둘 다 지정 시 자동 이체 안내 문구 노출
- 리스트: `출금계좌 → 입금계좌` 표기, 둘 다 + active 면 `자동` 배지
- `reload()` 진입 시 `applyRecurringTransfers(ym.value)` 선처리 → 잔액·거래 갱신된 상태로 화면 그림

### V2Layout.vue (`src/views/v2/V2Layout.vue`)

- `onMounted` 에서 `applyLivingBudgetCharges()` + `applyRecurringTransfers()` 호출
- v2 영역에 처음 진입할 때 한 번 자동 실행 (대시보드만 보는 사용자도 커버)

## 동작 흐름 예시 — "재욱 청년적금 70만원"

1. 자산 페이지에서 출금 계좌(예: 월급통장)와 입금 계좌(청년적금) 모두 등록
2. 고정지출 페이지에서 "재욱 청년적금" 항목 편집 → 출금: 월급통장, 입금: 청년적금 지정
3. v2 진입 시 (또는 고정지출 페이지 진입 시) 자동:
   - 월급통장 −700,000 (expense, recurring_id=X)
   - 청년적금 +700,000 (income,  recurring_id=X)
4. 거래 페이지에는 안 보임 (recurring_id 필터)
5. 자산 페이지에서 두 계좌 잔액이 매월 자동 변동

## 데이터 안전성

- **백필 상한**: `FEATURE_START = '2026-05'` 이전 월은 자동 생성하지 않음
- **미래월 차단**: 사용자가 미래월로 이동해도 현재월 초과 분은 처리 안 함
- **멱등성**: `recurring_id` + 해당 월 거래 존재 여부로 중복 방지
- **항목 삭제 시**: `ON DELETE SET NULL` → 자동 생성 거래는 남되 `recurring_id` 만 NULL 로 변경
  - 잔액 영향은 그대로 보존 (수동 정리 필요 시 거래 페이지에서 가능)
  - NULL 이 되면 거래 페이지에 다시 노출됨

## 사용자가 해야 할 일

1. Supabase SQL Editor 에서 마이그레이션 실행:
   ```
   supabase/migrations/2026_05_10_recurring_transfers.sql
   ```
2. 기존 `transfer` / `loan_payment` 항목들 편집해서 **출금 계좌** 지정
   - 안 하면 자동 안 돌아감 (이전과 동일하게 표시만 됨)
   - 입금 계좌(`target_account_id`)도 비어있는 경우 같이 채우기

## 변경 파일

- `supabase/migrations/2026_05_10_recurring_transfers.sql` (신규)
- `src/lib/api_v2.js`
- `src/views/LoginView.vue`
- `src/views/v2/Recurring.vue`
- `src/views/v2/Transactions.vue`
- `src/views/v2/V2Layout.vue`
- `docs/2026-05-10_recurring_transfers.md` (이 문서)
