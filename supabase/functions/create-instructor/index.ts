import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const authHeader = request.headers.get('Authorization')
    if (!authHeader) throw new Error('未登入')
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await client.auth.getUser()
    if (!user) throw new Error('未登入')
    const { data: actor } = await client.from('profiles').select('role,is_active').eq('id', user.id).single()
    if (actor?.role !== 'admin' || !actor.is_active) throw new Error('只有啟用中的管理員可以建立老師')
    const payload = await request.json()
    if (!payload.email || !payload.password || !payload.full_name || !payload.phone) throw new Error('請完整填寫老師資料')
    if (payload.password.length < 6) throw new Error('初始密碼至少需要 6 碼')
    const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY')
    if (!serviceRoleKey) throw new Error('Supabase Function 尚未設定 SERVICE_ROLE_KEY')
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, serviceRoleKey)
    const email = payload.email.trim().toLowerCase()
    let teacherId: string
    let createdNewUser = false
    const { data: created, error } = await admin.auth.admin.createUser({ email, password: payload.password, email_confirm: true, user_metadata: { full_name: payload.full_name, phone: payload.phone } })
    if (created?.user) {
      teacherId = created.user.id
      createdNewUser = true
    } else if (error?.message?.toLowerCase().includes('already') || error?.message?.toLowerCase().includes('registered')) {
      const { data: existing, error: existingError } = await admin.auth.admin.getUserByEmail(email)
      if (existingError || !existing.user) throw new Error('此 Email 已存在，但找不到對應的登入帳號。請確認 Supabase Auth 使用者資料。')
      teacherId = existing.user.id
      const { error: passwordError } = await admin.auth.admin.updateUserById(teacherId, { password: payload.password, email_confirm: true, user_metadata: { ...existing.user.user_metadata, full_name: payload.full_name, phone: payload.phone } })
      if (passwordError) throw passwordError
    } else {
      throw error ?? new Error('建立老師帳號失敗')
    }
    const { error: profileError } = await admin.from('profiles').upsert({ id: teacherId, email, full_name: payload.full_name.trim(), phone: payload.phone.trim(), role: 'instructor', is_instructor: true, is_active: payload.is_active !== false })
    if (profileError) {
      if (createdNewUser) await admin.auth.admin.deleteUser(teacherId)
      throw profileError
    }
    return new Response(JSON.stringify({ ok: true, id: teacherId, existing: !createdNewUser }), { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (error) {
    const message = error instanceof Error ? error.message : '建立老師失敗'
    console.error('create-instructor failed:', message)
    return new Response(JSON.stringify({ ok: false, error: message }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } })
  }
})
