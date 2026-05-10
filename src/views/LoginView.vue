<template>
  <div class="login-bg d-flex align-items-center justify-content-center">
    <div class="card login-card">
      <div class="card-body p-4">
        <div class="text-center mb-4">
          <i class="fas fa-piggy-bank fa-3x" style="color: #5e72e4"></i>
          <h4 class="mt-2">가계부</h4>
        </div>
        <form @submit.prevent="login">
          <div class="mb-3">
            <label class="form-label">이메일</label>
            <input type="email" class="form-control" v-model="email" placeholder="이메일 입력" required />
          </div>
          <div class="mb-3">
            <label class="form-label">비밀번호</label>
            <input type="password" class="form-control" v-model="password" placeholder="비밀번호 입력" required />
          </div>
          <div class="mb-3 form-check">
            <input type="checkbox" class="form-check-input" id="rememberMe" v-model="remember" />
            <label class="form-check-label" for="rememberMe">로그인 유지</label>
          </div>
          <div v-if="errorMsg" class="alert alert-danger py-2">{{ errorMsg }}</div>
          <button type="submit" class="btn btn-primary w-100" :disabled="logging">
            {{ logging ? '로그인 중...' : '로그인' }}
          </button>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase.js'

const router = useRouter()
const email = ref(localStorage.getItem('savedEmail') || '')
const password = ref('')
const remember = ref(!!localStorage.getItem('savedEmail'))
const logging = ref(false)
const errorMsg = ref('')

async function login() {
  if (logging.value) return
  logging.value = true
  errorMsg.value = ''

  const { error } = await supabase.auth.signInWithPassword({
    email: email.value,
    password: password.value,
  })

  if (error) {
    errorMsg.value = '이메일 또는 비밀번호가 올바르지 않습니다.'
    logging.value = false
    return
  }

  if (remember.value) {
    localStorage.setItem('savedEmail', email.value)
  } else {
    localStorage.removeItem('savedEmail')
  }

  router.push('/v2')
}
</script>

<style scoped>
.login-bg {
  min-height: 100vh;
  background: linear-gradient(87deg, #5e72e4 0, #825ee4 100%);
}

.login-card {
  width: 100%;
  max-width: 400px;
  border: 0;
  border-radius: 0.5rem;
  box-shadow: 0 0 2rem rgba(0, 0, 0, 0.2);
}
</style>
