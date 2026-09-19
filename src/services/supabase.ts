import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '../types/database'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
export const isSupabaseConfigured = Boolean(url && key && !url.includes('your-project'))
export const supabase: SupabaseClient<Database> | null = isSupabaseConfigured ? createClient<Database>(url!, key!) : null
