<template>
  <div class="v2-page recurring">
    <div class="d-flex align-items-center justify-content-between mb-3 flex-wrap gap-2">
      <h2 class="page-title m-0"><i class="fas fa-sync-alt"></i> 고정지출</h2>
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-light btn-sm" @click="shiftMonth(-1)" :disabled="loading">
          <i class="fas fa-chevron-left"></i>
        </button>
        <span class="ym-label">{{ ym }}</span>
        <button class="btn btn-light btn-sm" @click="shiftMonth(1)" :disabled="loading">
          <i class="fas fa-chevron-right"></i>
        </button>
        <div class="form-check ms-2 mb-0">
          <input id="showInactive" v-model="showInactive" type="checkbox" class="form-check-input" @change="reload" />
          <label for="showInactive" class="form-check-label small">비활성 포함</label>
        </div>
        <button class="btn btn-sm btn-light" @click="reload" :disabled="loading" title="새로고침">
          <i class="fas fa-sync-alt" :class="{ 'fa-spin': loading }"></i>
        </button>
        <button class="btn btn-sm btn-primary" @click="openCreate">
          <i class="fas fa-plus"></i> 항목 추가
        </button>
      </div>
    </div>

    <!-- 요약 -->
    <div class="row g-3 mb-3">
      <div class="col-6 col-md-3">
        <div class="card stat income"><div class="stat-label">수입</div>
          <div class="stat-value text-success">{{ won(totals.income) }}</div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card stat out"><div class="stat-label">고정지출</div>
          <div class="stat-value text-danger">{{ won(totals.fixedOut) }}</div>
          <div class="stat-sub small text-muted">지출+보험+상환</div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card stat saving"><div class="stat-label">저축/이체</div>
          <div class="stat-value">{{ won(totals.transfer) }}</div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card stat surplus" :class="{ neg: totals.surplus < 0 }">
          <div class="stat-label">가용 잉여</div>
          <div class="stat-value">{{ won(totals.surplus) }}</div></div>
      </div>
    </div>

    <!-- kind 별 그룹 -->
    <div v-if="loading && !items.length" class="text-muted">불러오는 중...</div>
    <div v-else>
      <template v-for="sec in displaySections" :key="sec.key">
        <div v-if="sec.groups.length" class="kind-section mb-4">
          <div class="kind-section-head">
            <h3 class="kind-section-title"><i class="fas" :class="sec.icon"></i> {{ sec.title }}</h3>
            <strong class="ms-auto" :class="sec.totalClass">{{ won(sec.total) }}</strong>
          </div>
          <div v-for="g in sec.groups" :key="g.kind" class="card section mb-2">
            <div class="section-head">
              <div class="d-flex align-items-center gap-2">
                <span class="kind-label" :class="`kind-${g.kind}`">{{ g.label }}</span>
                <span class="text-muted small">{{ g.items.length }}건</span>
              </div>
              <strong>{{ won(g.total) }}</strong>
            </div>
            <ul class="rec-list">
              <li v-for="r in g.items" :key="r.id" :class="{ inactive: !r.active }">
                <span class="badge bg-light text-dark me-2">{{ r.owner }}</span>
                <span class="rec-name">{{ r.name }}</span>
                <span v-if="r.day_of_month" class="text-muted small ms-2">매월 {{ r.day_of_month }}일</span>
                <span v-if="r.end_ym" class="badge bg-warning ms-2 text-dark">~ {{ r.end_ym }}</span>
                <span v-if="!r.active" class="badge bg-secondary ms-2">비활성</span>
                <span v-if="r.source_account_id || r.target_account_id" class="text-muted small ms-2">
                  <span v-if="r.source_account_id">{{ accountName(r.source_account_id) }}</span>
                  <span v-if="r.source_account_id && r.target_account_id"> → </span>
                  <span v-else-if="r.target_account_id">→ </span>
                  <span v-if="r.target_account_id">{{ accountName(r.target_account_id) }}</span>
                  <span v-if="isRecurringAuto(r)" class="badge bg-info ms-1" title="매월 자동 처리">자동</span>
                </span>
                <strong class="ms-auto amt">{{ won(r.amount) }}</strong>
                <span class="actions ms-2">
                  <button class="icon-btn" :title="r.active ? '비활성화' : '활성화'" @click="toggleActive(r)">
                    <i class="fas" :class="r.active ? 'fa-toggle-on text-success' : 'fa-toggle-off text-muted'"></i>
                  </button>
                  <button class="icon-btn" title="편집" @click="openEdit(r)">
                    <i class="fas fa-pen"></i>
                  </button>
                  <button class="icon-btn danger" title="삭제" @click="confirmDelete(r)">
                    <i class="fas fa-trash"></i>
                  </button>
                </span>
              </li>
            </ul>
          </div>
        </div>
      </template>
      <div v-if="!displaySections.some(s => s.groups.length) && !loading"
           class="text-muted small">표시할 항목 없음</div>
    </div>

    <!-- 추가/편집 모달 -->
    <Modal v-model="formOpen" :title="form.id ? '항목 편집' : '항목 추가'" size="md">
      <div class="mb-2">
        <label class="form-label small">이름</label>
        <input v-model="form.name" class="form-control" placeholder="예: 재욱 청년적금" />
      </div>
      <div class="row g-2 mb-2">
        <div class="col-6">
          <label class="form-label small">종류</label>
          <select v-model="form.kind" class="form-select">
            <option v-for="k in RECURRING_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
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
        <div class="col-6">
          <label class="form-label small">금액</label>
          <input v-model.number="form.amount" type="number" class="form-control" />
        </div>
        <div class="col-6">
          <label class="form-label small">이체일 (선택)</label>
          <input v-model.number="form.day_of_month" type="number" min="1" max="31" class="form-control" placeholder="미정이면 비움" />
        </div>
      </div>
      <div class="row g-2 mb-2">
        <div class="col-6">
          <label class="form-label small">시작월</label>
          <input v-model="form.start_ym" class="form-control" placeholder="2026-05" />
        </div>
        <div class="col-6">
          <label class="form-label small">종료월 (선택)</label>
          <input v-model="form.end_ym" class="form-control" placeholder="비우면 무제한" />
        </div>
      </div>
      <div v-if="needsSourceAccount" class="mb-2">
        <label class="form-label small">출금 계좌</label>
        <select v-model="form.source_account_id" class="form-select">
          <option :value="null">— 선택 —</option>
          <option v-for="a in sourceAccountOptions" :key="a.id" :value="a.id">{{ a.owner }} · {{ a.name }}</option>
        </select>
        <div v-if="form.kind === 'transfer'" class="form-text small text-muted">
          자산에서 "거래에서 사용" 체크된 계좌만 표시됩니다.
        </div>
      </div>
      <div v-if="needsTargetAccount" class="mb-2">
        <label class="form-label small">{{ form.kind === 'income' ? '입금 계좌' : '입금 계좌 (대상)' }}</label>
        <select v-model="form.target_account_id" class="form-select">
          <option :value="null">— 선택 —</option>
          <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.owner }} · {{ a.name }}</option>
        </select>
      </div>
      <div v-if="needsSourceAccount || needsTargetAccount" class="form-text small text-muted mb-2">
        <i class="fas fa-info-circle"></i>
        필요한 계좌가 지정되면 매월 자동으로 거래가 생성됩니다 (미지정 시 표시만).
      </div>
      <div class="form-check mb-2">
        <input id="recActive" v-model="form.active" type="checkbox" class="form-check-input" />
        <label for="recActive" class="form-check-label small">활성</label>
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

    <!-- 삭제 확인 -->
    <Modal v-model="deleteOpen" title="항목 삭제" size="sm">
      <p class="mb-1">정말 삭제하시겠어요?</p>
      <p v-if="delTarget" class="small text-muted m-0">
        {{ delTarget.name }} ({{ delTarget.owner }}, {{ won(delTarget.amount) }})
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
  listRecurring, createRecurring, updateRecurring, deleteRecurring,
  listAccounts,
  applyRecurringTransfers, isRecurringAuto,
  won, ymNow,
  RECURRING_KINDS, OWNERS,
} from '../../lib/api_v2.js'
import Modal from './components/Modal.vue'

const today = new Date()
const year  = ref(today.getFullYear())
const month = ref(today.getMonth() + 1)
const ym = computed(() => `${year.value}-${String(month.value).padStart(2, '0')}`)

const items = ref([])
const accounts = ref([])
const showInactive = ref(false)
const loading = ref(true)
const saving = ref(false)

const accountName = (id) => {
  const a = accounts.value.find(x => x.id === id)
  return a ? a.name : '-'
}

const totals = computed(() => {
  const sumKind = (k) => items.value.filter(r => r.kind === k && r.active).reduce((s, r) => s + Number(r.amount), 0)
  const income = sumKind('income')
  const transfer = sumKind('transfer')
  const expense = sumKind('expense')
  const insurance = sumKind('insurance')
  const loan_payment = sumKind('loan_payment')
  const fixedOut = expense + insurance + loan_payment           // 고정지출 (이체 제외)
  const totalOut = fixedOut + transfer                          // 가용 잉여 계산용
  return { income, transfer, expense, insurance, loan_payment, fixedOut, totalOut, surplus: income - totalOut }
})

function buildGroup(k) {
  const list = items.value.filter(r => r.kind === k.value)
  return {
    kind: k.value,
    label: k.label,
    items: list,
    total: list.filter(r => r.active).reduce((s, r) => s + Number(r.amount), 0),
  }
}
const incomeGroups   = computed(() => RECURRING_KINDS.filter(k => k.value === 'income').map(buildGroup).filter(g => g.items.length))
const fixedGroups    = computed(() => RECURRING_KINDS.filter(k => ['expense','insurance','loan_payment'].includes(k.value)).map(buildGroup).filter(g => g.items.length))
const transferGroups = computed(() => RECURRING_KINDS.filter(k => k.value === 'transfer').map(buildGroup).filter(g => g.items.length))

const displaySections = computed(() => [
  { key: 'income',    title: '수입',      icon: 'fa-arrow-down text-success', total: totals.value.income,    totalClass: 'text-success', groups: incomeGroups.value   },
  { key: 'fixed',     title: '고정지출',  icon: 'fa-arrow-up text-danger',    total: totals.value.fixedOut,  totalClass: 'text-danger',  groups: fixedGroups.value    },
  { key: 'transfer',  title: '저축/이체', icon: 'fa-exchange-alt text-info',  total: totals.value.transfer,  totalClass: '',             groups: transferGroups.value },
])

// ====== 폼 ======
const formOpen = ref(false)
const form = ref(emptyForm())
function emptyForm() {
  return {
    id: null, name: '', kind: 'expense', owner: '재욱',
    amount: 0, day_of_month: null,
    start_ym: ym.value, end_ym: '',
    source_account_id: null, target_account_id: null, active: true, memo: '',
  }
}
const needsSourceAccount = computed(() => ['transfer', 'loan_payment', 'expense', 'insurance'].includes(form.value.kind))
const needsTargetAccount = computed(() => ['transfer', 'loan_payment', 'income'].includes(form.value.kind))
// 저축/이체 출금은 "거래에서 사용" 켜진 계좌만 (거래 페이지의 결제 계좌와 일관)
const sourceAccountOptions = computed(() => {
  if (form.value.kind === 'transfer') return accounts.value.filter(a => a.tx_enabled)
  return accounts.value
})

function openCreate() { form.value = emptyForm(); formOpen.value = true }
function openEdit(r) {
  form.value = {
    id: r.id, name: r.name, kind: r.kind, owner: r.owner,
    amount: r.amount, day_of_month: r.day_of_month,
    start_ym: r.start_ym, end_ym: r.end_ym || '',
    source_account_id: r.source_account_id, target_account_id: r.target_account_id,
    active: r.active, memo: r.memo || '',
  }
  formOpen.value = true
}

async function saveForm() {
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      kind: form.value.kind,
      owner: form.value.owner,
      amount: Number(form.value.amount) || 0,
      day_of_month: form.value.day_of_month || null,
      start_ym: form.value.start_ym || ym.value,
      end_ym: form.value.end_ym || null,
      source_account_id: needsSourceAccount.value ? (form.value.source_account_id || null) : null,
      target_account_id: needsTargetAccount.value ? (form.value.target_account_id || null) : null,
      active: !!form.value.active,
      memo: form.value.memo || null,
    }
    if (form.value.id) {
      await updateRecurring(form.value.id, payload)
    } else {
      await createRecurring(payload)
    }
    formOpen.value = false
    await reload()
  } finally { saving.value = false }
}

async function toggleActive(r) {
  try {
    await updateRecurring(r.id, { active: !r.active })
    await reload()
  } catch (e) { /* noop */ }
}

// ====== 삭제 ======
const deleteOpen = ref(false)
const delTarget = ref(null)
function confirmDelete(r) { delTarget.value = r; deleteOpen.value = true }
async function doDelete() {
  if (!delTarget.value) return
  saving.value = true
  try {
    await deleteRecurring(delTarget.value.id)
    deleteOpen.value = false
    await reload()
  } finally { saving.value = false }
}

// ====== 데이터 로딩 ======
async function reload() {
  loading.value = true
  // 이전 달 항목 잔상 제거
  items.value = []
  try {
    // 자동 이체 누락분 먼저 처리 (멱등) — 그 후 잔액/거래가 갱신된 상태로 로드
    try { await applyRecurringTransfers(ym.value) } catch (e) { /* noop */ }

    const [recs, accs] = await Promise.all([
      listRecurring({ ym: ym.value, activeOnly: !showInactive.value }),
      listAccounts(),
    ])
    items.value = recs
    accounts.value = accs
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
.section-head { display: flex; justify-content: space-between; align-items: center; padding-bottom: 0.5rem; border-bottom: 2px solid #f0f3f7; margin-bottom: 0.5rem; }

.stat {
  border: none; border-radius: 12px; padding: 1rem;
  background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  border-left: 4px solid #5e72e4;
  height: 100%;
  display: flex; flex-direction: column; justify-content: center;
}
.stat.income  { border-left-color: #2dce89; }
.stat.out     { border-left-color: #fb6340; }
.stat.saving  { border-left-color: #11cdef; }
.stat.surplus { border-left-color: #5e72e4; }
.stat.surplus.neg { border-left-color: #f5365c; }
.stat.surplus.neg .stat-value { color: #f5365c; }

.kind-section-head {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.4rem 0.25rem;
  margin-bottom: 0.5rem;
}
.kind-section-title {
  font-size: 1.05rem; font-weight: 700; color: #32325d; margin: 0;
  display: flex; align-items: center; gap: 0.5rem;
}
.stat-label { font-size: 0.78rem; color: #8898aa; font-weight: 600; text-transform: uppercase; }
.stat-value { font-size: 1.3rem; font-weight: 700; color: #32325d; }
.stat-sub { margin-top: 0.15rem; }

.kind-label {
  font-size: 0.75rem; font-weight: 700; text-transform: uppercase;
  padding: 0.18rem 0.6rem; border-radius: 999px; color: #fff;
}
.kind-label.kind-income       { background: #2dce89; }
.kind-label.kind-transfer     { background: #11cdef; }
.kind-label.kind-expense      { background: #fb6340; }
.kind-label.kind-insurance    { background: #8965e0; }
.kind-label.kind-loan_payment { background: #f5365c; }

.rec-list { list-style: none; padding: 0; margin: 0; }
.rec-list li {
  display: flex; align-items: center; gap: 0.3rem;
  padding: 0.5rem 0.25rem;
  border-bottom: 1px dashed #f0f3f7;
  font-size: 0.92rem;
}
.rec-list li:last-child { border-bottom: none; }
.rec-list li.inactive { opacity: 0.5; }
.rec-name { color: #32325d; font-weight: 500; }
.amt { color: #32325d; }

.actions { display: flex; gap: 0.1rem; }
.icon-btn {
  width: 28px; height: 28px; border-radius: 6px;
  background: transparent; border: none; color: #8898aa; cursor: pointer;
}
.icon-btn:hover { background: #f0f3f7; color: #5e72e4; }
.icon-btn.danger:hover { color: #f5365c; }

.living .lb-label { font-size: 0.72rem; color: #8898aa; font-weight: 600; text-transform: uppercase; }
.living .lb-value { font-size: 1.05rem; font-weight: 700; color: #32325d; }

@media (max-width: 575px) {
  .rec-list li { flex-wrap: wrap; }
  .rec-list li .amt { margin-left: auto; }
  .actions { margin-left: auto; }
}
</style>
