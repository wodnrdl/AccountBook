<template>
  <transition name="fade-pop">
    <button v-if="show" class="fab-scroll-top" title="맨 위로" @click="toTop">
      <i class="fas fa-chevron-up"></i>
    </button>
  </transition>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

const show = ref(false)
const THRESHOLD = 240

function onScroll() {
  show.value = (window.scrollY || document.documentElement.scrollTop || 0) > THRESHOLD
}
function toTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

onMounted(() => {
  window.addEventListener('scroll', onScroll, { passive: true })
  onScroll()
})
onBeforeUnmount(() => {
  window.removeEventListener('scroll', onScroll)
})
</script>

<style scoped>
.fab-scroll-top {
  position: fixed;
  right: calc(1rem + env(safe-area-inset-right, 0px));
  bottom: calc(1.25rem + env(safe-area-inset-bottom, 0px));
  z-index: 1040;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: #fff;
  color: #5e72e4;
  border: none;
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.18);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.95rem;
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.fab-scroll-top:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 22px rgba(0, 0, 0, 0.22);
  color: #4456c7;
}
.fab-scroll-top:active { transform: translateY(0); }

.fade-pop-enter-active, .fade-pop-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}
.fade-pop-enter-from, .fade-pop-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
</style>
