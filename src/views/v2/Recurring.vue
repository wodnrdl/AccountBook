<template>
  <div class="v2-page">
    <h2 class="page-title"><i class="fas fa-sync-alt"></i> 고정지출</h2>
    <p class="text-muted">Phase 5 에서 구현 예정 — CRUD, 종료월 관리</p>

    <div v-if="loading" class="text-muted">불러오는 중...</div>
    <div v-else>
      <div v-for="g in groups" :key="g.kind" class="mb-4">
        <h5>{{ g.label }} <span class="text-muted small">합계 {{ won(sumOf(g.items)) }}</span></h5>
        <ul class="list-group">
          <li v-for="r in g.items" :key="r.id" class="list-group-item d-flex justify-content-between">
            <span>
              <span class="badge bg-light text-dark me-2">{{ r.owner }}</span>
              {{ r.name }}
              <span v-if="r.end_ym" class="badge bg-warning ms-1 text-dark">~ {{ r.end_ym }}</span>
            </span>
            <strong>{{ won(r.amount) }}</strong>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listRecurring, won, RECURRING_KINDS, ymNow } from '../../lib/api_v2.js'

const items = ref([])
const loading = ref(true)

const groups = computed(() => {
  return RECURRING_KINDS.map(k => ({
    kind: k.value,
    label: k.label,
    items: items.value.filter(r => r.kind === k.value),
  })).filter(g => g.items.length)
})

const sumOf = (list) => list.reduce((s, r) => s + Number(r.amount), 0)

onMounted(async () => {
  try {
    items.value = await listRecurring({ ym: ymNow() })
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page-title { display: flex; align-items: center; gap: 0.5rem; }
</style>
