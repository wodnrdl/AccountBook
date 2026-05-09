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

    <!-- 생활비 봉투 설정 -->
    <div class="card section mb-3 living">
      <div class="section-head">
        <div class="d-flex align-items-center gap-2">
          <i class="fas fa-shopping-basket text-info"></i>
          <span class="section-title">생활비 봉투</span>
        </div>
        <button v-if="!editLiving" class="btn btn-sm btn-outline-primary" @click="startEditLiving">편집</button>
      </div>
      <div v-if="!editLiving" class="row g-2 align-items-center">
        <div class="col-12 col-md-4">
          <div class="lb-label">매월 충전액</div>
          <div class="lb-value">{{ won(living?.monthly_amount || 0) }}</div>
        </div>
        <div class="col-6 col-md-3">
          <div class="lb-label">시작월</div>
          <div class="lb-value">{{ living?.start_ym || '-' }}</div>
        </div>
        <div class="col-6 col-md-3">
          <div class="lb-label">상태</div>
          <div class="lb-value">{{ living?.active ? '활성' : '비활성' }}</div>
        </div>
        <div class="col-12 small text-muted">
          매월 1일에 기본 결제 계좌(자산 관리에서 ⭐ 표시) 로 자동 입금됩니다.
        </div>
      </div>
      <div v-else class="row g-2 align-items-end">
        <div class="col-12 col-md-4">
          <label class="form-label small">매월 충전액 (원)</label>
          <input v-model.number="livingForm.monthly_amount" type="number" class="form-control" />
        </div>
        <div class="col-6 col-md-3">
          <label class="form-label small">시작월</label>
          <input v-model="livingForm.start_ym" class="form-control" placeholder="2026-05" />
        </div>
        <div class="col-6 col-md-3">
          <div class="form-check mt-3">
            <input id="lbActive" v-model="livingForm.active" type="checkbox" class="form-check-input" />
            <label for="lbActive" class="form-check-label small">활성</label>
          </div>
        </div>
        <div class="col-12 d-flex justify-content-end gap-2 mt-2">
          <button class="btn btn-sm btn-light" @click="editLiving = false">취소</button>
          <button class="btn btn-sm btn-primary" :disabled="savingLiving" @click="saveLiving">
            <i v-if="savingLiving" class="fas fa-spinner fa-spin"></i> 저장
          </button>
        </div>
      </div>
    </div>

    <!-- 요약 -->
    <div class="row g-3 mb-3">
      <div class="col-6 col-md-4">
        <div class="card stat income"><div class="stat-label">수입</div>
          <div class="stat-value text-success">{{ won(totals.income) }}</div></div>
      </div>
      <div class="col-6 col-md-4">
        <div class="card stat out"><div class="stat-label">고정지출 합계</div>
          <div class="stat-value text-danger">{{ won(totals.totalOut) }}</div>
          <div class="stat-sub small text-muted">이체+지출+보험+상환</div></div>
      </div>
      <div class="col-12 col-md-4">
        <div class="card stat surplus" :class="{ neg: totals.surplus < 0 }">
          <div class="stat-label">가용 잉여</div>
          <div class="stat-value">{{ won(totals.surplus) }}</div></div>
      </div>
    </div>

    <!-- kind 별 그룹 -->
    <div v-if="loading && !items.length" class="text-muted">불러오는 중...</div>
    <div v-else>
      <div v-for="g in groups" :key="g.kind" class="card section mb-3">
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
            <span v-if="r.target_account_id" class="text-muted small ms-2">→ {{ accountName(r.target_account_id) }}</span>
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
      <div v-if="!groups.length && !loading" class="text-muted small">표시할 항목 없음</div>
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
      <div v-if="needsTargetAccount" class="mb-2">
        <label class="form-label small">대상 계좌 (선택)</label>
        <select v-model="form.target_account_id" class="form-select">
          <option :value="null">— 없음 —</option>
          <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.owner }} · {{ a.name }}</option>
        </select>
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
  getLivingBudget, updateLivingBudget,
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

// 생활비 봉투
const living = ref(null)
const editLiving = ref(false)
const livingForm = ref({ monthly_amount: 1000000, start_ym: '2026-05', active: true })
const savingLiving = ref(false)
function startEditLiving() {
  livingForm.value = {
    monthly_amount: living.value?.monthly_amount ?? 1000000,
    start_ym: living.value?.start_ym ?? ym.value,
    active: living.value?.active ?? true,
  }
  editLiving.value = true
}
async function saveLiving() {
  savingLiving.value = true
  try {
    living.value = await updateLivingBudget({
      monthly_amount: Number(livingForm.value.monthly_amount) || 0,
      start_ym: livingForm.value.start_ym,
      active: !!livingForm.value.active,
    })
    editLiving.value = false
  } finally { savingLiving.value = false }
}

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
  const totalOut = transfer + expense + insurance + loan_payment
  return { income, transfer, expense, insurance, loan_payment, totalOut, surplus: income - totalOut }
})

const groups = computed(() => {
  return RECURRING_KINDS.map(k => {
    const list = items.value.filter(r => r.kind === k.value)
    return {
      kind: k.value,
      label: k.label,
      items: list,
      total: list.filter(r => r.active).reduce((s, r) => s + Number(r.amount), 0),
    }
  }).filter(g => g.items.length)
})

// ====== 폼 ======
const formOpen = ref(false)
const form = ref(emptyForm())
function emptyForm() {
  return {
    id: null, name: '', kind: 'expense', owner: '재욱',
    amount: 0, day_of_month: null,
    start_ym: ym.value, end_ym: '',
    target_account_id: null, active: true, memo: '',
  }
}
const needsTargetAccount = computed(() => ['transfer', 'loan_payment'].includes(form.value.kind))

function openCreate() { form.value = emptyForm(); formOpen.value = true }
function openEdit(r) {
  form.value = {
    id: r.id, name: r.name, kind: r.kind, owner: r.owner,
    amount: r.amount, day_of_month: r.day_of_month,
    start_ym: r.start_ym, end_ym: r.end_ym || '',
    target_account_id: r.target_account_id, active: r.active,
    memo: r.memo || '',
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
  try {
    const [recs, accs, lb] = await Promise.all([
      listRecurring({ ym: ym.value, activeOnly: !showInactive.value }),
      listAccounts(),
      getLivingBudget(),
    ])
    items.value = recs
    accounts.value = accs
    living.value = lb
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
}
.stat.income  { border-left-color: #2dce89; }
.stat.out     { border-left-color: #fb6340; }
.stat.surplus { border-left-color: #11cdef; }
.stat.surplus.neg { border-left-color: #f5365c; }
.stat.surplus.neg .stat-value { color: #f5365c; }
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
