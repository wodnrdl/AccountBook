<template>
  <div class="v2-page assets">
    <div class="d-flex align-items-center justify-content-between mb-3 flex-wrap gap-2">
      <h2 class="page-title m-0"><i class="fas fa-wallet"></i> 자산</h2>
      <div class="d-flex gap-2">
        <button class="btn btn-sm btn-light" @click="reload" :disabled="loading">
          <i class="fas fa-sync-alt" :class="{ 'fa-spin': loading }"></i>
        </button>
      </div>
    </div>

    <!-- 요약 -->
    <div class="row g-3 mb-3">
      <div class="col-12 col-md-4">
        <div class="card stat asset"><div class="stat-label">자산 합계</div>
          <div class="stat-value">{{ won(assetTotal) }}</div></div>
      </div>
      <div class="col-12 col-md-4">
        <div class="card stat liab"><div class="stat-label">부채 합계</div>
          <div class="stat-value text-danger">{{ won(liabTotal) }}</div></div>
      </div>
      <div class="col-12 col-md-4">
        <div class="card stat net"><div class="stat-label">순자산</div>
          <div class="stat-value" :class="net < 0 ? 'text-danger' : ''">{{ won(net) }}</div></div>
      </div>
    </div>

    <!-- 소유자 필터 -->
    <div class="owner-tabs mb-3">
      <button class="owner-tab" :class="{ active: filterOwner === 'all' }" @click="filterOwner = 'all'">
        전체 <span class="cnt">{{ accounts.length }}</span>
      </button>
      <button v-for="o in OWNERS" :key="o" class="owner-tab"
              :class="{ active: filterOwner === o }" @click="filterOwner = o">
        {{ o }} <span class="cnt">{{ countByOwner[o] || 0 }}</span>
      </button>
    </div>

    <!-- 추이 차트 -->
    <div class="card section mb-3">
      <div class="section-head">
        <div>
          <div class="section-title"><i class="fas fa-chart-line text-primary"></i> 월별 추이</div>
          <div class="section-sub text-muted">소유자별 자산 합계 (최근 6개월)</div>
        </div>
      </div>
      <LineChart v-if="chartMonths.length" :months="chartMonths" :series="chartSeries" />
      <div v-else class="text-muted small">스냅샷 데이터 없음</div>
    </div>

    <!-- 계좌 카드 -->
    <div v-if="loading && !accounts.length" class="text-muted">불러오는 중...</div>
    <div v-else>
      <div v-for="(group, owner) in displayGroups" :key="owner" class="mb-3">
        <div class="group-head">
          <span class="owner-badge" :style="{ background: ownerColor(owner) }">{{ owner }}</span>
          <span class="text-muted small">합계 {{ won(sumOf(group)) }}</span>
        </div>
        <div class="row g-2">
          <div v-for="a in group" :key="a.id" class="col-12 col-md-6 col-xl-4">
            <div class="card account-card clickable"
                 :class="{ liability: a.is_liability }"
                 title="클릭하여 이용 내역 보기"
                 @click="openHistory(a)">
              <div class="ac-head">
                <div class="ac-tags">
                  <span class="badge bg-light text-dark me-1">{{ typeLabel(a.type) }}</span>
                  <span v-if="a.is_liability" class="badge bg-danger me-1">부채</span>
                  <span v-if="a.tx_default" class="badge bg-warning text-dark me-1" title="기본 결제 계좌"><i class="fas fa-star"></i> 기본</span>
                  <span v-else-if="a.tx_enabled" class="badge bg-info text-dark me-1" title="거래에서 선택 가능"><i class="fas fa-credit-card"></i> 거래용</span>
                </div>
                <div class="ac-actions" @click.stop>
                  <button class="icon-btn" title="잔액 수정" @click="openBalance(a)">
                    <i class="fas fa-coins"></i>
                  </button>
                  <button class="icon-btn" title="편집" @click="openEdit(a)">
                    <i class="fas fa-pen"></i>
                  </button>
                  <button class="icon-btn danger" title="삭제" @click="confirmDelete(a)">
                    <i class="fas fa-trash"></i>
                  </button>
                </div>
              </div>
              <div class="ac-name">{{ a.name }}</div>
              <div class="ac-balance" :class="a.is_liability ? 'text-danger' : ''">{{ won(displayBalance(a)) }}</div>
              <div v-if="a.memo" class="ac-memo text-muted small">{{ a.memo }}</div>
            </div>
          </div>
        </div>
      </div>
      <div v-if="!filteredAccounts.length" class="text-muted small">표시할 계좌 없음</div>
    </div>

    <!-- 계좌 추가/편집 모달 -->
    <Modal v-model="formOpen" :title="form.id ? '계좌 편집' : '계좌 추가'" size="md">
      <div class="mb-2">
        <label class="form-label small">이름</label>
        <input v-model="form.name" class="form-control" placeholder="예: 우리 예금1" />
      </div>
      <div class="row g-2 mb-2">
        <div class="col-6">
          <label class="form-label small">타입</label>
          <select v-model="form.type" class="form-select">
            <option v-for="t in ACCOUNT_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
          </select>
        </div>
        <div class="col-6">
          <label class="form-label small">소유자</label>
          <select v-model="form.owner" class="form-select">
            <option v-for="o in OWNERS" :key="o" :value="o">{{ o }}</option>
          </select>
        </div>
      </div>
      <div class="row g-2 mb-2">
        <div class="col-12">
          <label class="form-label small">{{ form.id ? '잔액(편집은 별도 잔액수정 권장)' : '초기 잔액' }}</label>
          <input v-model.number="form.balance" type="number" class="form-control" />
        </div>
      </div>
      <div class="form-check mb-2">
        <input id="isLiab" v-model="form.is_liability" type="checkbox" class="form-check-input" />
        <label for="isLiab" class="form-check-label small">부채 (대출 등)</label>
      </div>

      <hr class="my-2" />
      <div class="form-check mb-1">
        <input id="txEnabled" v-model="form.tx_enabled" type="checkbox" class="form-check-input"
               @change="onTxEnabledChange" />
        <label for="txEnabled" class="form-check-label small">
          <i class="fas fa-credit-card text-info"></i> 거래에서 사용
          <span class="text-muted ms-1">(거래 등록 시 계좌 셀렉트에 노출)</span>
        </label>
      </div>
      <div class="form-check mb-2">
        <input id="txDefault" v-model="form.tx_default" type="checkbox" class="form-check-input"
               :disabled="!form.tx_enabled" />
        <label for="txDefault" class="form-check-label small">
          <i class="fas fa-star text-warning"></i> 기본 결제 계좌로 사용
          <span class="text-muted ms-1">(거래 추가 시 자동 선택)</span>
        </label>
      </div>

      <div class="mb-2">
        <label class="form-label small">메모</label>
        <input v-model="form.memo" class="form-control" />
      </div>
      <template #footer>
        <button class="btn btn-light" @click="formOpen = false">취소</button>
        <button class="btn btn-primary" :disabled="!form.name || saving" @click="saveForm">
          <i v-if="saving" class="fas fa-spinner fa-spin"></i>
          {{ form.id ? '저장' : '추가' }}
        </button>
      </template>
    </Modal>

    <!-- 잔액 수정 모달 -->
    <Modal v-model="balanceOpen" title="잔액 수정" size="sm">
      <div v-if="balTarget" class="mb-2 small text-muted">
        <strong>{{ balTarget.name }}</strong> · 현재 {{ won(balTarget.balance) }}
      </div>
      <div class="mb-2">
        <label class="form-label small">새 잔액</label>
        <input v-model.number="balForm.balance" type="number" class="form-control" autofocus />
      </div>
      <div class="mb-2">
        <label class="form-label small">적용 월 (스냅샷 기록)</label>
        <input v-model="balForm.ym" class="form-control" placeholder="2026-05" />
      </div>
      <template #footer>
        <button class="btn btn-light" @click="balanceOpen = false">취소</button>
        <button class="btn btn-primary" :disabled="saving" @click="saveBalance">
          <i v-if="saving" class="fas fa-spinner fa-spin"></i> 저장
        </button>
      </template>
    </Modal>

    <!-- 이용 내역 모달 -->
    <Modal v-model="historyOpen" :title="historyTarget ? `${historyTarget.name} 이용 내역` : '이용 내역'" size="md">
      <div v-if="historyTarget" class="hist-summary mb-2 d-flex align-items-center flex-wrap gap-2">
        <span class="badge bg-light text-dark">{{ typeLabel(historyTarget.type) }}</span>
        <span class="text-muted small">{{ historyTarget.owner }}</span>
        <strong class="ms-auto">{{ won(historyTarget.balance) }}</strong>
      </div>
      <div class="hist-month-picker mb-2">
        <button class="btn btn-light btn-sm" :disabled="historyLoading" @click="historyShiftMonth(-1)">
          <i class="fas fa-chevron-left"></i>
        </button>
        <span class="ym-label">{{ historyYm }}</span>
        <button class="btn btn-light btn-sm" :disabled="historyLoading" @click="historyShiftMonth(1)">
          <i class="fas fa-chevron-right"></i>
        </button>
      </div>
      <div v-if="historyLoading" class="text-muted small">불러오는 중...</div>
      <div v-else-if="!historyItems.length" class="text-muted small text-center py-3">이 달 거래 내역 없음</div>
      <ul v-else class="hist-list">
        <li v-for="t in historyItems" :key="t.id">
          <div class="hist-row">
            <span class="hist-date small text-muted">{{ t.date }}</span>
            <span class="hist-cat">
              {{ t.category || '미분류' }}
              <span v-if="t.recurring_id" class="badge bg-info text-dark ms-1">자동</span>
            </span>
            <strong :class="t.kind === 'income' ? 'text-success' : 'text-danger'">
              {{ t.kind === 'income' ? '+' : '-' }}{{ won(t.amount) }}
            </strong>
          </div>
          <div v-if="t.memo" class="hist-memo small text-muted">{{ t.memo }}</div>
        </li>
      </ul>
      <template #footer>
        <button class="btn btn-light" @click="historyOpen = false">닫기</button>
      </template>
    </Modal>

    <!-- 삭제 확인 -->
    <Modal v-model="deleteOpen" title="계좌 삭제" size="sm">
      <p class="mb-1">정말 삭제하시겠어요?</p>
      <p v-if="delTarget" class="small text-muted m-0">
        {{ delTarget.name }} ({{ delTarget.owner }}, {{ won(delTarget.balance) }})<br />
        스냅샷 기록도 함께 삭제됩니다.
      </p>
      <template #footer>
        <button class="btn btn-light" @click="deleteOpen = false">취소</button>
        <button class="btn btn-danger" :disabled="saving" @click="doDelete">
          <i v-if="saving" class="fas fa-spinner fa-spin"></i> 삭제
        </button>
      </template>
    </Modal>

    <FabAdd label="계좌 추가" @click="openCreate" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  createAccount, updateAccount, deleteAccount, updateBalance,
  setDefaultPaymentAccount, clearDefaultPaymentAccount,
  listSnapshotsRange,
  listTransactions,
  fetchDashboard,
  won, ymNow,
  ACCOUNT_TYPES, OWNERS,
} from '../../lib/api_v2.js'
import LineChart from './components/LineChart.vue'
import Modal from './components/Modal.vue'
import FabAdd from './components/FabAdd.vue'

const OWNER_COLORS = {
  '재욱':   '#5e72e4',
  '공주님': '#f5365c',
  '공동':   '#2dce89',
}
const ownerColor = (o) => OWNER_COLORS[o] || '#8898aa'
const typeLabel = (t) => ACCOUNT_TYPES.find(x => x.value === t)?.label || t

const accounts = ref([])
const snapshots = ref([])
const loading = ref(true)
const saving = ref(false)

// 실시간 계산 override 값 (fetchDashboard 결과와 동일 소스 → 대시보드와 순자산 일치)
const surplus = ref(0)              // 가용 잉여 → "총수입" 계좌 표시값
const livingRemaining = ref(0)      // 거래 페이지 잔여 → "생활비" 봉투 표시값
const mainAccountId = ref(null)     // 총수입 계좌 id (fetchDashboard 가 판별)

// 계좌 카드에 실제로 보여줄 값 (특정 계좌는 계산값으로 override)
function displayBalance(a) {
  if (a.tx_default) return livingRemaining.value
  if (a.id === mainAccountId.value) return surplus.value
  return Number(a.balance)
}

const filterOwner = ref('all')

// 합계
const assetTotal = computed(() => accounts.value.filter(a => !a.is_liability).reduce((s, a) => s + displayBalance(a), 0))
const liabTotal  = computed(() => accounts.value.filter(a =>  a.is_liability).reduce((s, a) => s + displayBalance(a), 0))
const net = computed(() => assetTotal.value - liabTotal.value)

const countByOwner = computed(() => {
  const c = {}
  for (const a of accounts.value) c[a.owner] = (c[a.owner] || 0) + 1
  return c
})

const filteredAccounts = computed(() => {
  if (filterOwner.value === 'all') return accounts.value
  return accounts.value.filter(a => a.owner === filterOwner.value)
})

const displayGroups = computed(() => {
  const g = {}
  for (const a of filteredAccounts.value) {
    if (!g[a.owner]) g[a.owner] = []
    g[a.owner].push(a)
  }
  // 정렬: 정의된 OWNERS 순서
  const ordered = {}
  for (const o of OWNERS) if (g[o]) ordered[o] = g[o]
  return ordered
})

const sumOf = (list) => list.reduce((s, a) => s + (a.is_liability ? -1 : 1) * displayBalance(a), 0)

// 차트: 최근 6개월, 소유자별 자산 합계
const chartMonths = computed(() => {
  const now = new Date()
  const arr = []
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    arr.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`)
  }
  return arr
})

const chartSeries = computed(() => {
  // ownerId 별로 month 합계 만들기
  // snapshot row: { account_id, year_month, balance }
  const accById = {}
  for (const a of accounts.value) accById[a.id] = a

  return OWNERS
    .filter(o => countByOwner.value[o]) // 계좌 있는 소유자만
    .map(o => {
      const values = chartMonths.value.map(ym => {
        let total = 0
        let any = false
        for (const a of accounts.value) {
          if (a.owner !== o || a.is_liability) continue
          // 해당 ym 의 스냅샷 (없으면 가장 최근 ≤ ym)
          const candidates = snapshots.value.filter(s => s.account_id === a.id && s.year_month <= ym)
          if (!candidates.length) continue
          candidates.sort((x, y) => x.year_month < y.year_month ? -1 : 1)
          total += Number(candidates[candidates.length - 1].balance)
          any = true
        }
        return any ? total : null
      })
      return { label: o, color: ownerColor(o), values }
    })
})

// 폼 상태
const formOpen = ref(false)
const form = ref(emptyForm())
function emptyForm() {
  return {
    id: null, name: '', type: 'savings', owner: '재욱',
    balance: 0, is_liability: false,
    tx_enabled: false, tx_default: false,
    memo: '',
  }
}
function openCreate() { form.value = emptyForm(); formOpen.value = true }
function openEdit(a) {
  form.value = {
    id: a.id, name: a.name, type: a.type, owner: a.owner,
    balance: a.balance, is_liability: a.is_liability,
    tx_enabled: !!a.tx_enabled, tx_default: !!a.tx_default,
    memo: a.memo || '',
  }
  formOpen.value = true
}
function onTxEnabledChange() {
  if (!form.value.tx_enabled) form.value.tx_default = false
}
async function saveForm() {
  saving.value = true
  try {
    const wantDefault = !!form.value.tx_default && !!form.value.tx_enabled
    const payload = {
      name: form.value.name.trim(),
      type: form.value.type,
      owner: form.value.owner,
      balance: Number(form.value.balance) || 0,
      is_liability: !!form.value.is_liability,
      tx_enabled: !!form.value.tx_enabled,
      // 기본값 처리는 setDefaultPaymentAccount 로 따로 처리
      tx_default: false,
      memo: form.value.memo || null,
    }
    let id = form.value.id
    if (id) {
      await updateAccount(id, payload)
    } else {
      const a = await createAccount(payload)
      id = a.id
      await updateBalance(a.id, payload.balance, ymNow())
    }
    if (wantDefault) {
      await setDefaultPaymentAccount(id)
    } else if (form.value.id) {
      // 기존에 기본이었는데 해제된 경우만 기본 해제
      const wasDefault = accounts.value.find(x => x.id === id)?.tx_default
      if (wasDefault) await clearDefaultPaymentAccount()
    }
    formOpen.value = false
    await reload()
  } finally { saving.value = false }
}

// 잔액 수정
const balanceOpen = ref(false)
const balTarget = ref(null)
const balForm = ref({ balance: 0, ym: ymNow() })
function openBalance(a) {
  balTarget.value = a
  balForm.value = { balance: a.balance, ym: ymNow() }
  balanceOpen.value = true
}
async function saveBalance() {
  if (!balTarget.value) return
  saving.value = true
  try {
    await updateBalance(balTarget.value.id, Number(balForm.value.balance) || 0, balForm.value.ym)
    balanceOpen.value = false
    await reload()
  } finally { saving.value = false }
}

// 이용 내역
const historyOpen = ref(false)
const historyTarget = ref(null)
const historyItems = ref([])
const historyLoading = ref(false)
const historyYm = ref(ymNow())

const historyUsed = computed(() =>
  historyItems.value.filter(t => t.kind === 'expense').reduce((s, t) => s + Number(t.amount || 0), 0)
)
const historyIncome = computed(() =>
  historyItems.value.filter(t => t.kind === 'income').reduce((s, t) => s + Number(t.amount || 0), 0)
)

async function loadHistory() {
  if (!historyTarget.value) return
  historyLoading.value = true
  try {
    historyItems.value = await listTransactions({
      accountId: historyTarget.value.id,
      ym: historyYm.value,
      includeRecurring: true,
    })
  } finally { historyLoading.value = false }
}

async function openHistory(a) {
  historyTarget.value = a
  historyItems.value = []
  historyYm.value = ymNow()
  historyOpen.value = true
  await loadHistory()
}

function historyShiftMonth(delta) {
  const [y, m] = historyYm.value.split('-').map(Number)
  const d = new Date(y, m - 1 + delta, 1)
  historyYm.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  loadHistory()
}

// 삭제
const deleteOpen = ref(false)
const delTarget = ref(null)
function confirmDelete(a) { delTarget.value = a; deleteOpen.value = true }
async function doDelete() {
  if (!delTarget.value) return
  saving.value = true
  try {
    await deleteAccount(delTarget.value.id)
    deleteOpen.value = false
    await reload()
  } finally { saving.value = false }
}

async function reload() {
  loading.value = true
  try {
    const ym = ymNow()
    // fetchDashboard 가 accounts + surplus + living(잔여) + mainAccountId 를 한 번에 반환 → 중복 호출 제거
    const dash = await fetchDashboard(ym)
    accounts.value = dash.accounts
    surplus.value = dash.recurring.surplus
    livingRemaining.value = Number(dash.living?.remaining || 0)
    mainAccountId.value = dash.mainAccountId
    if (chartMonths.value.length) {
      snapshots.value = await listSnapshotsRange(chartMonths.value[0], chartMonths.value[chartMonths.value.length - 1])
    }
  } finally { loading.value = false }
}

onMounted(reload)
</script>

<style scoped>
.page-title { display: flex; align-items: center; gap: 0.5rem; }
.section { border: none; border-radius: 12px; padding: 1.1rem; background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.04); }
.section-head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.75rem; }
.section-title { font-size: 1rem; font-weight: 700; color: #32325d; }
.section-sub { font-size: 0.8rem; }

.stat {
  border: none; border-radius: 12px; padding: 1rem;
  background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  border-left: 4px solid #5e72e4;
  height: 100%;
  display: flex; flex-direction: column; justify-content: center;
}
.stat.asset { border-left-color: #2dce89; }
.stat.liab  { border-left-color: #f5365c; }
.stat.net   { border-left-color: #5e72e4; }
.stat-label { font-size: 0.78rem; color: #8898aa; font-weight: 600; text-transform: uppercase; }
.stat-value { font-size: 1.4rem; font-weight: 700; color: #32325d; }

.owner-tabs {
  display: flex; flex-wrap: wrap; gap: 0.4rem;
  background: #fff; border-radius: 999px; padding: 0.3rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}
.owner-tab {
  border: none; background: transparent;
  padding: 0.4rem 0.9rem; border-radius: 999px;
  font-size: 0.85rem; color: #525f7f; font-weight: 600;
  cursor: pointer; display: flex; align-items: center; gap: 0.3rem;
}
.owner-tab:hover { background: #f0f3f7; }
.owner-tab.active { background: #5e72e4; color: #fff; }
.owner-tab .cnt { font-size: 0.7rem; opacity: 0.8; padding: 0 0.4rem; background: rgba(255,255,255,0.25); border-radius: 999px; }
.owner-tab:not(.active) .cnt { background: #e9ecef; }

.group-head {
  display: flex; align-items: center; gap: 0.5rem;
  margin: 0.75rem 0 0.5rem; padding: 0 0.25rem;
}
.owner-badge {
  color: #fff; padding: 0.15rem 0.6rem; border-radius: 999px;
  font-size: 0.78rem; font-weight: 700;
}

.account-card {
  border: none; border-radius: 12px; padding: 0.9rem 1rem;
  background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  height: 100%;
  border-left: 3px solid #5e72e4;
  transition: box-shadow 0.15s ease, transform 0.15s ease;
}
.account-card.liability { border-left-color: #f5365c; background: #fff7f8; }
.account-card.clickable { cursor: pointer; }
.account-card.clickable:hover {
  box-shadow: 0 6px 16px rgba(0,0,0,0.08);
  transform: translateY(-1px);
}

.hist-summary {
  padding: 0.5rem 0.75rem; background: #f9fbfd; border-radius: 8px;
}
.hist-month-picker {
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0.4rem 0.5rem; background: #fff; border: 1px solid #e9ecef;
  border-radius: 8px;
}
.hist-month-picker .ym-label {
  font-weight: 600; min-width: 5.5rem; text-align: center; color: #32325d;
}
.hist-list { list-style: none; padding: 0; margin: 0; }
.hist-list li {
  padding: 0.55rem 0.25rem;
  border-bottom: 1px dashed #f0f3f7;
}
.hist-list li:last-child { border-bottom: none; }
.hist-row {
  display: flex; align-items: center; gap: 0.6rem;
  font-size: 0.92rem;
}
.hist-date { flex: 0 0 5.5rem; }
.hist-cat {
  flex: 1 1 auto; min-width: 0;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  color: #32325d; font-weight: 500;
}
.hist-memo { padding-left: 5.9rem; margin-top: 0.15rem; }
.ac-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.4rem; }
.ac-actions { display: flex; gap: 0.15rem; }
.ac-name { font-weight: 600; color: #32325d; }
.ac-balance { font-size: 1.25rem; font-weight: 700; color: #32325d; margin-top: 0.2rem; }
.ac-memo { margin-top: 0.25rem; }

.icon-btn {
  width: 28px; height: 28px; border-radius: 6px;
  background: transparent; border: none; color: #8898aa; cursor: pointer;
}
.icon-btn:hover { background: #f0f3f7; color: #5e72e4; }
.icon-btn.danger:hover { color: #f5365c; }
</style>
