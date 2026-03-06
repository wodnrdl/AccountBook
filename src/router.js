import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from './lib/supabase.js'
import HomeView from './views/HomeView.vue'
import RegistrationView from './views/RegistrationView.vue'
import LoginView from './views/LoginView.vue'

const routes = [
  { path: '/', redirect: '/home' },
  { path: '/login', component: LoginView, meta: { public: true } },
  { path: '/home', component: HomeView },
  { path: '/registration', component: RegistrationView },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  if (to.meta.public) return true
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return '/login'
  return true
})

export default router
