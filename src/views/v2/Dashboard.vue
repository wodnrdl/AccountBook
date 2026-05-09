<template>
  <div class="v2-page dashboard">
    <!-- 헤더: 월 선택 -->
    <div class="d-flex align-items-center justify-content-between mb-3 flex-wrap gap-2">
      <h2 class="page-title m-0"><i class="fas fa-th-large"></i> 대시보드</h2>
      <div class="month-picker">
        <button class="btn btn-light btn-sm" @click="shiftMonth(-1)" :disabled="loading">
          <i class="fas fa-chevron-left"></i>
        </button>
        <span class="ym-label">{{ year }}년 {{ month }}월</span>
        <button class="btn btn-light btn-sm" @click="shiftMonth(1)" :disabled="loading">
          <i class="fas fa-chevron-right"></i>
        </button>
        <button class="btn btn-light btn-sm ms-2" @click="reload" :disabled="loading" title="새로고침">
          <i class="fas fa-sync-alt" :class="{ 'fa-spin': loading }"></i>
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-danger">{{ error }}</div>

    <!-- KPI 4개 -->
    <div class="row g-3 mb-3">
      <div class="col-6 col-lg-3">
        <div class="card kpi income">
          <div class="kpi-label">이번 달 수입</div>
          <div class="kpi-value">
            <template v-if="loading"><span class="skel"/></template>
            <template v-else>{{ wonShort(d.recurring.income) }}<span class="unit">원</span></template>
          </div>
          <div class="kpi-sub">고정 + 단발 {{ wonShort(d.recurring.income + d.tx.income) }}원</div>
        </div>
      </div>
      <div class="col-6 col-lg-3">
        <div class="card kpi out">
          <div class="kpi-label">이번 달 고정지출</div>
          <div class="kpi-value">
            <template v-if="loading"><span class="skel"/></template>
            <template v-else>{{ wonShort(d.recurring.totalOut) }}<span class="unit">원</span></template>
          </div>
          <div class="kpi-sub">저축·이체·보험·상환 포함</div>
        </div>
      </div>
      <div class="col-6 col-lg-3">
        <div class="card kpi surplus" :class="{ negative: d.recurring.surplus < 0 }">
          <div class="kpi-label">가용 잉여</div>
          <div class="kpi-value">
            <template v-if="loading"><span class="skel"/></template>
            <template v-else>{{ wonShort(d.recurring.surplus) }}<span class="unit">원</span></template>
          </div>
          <div class="kpi-sub">수입 − 고정지출</div>
        </div>
      </div>
      <div class="col-6 col-lg-3">
        <div class="card kpi networth">
          <div class="kpi-label">순자산</div>
          <div class="kpi-value">
            <template v-if="loading"><span class="skel"/></template>
            <template v-else>{{ wonShort(d.netWorth) }}<span class="unit">원</span></template>
          </div>
          <div class="kpi-sub">자산 − 부채</div>
        </div>
      </div>
    </div>

    <!-- 자산 / 부채 -->
    <div class="row g-3 mb-3">
      <!-- 자산 -->
      <div class="col-12 col-lg-7">
        <div class="card section">
          <div class="section-head">
            <div>
              <div class="section-title"><i class="fas fa-coins text-warning"></i> 자산</div>
              <div class="section-total">{{ won(d.assetTotal) }}</div>
            </div>
            <router-link to="/v2/assets" class="btn btn-sm btn-outline-primary">관리</router-link>
          </div>

          <div class="row g-3 align-items-center">
            <div class="col-12 col-sm-5 text-center">
              <Donut :segments="ownerSegments" :total="d.assetTotal" :loading="loading" />
            </div>
            <div class="col-12 col-sm-7">
              <ul class="owner-list">
                <li v-for="seg in ownerSegments" :key="seg.label" v-show="seg.value > 0">
                  <span class="dot" :style="{ background: seg.color }"></span>
                  <span class="name">{{ seg.label }}</span>
                  <span class="pct text-muted">{{ seg.pct }}%</span>
                  <strong class="amt">{{ wonShort(seg.value) }}원</strong>
                </li>
                <li v-if="d.assetTotal === 0 && !loading" class="text-muted small">자산 데이터 없음</li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <!-- 부채 -->
      <div class="col-12 col-lg-5">
        <div class="card section">
          <div class="section-head">
            <div>
              <div class="section-title"><i class="fas fa-hand-holding-usd text-danger"></i> 부채</div>
              <div class="section-total text-danger">{{ won(d.liabilityTotal) }}</div>
            </div>
          </div>
          <ul class="debt-list">
            <li v-for="a in liabilityAccounts" :key="a.id">
              <div class="d-flex justify-content-between">
                <span><span class="badge bg-light text-dark me-2">{{ a.owner }}</span>{{ a.name }}</span>
                <strong class="text-danger">{{ won(a.balance) }}</strong>
              </div>
            </li>
            <li v-if="!liabilityAccounts.length && !loading" class="text-muted small">부채 없음</li>
          </ul>
          <div v-if="d.recurring.loan_payment > 0" class="repay-note text-muted small mt-2">
            <i class="fas fa-info-circle"></i>
            매월 상환 {{ won(d.recurring.loan_payment) }}
          </div>
        </div>
      </div>
    </div>

    <!-- 이번 달 고정 흐름 -->
    <div class="card section">
      <div class="section-head">
        <div>
          <div class="section-title"><i class="fas fa-stream text-primary"></i> 이번 달 고정 흐름</div>
          <div class="section-total">{{ recurring.length }}건 · 합계 {{ won(d.recurring.totalOut + d.recurring.income) }}</div>
        </div>
        <router-link to="/v2/recurring" class="btn btn-sm btn-outline-primary">관리</router-link>
      </div>

      <div v-if="loading" class="text-muted">불러오는 중...</div>
      <div v-else>
        <div v-for="g in recurringGroups" :key="g.kind" class="kind-group">
          <div class="kind-head">
            <span class="kind-label" :class="`kind-${g.kind}`">{{ g.label }}</span>
            <span class="text-muted small">{{ g.items.length }}건</span>
            <strong class="ms-auto">{{ won(g.total) }}</strong>
          </div>
          <ul class="rec-list">
            <li v-for="r in g.items" :key="r.id">
              <span class="badge bg-light text-dark me-2">{{ r.owner }}</span>
              <span class="rec-name">{{ r.name }}</span>
              <span v-if="r.end_ym" class="badge bg-warning ms-1 text-dark">~ {{ r.end_ym }}</span>
              <strong class="ms-auto">{{ won(r.amount) }}</strong>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  fetchDashboard, listRecurring, won, wonShort, ymNow,
  RECURRING_KINDS, OWNERS,
} from '../../lib/api_v2.js'
import Donut from './components/Donut.vue'

const OWNER_COLORS = {
  '재욱':   '#5e72e4',
  '공주님': '#f5365c',
  '공동':   '#2dce89',
}

const today = new Date()
const year  = ref(today.getFullYear())
const month = ref(today.getMonth() + 1)
const ym = computed(() => `${year.value}-${String(month.value).padStart(2, '0')}`)

const loading = ref(true)
const error = ref('')
const d = ref(emptyDashboard())
const recurring = ref([])

function emptyDashboard() {
  return {
    ym: ymNow(),
    recurring: { income: 0, transfer: 0, expense: 0, insurance: 0, loan_payment: 0, totalOut: 0, surplus: 0 },
    tx: { income: 0, expense: 0 },
    accounts: [],
    assetTotal: 0, liabilityTotal: 0, netWorth: 0,
    byOwner: { '재욱': 0, '공주님': 0, '공동': 0 },
  }
}

const ownerSegments = computed(() => {
  const total = d.value.assetTotal || 1
  return OWNERS.map(o => {
    const v = d.value.byOwner[o] || 0
    return {
      label: o,
      value: v,
      color: OWNER_COLORS[o],
      pct: total > 0 ? Math.round(v / total * 100) : 0,
    }
  })
})

const liabilityAccounts = computed(() => d.value.accounts.filter(a => a.is_liability))

const recurringGroups = computed(() => {
  return RECURRING_KINDS.map(k => {
    const items = recurring.value.filter(r => r.kind === k.value)
    return {
      kind: k.value,
      label: k.label,
      items,
      total: items.reduce((s, r) => s + Number(r.amount), 0),
    }
  }).filter(g => g.items.length)
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [summary, recs] = await Promise.all([
      fetchDashboard(ym.value),
      listRecurring({ ym: ym.value, activeOnly: true }),
    ])
    d.value = summary
    recurring.value = recs
  } catch (e) {
    error.value = e.message || String(e)
  } finally {
    loading.value = false
  }
}

function shiftMonth(delta) {
  let y = year.value, m = month.value + delta
  if (m < 1)  { m = 12; y-- }
  if (m > 12) { m = 1;  y++ }
  year.value = y
  month.value = m
  load()
}

function reload() { load() }

onMounted(load)
</script>

<style scoped>
.dashboard { padding-bottom: 2rem; }
.page-title { display: flex; align-items: center; gap: 0.5rem; }

.month-picker { display: flex; align-items: center; gap: 0.4rem; }
.ym-label { font-weight: 600; min-width: 6.5rem; text-align: center; }

/* KPI 카드 */
.kpi {
  border: none;
  border-radius: 12px;
  padding: 1rem;
  height: 100%;
  background: #fff;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  border-left: 4px solid #5e72e4;
}
.kpi.income   { border-left-color: #2dce89; }
.kpi.out      { border-left-color: #fb6340; }
.kpi.surplus  { border-left-color: #11cdef; }
.kpi.surplus.negative { border-left-color: #f5365c; }
.kpi.networth { border-left-color: #5e72e4; }
.kpi-label { color: #8898aa; font-size: 0.8rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }
.kpi-value { font-size: 1.6rem; font-weight: 700; line-height: 1.2; margin-top: 0.3rem; color: #32325d; }
.kpi-value .unit { font-size: 0.9rem; font-weight: 500; margin-left: 2px; color: #8898aa; }
.kpi-sub { font-size: 0.75rem; color: #8898aa; margin-top: 0.25rem; }
.kpi.surplus.negative .kpi-value { color: #f5365c; }

/* 섹션 카드 */
.section {
  border: none;
  border-radius: 12px;
  padding: 1.25rem;
  background: #fff;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  height: 100%;
}
.section-head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1rem; }
.section-title { font-size: 1rem; font-weight: 700; color: #32325d; }
.section-total { font-size: 1.4rem; font-weight: 700; color: #32325d; margin-top: 0.2rem; }

/* 소유자 리스트 */
.owner-list { list-style: none; padding: 0; margin: 0; }
.owner-list li {
  display: grid;
  grid-template-columns: 14px 1fr auto auto;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0;
  border-bottom: 1px solid #f0f3f7;
}
.owner-list li:last-child { border-bottom: none; }
.dot { width: 12px; height: 12px; border-radius: 50%; }
.owner-list .name { font-weight: 500; color: #32325d; }
.owner-list .pct { font-size: 0.85rem; }
.owner-list .amt { color: #32325d; font-size: 0.95rem; }

/* 부채 리스트 */
.debt-list { list-style: none; padding: 0; margin: 0; }
.debt-list li { padding: 0.4rem 0; border-bottom: 1px solid #f0f3f7; }
.debt-list li:last-child { border-bottom: none; }

/* 고정 흐름 */
.kind-group { margin-bottom: 1.25rem; }
.kind-group:last-child { margin-bottom: 0; }
.kind-head {
  display: flex; align-items: center; gap: 0.5rem;
  padding-bottom: 0.4rem; border-bottom: 2px solid #f0f3f7; margin-bottom: 0.5rem;
}
.kind-label {
  font-size: 0.75rem; font-weight: 700; text-transform: uppercase;
  padding: 0.15rem 0.55rem; border-radius: 999px; color: #fff;
}
.kind-label.kind-income       { background: #2dce89; }
.kind-label.kind-transfer     { background: #11cdef; }
.kind-label.kind-expense      { background: #fb6340; }
.kind-label.kind-insurance    { background: #8965e0; }
.kind-label.kind-loan_payment { background: #f5365c; }

.rec-list { list-style: none; padding: 0; margin: 0; }
.rec-list li {
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0.35rem 0.25rem;
  border-bottom: 1px dashed #f0f3f7;
  font-size: 0.92rem;
}
.rec-list li:last-child { border-bottom: none; }
.rec-name { color: #32325d; }

/* 스켈레톤 */
.skel {
  display: inline-block;
  width: 80px; height: 1.4rem;
  background: linear-gradient(90deg, #f0f3f7 25%, #e6ebf2 50%, #f0f3f7 75%);
  background-size: 200% 100%;
  animation: shimmer 1.2s infinite;
  border-radius: 4px;
}
@keyframes shimmer { 0%{background-position: 200% 0} 100%{background-position: -200% 0} }

@media (max-width: 575px) {
  .kpi-value { font-size: 1.3rem; }
}
</style>
