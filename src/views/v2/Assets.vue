<template>
  <div class="v2-page">
    <h2 class="page-title"><i class="fas fa-wallet"></i> 자산</h2>
    <p class="text-muted">Phase 4 에서 구현 예정 — 계좌별 잔액 카드, 월별 추이</p>
    <div v-if="loading" class="text-muted">불러오는 중...</div>
    <div v-else>
      <div v-for="(group, owner) in grouped" :key="owner" class="mb-4">
        <h5>{{ owner }} <span class="text-muted small">합계 {{ won(sumOf(group)) }}</span></h5>
        <ul class="list-group">
          <li v-for="a in group" :key="a.id" class="list-group-item d-flex justify-content-between">
            <span>
              <span class="badge bg-light text-dark me-2">{{ typeLabel(a.type) }}</span>
              {{ a.name }}
              <span v-if="a.is_liability" class="badge bg-danger ms-1">부채</span>
            </span>
            <strong :class="a.is_liability ? 'text-danger' : ''">{{ won(a.balance) }}</strong>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listAccounts, won, ACCOUNT_TYPES } from '../../lib/api_v2.js'

const accounts = ref([])
const loading = ref(true)

const typeLabel = (t) => ACCOUNT_TYPES.find(x => x.value === t)?.label || t

const grouped = computed(() => {
  const g = {}
  for (const a of accounts.value) {
    if (!g[a.owner]) g[a.owner] = []
    g[a.owner].push(a)
  }
  return g
})

const sumOf = (list) => list.reduce((s, a) => s + (a.is_liability ? -1 : 1) * Number(a.balance), 0)

onMounted(async () => {
  try {
    accounts.value = await listAccounts()
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page-title { display: flex; align-items: center; gap: 0.5rem; }
</style>
