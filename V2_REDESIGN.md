# V2 Redesign — 진행 문서

> 이 문서는 v2-redesign 브랜치 작업 재개용입니다. 세션이 끊겨도 이 문서만 보면 어디까지 했고 다음에 뭘 할지 알 수 있어야 합니다.

## 목표

- **보기 쉽고 관리하기 쉬운 가계부**로 리뉴얼
- 기능 추가보다는 **자산/고정지출/부채를 한눈에** 보여주는 구조 개선
- 참고 데이터: `c:\Users\EVENTUS\Downloads\오늘까지_가계부_내용.txt` (월급, 매월 고정, 자산, 보험, 대출 정리본)

## 브랜치 전략

- `main` = 기존 동작하는 가계부 (배포 중) — **건드리지 않음**, 언제든 롤백 가능
- `v2-redesign` = 새 버전 (현재 작업 브랜치)
- 신규 화면/테이블만 추가하고 **기존 row_data·HomeView·RegistrationView 는 그대로 둠** → 비교/롤백 용이

## DB 스키마 (신규 테이블만)

기존 `category / category_nav / row_data / data_log` 는 그대로 두고, 아래 신규 4개만 추가:

| 테이블 | 용도 |
|---|---|
| `accounts` | 자산/부채 계좌 (예금, 적금, 청약, 상품권, 금, 보증금, 대출 등) |
| `balance_snapshots` | 월별 잔액 스냅샷 (추이 그래프용) |
| `recurring_items` | 매월 반복 항목 (수입/저축이체/지출/보험/대출상환) |
| `transactions` | 단발성 거래 (일반 수입·지출) |

스키마 파일: `supabase/schema_v2.sql`
시드 데이터: `supabase/seed_v2.sql`

### owner 값
`재욱`, `공주님`, `공동`, `우주` — TEXT 컬럼으로 단순화 (별도 profile 테이블 X)

### kind / type 값

**accounts.type**: `savings`(예금), `installment`(적금), `housing`(청약), `voucher`(상품권), `gold`(금), `irp`(IRP/연금), `deposit`(보증금), `loan`(대출)

**recurring_items.kind**: `income`(수입), `transfer`(이체/저축), `expense`(지출), `insurance`(보험), `loan_payment`(대출상환)

## 화면 (라우트)

| 경로 | 화면 | 상태 |
|---|---|---|
| `/v2` | 대시보드 (수입/지출/자산/부채 한눈에) | TODO |
| `/v2/assets` | 자산 관리 (계좌별 잔액 + 월별 추이) | TODO |
| `/v2/recurring` | 매월 고정지출 관리 | TODO |
| `/v2/transactions` | 단발 거래 (등록/통계 리뉴얼) | TODO |
| `/home` | 기존 대시보드 (보존) | 유지 |
| `/registration` | 기존 등록/통계 (보존) | 유지 |

`/` 진입 시 일단 `/home`(기존)으로 보내고, v2 가 어느 정도 완성되면 `/v2`로 변경.

## 디자인 톤

- 기존 Bootstrap + FontAwesome + 메인컬러 `#5e72e4` 유지
- 레이아웃·정보위계만 재정리

## 시드 데이터 가정

다운로드 메모를 그대로 입력. 모호한 부분은 다음과 같이 가정 — **첫 화면에서 사용자가 수정 가능하게 만들 것**:

- 첫 매월 블록(부모님통장, 청년적금 등) → 재욱 소유로 표기
- 둘째 매월 블록(주택청약 10만, 용돈 40만, 대출 20만, 임대료 30.85만) → 공주님 / 임대료는 공동
- 첫 자산 블록(상품권, 예금1·2, 적금, 청약, 정기예금, IRP) → 재욱
- 둘째 자산 블록(기업/우리예금, 청약 1445만, 금, 보증금, 대출) → 공주님 또는 공동
- 시작월: 2026-05 기준
- 금 적립 종료월: 2026-07

## 진행 단계 (체크리스트)

### Phase 1 — 기반 (DB + 시드) ✅
- [x] V2_REDESIGN.md 문서 작성
- [x] `supabase/schema_v2.sql` 작성
- [x] `supabase/seed_v2.sql` 작성
- [x] 사용자가 Supabase SQL Editor 에서 schema_v2.sql + seed_v2.sql 실행 (수동)
- [x] Phase 1 커밋 (34d776a)

### Phase 2 — 라우팅 + 공통 레이아웃 ✅
- [x] `src/lib/api_v2.js` — accounts/snapshots/recurring/transactions CRUD + dashboard 요약
- [x] `src/views/v2/V2Layout.vue` — v2 전용 사이드바 (대시보드/자산/고정지출/거래 + 기존화면 복귀 링크)
- [x] `src/views/v2/Dashboard.vue` / `Assets.vue` / `Recurring.vue` / `Transactions.vue` — placeholder
- [x] `src/router.js` — `/v2/*` nested routes (기존 `/home`, `/registration` 보존)
- [x] `src/App.vue` — `/v2/*` 진입 시 기존 사이드바 우회 (V2Layout 단독 렌더)
- [x] `npm run build` 통과
- [ ] Phase 2 커밋 ⬅ **다음 작업**

### Phase 3 — 대시보드 (`/v2`) ⬅ **여기 진행 예정**
- [ ] 이번 달 카드: 수입 / 고정지출 / 가용잉여
- [ ] 자산 총합 + 소유자별 자산 도넛
- [ ] 부채 (대출 잔액)
- [ ] 다가오는 고정이체 리스트

### Phase 4 — 자산 관리 (`/v2/assets`)
- [ ] 계좌 카드 그리드 (소유자별 그룹)
- [ ] 잔액 입력/수정 → balance_snapshots 자동 기록
- [ ] 월별 추이 라인차트 (계좌별/소유자별 토글)

### Phase 5 — 고정지출 (`/v2/recurring`)
- [ ] 매월 항목 표 (kind 별 그룹)
- [ ] 종료월 표시 (예: 금적립 2026-07)
- [ ] CRUD

### Phase 6 — 단발 거래 (`/v2/transactions`)
- [ ] 모바일 친화 카드 리스트 + 필터(소유자/카테고리/월)
- [ ] 등록 모달
- [ ] 월별 통계 (기존 통계 리뉴얼)

### Phase 7 — 마무리
- [ ] `/` 기본 진입을 `/v2`로 변경
- [ ] README/CLAUDE.md 업데이트
- [ ] main 으로 머지 vs 별도 배포 결정

## 작업 재개 시 체크리스트

세션이 끊겨서 다시 시작할 때:
1. `git status` — 미커밋 변경 확인
2. `git log --oneline -5` — 마지막 커밋 확인
3. 이 문서의 체크리스트에서 ⬅ 표시된 단계 또는 마지막 체크 안 된 항목 확인
4. 해당 단계의 산출물(파일) 존재 여부 확인 후 이어서 진행

## 참고 — 기존 구조 (건드리지 않음)
- `src/lib/api.js` — row_data 기반 API
- `src/views/HomeView.vue` — 기존 대시보드 (차트, 캘린더)
- `src/views/RegistrationView.vue` — TUI Grid 기반 등록/관리
- `supabase/schema.sql` — 기존 4개 테이블
