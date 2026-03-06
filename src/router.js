import { createRouter, createWebHistory } from 'vue-router'
import HomeView from './views/HomeView.vue'
import RegistrationView from './views/RegistrationView.vue'

const routes = [
  { path: '/', redirect: '/home' },
  { path: '/home', component: HomeView },
  { path: '/registration', component: RegistrationView },
]

export default createRouter({
  history: createWebHistory(),
  routes,
})
