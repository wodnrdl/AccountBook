<template>
  <div class="v2-page">
    <h2 class="page-title"><i class="fas fa-edit"></i> 거래</h2>
    <p class="text-muted">Phase 6 에서 구현 예정 — 단발성 거래 등록/조회/통계</p>

    <div v-if="loading" class="text-muted">불러오는 중...</div>
    <div v-else-if="!items.length" class="text-muted">
      이번 달 거래 내역이 없습니다. (등록 UI 는 Phase 6)
    </div>
    <ul v-else class="list-group">
      <li v-for="t in items" :key="t.id" class="list-group-item d-flex justify-content-between">
        <span>
          <span class="badge bg-light text-dark me-2">{{ t.owner }}</span>
          <span class="text-muted me-2">{{ t.date }}</span>
          {{ t.category || '-' }}
          <span v-if="t.memo" class="text-muted ms-2">— {{ t.memo }}</span>
        </span>
        <strong :class="t.kind === 'income' ? 'text-success' : 'text-danger'">
          {{ t.kind === 'income' ? '+' : '-' }}{{ won(t.amount) }}
        </strong>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listTransactions, won, ymNow } from '../../lib/api_v2.js'

const items = ref([])
const loading = ref(true)

onMounted(async () => {
  try {
    items.value = await listTransactions({ ym: ymNow() })
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page-title { display: flex; align-items: center; gap: 0.5rem; }
</style>
