<template>
  <Modal v-model="open" :title="account ? `${account.name} 이용 내역` : '이용 내역'" size="md">
    <div v-if="account" class="hist-summary mb-2 d-flex align-items-center flex-wrap gap-2">
      <span class="badge bg-light text-dark">{{ typeLabel(account.type) }}</span>
      <span class="text-muted small">{{ account.owner }}</span>
      <strong v-if="account.balance != null" class="ms-auto">{{ won(account.balance) }}</strong>
    </div>
    <div class="hist-month-picker mb-2">
      <button class="btn btn-light btn-sm" :disabled="loading" @click="shiftMonth(-1)">
        <i class="fas fa-chevron-left"></i>
      </button>
      <span class="ym-label">{{ ym }}</span>
      <button class="btn btn-light btn-sm" :disabled="loading" @click="shiftMonth(1)">
        <i class="fas fa-chevron-right"></i>
      </button>
    </div>
    <div v-if="loading" class="text-muted small">불러오는 중...</div>
    <div v-else-if="!items.length" class="text-muted small text-center py-3">이 달 거래 내역 없음</div>
    <ul v-else class="hist-list">
      <li v-for="t in items" :key="t.id">
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
      <button class="btn btn-light" @click="open = false">닫기</button>
    </template>
  </Modal>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { listTransactions, won, ymNow, ACCOUNT_TYPES } from '../../../lib/api_v2.js'
import Modal from './Modal.vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  account:    { type: Object,  default: null },
  initialYm:  { type: String,  default: '' },
})
const emit = defineEmits(['update:modelValue'])

const open = computed({
  get() { return props.modelValue },
  set(v) { emit('update:modelValue', v) },
})

const ym = ref(ymNow())
const items = ref([])
const loading = ref(false)

const used = computed(() =>
  items.value.filter(t => t.kind === 'expense').reduce((s, t) => s + Number(t.amount || 0), 0)
)
const income = computed(() =>
  items.value.filter(t => t.kind === 'income').reduce((s, t) => s + Number(t.amount || 0), 0)
)

const typeLabel = (t) => ACCOUNT_TYPES.find(x => x.value === t)?.label || t

async function load() {
  if (!props.account) return
  loading.value = true
  try {
    items.value = await listTransactions({
      accountId: props.account.id,
      ym: ym.value,
      includeRecurring: true,
    })
  } finally { loading.value = false }
}

function shiftMonth(delta) {
  const [y, m] = ym.value.split('-').map(Number)
  const d = new Date(y, m - 1 + delta, 1)
  ym.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  load()
}

// 모달이 열리는 순간 ym 초기화 + 로드
watch(() => props.modelValue, (v) => {
  if (v && props.account) {
    ym.value = props.initialYm || ymNow()
    items.value = []
    load()
  }
})
</script>

<style scoped>
.hist-summary { padding: 0.5rem 0.75rem; background: #f9fbfd; border-radius: 8px; }
.hist-month-picker {
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0.4rem 0.5rem; background: #fff; border: 1px solid #e9ecef;
  border-radius: 8px;
}
.hist-month-picker .ym-label {
  font-weight: 600; min-width: 5.5rem; text-align: center; color: #32325d;
}
.hist-totals { line-height: 1.4; }

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
</style>
