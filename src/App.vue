<template>
  <div v-if="isLoginPage || isV2">
    <router-view />
  </div>
  <div v-else>
    <!-- Sidebar -->
    <nav class="sidebar" :class="{ show: sidebarOpen }">
      <a class="brand" href="/home">
        <i class="fas fa-piggy-bank fa-2x" style="color: #5e72e4"></i>
      </a>
      <ul class="nav flex-column">
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" to="/home" @click="sidebarOpen = false">
            <i class="fas fa-chart-bar"></i> 통계
          </router-link>
        </li>
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" to="/registration" @click="sidebarOpen = false">
            <i class="fas fa-edit"></i> 등록
          </router-link>
        </li>
        <li class="nav-item mt-auto" style="border-top: 1px solid #e9ecef; padding-top: 0.5rem;">
          <router-link class="nav-link" to="/v2" @click="sidebarOpen = false">
            <i class="fas fa-rocket"></i> 새 버전 (v2)
          </router-link>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#" @click.prevent="logout">
            <i class="fas fa-sign-out-alt"></i> 로그아웃
          </a>
        </li>
      </ul>
    </nav>

    <!-- Mobile overlay -->
    <div v-if="sidebarOpen" class="sidebar-overlay d-md-none" @click="sidebarOpen = false"></div>

    <!-- Mobile toggle -->
    <button v-if="!sidebarOpen" class="btn btn-sm d-md-none sidebar-toggle"
            @click="sidebarOpen = true">
      <i class="fas fa-bars"></i>
    </button>

    <!-- Main -->
    <div class="main-content" @click="sidebarOpen = false">
      <router-view />
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from './lib/supabase.js'

const route = useRoute()
const router = useRouter()
const sidebarOpen = ref(false)
const isLoginPage = computed(() => route.path === '/login')
const isV2 = computed(() => route.path.startsWith('/v2'))

async function logout() {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>
