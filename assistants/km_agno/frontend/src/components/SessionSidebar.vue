<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <h2 class="title">Chats</h2>
      <button type="button" class="btn-new" @click="emit('new-chat')">New chat</button>
    </div>
    <label class="user-field">
      <span>User ID</span>
      <input
        v-model="localUserId"
        type="text"
        autocomplete="username"
        placeholder="local"
        @change="onUserIdCommit"
        @keydown.enter="onUserIdCommit"
      />
    </label>
    <p v-if="listError" class="side-error">{{ listError }}</p>
    <ul class="session-list">
      <li v-for="s in sessions" :key="s.session_id">
        <button
          type="button"
          class="session-item"
          :class="{ active: s.session_id === selectedSessionId }"
          @click="emit('select', s.session_id)"
        >
          <span class="session-name">{{ s.session_name || s.session_id }}</span>
          <span class="session-id">{{ s.session_id }}</span>
        </button>
      </li>
    </ul>
    <div v-if="loading" class="side-muted">Loading…</div>
    <button
      v-if="hasMore && !loading"
      type="button"
      class="btn-more"
      @click="loadMore"
    >
      Load more
    </button>
  </aside>
</template>

<script setup>
import { ref, watch, onMounted, computed } from 'vue'
import { listSessions } from '@/services/agentOs.js'

const props = defineProps({
  agentId: { type: String, required: true },
  userId: { type: String, required: true },
  selectedSessionId: { type: String, default: null }
})

const emit = defineEmits(['select', 'new-chat', 'update:userId'])

const sessions = ref([])
const nextPage = ref(1)
const totalPages = ref(1)
const loading = ref(false)
const listError = ref(null)
const localUserId = ref(props.userId)

watch(
  () => props.userId,
  (v) => {
    localUserId.value = v
  }
)

const hasMore = computed(
  () => totalPages.value > 0 && nextPage.value <= totalPages.value
)

async function fetchSessions(append) {
  if (!props.agentId) return
  listError.value = null
  loading.value = true
  try {
    const res = await listSessions({
      userId: props.userId || undefined,
      agentId: props.agentId,
      page: nextPage.value,
      limit: 25
    })
    const rows = res.data ?? []
    const meta = res.meta ?? {}
    totalPages.value = meta.total_pages != null ? meta.total_pages : rows.length > 0 ? 1 : 0
    if (append) {
      sessions.value = [...sessions.value, ...rows]
    } else {
      sessions.value = rows
    }
    if (rows.length > 0) {
      nextPage.value += 1
    }
  } catch (e) {
    listError.value = e.message || 'Failed to list sessions'
  } finally {
    loading.value = false
  }
}

function refreshList() {
  sessions.value = []
  nextPage.value = 1
  totalPages.value = 0
  fetchSessions(false)
}

function loadMore() {
  fetchSessions(true)
}

function onUserIdCommit() {
  const v = localUserId.value.trim() || 'local'
  localUserId.value = v
  emit('update:userId', v)
}

watch(
  () => [props.agentId, props.userId],
  () => {
    refreshList()
  }
)

onMounted(() => {
  refreshList()
})

defineExpose({
  refreshList
})
</script>

<style scoped>
.sidebar {
  width: 280px;
  min-width: 280px;
  border-right: 1px solid #1e293b;
  background: #0f172a;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.sidebar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1rem 0.75rem;
  gap: 0.5rem;
}

.title {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
  color: #f1f5f9;
}

.btn-new {
  background: #10b981;
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 0.375rem 0.625rem;
  font-size: 0.8125rem;
  cursor: pointer;
}

.btn-new:hover {
  background: #059669;
}

.user-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0 1rem 0.75rem;
  font-size: 0.75rem;
  color: #94a3b8;
}

.user-field input {
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 8px;
  padding: 0.5rem 0.625rem;
  color: #f1f5f9;
  font-size: 0.875rem;
}

.side-error {
  margin: 0 1rem 0.5rem;
  font-size: 0.75rem;
  color: #fca5a5;
}

.session-list {
  list-style: none;
  margin: 0;
  padding: 0 0.5rem;
  overflow-y: auto;
  flex: 1;
}

.session-item {
  width: 100%;
  text-align: left;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 8px;
  padding: 0.5rem 0.625rem;
  margin-bottom: 0.25rem;
  cursor: pointer;
  color: #e2e8f0;
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.session-item:hover {
  background: #1e293b;
}

.session-item.active {
  border-color: #10b981;
  background: #1e293b;
}

.session-name {
  font-size: 0.8125rem;
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.session-id {
  font-size: 0.6875rem;
  color: #64748b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.side-muted {
  padding: 0.5rem 1rem;
  font-size: 0.75rem;
  color: #64748b;
}

.btn-more {
  margin: 0.5rem 1rem 1rem;
  background: #1e293b;
  border: 1px solid #334155;
  color: #cbd5e1;
  border-radius: 8px;
  padding: 0.5rem;
  font-size: 0.8125rem;
  cursor: pointer;
}

.btn-more:hover {
  border-color: #10b981;
  color: #10b981;
}
</style>
