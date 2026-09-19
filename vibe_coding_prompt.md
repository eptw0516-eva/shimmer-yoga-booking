# 瑜伽教室系統 Vibe Coding 實戰 Prompt 指南

請將本指南中的 Prompt 依照順序（階段一至階段四）逐一提供給 VS Code 中的 Claude 執行。切勿一次性丟入全部內容，確保每一步驗證成功後再進入下一步。

---

## 階段一：初始化專案骨架與環境設定
**使用時機**：在 VS Code 開啟一個空白資料夾後發送。

```text
請依據專案根目錄的 `.clauderules` 規範，在當前空目錄中初始化「瑜伽教室預約系統」的前端專案：
1. 使用 Vite + Vue 3 + TypeScript 建立專案骨架。
2. 安裝並配置 Tailwind CSS、Lucide Vue Next（圖示庫）、Pinia（狀態管理）以及 @supabase/supabase-js。
3. 配置 Mobile-First 視角容器，確保在桌面瀏覽器開啟時呈現居中手機預覽框（寬度 430px），在行動裝置或 LINE LIFF 內時滿版呈現。
4. 建立基礎路由結構（Vue Router）：
   - `/`：課表預約首頁
   - `/my-passes`：我的堂數與預約紀錄
   - `/check-in`：現場簽到頁（老師/學員雙視圖）
   - `/admin`：教室管理後台
5. 建立 `.env.example` 檔案，預留 VITE_SUPABASE_URL 與 VITE_SUPABASE_ANON_KEY。

完成後請直接執行建置確認無錯誤，並提供本機啟動指令。
```

---

## 階段二：資料庫結構與防超賣交易 (Supabase Migration)
**使用時機**：專案骨架跑通後，準備建立資料庫表結構與 RPC。

```text
我們需要設計本系統的後端資料結構。請在 `/supabase/migrations` 目錄下生成一份完整的 SQL 檔案，涵蓋以下設計：
1. 建立必要資料表：
   - `profiles`：用戶資料（含 role: member / instructor / admin, line_user_id, phone, full_name）
   - `user_packages`：學員購買的堂數包（total_credits, remaining_credits, valid_until, status）
   - `classes`：排課主表（title, instructor_id, room, start_time, end_time, capacity, booked_count）
   - `bookings`：預約紀錄（user_id, class_id, status: confirmed / cancelled / attended, created_at）
2. 建立防超賣與扣課 Stored Procedure (RPC) `book_class(p_class_id UUID, p_user_id UUID)`：
   - 使用單一交易（BEGIN ... COMMIT）。
   - 對排課列加上 `FOR UPDATE` 行級鎖，檢查 `booked_count < capacity`。
   - 檢查用戶在 `user_packages` 中是否有未過期且 `remaining_credits > 0` 的堂數。
   - 若通過，扣除 1 堂點數，課堂 `booked_count + 1`，並在 `bookings` 新增紀錄。
   - 若失敗，拋出明確例外（如 'CLASS_FULL' 或 'INSUFFICIENT_CREDITS'）。
3. 建立對應取消預約與退點 RPC `cancel_booking(p_booking_id UUID)`。
4. 啟用全部資料表的 RLS，並建立標準 CRUD 安全策略。
5. 在前端 `src/types/database.ts` 中產生對應的 TypeScript Interface。
```

---

## 階段三：學員端核心功能串接（課表與預約）
**使用時機**：資料庫 Schema 與 TypeScript 定義完成後。

```text
現在請實作學員端核心畫面與互動邏輯：
1. 建立 `src/services/supabase.ts` 客戶端封裝。
2. 建立 `src/stores/bookingStore.ts`：
   - 取得當週/當月課表。
   - 呼叫 Supabase RPC `book_class` 與 `cancel_booking`。
3. 實作首頁課表視圖 `src/views/ScheduleView.vue`：
   - 上方提供日期橫向滾動選擇器（週一至週日）。
   - 課程卡片顯示：課程名稱、老師姓名、時段、剩餘名額（若已滿顯示「額滿」按鈕反灰）。
   - 點擊「立即預約」彈出確認 Modal（顯示剩餘可用堂數）。
   - 串接預約交易，並在成功後呈現明確 Toast 提示與扣堂後餘額更新。
4. 實作 `src/views/MyPassesView.vue`：
   - 顯示個人可用剩餘堂數、有效期限。
   - 列表呈現「已預約即將上課」與「歷史上課紀錄」。
```

---

## 階段四：現場簽到與管理員後台
**使用時機**：學員預約正常運作後，補齊管理與簽到環節。

```text
最後請實作上課簽到與管理端功能：
1. 簽到機制 `src/views/CheckInView.vue`：
   - 老師視圖：選擇今日名下課程，展開已預約學員名單，提供一鍵勾選「簽到（Attended）」或「缺席（No Show）」。
   - 學員快速視圖：提供個人動態簽到 QR Code（或點擊輸入課堂簽到碼）。
2. 管理後台 `src/views/AdminView.vue`：
   - 學員管理：搜尋學員、查看剩餘堂數，並提供按鈕可手動加贈/扣除堂數（附帶備註原因）。
   - 排課管理：新增/修改單堂瑜伽課（名稱、講師、上限人數、開課時間）。
3. 權限防護：在前端路由導航守衛（Router Guard）加入判斷，非 admin 角色進入 `/admin` 需重定向至首頁。
```