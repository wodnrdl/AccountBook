<template>
  <button class="fab-add" :title="label" @click="$emit('click')">
    <i class="fas fa-plus"></i>
    <span v-if="label" class="fab-label">{{ label }}</span>
  </button>
</template>

<script setup>
defineProps({
  label: { type: String, default: '추가' },
})
defineEmits(['click'])
</script>

<style scoped>
.fab-add {
  position: fixed;
  right: calc(1rem + env(safe-area-inset-right, 0px));
  bottom: calc(1.25rem + env(safe-area-inset-bottom, 0px));
  z-index: 1040;
  background: #5e72e4;
  color: #fff;
  border: none;
  border-radius: 999px;
  padding: 0.7rem 1.3rem;
  box-shadow: 0 8px 20px rgba(94, 114, 228, 0.4);
  display: inline-flex;
  align-items: center;
  gap: 0.55rem;
  font-weight: 600;
  font-size: 0.95rem;
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.fab-add:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 24px rgba(94, 114, 228, 0.5);
}
.fab-add:active {
  transform: translateY(0);
}
.fab-add i { font-size: 0.95rem; }
</style>
