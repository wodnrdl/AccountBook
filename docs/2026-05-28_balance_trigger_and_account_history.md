# 2026-05-28 — 잔액 드리프트 차단(DB 트리거) + 계좌 내역 개선 + UI 정리

## 배경
사용자 보고: "고정지출/거래를 등록해도 **자산의 계좌 잔액에 반영이 안 된다**." 새로고침(F5)해도 동일.

실데이터 조사 결과, 계좌18(생활비, 가상 봉투)에서:
- 거래 합계(net) = **47,187원** (거래탭 "잔여"와 일치)
- 저장된 `accounts.balance` = **102,187원** (자산탭 표시값)
- 차이 **55,000원** = 거래 174 `포도청 삼계탕`

즉 거래는 들어갔는데 잔액 컬럼만 안 깎인 **드리프트(desync)** 상태였다.

---

## 1. 원인 — 클라이언트 기반 잔액 증감

기존엔 거래 저장 시 클라이언트(`api_v2.js`)가 `increment_account_balance` RPC 를 호출해
`accounts.balance` 를 ±했다. RPC 호출이 **한 번이라도 실패/누락되면** 거래는 남고 잔액만 어긋나며,
이후 영구히 desync 된다. 거래탭은 매번 거래를 합산하므로 정상, 자산탭은 틀어진 컬럼을 그대로 표시 → "F5 해도 안 바뀜".

## 2. 해결 — 잔액 동기화를 DB 트리거로 이관

`transactions` 의 INSERT/UPDATE/DELETE 에 트리거(`trg_tx_apply_balance`)를 걸어
잔액을 **거래와 원자적으로** 갱신한다. 클라이언트 실패로 한 번 빠지는 식의 드리프트가 구조적으로 불가능해진다.

- `api_v2.js`: `adjustAccountBalance` / `txDelta` / `applyTxBalance` 제거.
  `createTransaction` / `updateTransaction` / `deleteTransaction` 는 쓰기 후 `invalidateAccounts()` 만 호출(캐시 무효화).
- `supabase/migrations/2026_05_28_balance_trigger.sql` (신규): 트리거 함수 + 트리거.
- `supabase/schema_v2.sql`: 신규 설치용 정의에도 동일 트리거 추가.
- 수동 "잔액 수정"(`updateBalance`)은 `accounts` 직접 PATCH 라 트리거와 무관 — 절대값 덮어쓰기 그대로 동작.

### 드리프트 1회 교정
```
UPDATE accounts SET balance = 47187 WHERE id = 18;   -- 생활비: 잔액 = 거래합계
```
봉투 외 일반 계좌는 초기잔액이 거래합계와 별개라 일괄 보정하지 않음(필요 시 개별 검증).

### ⚠️ 배포 주의
새 코드(클라이언트 잔액 RPC 제거)와 트리거 마이그레이션은 **반드시 함께** 적용.
구 코드 + 트리거가 동시에 살아있으면 **이중 차감**된다. 트리거만 있고 구 코드면 OK, 신 코드인데 트리거 없으면 잔액이 안 변한다.

---

## 3. 계좌 이용 내역 개선

- 자동거래(고정지출)도 내역에 표시 — `listTransactions({ includeRecurring: true })`.
  자동 생성분은 `자동` 배지로 구분.
- **모든 계좌**에서 내역 열람 가능 (기존엔 `tx_enabled` 계좌만 클릭됐음).
  주택청약·예금 등 비거래 계좌도 클릭 → 내역 확인.
- 적용: `src/views/v2/Assets.vue`(인라인 모달), `src/views/v2/components/AccountHistoryModal.vue`(대시보드용).

---

## 4. UI 정리

- **순자산 KPI** 를 억/만 표기로 변경: `wonEokMan()` 추가 (예: `1억 3515만원`, `1억 0000만`).
  대시보드 순자산에만 적용, 만 미만은 버림, 음수 `-` 표기. (`api_v2.js`, `Dashboard.vue`)
- **v2 사이드바에서 "기존 화면" 메뉴 제거** (`V2Layout.vue`). 로그아웃은 하단 유지.
  (라우트 `/home` 자체는 아직 살아있음 — 주소로는 접근 가능)

---

## 변경 파일
```
src/lib/api_v2.js                                  잔액 RPC 제거 + wonEokMan
src/views/v2/Dashboard.vue                          순자산 억/만 표기
src/views/v2/Assets.vue                             전 계좌 내역 열람 + 자동거래 포함/배지
src/views/v2/V2Layout.vue                           기존 화면 메뉴 제거
src/views/v2/components/AccountHistoryModal.vue     자동거래 포함/배지
supabase/schema_v2.sql                              tx_apply_balance 트리거
supabase/migrations/2026_05_28_balance_trigger.sql  (신규) 트리거 마이그레이션
```

## 검증 체크리스트
- [ ] Supabase SQL Editor 에서 `2026_05_28_balance_trigger.sql` 실행
- [ ] 거래 추가/수정/삭제 시 자산 계좌 잔액이 즉시(새로고침 후) 반영
- [ ] 거래 합계(거래탭 잔여)와 자산 잔액이 일치
- [ ] 자산에서 비거래 계좌 클릭 → 내역에 자동거래가 `자동` 배지로 표시
- [ ] 대시보드 순자산이 `N억 NNNN만원` 으로 표시
