<template>
  <div>
    <!-- Sidebar -->
    <nav class="sidebar" :class="{ show: sidebarOpen }">
      <a class="brand" href="/home">
        <i class="fas fa-piggy-bank fa-2x" style="color: #5e72e4"></i>
      </a>
      <ul class="nav flex-column">
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" to="/home">
            <i class="fas fa-chart-bar"></i> 통계
          </router-link>
        </li>
        <li class="nav-item">
          <router-link class="nav-link" active-class="active" to="/registration">
            <i class="fas fa-edit"></i> 등록
          </router-link>
        </li>
      </ul>
    </nav>

    <!-- Mobile toggle -->
    <button class="btn btn-sm d-md-none position-fixed" style="z-index:101;top:10px;left:10px"
            @click="sidebarOpen = !sidebarOpen">
      <i class="fas fa-bars"></i>
    </button>

    <!-- Main -->
    <div class="main-content">
      <router-view />
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
const sidebarOpen = ref(false)
</script>
