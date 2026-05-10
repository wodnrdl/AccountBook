<template>
  <div class="v2-shell">
    <!-- Sidebar -->
    <nav class="sidebar v2-sidebar" :class="{ show: sidebarOpen }">
      <a class="brand" href="/v2">
        <i class="fas fa-piggy-bank fa-2x" style="color: #5e72e4"></i>
        <span class="brand-tag">v2</span>
      </a>
      <ul class="nav flex-column">
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" exact-active-class="active" to="/v2" @click="sidebarOpen = false">
            <i class="fas fa-th-large"></i> 대시보드
          </router-link>
        </li>
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" to="/v2/assets" @click="sidebarOpen = false">
            <i class="fas fa-wallet"></i> 자산
          </router-link>
        </li>
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" to="/v2/recurring" @click="sidebarOpen = false">
            <i class="fas fa-sync-alt"></i> 고정지출
          </router-link>
        </li>
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" to="/v2/transactions" @click="sidebarOpen = false">
            <i class="fas fa-edit"></i> 거래
          </router-link>
        </li>

        <li class="nav-item mt-auto" style="border-top: 1px solid #e9ecef; padding-top: 0.5rem;">
          <router-link class="nav-link text-muted" to="/home" @click="sidebarOpen = false">
            <i class="fas fa-undo"></i> 기존 화면
          </router-link>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#" @click.prevent="logout">
            <i class="fas fa-sign-out-alt"></i> 로그아웃
          </a>
        </li>
      </ul>
    </nav>

    <div v-if="sidebarOpen" class="sidebar-overlay d-md-none" @click="sidebarOpen = false"></div>

    <button v-if="!sidebarOpen" class="btn btn-sm d-md-none sidebar-toggle"
            @click="sidebarOpen = true">
      <i class="fas fa-bars"></i>
    </button>

    <div class="main-content" @click="sidebarOpen = false">
      <router-view />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../lib/supabase.js'
import { applyLivingBudgetCharges, applyRecurringTransfers } from '../../lib/api_v2.js'

const router = useRouter()
const sidebarOpen = ref(false)

async function logout() {
  await supabase.auth.signOut()
  router.push('/login')
}

// v2 진입 시 자동 처리 (멱등 — 이미 처리된 월은 스킵)
onMounted(async () => {
  try { await applyLivingBudgetCharges() } catch (e) { /* noop */ }
  try { await applyRecurringTransfers() } catch (e) { /* noop */ }
})
</script>

<style scoped>
.brand-tag {
  display: inline-block;
  margin-left: 0.4rem;
  font-size: 0.7rem;
  font-weight: 700;
  color: #fff;
  background: #5e72e4;
  padding: 0.1rem 0.4rem;
  border-radius: 999px;
  vertical-align: middle;
}
</style>
