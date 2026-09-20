export type UserRole = 'member' | 'instructor' | 'admin'
export type PackageStatus = 'active' | 'expired' | 'depleted'
export type BookingStatus = 'confirmed' | 'cancelled' | 'late_cancelled' | 'attended' | 'no_show'
export type CourseType = '常態課' | '預約團體課' | '一對一私人課' | '單堂工作坊'
export type PurchasePlanType = 'single' | 'credits' | 'unlimited' | 'stored_value'
export type PaymentMethod = 'bank_transfer' | 'cash'
export type OrderStatus = 'pending_review' | 'approved' | 'rejected'

export interface Profile {
  id: string
  email?: string | null
  role: UserRole
  line_user_id: string | null
  phone: string | null
  birth_date?: string | null
  is_instructor?: boolean
  is_active?: boolean
  full_name: string
  avatar_url?: string | null
  created_at: string
}
export interface UserPackage {
  id: string
  user_id: string
  owner_id?: string | null
  package_name?: string
  package_type?: string | null
  initial_credits?: number
  total_credits: number
  remaining_credits: number
  valid_until: string
  status: PackageStatus
  note?: string | null
  created_at: string
  plan_name?: string
  plan_type?: PurchasePlanType
  shared_with_phones?: string[]
  purchase_amount?: number | null
  unit_price?: number | null
  plan_description?: string | null
  shareable?: boolean
}
export interface PurchasePlan {
  id: string
  name: string
  type: PurchasePlanType
  description: string
  price: number
  unit_price?: number
  note?: string | null
  credits: number | null
  validDays: number
  shareable: boolean
  badge?: string
  is_active?: boolean
}
export interface PurchaseOrder {
  id: string
  user_id: string
  plan_id: string
  plan_name: string
  amount: number
  payment_method: PaymentMethod
  transfer_last_five: string | null
  status: OrderStatus
  created_at: string
  package_id?: string
}
export interface YogaClass {
  id: string
  title: string
  description?: string | null
  instructor_id: string
  instructor_name?: string
  instructor_bio?: string
  course_type: CourseType
  room: string
  start_time: string
  end_time: string
  capacity: number
  booked_count: number
  level: '初階' | '中階' | '高階' | '進階'
}
export interface Booking {
  id: string
  user_id: string
  class_id: string
  status: BookingStatus
  created_at: string
  checked_in_at?: string | null
  class?: YogaClass
}
export interface AttendanceRecord {
  booking_id: string
  status: 'attended' | 'no_show'
}
export interface CheckInResult {
  booking: Booking
  class: YogaClass
}
export interface Database {
  public: {
    Tables: {
      profiles: { Row: Profile; Insert: Partial<Profile> & Pick<Profile, 'id' | 'full_name'>; Update: Partial<Profile>; Relationships: [] }
      user_packages: { Row: UserPackage; Insert: Omit<UserPackage, 'id' | 'created_at'>; Update: Partial<UserPackage>; Relationships: [] }
      classes: { Row: YogaClass; Insert: Omit<YogaClass, 'id'>; Update: Partial<YogaClass>; Relationships: [] }
      bookings: { Row: Booking; Insert: Omit<Booking, 'id' | 'created_at'>; Update: Partial<Booking>; Relationships: [] }
      purchase_orders: { Row: PurchaseOrder; Insert: Omit<PurchaseOrder, 'id' | 'created_at'>; Update: Partial<PurchaseOrder>; Relationships: [] }
      purchase_plans: { Row: { id: string; category: PurchasePlanType; name: string; badge: string | null; note: string | null; description: string; valid_days: number; shareable: boolean; credits: number | null; unit_price: number; total_price: number; is_active: boolean; sort_order: number; created_at: string; updated_at: string }; Insert: never; Update: Partial<{ name: string; category: PurchasePlanType; badge: string | null; note: string | null; description: string; valid_days: number; shareable: boolean; credits: number | null; unit_price: number; total_price: number; is_active: boolean; sort_order: number }>; Relationships: [] }
    }
    Functions: {
      book_class: { Args: { p_class_id: string; p_user_id: string }; Returns: Booking }
      cancel_booking: { Args: { p_booking_id: string }; Returns: Booking }
      late_cancel_booking: { Args: { p_booking_id: string }; Returns: Booking }
      checkin_class: { Args: { p_booking_id: string; p_token: string }; Returns: Booking }
      approve_purchase_order: { Args: { p_order_id: string }; Returns: UserPackage }
    },
    Views: {},
    Enums: {
      user_role: UserRole
      package_status: PackageStatus
      booking_status: BookingStatus
    },
    CompositeTypes: {}
  }
}
