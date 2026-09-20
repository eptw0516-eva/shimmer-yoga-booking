# Google 快速登入設定指引

目前網站已先移除「使用 Google 快速登入」按鈕，避免會員點擊沒有完成設定的功能。Email 登入與註冊不受影響。

## 是否可以全部由程式自動完成？

不能全部自動完成。程式可以準備 OAuth 呼叫與登入畫面，但以下操作必須由專案管理者在 Google Cloud 與 Supabase 後台完成：

- 建立 Google OAuth Client ID
- 設定 Google OAuth 同意畫面
- 取得 Client ID 與 Client Secret
- 將 Google 的 redirect URI 加入白名單
- 將 Client ID／Secret 儲存到 Supabase Auth Provider
- 設定正式網站與本機測試網址

不要把 Client Secret 放進 Vue 前端、`VITE_` 環境變數或 Git。

## 一、確認正式網站網址

目前正式網站：

```text
https://shimmer-yoga-booking.vercel.app
```

Supabase OAuth callback URL 通常是：

```text
https://jazdcyvarbsmvhmxojce.supabase.co/auth/v1/callback
```

實際 callback URL 請以 Supabase Dashboard 的 Google Provider 設定頁面顯示為準。

## 二、建立 Google OAuth 應用程式

1. 開啟 [Google Cloud Console](https://console.cloud.google.com/)。
2. 選擇現有專案，或建立新的專案。
3. 進入 **APIs & Services → OAuth consent screen**。
4. User type 選擇 **External**（若是 Workspace 內部系統才選 Internal）。
5. 填寫 App name，例如 `微光空中瑜珈`。
6. 填寫支援 Email 與 Developer contact information。
7. 儲存並繼續。
8. 若應用程式處於 Testing，將需要登入的測試帳號加入 Test users。

Google 登入只需要基本 OpenID scope：`openid`、`email`、`profile`。不需要加入 Gmail、Drive 或其他高權限 scope。

## 三、建立 OAuth Client ID

1. 進入 **APIs & Services → Credentials**。
2. 點擊 **Create Credentials → OAuth client ID**。
3. Application type 選擇 **Web application**。
4. Authorized JavaScript origins 加入：

   ```text
   https://shimmer-yoga-booking.vercel.app
   ```

5. 若需要本機測試，再加入：

   ```text
   http://localhost:5173
   ```

6. Authorized redirect URIs 加入 Supabase callback URL：

   ```text
   https://jazdcyvarbsmvhmxojce.supabase.co/auth/v1/callback
   ```

7. 建立後保存 **Client ID** 與 **Client Secret**。

## 四、在 Supabase 啟用 Google Provider

1. 開啟 [Supabase Dashboard](https://supabase.com/dashboard)。
2. 選擇本專案。
3. 進入 **Authentication → Providers → Google**。
4. 開啟 Google provider。
5. 貼上 Google Cloud 的 Client ID 與 Client Secret。
6. 儲存設定。

接著進入 **Authentication → URL Configuration**，確認：

- Site URL：

  ```text
  https://shimmer-yoga-booking.vercel.app
  ```

- Additional Redirect URLs：

  ```text
  https://shimmer-yoga-booking.vercel.app
  http://localhost:5173
  ```

## 五、通知開發者重新啟用按鈕

完成上述後，請告知「Google Provider 已啟用」。重新啟用前需要確認：

- Google 登入成功後能回到網站
- 新 Google 使用者會建立 `profiles`
- 既有 Email 是否可能因同 Email 而發生帳號合併或衝突
- 測試環境與正式環境 redirect URL 都能使用

## 六、測試清單

1. 使用未註冊的 Google 帳號登入。
2. 確認 Supabase Authentication → Users 出現帳號。
3. 確認 `public.profiles` 有相同 UUID 的會員資料。
4. 登出後重新使用 Google 登入。
5. 測試一般會員預約、票券與簽到。
6. 確認非管理員 Google 帳號不會取得管理員權限。

## 安全注意事項

- Client Secret 只能放在 Supabase Provider 設定。
- 若曾將 Secret 貼到聊天、截圖或 Git，應立即撤銷並重新建立。
- 不要將 Google Client Secret 寫入 `.env` 的 `VITE_` 變數。
- 不要把 service role key 放入前端或 Google OAuth 設定。
