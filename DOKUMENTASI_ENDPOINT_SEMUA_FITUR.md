# Dokumentasi Lengkap Link Endpoint API Semua Fitur — Aplikasi TKA (`appstka`)

Dokumen ini merinci **seluruh link endpoint HTTP (`GET`, `POST`, `PATCH`, `PUT`, `DELETE`) dan WebSocket (`WS/WSS`)** yang dipanggil oleh setiap fitur di aplikasi Flutter `appstka` beserta server proxy `tool/secure_api_gateway.dart`.

> **Keamanan & Base URL Utama**
> - Pada **Flutter Web** dan **Pengujian API (Thunder Client / Postman / cURL)**, seluruh trafik masuk melalui **TKA Secure API Gateway**:
>   - **Base URL Gateway:** `http://localhost:8787`
>   - **WebSocket Gateway:** `ws://localhost:8787`
> - Gateway secara otomatis menyuntikkan `apikey`, `Authorization` (jika tidak membawa JWT user), `BREVO_API_KEY`, dan `MAPTILER_API_KEY` di sisi server sehingga **tidak ada secret key yang terekspos di client**.
> - Pada **Android / iOS / Desktop** (jika tidak diarahkan ke Gateway), base URL membaca `SUPABASE_URL` dari `.env` lokal (`lib/config/app_env.dart`) dengan path yang **100% identik** (`/auth/v1/*`, `/rest/v1/*`, `/storage/v1/*`, `/realtime/v1/*`).

---

## Ringkasan Arsitektur & Fitur Keamanan Gateway

| Komponen Gateway | Aturan / Konfigurasi (`tool/secure_api_gateway.dart`) |
| :--- | :--- |
| **Rate Limiter** | Endpoint sensitif (`/auth/*`, `/brevo/*`, `/api/auth/*`): **40 req / menit / IP**. Endpoint API umum: **300 req / menit / IP** (melebihi batas -> `429 Too Many Requests`). |
| **Security WAF** | Memblokir pola SQL Injection & XSS pada Query String maupun JSON Body (`400 Bad Request`). |
| **RAM Cache (`X-Cache`)** | `GET /api/map/style.json` (TTL **1 jam**), `GET /rest/v1/stations` (TTL **5 menit**), `GET /rest/v1/train_schedules` (TTL **2 menit**, auto-invalidate saat ada `POST`/`PATCH`/`DELETE`). |
| **Headers Standar Client** | `Content-Type: application/json`, `Accept: application/json`, `Authorization: Bearer <ACCESS_TOKEN_JWT>` (opsional saat via Gateway, wajib untuk operasi terikat sesi user). |

---

## Matriks Ringkas Seluruh Endpoint per Modul Fitur

| No | Modul Fitur | `GET` | `POST` | `PATCH` | `PUT` | `DELETE` | `WS` | Total |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0** | Infrastruktur & Health Gateway | 2 | — | — | — | — | — | **2** |
| **1** | Autentikasi, Login, Register, Google OAuth & Captcha | 2 | 5 | — | — | — | — | **7** |
| **2** | Reset Kata Sandi 3-Tahap (Email -> OTP -> Sandi Baru) | *(internal)* | 3 | — | 1 | — | — | **4** |
| **3** | Profil Pengguna, Edit Identitas & Upload Avatar | 2 | 1 | 2 | — | — | — | **5** |
| **4** | Dompet TKAPay (Saldo, Top Up, Scan QR & Riwayat) | 2 | 1 | 1 | — | — | — | **4** |
| **5** | Master Stasiun, Jadwal & Katalog Kereta | 4 | 1 | — | — | — | — | **5** |
| **6** | Riwayat Pencarian Rute (`recent_searches`) | 1 | 1 | — | — | 2 | — | **4** |
| **7** | Pemesanan Tiket (`bookings`) & Pembayaran (`payments`) | 1 | 3 | 2 | — | — | — | **6** |
| **8** | E-Ticket Boarding Pass & QR Storage (`tickets-qr`) | 1 | 2 | — | — | — | — | **3** |
| **9** | Pembatalan Tiket & Refund (`cancellations`) | 2 | 2 | 1 | — | — | — | **5** |
| **10** | Live Tracking, Peta MapLibre/MapTiler & Global Search | 5 | — | — | — | — | 1 | **6** |
| **11** | Favorit, Preferensi & Notifikasi Brevo Email | 4 | 4 | 3 | — | 1 | — | **12** |
| **12** | Dashboard Admin, Armada, Transaksi & Audit Log | 3 | 4 | 2 | — | — | — | **9** |
| | **TOTAL KESELURUHAN** | **29** | **27** | **11** | **1** | **3** | **1** | **72** |

---

## Modul 0 — Infrastruktur & Health Check Gateway

| Fitur | Method | Link Endpoint Lengkap | Keterangan & Respons |
| :--- | :---: | :--- | :--- |
| **Cek Status Server Gateway** | `GET` | `http://localhost:8787/health` | `200 OK`: `{"status":"ok","gateway":"TKA Secure API Gateway","secrets_protected":true}` (`tool/secure_api_gateway.dart:218`) |
| **Alias Health Check** | `GET` | `http://localhost:8787/api/health` | Sama dengan `/health`. |
| **CORS Preflight** | `OPTIONS` | `http://localhost:8787/*` | `204 No Content` dengan header `Access-Control-Allow-Methods: GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD`. |

---

## Modul 1 — Autentikasi, Registrasi, Login, Google OAuth & Captcha

**Pemicu UI:** `lib/register/register_screen.dart`, `lib/login/login_screen.dart`, `lib/login/widgets/cloudflare_turnstile_box.dart`, `lib/profile/profile_screen.dart`  
**Service:** `lib/services/auth_service.dart`, `lib/services/turnstile_service.dart`, `lib/services/session_service.dart`, `lib/services/supabase_service.dart`

### 1.1 Verifikasi Captcha Cloudflare Turnstile (Melalui Secure API Gateway — Bebas CORS Web)
- **Method & URL:** `POST http://localhost:8787/api/security/turnstile/verify`
- **Pemicu:** `lib/login/widgets/cloudflare_turnstile_box.dart:40` -> `lib/services/turnstile_service.dart:60-72` -> `tool/secure_api_gateway.dart:341-353`
- **Headers:** `Content-Type: application/json`, `Accept: application/json`
- **Body JSON:** `{"response": "<TURNSTILE_CLIENT_TOKEN>"}`
- **Proses Internal Server-Side:** Gateway menyuntikkan `TURNSTILE_SECRET_KEY` dari `.env` lalu memanggil `POST https://challenges.cloudflare.com/turnstile/v0/siteverify` secara server-to-server agar browser Web bebas error CORS (`Failed to fetch`).
- **Response:** `200 OK` -> `{"success": true, "verified": true, "hostname": "...", "message": "Verifikasi Cloudflare Turnstile berhasil."}`

### 1.2 Registrasi Akun Penumpang Baru (Supabase Auth)
- **Method & URL:** `POST http://localhost:8787/auth/v1/signup`
- **Pemicu:** `lib/register/register_screen.dart:99` -> `lib/services/auth_service.dart:60-68` *(juga auto-session di `auth_service.dart:561` dan anonymous upload fallback di `supabase_storage_service.dart:296`)*
- **Body JSON:**
```json
{
  "email": "budi.santoso@gmail.com",
  "password": "PasswordKuat123!",
  "data": {
    "full_name": "Budi Santoso",
    "phone": "081234567890",
    "role": "passenger"
  }
}
```
- **Response:** `200 OK` (trigger DB `on_auth_user_created_sync_users` otomatis menyinkronkan ke `public.users`). Duplikat: `400 / 422 User already registered`.

### 1.3 Sinkronisasi / Upsert Data Penumpang ke Tabel Tunggal `users`
- **Method & URL:** `POST http://localhost:8787/rest/v1/users`
- **Pemicu:** `lib/services/auth_service.dart:100`, `193`, `439`, `483`
- **Headers:** `Content-Type: application/json`, `Authorization: Bearer <ACCESS_TOKEN_JWT>`, `Prefer: resolution=merge-duplicates`
- **Body JSON:**
```json
{
  "id": "75dcc7c4-1bf6-4a9a-a992-8c2137de4098",
  "email": "budi.santoso@gmail.com",
  "full_name": "Budi Santoso",
  "phone": "081234567890",
  "role": "passenger",
  "created_at": "2026-11-27T10:00:00.000Z",
  "updated_at": "2026-11-27T10:00:00.000Z"
}
```
- **Response:** `201 Created` / `200 OK`.

### 1.4 Login Menggunakan Email & Kata Sandi
- **Method & URL:** `POST http://localhost:8787/auth/v1/token?grant_type=password`
- **Pemicu:** `lib/login/login_screen.dart:381` -> `lib/services/auth_service.dart:161-164`
- **Body JSON:**
```json
{
  "email": "budi.santoso@gmail.com",
  "password": "PasswordKuat123!"
}
```
- **Response:** `200 OK` -> `{"access_token": "<JWT>", "refresh_token": "...", "user": {...}}`. Salah sandi: `400 Invalid login credentials`.

### 1.5 Sinkronisasi Profil & Saldo Setelah Login
- **Method & URL:** `GET http://localhost:8787/rest/v1/users?select=*&email=eq.budi.santoso@gmail.com`
- **Pemicu:** `lib/services/auth_service.dart:186-190`, `447-451`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN_JWT>`, `Accept: application/vnd.pgrst.object+json`
- **Response:** `200 OK` -> objek profil user termasuk `balance`, `avatar_url`, `nik`, `gender`, `birth_date`.

### 1.6 Login Google OAuth (Redirect & Tukar Kode PKCE)
- **Tahap Redirect (Browser):**
  - `GET http://localhost:8787/auth/v1/authorize?provider=google&redirect_to=http%3A%2F%2Flocalhost%3A5500&access_type=offline&prompt=select_account`
  - Pemicu: `lib/login/login_screen.dart:438` -> `lib/services/auth_service.dart:322-329`
- **Tahap Tukar Kode (`getSessionFromUrl`):**
  - `POST http://localhost:8787/auth/v1/token?grant_type=pkce`
  - Pemicu: `lib/services/supabase_service.dart:90`, `lib/services/auth_service.dart:392`
  - Body JSON: `{"auth_code": "<CODE_DARI_CALLBACK>", "code_verifier": "<PKCE_VERIFIER>"}`

### 1.7 Logout / Keluar Akun
- **Method & URL:** `POST http://localhost:8787/auth/v1/logout`
- **Pemicu:** `lib/profile/profile_screen.dart:177`, `lib/admin/admin_dashboard_screen.dart:403` -> `lib/services/session_service.dart:596`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN_JWT>`
- **Response:** `204 No Content`.

---

## Modul 2 — Reset Kata Sandi 3-Tahap (Validasi Email Terdaftar -> OTP -> Sandi Baru)

**Pemicu UI:**
1. Halaman 1 (Input Email): `lib/forgot_password/forgot_password_screen.dart` (juga dari `lib/profile/security_screen.dart`)
2. Halaman 2 (Khusus Verifikasi OTP): `lib/forgot_password/verify_reset_otp_screen.dart`
3. Halaman 3 (Input Sandi Baru): `lib/forgot_password/reset_new_password_screen.dart`

### 2.1 Tahap 1 — Validasi Email Terdaftar & Kirim Kode OTP via Brevo
- **Method & URL:** `POST http://localhost:8787/api/auth/password-reset/request`
- **Pemicu:** `lib/forgot_password/forgot_password_screen.dart:75` & `lib/forgot_password/verify_reset_otp_screen.dart:137` -> `lib/services/auth_service.dart:661-673`
- **Body JSON:**
```json
{
  "email": "samawwalazhar@gmail.com"
}
```
- **Proses Internal Server-Side di Gateway (`tool/secure_api_gateway.dart:723-908`):**
  1. `GET <SUPABASE>/rest/v1/users?select=id,email,full_name&email=ilike.<email>&limit=5`
  2. `GET <SUPABASE>/auth/v1/admin/users?page=1&per_page=100`
  3. Jika terdaftar -> `POST https://api.brevo.com/v3/smtp/email` mengirim OTP 6-digit ke email milik user tersebut.
- **Response:**
  - `200 OK`: `{"success":true,"email":"samawwalazhar@gmail.com","expiresInSeconds":900,"message":"Kode verifikasi 6 digit telah dikirim..."}`
  - `404 Not Found`: `{"success":false,"code":"EMAIL_NOT_REGISTERED","message":"Email ... belum terdaftar di sistem TKA..."}`
  - `400 Bad Request` (`INVALID_EMAIL`) | `502 Bad Gateway` (`EMAIL_SEND_FAILED`).

### 2.2 Tahap 2 — Verifikasi Mandiri Kode OTP 6-Digit
- **Method & URL:** `POST http://localhost:8787/api/auth/password-reset/verify-otp`
- **Pemicu:** `lib/forgot_password/verify_reset_otp_screen.dart:93` -> `lib/services/auth_service.dart:787-799`
- **Body JSON:**
```json
{
  "email": "samawwalazhar@gmail.com",
  "otp": "482910"
}
```
- **Response:**
  - `200 OK`: `{"success":true,"valid":true,"resetToken":"<64_HEX_TOKEN>","message":"Kode OTP valid! Silakan buat kata sandi baru Anda."}`
  - `400 Bad Request`: `OTP_INVALID` (maks 5x salah), `OTP_NOT_FOUND`, `OTP_EXPIRED` (> 15 menit).
  - `429 Too Many Requests`: `OTP_TOO_MANY_ATTEMPTS`.

### 2.3 Tahap 3 — Konfirmasi & Simpan Kata Sandi Baru
- **Method & URL:** `POST http://localhost:8787/api/auth/password-reset/confirm`
- **Pemicu:** `lib/forgot_password/reset_new_password_screen.dart:97` -> `lib/services/auth_service.dart:893-909`
- **Body JSON:**
```json
{
  "email": "samawwalazhar@gmail.com",
  "resetToken": "<64_HEX_TOKEN>",
  "newPassword": "PasswordBaru#2026"
}
```
- **Proses Internal Server-Side di Gateway:** `PUT <SUPABASE>/auth/v1/admin/users/{authUserId}` (atau `POST /auth/v1/admin/users` untuk user migrasi) lalu menghanguskan OTP & `resetToken`.
- **Response:**
  - `200 OK`: `{"success":true,"message":"Kata sandi berhasil diperbarui! Silakan masuk dengan kata sandi baru Anda."}`
  - `401 Unauthorized` (`RESET_TOKEN_INVALID`) | `400 Bad Request`.

### 2.4 Fallback Update Password Saat Sesi User Aktif (Non-Web)
- **Method & URL:** `PUT http://localhost:8787/auth/v1/user`
- **Pemicu:** `lib/services/auth_service.dart:993-995`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN_JWT>`
- **Body JSON:** `{"password": "PasswordBaru#2026"}`

---

## Modul 3 — Profil Pengguna, Edit Identitas & Upload Foto Avatar

**Pemicu UI:** `lib/profile/profile_screen.dart`, `lib/profile/edit_profile_screen.dart`  
**Service:** `lib/services/session_service.dart`, `lib/services/supabase_storage_service.dart`

### 3.1 Ambil Data Profil Lengkap dari Tabel Tunggal `users`
- **Method & URL:** `GET http://localhost:8787/rest/v1/users?select=*&email=eq.<email>`
- **Pemicu:** `lib/profile/profile_screen.dart:82`, `lib/profile/edit_profile_screen.dart:87`, `lib/services/session_service.dart:225,440`

### 3.2 Perbarui Data Profil & Identitas Penumpang
- **Method & URL:** `PATCH http://localhost:8787/rest/v1/users?id=eq.<USER_UUID>` *(fallback: `?email=eq.<email>`)*
- **Pemicu:** `lib/profile/edit_profile_screen.dart:212,685` -> `lib/services/session_service.dart:244-251`
- **Body JSON:**
```json
{
  "full_name": "Azhar Samawwal",
  "phone": "085738686279",
  "nik": "3514062607090001",
  "gender": "Laki-laki",
  "document_type": "KTP / NIK",
  "birth_date": "1994-06-26",
  "avatar_url": "http://localhost:8787/storage/v1/object/public/avatars/azhar_1795580000.jpg",
  "updated_at": "2026-11-27T10:15:00.000Z"
}
```
- **Response:** `204 No Content` / `200 OK`.

### 3.3 Unggah Foto Profil ke Supabase Storage (Bucket `avatars`)
- **Method & URL:** `POST http://localhost:8787/storage/v1/object/avatars/<safeKey>_<timestamp>.<jpg|png|webp>`
- **Pemicu:** `lib/profile/edit_profile_screen.dart:199,539` -> `lib/services/supabase_storage_service.dart:335-353`
- **Headers:** `Content-Type: image/jpeg` (`image/png` / `image/webp`), `x-upsert: false` (retry `true` bila konflik), `Authorization: Bearer <ACCESS_TOKEN_JWT>`
- **Body:** Raw Binary Bytes (Maks. 2 MB).

### 3.4 Akses Publik Gambar Avatar
- **Method & URL:** `GET http://localhost:8787/storage/v1/object/public/avatars/<fileName>` (`lib/services/supabase_storage_service.dart:356,394`)

### 3.5 Update Khusus Kolom `avatar_url` di Tabel `users`
- **Method & URL:** `PATCH http://localhost:8787/rest/v1/users?email=eq.<email>`
- **Pemicu:** `lib/profile/edit_profile_screen.dart:211,548,681` -> `lib/services/session_service.dart:473-475`
- **Body JSON:** `{"avatar_url": "http://localhost:8787/storage/v1/object/public/avatars/<fileName>"}`

---

## Modul 4 — Dompet Digital TKAPay (Saldo, Top Up, Scan QR & Riwayat)

**Pemicu UI:** `lib/dashboard/dashboard_screen.dart`, `lib/wallet/top_up_screen.dart`, `lib/wallet/top_up_history_screen.dart`, `lib/wallet/scan_qr_screen.dart`

### 4.1 Cek Saldo TKAPay
- **Method & URL:** `GET http://localhost:8787/rest/v1/users?select=*&email=eq.<email>`
- **Pemicu:** `dashboard_screen.dart:165`, `top_up_screen.dart:69`, `scan_qr_screen.dart:233`, `payment_method_screen.dart:63`, `payment_screen.dart:85` -> `session_service.dart:335`

### 4.2 Update Saldo (Top Up / Potong Saldo Bayar Tiket / Scan QR Merchant)
- **Method & URL:** `PATCH http://localhost:8787/rest/v1/users?email=eq.<email>`
- **Pemicu:** `top_up_screen.dart:147`, `scan_qr_screen.dart:361`, `payment_method_screen.dart:248,319`, `payment_screen.dart:282,438` -> `session_service.dart:374`
- **Body JSON:** `{"balance": 350000}`

### 4.3 Catat Transaksi Top Up ke Tabel `payments`
- **Method & URL:** `POST http://localhost:8787/rest/v1/payments`
- **Pemicu:** `lib/wallet/top_up_screen.dart:152-158` -> `lib/services/user_db_service.dart:2468`
- **Body JSON:**
```json
{
  "payment_id": "PAY-872341092",
  "booking_id": "TOPUP-WALLET",
  "user_id": "75dcc7c4-1bf6-4a9a-a992-8c2137de4098",
  "payment_method": "BCA Virtual Account",
  "payment_channel": "Virtual Account",
  "reference_number": "TOP-872341092",
  "amount": 100000,
  "status": "Berhasil",
  "paid_at": "2026-11-27T10:20:00.000Z",
  "created_at": "2026-11-27T10:20:00.000Z"
}
```

### 4.4 Ambil Riwayat Pembayaran & Top Up User
- **Method & URL:** `GET http://localhost:8787/rest/v1/payments?select=*&user_id=eq.<USER_UUID>&order=created_at.desc&limit=50`
- **Pemicu:** `lib/wallet/top_up_history_screen.dart:33`, `lib/notifications/notifications_screen.dart:36` -> `lib/services/user_db_service.dart:2008-2018`

---

## Modul 5 — Master Stasiun, Pencarian Jadwal & Katalog Kereta

**Pemicu UI:** `antar_kota_screen.dart`, `train_search_results_screen.dart`, `bandara_screen.dart`, `komuter_screen.dart`, `lokal_screen.dart`, `katalog_ka_screen.dart`

### 5.1 Ambil Daftar Master Stasiun Ringkas *(Cached 5 Menit di Gateway + 10 Menit di Client)*
- **Method & URL:** `GET http://localhost:8787/rest/v1/stations?select=code,name,city,region&order=name.asc`
- **Pemicu:** `antar_kota_screen.dart:59`, `bandara_screen.dart:16`, `komuter_screen.dart:18`, `lokal_screen.dart:20` -> `user_db_service.dart:1505,2709`

### 5.2 Ambil Daftar Master Stasiun Lengkap (Dengan Koordinat Peta & Fasilitas)
- **Method & URL:** `GET http://localhost:8787/rest/v1/stations?select=*`
- **Pemicu:** `lib/tracking/live_map_screen.dart:120` -> `lib/services/train_tracking_service.dart:140`

### 5.3 Cari Jadwal Kereta Api *(Cached 2 Menit di Gateway + 5 Menit di Client)*
- **Method & URL:** `GET http://localhost:8787/rest/v1/train_schedules?select=*&limit=100`
- **Pemicu:** `lib/booking/train_search_results_screen.dart:68` -> `lib/services/user_db_service.dart:1696-1698`

### 5.4 Muat Katalog / Semua Jadwal Kereta Terurut
- **Method & URL:** `GET http://localhost:8787/rest/v1/train_schedules?select=*&order=created_at.desc&limit=100`
- **Pemicu:** `katalog_ka_screen.dart:18`, `bandara_screen.dart:17`, `komuter_screen.dart:19`, `lokal_screen.dart:21` -> `user_db_service.dart:1977-1980`

### 5.5 Sinkronisasi & Ambil Aset Gambar Armada Kereta (Bucket `train-assets`)
- **Upload Seed Aset:** `POST http://localhost:8787/storage/v1/object/train-assets/<fileName>` (`x-upsert: true`, `katalog_ka_screen.dart:200` -> `supabase_storage_service.dart:501`)
- **URL Publik Aset:** `GET http://localhost:8787/storage/v1/object/public/train-assets/<fileName>` (`supabase_storage_service.dart:482`)

---

## Modul 6 — Riwayat Pencarian Rute (`recent_searches` — CRUD Lengkap)

**Pemicu UI:** `lib/intercity/antar_kota_screen.dart`  
**Service:** `lib/services/user_db_service.dart:1545-1672`

- **Ambil 10 Riwayat Pencarian:** `GET http://localhost:8787/rest/v1/recent_searches?select=*&user_id=eq.<USER_UUID>&order=created_at.desc&limit=10` (`antar_kota_screen.dart:60,340` -> `user_db_service.dart:1563`)
- **Simpan / Upsert Pencarian:** `POST http://localhost:8787/rest/v1/recent_searches` (`Prefer: resolution=merge-duplicates`, `antar_kota_screen.dart:339` -> `user_db_service.dart:1629`)
```json
{
  "id": "SRCH-1795580123",
  "user_id": "75dcc7c4-1bf6-4a9a-a992-8c2137de4098",
  "origin_code": "GMR",
  "origin_name": "Gambir",
  "dest_code": "SBI",
  "dest_name": "Surabaya Pasarturi",
  "travel_date": "28 Nov 2026",
  "passengers": "1 Dewasa, 0 Bayi",
  "created_at": "2026-11-27T10:30:00.000Z"
}
```
- **Hapus 1 Item Riwayat:** `DELETE http://localhost:8787/rest/v1/recent_searches?id=eq.<SEARCH_ID>` (`antar_kota_screen.dart:295` -> `user_db_service.dart:1647`)
- **Hapus Semua Riwayat User:** `DELETE http://localhost:8787/rest/v1/recent_searches?user_id=eq.<USER_UUID>` (`antar_kota_screen.dart:271` -> `user_db_service.dart:1667`)

---

## Modul 7 — Pemesanan Tiket (`bookings`), Pembayaran (`payments`) & E-Ticket Email

**Pemicu UI:** `payment_method_screen.dart`, `qris_payment_screen.dart`, `payment_screen.dart`, `orders_screen.dart`, `my_tickets_screen.dart`, `dashboard_screen.dart`

### 7.1 Ambil Daftar Pesanan / Tiket User Aktif *(TTL Cache 25 Detik + Request Coalescing)*
- **Method & URL:** `GET http://localhost:8787/rest/v1/bookings?select=*&passenger_email=eq.<email>&order=created_at.desc`
- **Pemicu:** `dashboard_screen.dart:168`, `orders_screen.dart:59`, `my_tickets_screen.dart:52`, `profile_screen.dart:47`, `live_tracking_screen.dart:225`, `top_up_history_screen.dart:32`, `notifications_screen.dart:35`, `scan_qr_screen.dart:54` -> `user_db_service.dart:1886`

### 7.2 Buat Pemesanan Tiket Baru (Multi-Penumpang Upsert / Single Insert)
- **Method & URL:**
  - Multi-Penumpang (`createBookingOrder`): `POST http://localhost:8787/rest/v1/bookings` (`Prefer: resolution=merge-duplicates`)
  - Single-Penumpang (`createBooking`): `POST http://localhost:8787/rest/v1/bookings?select=*` (`Prefer: return=representation`)
- **Pemicu:** `payment_method_screen.dart:209,227`, `qris_payment_screen.dart:160`, `payment_screen.dart:419,464` -> `user_db_service.dart:2198,2317`
- **Body JSON:**
```json
{
  "booking_id": "TKA-580123",
  "user_id": "75dcc7c4-1bf6-4a9a-a992-8c2137de4098",
  "passenger_name": "Azhar Samawwal",
  "passenger_email": "samawwalazhar@gmail.com",
  "passenger_phone": "085738686279",
  "passenger_nik": "3514062607090001",
  "train_number": "KA 2",
  "train_name": "KA Argo Bromo Anggrek",
  "train_class": "Eksekutif",
  "wagon_class": "Eksekutif",
  "route": "GMR -> SBI",
  "origin_code": "GMR",
  "origin_name": "Gambir",
  "origin_city": "Jakarta Pusat",
  "dest_code": "SBI",
  "dest_name": "Surabaya Pasarturi",
  "dest_city": "Surabaya",
  "travel_date": "28 Nov 2026",
  "departure_time": "08:20 WIB",
  "arrival_time": "16:25 WIB",
  "seat_number": "EKS-1 / 3A",
  "amount": 640000,
  "total_amount": 640000,
  "status": "Sudah Dibayar",
  "payment_method": "QRIS",
  "va_number": "NMID-1795580123",
  "created_at": "2026-11-27T10:35:00.000Z"
}
```

### 7.3 Pelunasan Pesanan Pending (`Menunggu Pembayaran` -> `Sudah Dibayar`)
- **Method & URL:** `PATCH http://localhost:8787/rest/v1/bookings?booking_id=eq.<BOOKING_CODE>`
- **Pemicu:** `payment_screen.dart:410` -> `user_db_service.dart:2400-2402`
- **Body JSON:** `{"status":"Sudah Dibayar","payment_method":"BCA Virtual Account","va_number":"VA-9001842910","user_id":"<USER_UUID>"}`

### 7.4 Rekam Pembayaran Tiket ke Tabel `payments`
- **Method & URL:** `POST http://localhost:8787/rest/v1/payments` (`user_db_service.dart:2468`)

### 7.5 Tandai Perjalanan Selesai (`Perjalanan Selesai`)
- **Method & URL:** `PATCH http://localhost:8787/rest/v1/bookings?booking_id=eq.<BOOKING_CODE>&select=*`
- **Pemicu:** `my_tickets_screen.dart:180` -> `user_db_service.dart:2574-2577`
- **Body JSON:** `{"status": "Perjalanan Selesai"}`

### 7.6 Kirim Email Konfirmasi E-Ticket Otomatis (Brevo Proxy)
- **Method & URL:** `POST http://localhost:8787/brevo/v3/smtp/email` *(Non-Web: `https://api.brevo.com/v3/smtp/email`)*
- **Pemicu:** `user_db_service.dart:2597` -> `brevo_notification_service.dart:469`

---

## Modul 8 — E-Ticket Boarding Pass & QR Code Storage (`tickets-qr`)

| Aksi | Method | Link Endpoint Lengkap | Headers / Body |
| :--- | :---: | :--- | :--- |
| **Upload PNG QR Boarding Pass** | `POST` | `http://localhost:8787/storage/v1/object/tickets-qr/<BOOKING_ID>.png` | `Content-Type: image/png`, `x-upsert: true`, body = bytes PNG 400×400 px (`supabase_storage_service.dart:204`) |
| **Cek Eksistensi File QR** | `POST` | `http://localhost:8787/storage/v1/object/list/tickets-qr` | JSON: `{"prefix":"","search":"<BOOKING_ID>.png"}` (`supabase_storage_service.dart:255`) |
| **Tampilkan Gambar QR Publik** | `GET` | `http://localhost:8787/storage/v1/object/public/tickets-qr/<BOOKING_ID>.png` | `eticket_boarding_pass_screen.dart:119` (`supabase_storage_service.dart:214,233`) |

---

## Modul 9 — Pembatalan Tiket & Pengajuan Refund (`cancellations` & `bookings`)

- **Ubah Status Booking Jadi `Dibatalkan`:** `PATCH http://localhost:8787/rest/v1/bookings?booking_id=eq.<BOOKING_CODE>&select=*` *(fallback `POST /rest/v1/bookings?select=*` upsert)* (`refund_screen.dart:52` -> `user_db_service.dart:2518,2531`)
  - Body JSON: `{"status":"Dibatalkan","cancel_reason":"Perubahan jadwal mendadak","refund_amount":480000,"user_id":"<USER_UUID>"}`
- **Cek Anti-Duplikasi Pembatalan:** `GET http://localhost:8787/rest/v1/cancellations?select=id&booking_id=eq.<BOOKING_UUID>&user_id=eq.<USER_UUID>&limit=1` (`user_db_service.dart:2671`)
- **Insert Data Pembatalan / Refund:** `POST http://localhost:8787/rest/v1/cancellations` (`user_db_service.dart:2690`)
  - Body JSON: `{"booking_id":"<BOOKING_UUID>","user_id":"<USER_UUID>","reason":"Perubahan jadwal mendadak [Kode: TKA-580123]","refund_amount":480000}`
- **Ambil Riwayat Refund User:** `GET http://localhost:8787/rest/v1/cancellations?select=*&user_id=eq.<USER_UUID>&limit=50` (`top_up_history_screen.dart:34` -> `user_db_service.dart:2036`)
- **Kirim Email Konfirmasi Refund:** `POST http://localhost:8787/brevo/v3/smtp/email` (`user_db_service.dart:2629` -> `brevo_notification_service.dart:723`)

---

## Modul 10 — Live Tracking, Peta MapLibre + MapTiler, Global Search & Realtime WebSocket

- **Muat Style Peta Vector MapTiler — Khusus Indonesia Only *(RAM Cache 1 Jam, < 4ms)*:** `GET http://localhost:8787/api/map/style.json` (inlined TileJSON + bounds ketat Indonesia `[94.8, -11.2, 141.2, 6.3]`, `minzoom: 4`, `maxzoom: 13`, 22 layer non-esensial dipangkas; `live_map_screen.dart:1257`, `live_tracking_screen.dart:1170`, `station_detail_screen.dart:178` -> `secure_api_gateway.dart:335`)
- **Self-Hosted MapLibre GL JS v6.4.1 Assets *(Bebas CSP/unpkg)*:** `GET http://localhost:8787/api/map/lib/{maplibre-gl.mjs | maplibre-gl-shared.mjs | maplibre-gl-worker.mjs | maplibre-gl.css}` (`lib/main.dart:15-21`, `web/index.html:41-43`)
- **Daftar Perjalanan Kereta Aktif (`train_trips`):** `GET http://localhost:8787/rest/v1/train_trips?select=*&order=scheduled_departure.asc` (`live_map_screen.dart:120`, `train_schedule_screen.dart:397` -> `train_tracking_service.dart:176`)
- **Daftar Pemberhentian / Peron (`train_trip_stops`):** `GET http://localhost:8787/rest/v1/train_trip_stops?select=*&order=stop_sequence.asc` (`train_tracking_service.dart:186`)
- **Supabase Realtime WebSocket (`public:train_trips_live`):** `WS ws://localhost:8787/realtime/v1/websocket?apikey=tka-gateway-protected-client&vsn=1.0.0` (`train_tracking_service.dart:286` -> `secure_api_gateway.dart:202`)
- **Global Search (2 Query Paralel di `global_search_screen.dart:78`):**
  - `GET http://localhost:8787/rest/v1/stations?select=*&or=(name.ilike.%25<QUERY>%25,code.ilike.%25<QUERY>%25,city.ilike.%25<QUERY>%25,region.ilike.%25<QUERY>%25)&limit=15` (`train_tracking_service.dart:471`)
  - `GET http://localhost:8787/rest/v1/train_trips?select=*&or=(train_name.ilike.%25<QUERY>%25,train_number.ilike.%25<QUERY>%25,origin_station_code.ilike.%25<QUERY>%25,destination_station_code.ilike.%25<QUERY>%25,region.ilike.%25<QUERY>%25)&limit=20` (`train_tracking_service.dart:476`)

---

## Modul 11 — Kereta Favorit, Preferensi & Notifikasi Brevo

### 11.1 Kereta Favorit (`user_favorites`)
- **GET:** `http://localhost:8787/rest/v1/user_favorites?select=*&user_id=eq.<USER_ID>&order=created_at.desc` (`train_tracking_service.dart:628`)
- **POST (Upsert):** `http://localhost:8787/rest/v1/user_favorites?on_conflict=user_id,train_number,origin_station_code,destination_station_code` (`favorites_screen.dart:105`, `live_map_screen.dart:1473`, `train_detail_screen.dart:43` -> `train_tracking_service.dart:709`)
- **PATCH (Update Alert):** `http://localhost:8787/rest/v1/user_favorites?user_id=eq.<USER_ID>&train_number=eq.<NO>&origin_station_code=eq.<ORIG>&destination_station_code=eq.<DEST>` (`favorites_screen.dart:238` -> `train_tracking_service.dart:746`)
- **DELETE:** `http://localhost:8787/rest/v1/user_favorites?user_id=eq.<USER_ID>&train_number=eq.<NO>&origin_station_code=eq.<ORIG>&destination_station_code=eq.<DEST>` (`favorites_screen.dart:522` -> `train_tracking_service.dart:680,772`)

### 11.2 Preferensi Notifikasi & Zona Waktu (`user_notification_preferences`)
- **GET:** `http://localhost:8787/rest/v1/user_notification_preferences?select=*&user_id=eq.<USER_ID>` (`train_tracking_service.dart:795`)
- **POST (Upsert):** `http://localhost:8787/rest/v1/user_notification_preferences?on_conflict=user_id` (`train_tracking_service.dart:834`)

### 11.3 Notifikasi Perjalanan (`train_notifications`) & Brevo Email
- **GET Inbox:** `http://localhost:8787/rest/v1/train_notifications?select=*&user_id=eq.<USER_ID>&order=created_at.desc&limit=80` (`live_map_screen.dart:149` -> `brevo_notification_service.dart:94`)
- **GET Cek Duplikat:** `http://localhost:8787/rest/v1/train_notifications?select=id&user_id=eq.<USER_ID>&event_dedup_key=eq.<DEDUP_KEY>` (`brevo_notification_service.dart:173`)
- **POST Insert Notifikasi:** `http://localhost:8787/rest/v1/train_notifications?select=id` (`favorites_screen.dart:201` -> `brevo_notification_service.dart:192`)
- **POST Kirim Email Brevo:** `http://localhost:8787/brevo/v3/smtp/email` *(Non-Web: `https://api.brevo.com/v3/smtp/email`)* (`brevo_notification_service.dart:351,469`)
- **PATCH Status Brevo / Tandai 1 Dibaca:** `http://localhost:8787/rest/v1/train_notifications?id=eq.<NOTIF_ID>` (`brevo_notification_service.dart:256,409`)
- **PATCH Tandai Semua Dibaca:** `http://localhost:8787/rest/v1/train_notifications?user_id=eq.<USER_ID>` (`brevo_notification_service.dart:426`)

---

## Modul 12 — Dashboard Admin (Armada, Transaksi, Akun Admin & Audit Log)

**Pemicu UI:** `lib/admin/admin_dashboard_screen.dart` -> **Service:** `lib/services/admin_service.dart`

- **GET Jadwal Armada:** `http://localhost:8787/rest/v1/train_schedules?select=id,train_number,train_name,category,origin,destination,departure_time,arrival_time,status,capacity,booked_seats,fare&order=departure_time.asc` (`admin_service.dart:314`)
- **POST Tambah Jadwal:** `http://localhost:8787/rest/v1/train_schedules` (`admin_service.dart:397`)
- **PATCH Status Operasional Kereta:** `http://localhost:8787/rest/v1/train_schedules?id=eq.<SCHEDULE_ID>` (`admin_dashboard_screen.dart:2690` -> `admin_service.dart:377`)
- **GET 50 Transaksi Tiket:** `http://localhost:8787/rest/v1/bookings?select=booking_id,passenger_name,passenger_email,passenger_phone,train_number,train_name,route,travel_date,departure_time,seat_number,wagon_class,amount,status,payment_method,created_at&order=created_at.desc&limit=50` (`admin_service.dart:418`)
- **PATCH Status Transaksi Tiket:** `http://localhost:8787/rest/v1/bookings?booking_id=eq.<BOOKING_ID>` (`admin_dashboard_screen.dart:939,976` -> `admin_service.dart:497`)
- **GET Daftar Akun Admin:** `http://localhost:8787/rest/v1/admin_users?select=id,email,full_name,role,status,created_at&order=created_at.desc` (`admin_service.dart:518`)
- **POST Register Auth Admin:** `http://localhost:8787/auth/v1/signup` (`admin_dashboard_screen.dart:747` -> `admin_service.dart:569`)
- **POST Simpan Tabel `admin_users`:** `http://localhost:8787/rest/v1/admin_users` (`admin_service.dart:583`)
- **POST Catat Audit Trail `admin_audit_logs`:** `http://localhost:8787/rest/v1/admin_audit_logs` (`admin_service.dart:598`)

---

## Fitur UI Tanpa Network Request (Murni Client-Side / Instan 0 ms)

- **Onboarding & Splash:** `splash_screen.dart`, `onboarding_screen.dart`
- **Pilih Kursi, Form Penumpang & Konfirmasi Pesanan:** `seat_selection_screen.dart`, `passenger_form_screen.dart`, `order_confirmation_screen.dart`
- **Detail Pesanan & Status Transaksi:** `order_detail_screen.dart`, `transaction_status_screen.dart` (mengambil langsung dari cache RAM `UserDatabaseService.getCachedBookings()`)
- **Layanan Statis:** `lrt_mrt_screen.dart`, `customer_service_screen.dart`, `lainnya_screen.dart`
