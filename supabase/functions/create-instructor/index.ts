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
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SERVICE_ROLE_KEY')!)
    const { data: created, error } = await admin.auth.admin.createUser({ email: payload.email.trim(), password: payload.password, email_confirm: true, user_metadata: { full_name: payload.full_name, phone: payload.phone } })
    if (error || !created.user) throw error ?? new Error('建立老師帳號失敗')
    const { error: profileError } = await admin.from('profiles').upsert({ id: created.user.id, email: payload.email.trim(), full_name: payload.full_name.trim(), phone: payload.phone.trim(), role: 'instructor', is_instructor: true, is_active: payload.is_active !== false })
    if (profileError) throw profileError
    return new Response(JSON.stringify({ id: created.user.id }), { headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : '建立老師失敗' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } })
  }
})
