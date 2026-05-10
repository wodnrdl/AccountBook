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

---

## 후속 보완 (같은 날 추가 작업)

### 4. 생활비 봉투 단순화 — config 의존성 제거

기존 `living_budget` 테이블의 `monthly_amount` / `start_ym` / `active` 설정과 `applyLivingBudgetCharges()` 자동 충전을 모두 **제거**.

**왜:**
- 자동 충전은 결국 income 거래로 잔액에 들어감 → 정기수입(income)이나 저축/이체(transfer) 의 입금 쪽으로 이미 대체 가능
- 별도 충전 항목/UI/안내 알림이 중복이고, 시작월 설정·기본계좌 누락 안내 등 부수 분기가 많아 복잡도만 키움
- 이제는 "기본 결제 계좌(⭐)의 모든 income/expense 합계"를 그대로 보여주면 충분

**바뀐 동작 (`fetchLivingBudgetStatus`):**
- `living_budget` config 의존 X → 기본 결제 계좌만 있으면 동작
- `carryOver` = 해당 계좌의 이전 달까지 모든 (income − expense)
- `income` = 이번 달 모든 income 합계 (충전 카테고리 한정 X)
- `used` = 이번 달 모든 expense 합계
- `remaining` = `carryOver + income − used`

**Dashboard.vue:**
- "이번달 충전" 라벨 → "이번달 입금"
- 수동 충전 버튼·안내 메시지 제거 (`charging`, `livingNotice`, `manualCharge` 삭제)
- 기본 결제 계좌 미설정 시에만 안내 + `자산 관리` 링크

**Recurring.vue:**
- 생활비 봉투 편집 카드 섹션 통째로 제거 (`getLivingBudget` / `updateLivingBudget` import 도 삭제)

**V2Layout.vue:**
- `onMounted` 의 `applyLivingBudgetCharges()` 호출 삭제 (`applyRecurringTransfers` 만 남음)

> 참고: `living_budget` 테이블은 DB 에 그대로 남겨둠 (드롭하지 않음). 향후 다시 활용할 여지가 있어 read 만 사라진 상태.

### 5. 거래용(`tx_default`) 계좌 수동 지출은 자산 잔액 미반영

생활비 봉투(=기본 결제 계좌)의 수동 expense 거래는 이제 `accounts.balance` 를 깎지 않음. 봉투 잔액은 `fetchLivingBudgetStatus` 의 `remaining` 으로만 계산.

**왜:**
- 생활비를 쓸 때마다 봉투 잔액과 자산 카드 잔액이 함께 줄면 이중 표시 느낌
- 봉투는 "이번 달 입금 − 사용" 으로 추적, 자산 카드 잔액은 자동 거래(이체/수입 등) 로만 변동시키는 게 직관적

**구현 (`api_v2.js`):**
- `shouldSkipBalanceSync(t)` — `expense` && `recurring_id == null` && 해당 계좌의 `tx_default == true` 일 때 잔액 동기화 스킵
- `applyTxBalance(t, delta)` 헬퍼로 `createTransaction` / `updateTransaction` / `deleteTransaction` 모두 일관 처리
- 자동 거래 (`recurring_id` 가 있는 경우) 는 항상 잔액 반영 — 월급/이체 등은 그대로 자산 잔액에 들어가야 함

### 6. 고정지출 항목 수정/삭제 시 이번 달 자동 거래 정리

**`updateRecurring(id, fields)`:**
- 수정 후 해당 항목이 이번 달에 만든 자동 거래 삭제 (`deleteThisMonthAuto`)
- 다음 `applyRecurringTransfers()` 호출 시 도래여부·새 설정으로 재생성됨

**`deleteRecurring(id)`:**
- 삭제 전 해당 항목이 만든 **모든** 자동 거래를 `deleteTransaction` 으로 정리 → 잔액도 자동 원복
- 그 후 `recurring_items` 에서 행 삭제

> 이전에는 `ON DELETE SET NULL` 로 거래는 남고 `recurring_id` 만 NULL 이 되어 거래 페이지에 노출됐는데, 실사용에서 "삭제했는데 잔액이 안 줄어든다" 혼란이 있어 적극 정리 방식으로 변경.

### 7. 이체일 도래 전 자동 거래 보류

`applyRecurringTransfers` 가 이번 달 처리 시 `day_of_month` 가 **오늘 이후**면 그 항목은 스킵.

**왜:**
- 매월 25일 월급인데 5일에 v2 진입했다고 25일자 거래가 미리 찍히면 잔액·요약이 실제와 어긋남
- 도래일 지나서 다시 진입하면 멱등 처리로 정상 생성됨

### 8. 저축/이체 출금 계좌는 `tx_enabled` 인 계좌만 노출

`Recurring.vue` 모달에서 `kind === 'transfer'` 인 경우 출금 계좌 셀렉트는 `tx_enabled` 인 계좌로 한정.

**왜:**
- 거래 페이지의 결제 계좌 후보와 일관성 유지 — 적금/투자 같은 "거래에서 사용 X" 계좌가 출금원으로 잘못 선택되는 실수 방지

`expense` / `insurance` / `loan_payment` 의 출금 계좌는 모든 계좌 노출 그대로.

### 9. 자산 카드 클릭 → 이용 내역 모달 (`Assets.vue`)

`tx_enabled` 인 계좌 카드를 클릭하면 해당 계좌의 최근 거래 200건 모달 표시.

- `listTransactions({ accountId, includeRecurring: true, limit: 200 })`
- 카드 우상단 액션 버튼은 `@click.stop` 으로 모달 트리거 차단
- `clickable` 클래스로 호버 효과 (그림자 + transform)

### 10. `listTransactions` API 확장

옵션 추가:
- `accountId` — 특정 계좌의 거래만 조회 (자산 이용 내역 모달용)
- `limit` — 최대 행 수 제한
- `includeRecurring` — 기본 false 유지 (거래 페이지·대시보드 합계 보호)

### 11. 거래 페이지 합계 카드 — `livingStatus` 직접 사용

기존: `filtered` 거래 합산
문제: `filtered` 는 `recurring_id IS NOT NULL` 이 빠져있어 자동 입금/이체가 합계에 빠짐

수정: `totals` 를 `fetchLivingBudgetStatus` 결과로 채움 → carryOver/income/expense/remaining 모두 자동 거래 포함된 실제 값.

### 12. 고정지출 페이지 섹션 분리

수입 / 고정지출 / 저축·이체 세 섹션 헤더 + 합계.

- `fixedOut` = expense + insurance + loan_payment (이체 제외)
- `transfer` 별도 표시 — 가용 잉여 계산은 기존대로 `income − (fixedOut + transfer)`
- 섹션 헤더에 아이콘 + 섹션 합계 우측 정렬

### 추가 변경 파일

- `src/lib/api_v2.js`
- `src/views/v2/Assets.vue`
- `src/views/v2/Dashboard.vue`
- `src/views/v2/Recurring.vue`
- `src/views/v2/Transactions.vue`
- `src/views/v2/V2Layout.vue`
