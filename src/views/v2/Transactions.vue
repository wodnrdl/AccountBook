<template>
  <div class="v2-page transactions">
    <div class="d-flex align-items-center justify-content-between mb-3 flex-wrap gap-2">
      <h2 class="page-title m-0"><i class="fas fa-edit"></i> 거래</h2>
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-light btn-sm" @click="shiftMonth(-1)" :disabled="loading">
          <i class="fas fa-chevron-left"></i>
        </button>
        <span class="ym-label">{{ ym }}</span>
        <button class="btn btn-light btn-sm" @click="shiftMonth(1)" :disabled="loading">
          <i class="fas fa-chevron-right"></i>
        </button>
        <button class="btn btn-sm btn-light" @click="reload" :disabled="loading" title="새로고침">
          <i class="fas fa-sync-alt" :class="{ 'fa-spin': loading }"></i>
        </button>
        <button class="btn btn-sm btn-primary" @click="openCreate">
          <i class="fas fa-plus"></i> 추가
        </button>
      </div>
    </div>

    <!-- 요약 -->
    <div class="row g-2 mb-3">
      <div class="col-6 col-md-3">
        <div class="card stat carry"><div class="stat-label">이월</div>
          <div class="stat-value" :class="totals.carryOver < 0 ? 'text-danger' : ''">{{ won(totals.carryOver) }}</div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card stat income"><div class="stat-label">이번달 수입</div>
          <div class="stat-value text-success">+{{ won(totals.income) }}</div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card stat expense"><div class="stat-label">이번달 지출</div>
          <div class="stat-value text-danger">-{{ won(totals.expense) }}</div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card stat net" :class="{ neg: totals.remaining < 0 }">
          <div class="stat-label">잔여 (이월포함)</div>
          <div class="stat-value">{{ won(totals.remaining) }}</div></div>
      </div>
    </div>

    <!-- 카테고리 통계 -->
    <div v-if="categoryStats.length" class="card section mb-3">
      <div class="section-head">
        <div class="section-title"><i class="fas fa-chart-pie text-primary"></i> 카테고리별 지출</div>
      </div>
      <div class="cat-stats">
        <div v-for="c in categoryStats" :key="c.name" class="cat-row">
          <div class="cat-line">
            <span class="cat-name">{{ c.name }}</span>
            <span class="text-muted small">{{ c.count }}건</span>
            <strong class="ms-auto">{{ won(c.total) }}</strong>
          </div>
          <div class="cat-bar"><div class="cat-fill" :style="{ width: c.pct + '%' }"></div></div>
        </div>
      </div>
    </div>

    <!-- 필터 -->
    <div class="filter-bar mb-3">
      <div class="kind-filter">
        <button class="f-btn" :class="{ active: filters.kind === 'all' }" @click="filters.kind = 'all'">전체</button>
        <button class="f-btn" :class="{ active: filters.kind === 'income' }" @click="filters.kind = 'income'">수입</button>
        <button class="f-btn" :class="{ active: filters.kind === 'expense' }" @click="filters.kind = 'expense'">지출</button>
      </div>
      <select v-model="filters.owner" class="form-select form-select-sm">
        <option value="all">소유자: 전체</option>
        <option v-for="o in OWNERS" :key="o" :value="o">{{ o }}</option>
      </select>
      <select v-model="filters.category" class="form-select form-select-sm">
        <option value="all">카테고리: 전체</option>
        <option v-for="c in availableCategories" :key="c" :value="c">{{ c }}</option>
      </select>
    </div>

    <!-- 리스트 -->
    <div v-if="loading" class="text-muted">불러오는 중...</div>
    <div v-else-if="!filtered.length" class="empty-state">
      <i class="fas fa-receipt fa-2x text-muted mb-2"></i>
      <p class="text-muted">표시할 거래가 없습니다</p>
      <button class="btn btn-sm btn-primary" @click="openCreate">
        <i class="fas fa-plus"></i> 첫 거래 등록
      </button>
    </div>
    <div v-else>
      <div v-for="grp in groupedByDate" :key="grp.date" class="date-group">
        <div class="date-head">
          <span class="date-label">{{ formatDate(grp.date) }}</span>
          <span class="date-total" :class="grp.net >= 0 ? 'text-success' : 'text-danger'">
            {{ grp.net >= 0 ? '+' : '-' }}{{ won(Math.abs(grp.net)) }}
          </span>
        </div>
        <ul class="tx-list">
          <li v-for="t in grp.items" :key="t.id">
            <span class="kind-dot" :class="`k-${t.kind}`"></span>
            <span class="tx-cat">{{ t.category || '미분류' }}</span>
            <span class="badge bg-light text-dark ms-2">{{ t.owner }}</span>
            <span v-if="t.account_id" class="text-muted small ms-2">{{ accountName(t.account_id) }}</span>
            <span v-if="t.memo" class="tx-memo text-muted small ms-2">— {{ t.memo }}</span>
            <strong class="ms-auto" :class="t.kind === 'income' ? 'text-success' : 'text-danger'">
              {{ t.kind === 'income' ? '+' : '-' }}{{ won(t.amount) }}
            </strong>
            <span class="actions ms-2">
              <button class="icon-btn" title="편집" @click="openEdit(t)">
                <i class="fas fa-pen"></i>
              </button>
              <button class="icon-btn danger" title="삭제" @click="confirmDelete(t)">
                <i class="fas fa-trash"></i>
              </button>
            </span>
          </li>
        </ul>
      </div>
    </div>

    <!-- 추가/편집 모달 -->
    <Modal v-model="formOpen" :title="form.id ? '거래 편집' : '거래 추가'" size="md">
      <div class="row g-2 mb-2">
        <div class="col-7">
          <label class="form-label small">날짜</label>
          <input v-model="form.date" type="date" class="form-control" />
        </div>
        <div class="col-5">
          <label class="form-label small">종류</label>
          <select v-model="form.kind" class="form-select">
            <option value="expense">지출</option>
            <option value="income">수입</option>
          </select>
        </div>
      </div>
      <div class="row g-2 mb-2">
        <div class="col-6">
          <label class="form-label small">금액</label>
          <input v-model.number="form.amount" type="number" class="form-control" />
        </div>
        <div class="col-6">
          <label class="form-label small">소유자</label>
          <select v-model="form.owner" class="form-select">
            <option v-for="o in OWNERS" :key="o" :value="o">{{ o }}</option>
          </select>
        </div>
      </div>
      <div class="mb-2">
        <label class="form-label small">카테고리</label>
        <input v-model="form.category" class="form-control" list="cat-suggest" placeholder="식비, 교통 등" />
        <datalist id="cat-suggest">
          <option v-for="c in suggestCategories" :key="c" :value="c" />
        </datalist>
      </div>
      <div class="mb-2">
        <label class="form-label small">계좌</label>
        <select v-if="paymentAccounts.length" v-model="form.account_id" class="form-select">
          <option :value="null">— 없음 —</option>
          <option v-for="a in paymentAccounts" :key="a.id" :value="a.id">
            {{ a.tx_default ? '⭐ ' : '' }}{{ a.owner }} · {{ a.name }}
          </option>
        </select>
        <div v-else class="form-text text-warning small">
          <i class="fas fa-info-circle"></i>
          결제용으로 지정된 계좌가 없습니다. <router-link to="/v2/assets">자산 관리</router-link> 에서 "거래에서 사용" 을 켜주세요.
        </div>
      </div>
      <div class="mb-2">
        <label class="form-label small">메모</label>
        <input v-model="form.memo" class="form-control" />
      </div>
      <template #footer>
        <button class="btn btn-light" @click="formOpen = false">취소</button>
        <button class="btn btn-primary" :disabled="!form.amount || saving" @click="saveForm">
          <i v-if="saving" class="fas fa-spinner fa-spin"></i>
          {{ form.id ? '저장' : '추가' }}
        </button>
      </template>
    </Modal>

    <!-- 삭제 확인 -->
    <Modal v-model="deleteOpen" title="거래 삭제" size="sm">
      <p class="mb-1">정말 삭제하시겠어요?</p>
      <p v-if="delTarget" class="small text-muted m-0">
        {{ delTarget.date }} · {{ delTarget.category || '미분류' }} · {{ won(delTarget.amount) }}
      </p>
      <template #footer>
        <button class="btn btn-light" @click="deleteOpen = false">취소</button>
        <button class="btn btn-danger" :disabled="saving" @click="doDelete">
          <i v-if="saving" class="fas fa-spinner fa-spin"></i> 삭제
        </button>
      </template>
    </Modal>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  listTransactions, createTransaction, updateTransaction, deleteTransaction,
  listAccounts, listPaymentAccounts,
  fetchLivingBudgetStatus,
  won, OWNERS,
} from '../../lib/api_v2.js'
import Modal from './components/Modal.vue'

const SUGGEST_EXPENSE = ['식비', '카페', '교통', '쇼핑', '생활', '의료', '여가', '교육', '통신', '미용', '기타']
const SUGGEST_INCOME  = ['보너스', '부수입', '환급', '용돈', '기타']

const today = new Date()
const year  = ref(today.getFullYear())
const month = ref(today.getMonth() + 1)
const ym = computed(() => `${year.value}-${String(month.value).padStart(2, '0')}`)

const items = ref([])
const accounts = ref([])         // 모든 계좌 (목록의 계좌명 표시용)
const paymentAccounts = ref([])  // tx_enabled=true 만 (모달 셀렉트용)
const livingStatus = ref(null)   // 생활비 봉투 carry-over 정보
const loading = ref(true)
const saving = ref(false)

const defaultPaymentId = computed(() => paymentAccounts.value.find(a => a.tx_default)?.id || null)

const filters = ref({ kind: 'all', owner: 'all', category: 'all' })

const accountName = (id) => {
  const a = accounts.value.find(x => x.id === id)
  return a ? a.name : ''
}

const filtered = computed(() => {
  return items.value.filter(t => {
    if (filters.value.kind !== 'all' && t.kind !== filters.value.kind) return false
    if (filters.value.owner !== 'all' && t.owner !== filters.value.owner) return false
    if (filters.value.category !== 'all' && (t.category || '미분류') !== filters.value.category) return false
    return true
  })
})

const totals = computed(() => {
  const income  = filtered.value.filter(t => t.kind === 'income').reduce((s, t) => s + Number(t.amount), 0)
  const expense = filtered.value.filter(t => t.kind === 'expense').reduce((s, t) => s + Number(t.amount), 0)
  const carryOver = livingStatus.value?.carryOver || 0
  // 잔여 = 이월 + 이번달 수입 - 이번달 지출 (v1 의 이월 누적 계산과 동일)
  return { income, expense, carryOver, remaining: carryOver + income - expense }
})

const availableCategories = computed(() => {
  const set = new Set()
  for (const t of items.value) set.add(t.category || '미분류')
  return [...set].sort()
})

const categoryStats = computed(() => {
  // 지출만 (수입 제외)
  const expenses = filtered.value.filter(t => t.kind === 'expense')
  const total = expenses.reduce((s, t) => s + Number(t.amount), 0)
  if (!total) return []
  const map = {}
  for (const t of expenses) {
    const k = t.category || '미분류'
    if (!map[k]) map[k] = { name: k, total: 0, count: 0 }
    map[k].total += Number(t.amount)
    map[k].count += 1
  }
  return Object.values(map)
    .map(c => ({ ...c, pct: Math.round((c.total / total) * 100) }))
    .sort((a, b) => b.total - a.total)
})

const groupedByDate = computed(() => {
  const map = {}
  for (const t of filtered.value) {
    if (!map[t.date]) map[t.date] = { date: t.date, items: [], net: 0 }
    map[t.date].items.push(t)
    map[t.date].net += (t.kind === 'income' ? 1 : -1) * Number(t.amount)
  }
  return Object.values(map).sort((a, b) => a.date < b.date ? 1 : -1)
})

function formatDate(d) {
  const dt = new Date(d)
  const days = ['일', '월', '화', '수', '목', '금', '토']
  return `${d} (${days[dt.getDay()]})`
}

// 폼
const formOpen = ref(false)
const form = ref(emptyForm())
function emptyForm() {
  return {
    id: null,
    date: new Date().toISOString().slice(0, 10),
    kind: 'expense',
    amount: 0,
    category: '',
    owner: '재욱',
    account_id: defaultPaymentId.value,
    memo: '',
  }
}
const suggestCategories = computed(() => form.value.kind === 'income' ? SUGGEST_INCOME : SUGGEST_EXPENSE)

function openCreate() {
  form.value = emptyForm()
  // 화면에서 보고있는 월의 1일을 기본 날짜로 (현재 월이 아니면)
  const cur = new Date()
  const curYm = `${cur.getFullYear()}-${String(cur.getMonth() + 1).padStart(2, '0')}`
  if (ym.value !== curYm) form.value.date = `${ym.value}-01`
  formOpen.value = true
}

function openEdit(t) {
  form.value = {
    id: t.id, date: t.date, kind: t.kind,
    amount: t.amount, category: t.category || '',
    owner: t.owner, account_id: t.account_id, memo: t.memo || '',
  }
  formOpen.value = true
}

async function saveForm() {
  saving.value = true
  try {
    const payload = {
      date: form.value.date,
      kind: form.value.kind,
      amount: Number(form.value.amount) || 0,
      category: form.value.category.trim() || null,
      owner: form.value.owner,
      account_id: form.value.account_id || null,
      memo: form.value.memo || null,
    }
    if (form.value.id) {
      await updateTransaction(form.value.id, payload)
    } else {
      await createTransaction(payload)
    }
    formOpen.value = false
    await reload()
  } finally { saving.value = false }
}

// 삭제
const deleteOpen = ref(false)
const delTarget = ref(null)
function confirmDelete(t) { delTarget.value = t; deleteOpen.value = true }
async function doDelete() {
  if (!delTarget.value) return
  saving.value = true
  try {
    await deleteTransaction(delTarget.value.id)
    deleteOpen.value = false
    await reload()
  } finally { saving.value = false }
}

async function reload() {
  loading.value = true
  // 이전 달 거래 잔상 제거
  items.value = []
  livingStatus.value = null
  try {
    const [txs, accs, pays, lbs] = await Promise.all([
      listTransactions({ ym: ym.value }),
      listAccounts(),
      listPaymentAccounts(),
      fetchLivingBudgetStatus(ym.value),
    ])
    items.value = txs
    accounts.value = accs
    paymentAccounts.value = pays
    livingStatus.value = lbs
  } finally { loading.value = false }
}

function shiftMonth(delta) {
  let y = year.value, m = month.value + delta
  if (m < 1)  { m = 12; y-- }
  if (m > 12) { m = 1;  y++ }
  year.value = y; month.value = m
  reload()
}

onMounted(reload)
</script>

<style scoped>
.page-title { display: flex; align-items: center; gap: 0.5rem; }
.ym-label { font-weight: 600; min-width: 5.5rem; text-align: center; }

.section { border: none; border-radius: 12px; padding: 1rem 1.1rem; background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.04); }
.section-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.6rem; }
.section-title { font-size: 1rem; font-weight: 700; color: #32325d; }

.stat {
  border: none; border-radius: 12px; padding: 0.85rem 1rem;
  background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  border-left: 4px solid #5e72e4;
  height: 100%;
}
.stat.carry   { border-left-color: #8898aa; }
.stat.income  { border-left-color: #2dce89; }
.stat.expense { border-left-color: #f5365c; }
.stat.net     { border-left-color: #11cdef; }
.stat.net.neg { border-left-color: #f5365c; }
.stat.net.neg .stat-value { color: #f5365c; }
.stat-label { font-size: 0.72rem; color: #8898aa; font-weight: 600; text-transform: uppercase; }
.stat-value { font-size: 1.15rem; font-weight: 700; color: #32325d; }

/* 카테고리 통계 */
.cat-stats { display: flex; flex-direction: column; gap: 0.5rem; }
.cat-row {}
.cat-line { display: flex; align-items: center; gap: 0.5rem; font-size: 0.92rem; margin-bottom: 0.2rem; }
.cat-name { font-weight: 500; color: #32325d; }
.cat-bar { width: 100%; height: 6px; background: #f0f3f7; border-radius: 999px; overflow: hidden; }
.cat-fill { height: 100%; background: linear-gradient(90deg, #5e72e4 0, #825ee4 100%); border-radius: 999px; transition: width 0.3s ease; }

/* 필터 바 */
.filter-bar {
  display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center;
}
.kind-filter {
  display: flex; background: #fff; border-radius: 999px; padding: 0.25rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}
.f-btn {
  border: none; background: transparent;
  padding: 0.35rem 1rem; border-radius: 999px;
  font-size: 0.85rem; color: #525f7f; font-weight: 600;
  cursor: pointer;
}
.f-btn:hover { background: #f0f3f7; }
.f-btn.active { background: #5e72e4; color: #fff; }
.filter-bar select { width: auto; min-width: 7rem; }

/* 빈 상태 */
.empty-state {
  text-align: center; padding: 3rem 1rem;
  background: #fff; border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}

/* 날짜 그룹 */
.date-group {
  background: #fff; border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  padding: 0.75rem 1rem;
  margin-bottom: 0.75rem;
}
.date-head {
  display: flex; justify-content: space-between; align-items: center;
  padding-bottom: 0.4rem; border-bottom: 2px solid #f0f3f7; margin-bottom: 0.3rem;
}
.date-label { font-weight: 600; color: #32325d; }
.date-total { font-weight: 700; }

.tx-list { list-style: none; padding: 0; margin: 0; }
.tx-list li {
  display: flex; align-items: center; gap: 0.3rem;
  padding: 0.5rem 0;
  border-bottom: 1px dashed #f0f3f7;
  font-size: 0.92rem;
}
.tx-list li:last-child { border-bottom: none; }
.tx-cat { font-weight: 600; color: #32325d; }
.tx-memo { font-style: italic; }
.kind-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.kind-dot.k-income  { background: #2dce89; }
.kind-dot.k-expense { background: #f5365c; }

.actions { display: flex; gap: 0.1rem; }
.icon-btn {
  width: 28px; height: 28px; border-radius: 6px;
  background: transparent; border: none; color: #8898aa; cursor: pointer;
}
.icon-btn:hover { background: #f0f3f7; color: #5e72e4; }
.icon-btn.danger:hover { color: #f5365c; }

@media (max-width: 575px) {
  .tx-list li { flex-wrap: wrap; }
  .tx-list li strong { margin-left: auto; }
  .actions { margin-left: auto; }
  .stat-value { font-size: 1rem; }
}
</style>
