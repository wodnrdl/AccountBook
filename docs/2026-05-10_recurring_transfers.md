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

## 3. 매월 자동 거래 처리 (전 종류 자동화)

### 동기
- 매월 정해진 금액의 수입/지출/이체를 수동으로 자산 잔액에 반영하는 게 비효율적
- 종류별로 필요한 계좌만 채워주면 매월 멱등 자동 거래 생성 → 자산 잔액이 항상 실제와 일치

### 종류별 동작

| 종류 | 입력 | 자동 처리 |
|---|---|---|
| 수입(income) | 입금 계좌 | 매월 +amount 단일 거래 |
| 저축/이체(transfer) | 출금+입금 | 매월 -amount/+amount 한 쌍 |
| 일반지출(expense) | 출금 계좌 | 매월 -amount 단일 거래 |
| 보험(insurance) | 출금 계좌 | 매월 -amount 단일 거래 |
| 대출상환(loan_payment) | 출금+입금 | 매월 -amount/+amount 한 쌍 |

각 종류마다 필요한 계좌가 비어있으면 자동 안 함 (이전과 동일하게 표시만 됨).

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
- 활성 항목 중 종류별 필요 계좌가 채워진 것만 처리 (`isRecurringAuto` 판정)
  - income → target 필요
  - expense/insurance → source 필요
  - transfer/loan_payment → source+target 둘 다 필요
- 각 월(`max(start_ym, '2026-05')` ~ `min(uptoYm, 현재월)`)에 대해 멱등 처리
  - `recurring_id` 로 중복 체크 → 한 항목당 한 달에 한 번만 생성
  - `end_ym` 지난 월 스킵
  - `day_of_month` 가 그 달 말일 초과면 말일로 클램프
- 종류별 거래 생성 (모두 `recurring_id=item.id` 마킹):
  - income: 단일 income tx (account=target)
  - expense/insurance: 단일 expense tx (account=source)
  - transfer/loan_payment: expense+income 한 쌍
- `createTransaction` 가 `adjustAccountBalance` 호출 → 잔액 자동 동기화
- `FEATURE_START = '2026-05'` 상한선으로 과거 백필 방지 (기존 자산 잔액 보호)

**`isRecurringAuto(r)` (신규)** — 자동 처리 가능 여부 판정. UI 의 `자동` 배지 표시에도 사용.

**`listTransactions` 변경**
- `includeRecurring` 옵션 추가 (기본 `false`)
- 기본 호출 시 `recurring_id IS NOT NULL` 거래는 결과에서 제외
- 거래 페이지·대시보드 요약에 자동이체가 이중계상되지 않도록 함

### Recurring.vue (`src/views/v2/Recurring.vue`)

- 모달: 종류별로 필요한 계좌 셀렉트 노출
  - `needsSourceAccount`: transfer/loan_payment/expense/insurance → 출금 계좌
  - `needsTargetAccount`: transfer/loan_payment/income → 입금 계좌
- 리스트: `출금계좌 → 입금계좌` 표기, `isRecurringAuto(r)` 충족 시 `자동` 배지
- `reload()` 진입 시 `applyRecurringTransfers(ym.value)` 선처리 → 잔액·거래 갱신된 상태로 화면 그림

### V2Layout.vue (`src/views/v2/V2Layout.vue`)

- `onMounted` 에서 `applyLivingBudgetCharges()` + `applyRecurringTransfers()` 호출
- v2 영역에 처음 진입할 때 한 번 자동 실행 (대시보드만 보는 사용자도 커버)

## 동작 흐름 예시 — 월급통장 자동화 풀세트

1. 자산 페이지: 월급통장 추가 (잔액 0 으로 시작)
2. 고정지출 항목 편집:
   - **재욱 월급(income)** → 입금 계좌: 월급통장
   - **재욱 청년적금(transfer)** → 출금: 월급통장, 입금: 적금
   - **재욱 보험 1(insurance)** → 출금: 월급통장
   - **임대료(expense)** → 출금: 월급통장
3. v2 진입 시 자동 (이번달 1일자로):
   - 월급통장 +4,000,000 (월급)
   - 월급통장 -700,000 / 적금 +700,000 (청년적금)
   - 월급통장 -14,220 (보험)
   - 월급통장 -308,500 (임대료)
4. 거래 페이지에는 안 보임 (recurring_id 필터로 제외)
5. 자산 페이지에서 모든 계좌 잔액이 매월 자동 변동

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
