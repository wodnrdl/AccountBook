<template>
  <div class="v2-page">
    <h2 class="page-title"><i class="fas fa-th-large"></i> 대시보드 <span class="ym">{{ ym }}</span></h2>
    <p class="text-muted">Phase 3 에서 구현 예정 — 수입/지출/저축/자산/부채 한눈에</p>

    <div v-if="loading" class="text-muted">불러오는 중...</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else class="preview">
      <pre>{{ summary }}</pre>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { fetchDashboard, ymNow } from '../../lib/api_v2.js'

const ym = ref(ymNow())
const loading = ref(true)
const error = ref('')
const summary = ref(null)

onMounted(async () => {
  try {
    const d = await fetchDashboard(ym.value)
    summary.value = {
      ym: d.ym,
      '월 수입': d.recurring.income,
      '월 고정지출 합계': d.recurring.totalOut,
      '월 가용잉여': d.recurring.surplus,
      '자산 총합': d.assetTotal,
      '부채 총합': d.liabilityTotal,
      '순자산': d.netWorth,
      '소유자별 자산': d.byOwner,
    }
  } catch (e) {
    error.value = e.message || String(e)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page-title { display: flex; align-items: center; gap: 0.5rem; }
.ym { font-size: 0.9rem; color: #8898aa; font-weight: 400; margin-left: 0.5rem; }
.preview pre {
  background: #f6f9fc;
  padding: 1rem;
  border-radius: 8px;
  font-size: 0.85rem;
}
</style>
