<template>
  <Teleport to="body">
    <transition name="fade">
      <div v-if="modelValue" class="v2-modal-backdrop" @click.self="close">
        <div class="v2-modal" :class="size">
          <div class="v2-modal-head">
            <h5 class="m-0">{{ title }}</h5>
            <button class="btn-close" @click="close"><i class="fas fa-times"></i></button>
          </div>
          <div class="v2-modal-body">
            <slot />
          </div>
          <div v-if="$slots.footer" class="v2-modal-foot">
            <slot name="footer" />
          </div>
        </div>
      </div>
    </transition>
  </Teleport>
</template>

<script setup>
const props = defineProps({
  modelValue: Boolean,
  title: { type: String, default: '' },
  size:  { type: String, default: 'md' }, // sm/md/lg
})
const emit = defineEmits(['update:modelValue', 'close'])
function close() {
  emit('update:modelValue', false)
  emit('close')
}
</script>

<style scoped>
.v2-modal-backdrop {
  position: fixed; inset: 0;
  background: rgba(0,0,0,0.45);
  z-index: 1050;
  display: flex; align-items: center; justify-content: center;
  padding: 1rem;
}
.v2-modal {
  background: #fff; border-radius: 12px;
  width: 100%; max-width: 480px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
  display: flex; flex-direction: column;
  max-height: 90vh;
}
.v2-modal.sm { max-width: 360px; }
.v2-modal.lg { max-width: 720px; }

.v2-modal-head {
  display: flex; justify-content: space-between; align-items: center;
  padding: 0.9rem 1.1rem; border-bottom: 1px solid #f0f3f7;
}
.v2-modal-body { padding: 1.1rem; overflow-y: auto; }
.v2-modal-foot {
  display: flex; justify-content: flex-end; gap: 0.5rem;
  padding: 0.75rem 1.1rem; border-top: 1px solid #f0f3f7;
  background: #f9fbfd; border-radius: 0 0 12px 12px;
}
.btn-close {
  background: none; border: none; font-size: 1rem; color: #8898aa; cursor: pointer;
  width: 28px; height: 28px; border-radius: 6px;
}
.btn-close:hover { background: #f0f3f7; }

.fade-enter-active, .fade-leave-active { transition: opacity 0.15s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
