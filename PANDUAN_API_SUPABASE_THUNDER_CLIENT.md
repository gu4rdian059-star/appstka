# 📖 Panduan Lengkap REST API Supabase (Thunder Client & Frontend)

Panduan ini mendokumentasikan secara rinci cara melakukan request API ke backend **Supabase TKA** (`lbjpvbwmctzuhkqdidpt`) menggunakan **Thunder Client**, Postman, cURL, maupun Frontend Flutter.

---

## ⚡ 0. Cara Cepat: Import Koleksi Thunder Client (1-Klik Siap Pakai!)

Untuk mempermudah pengujian tanpa mengetik URL, header, dan body JSON satu per satu, telah disediakan file koleksi yang **sudah divalidasi 100% kompatibel dengan Thunder Client**:

### Opsi 1: Format Native Thunder Client (Direkomendasikan)
1. File Koleksi Request: [`thunder-collection_TKA_Supabase_API.json`](file:///d:/UBIG/PROYEK/appstka/thunder-collection_TKA_Supabase_API.json)
2. File Environment Variabel: [`thunder-environment_TKA_Supabase.json`](file:///d:/UBIG/PROYEK/appstka/thunder-environment_TKA_Supabase.json)

**Langkah Import:**
1. Buka **Thunder Client** di panel sebelah kiri IDE Anda.
2. Klik tab **Collections** (ikon folder).
3. Klik tombol menu titik tiga (**`...`**) di kanan atas tab Collections ➡️ Pilih **Import**.
4. Pilih file: `d:\UBIG\PROYEK\appstka\thunder-collection_TKA_Supabase_API.json`.
5. Pindah ke tab **Env** (ikon silinder/lingkungan) ➡️ Klik menu titik tiga (**`...`**) ➡️ Pilih **Import** ➡️ Pilih file: `d:\UBIG\PROYEK\appstka\thunder-environment_TKA_Supabase.json`.
6. Pada dropdown Environment di kanan atas Thunder Client, pilih **TKA Supabase Production**.

---

### Opsi 2: Format Postman 2.1.0 (Alternatif Universal)
Jika ingin menggunakan parser Postman:
1. File Koleksi Request: [`postman-collection_TKA_Supabase_API.json`](file:///d:/UBIG/PROYEK/appstka/postman-collection_TKA_Supabase_API.json)
2. File Environment Variabel: [`postman-environment_TKA_Supabase.json`](file:///d:/UBIG/PROYEK/appstka/postman-environment_TKA_Supabase.json)

**Langkah Import:**
1. Di tab **Collections** ➡️ Titik tiga (**`...`**) ➡️ **Import** ➡️ Pilih file `postman-collection_TKA_Supabase_API.json`.
2. Di tab **Env** ➡️ Titik tiga (**`...`**) ➡️ **Import** ➡️ Pilih file `postman-environment_TKA_Supabase.json`.

🎉 **Selesai!** Seluruh request (Auth, Users, Schedules, Stations, Bookings, Payments, Cancellations, Recent Searches) langsung muncul dan siap digunakan.

---

## 📌 1. Jawaban Arsitektur: Apakah Front End Mengambil Data dengan Cara GET atau Langsung ke Tabel Database?

### **Jawabannya: Front End 100% Mengambil Data Menggunakan HTTP GET API (REST API)!**

Banyak developer mengira bahwa sintaks Flutter seperti:
```dart
final data = await SupabaseService.client.from('train_schedules').select('*');
```
berarti aplikasi membuka koneksi socket TCP PostgreSQL langsung (port `5432`). **Itu tidak benar.**

### Mengapa?
1. **Tidak Ada Direct Database Socket**: Di lingkungan mobile/web, aplikasi **tidak boleh** dan **tidak bisa** terhubung langsung ke port database Postgres karena alasan keamanan dan arsitektur client-server.
2. **Supabase Menggunakan PostgREST**: Supabase menyediakan layer REST API otomatis bernama **PostgREST**.
3. **Sintaks Flutter SDK adalah Pembungkus (HTTP Wrapper)**:
   - Ketika Anda menulis:
     ```dart
     client.from('train_schedules').select('*');
     ```
     Flutter sebenarnya mengeksekusi HTTP Request:
     ```http
     GET https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/train_schedules?select=*
     ```
   - Ketika Anda menulis:
     ```dart
     client.from('bookings').insert(map);
     ```
     Flutter sebenarnya mengeksekusi HTTP Request:
     ```http
     POST https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/bookings
     ```
   - Ketika Anda menulis:
     ```dart
     client.from('users').update({'balance': 500000}).eq('id', userId);
     ```
     Flutter sebenarnya mengeksekusi HTTP Request:
     ```http
     PATCH https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/users?id=eq.<userId>
     ```

**Kesimpulan:**
Frontend Flutter Anda sudah menggunakan pola **REST API** (HTTP GET, POST, PATCH, DELETE) yang sama persis seperti yang Anda jalankan melalui Thunder Client!

---

## 📌 2. Penyatuan Tabel `profiles` ke Tabel `users`

Sebelumnya terdapat dua konsep:
- Tabel `profiles` (hanya menyimpan profil pengguna)
- Tabel `users` (tabel user di schema public)

### Status Migrasi Sekarang:
1. **Frontend Flutter (`lib/`)**:
   - `lib/services/auth_service.dart` ➡️ Menggunakan `.from('users')`
   - `lib/services/session_service.dart` ➡️ Menggunakan `.from('users')`
   - `lib/profile/profile_screen.dart` ➡️ Mengambil data dari `users`
   - `lib/profile/edit_profile_screen.dart` ➡️ Mengambil & menyimpan data ke `users`
2. **Database Supabase**:
   - Telah disediakan skrip SQL: [`unify_profiles_to_users.sql`](file:///d:/UBIG/PROYEK/appstka/unify_profiles_to_users.sql)
   - Skrip ini menambahkan kolom `balance`, `avatar_url`, dll ke tabel `users`, memigrasikan semua data lama dari `profiles` ke `users`, mengaktifkan RLS yang mengizinkan operasi publik/user, dan membuat alias VIEW `profiles` agar kompatibilitas query lama tetap terjaga 100%.

---

## 📌 3. Konfigurasi Environment Thunder Client

### Informasi Proyek:
- **Base URL Supabase**: `https://lbjpvbwmctzuhkqdidpt.supabase.co`
- **Anon Publishable Key**:
  ```text
  sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  ```

### Headers yang Wajib Ada di Setiap Request:
| Header | Nilai | Keterangan |
| :--- | :--- | :--- |
| `apikey` | `sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1` | **Wajib di semua request** (Auth & Database) |
| `Content-Type` | `application/json` | **Wajib untuk POST & PATCH** |
| `Prefer` | `return=representation` | **Sangat disarankan untuk POST & PATCH** (mengembalikan data yang baru dibuat/diubah) |
| `Authorization` | `Bearer <access_token>` | **Wajib setelah login** untuk endpoint yang memerlukan otentikasi user. Jika belum login (misal Signup atau Login), header ini **jangan diisi token kedaluwarsa** atau gunakan anon key! |

> [!WARNING]
> **Penyebab Error `403 Forbidden` (`bad_jwt: token is expired`) pada Thunder Client**:
> Di tangkapan layar Anda sebelumnya, Anda mencoba melakukan `POST /auth/v1/signup`, namun di tab **Headers** atau tab **Auth** pada Thunder Client masih tersimpan token Bearer lama yang sudah kadaluarsa (expired). Supabase langsung menolak request sebelum membaca body JSON.
> **Solusi**: Di tab **Auth** Thunder Client, pilih **Inherit / None** untuk request SignUp & Login.

---

## 📌 4. Endpoint Otentikasi (Auth API)

### 4.1. Sign Up (Mendaftarkan Akun Baru)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/auth/v1/signup`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Content-Type: application/json
  ```
- **Body (JSON)**:
  ```json
  {
    "email": "penumpang.tka@gmail.com",
    "password": "Password123!",
    "data": {
      "full_name": "Penumpang TKA Hebat",
      "phone": "081234567890",
      "role": "passenger"
    }
  }
  ```
- **Response Sukses (HTTP 200)**:
  Supabase mengembalikan object `user` beserta `access_token` jika auto-confirm aktif.

---

### 4.2. Login / Sign In (Mendapatkan Access Token JWT)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/auth/v1/token?grant_type=password`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Content-Type: application/json
  ```
- **Body (JSON)**:
  ```json
  {
    "email": "penumpang.tka@gmail.com",
    "password": "Password123!"
  }
  ```
- **Response Sukses (HTTP 200)**:
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "expires_in": 3600,
    "refresh_token": "...",
    "user": {
      "id": "3b75f548-64a4-4595-acd0-16d8d3c1f4ae",
      "email": "penumpang.tka@gmail.com"
    }
  }
  ```
> [!TIP]
> Salin nilai `"access_token"` tersebut! Token inilah yang akan digunakan di header `Authorization: Bearer <access_token>` untuk request ke tabel database.

---

### 4.3. Get User Profil (Mendapatkan Info Pengguna yang Sedang Login)
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/auth/v1/user`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Authorization: Bearer <access_token>
  ```
- **Response**: Mengembalikan detail data user akun Supabase Auth.

---

### 4.4. Logout (Keluar Sesi)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/auth/v1/logout`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Authorization: Bearer <access_token>
  ```
- **Response**: `HTTP 204 No Content` (Sesi berhasil dihapus).

---

## 📌 5. Panduan Lengkap Semua Tabel Database (CRUD)

Berikut adalah daftar lengkap URL, method, headers, dan payload body JSON untuk **semua tabel** di database TKA Supabase.

---

### TABEL 1: `users` (Tabel Tunggal Pengguna)

#### 1. GET Semua Data User
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/users?select=*`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Authorization: Bearer <access_token>
  ```

#### 2. GET Filter User Berdasarkan Email atau ID
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/users?email=eq.penumpang.tka@gmail.com`
- **Headers**: `apikey` + `Authorization`

#### 3. POST (Tambah Data User Baru)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/users`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Authorization: Bearer <access_token>
  Content-Type: application/json
  Prefer: return=representation
  ```
- **Body (JSON)**:
  ```json
  {
    "id": "3b75f548-64a4-4595-acd0-16d8d3c1f4ae",
    "email": "penumpang.tka@gmail.com",
    "full_name": "Penumpang TKA Hebat",
    "phone": "081234567890",
    "role": "passenger",
    "balance": 250000
  }
  ```

#### 4. PATCH (Update Profil / Saldo User)
- **Method**: `PATCH`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/users?id=eq.3b75f548-64a4-4595-acd0-16d8d3c1f4ae`
- **Body (JSON)**:
  ```json
  {
    "full_name": "Penumpang TKA Hebat (Updated)",
    "phone": "089876543210",
    "balance": 500000,
    "updated_at": "2026-11-24T12:00:00Z"
  }
  ```

#### 5. DELETE User
- **Method**: `DELETE`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/users?id=eq.3b75f548-64a4-4595-acd0-16d8d3c1f4ae`

---

### TABEL 2: `train_schedules` (Jadwal & Rute Kereta Api)

#### 1. GET Semua Jadwal Kereta
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/train_schedules?select=*`

#### 2. GET Filter Berdasarkan Stasiun Asal & Tujuan
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/train_schedules?origin_code=eq.GMR&dest_code=eq.BD`

#### 3. POST (Tambah Jadwal Kereta Baru)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/train_schedules`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Content-Type: application/json
  Prefer: return=representation
  ```
- **Body (JSON)**:
  ```json
  {
    "train_number": "KA-102",
    "train_name": "Argo Parahyangan",
    "category": "Eksekutif",
    "origin_code": "GMR",
    "origin_name": "Stasiun Gambir",
    "origin_city": "Jakarta",
    "dest_code": "BD",
    "dest_name": "Stasiun Bandung",
    "dest_city": "Bandung",
    "departure_time": "08:00:00",
    "arrival_time": "11:00:00",
    "duration": "3j 0m",
    "base_fare": 150000,
    "fare": 150000,
    "status": "Tersedia",
    "capacity": 300,
    "booked_seats": 0,
    "available_seats": 300,
    "available_classes": "Eksekutif, Bisnis"
  }
  ```

#### 4. PATCH (Update Jadwal Kereta)
- **Method**: `PATCH`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/train_schedules?train_number=eq.KA-102`
- **Body (JSON)**:
  ```json
  {
    "fare": 160000,
    "available_seats": 290
  }
  ```

#### 5. DELETE Jadwal Kereta
- **Method**: `DELETE`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/train_schedules?train_number=eq.KA-102`

---

### TABEL 3: `stations` (Daftar Stasiun)

#### 1. GET Semua Stasiun (Diurutkan berdasarkan Kota)
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/stations?select=*&order=city.asc`

#### 2. POST (Tambah Stasiun Baru)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/stations`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Content-Type: application/json
  Prefer: return=representation
  ```
- **Body (JSON)**:
  ```json
  {
    "code": "ML",
    "name": "Stasiun Malang",
    "city": "Malang",
    "region": "Jawa Timur"
  }
  ```

#### 3. PATCH (Update Data Stasiun)
- **Method**: `PATCH`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/stations?code=eq.ML`
- **Body (JSON)**:
  ```json
  {
    "name": "Stasiun Malang Kotabaru"
  }
  ```

#### 4. DELETE Stasiun
- **Method**: `DELETE`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/stations?code=eq.ML`

---

### TABEL 4: `bookings` (Transaksi Pemesanan Tiket)

#### 1. GET Semua Booking (Diurutkan dari yang Terbaru)
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/bookings?select=*&order=created_at.desc`

#### 2. GET Booking Milik User Tertentu
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/bookings?user_id=eq.3b75f548-64a4-4595-acd0-16d8d3c1f4ae`

#### 3. POST (Buat Booking / Tiket Baru)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/bookings`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Content-Type: application/json
  Prefer: return=representation
  ```
- **Body (JSON)**:
  ```json
  {
    "booking_id": "TKA-20261124-001",
    "user_id": "3b75f548-64a4-4595-acd0-16d8d3c1f4ae",
    "passenger_name": "Penumpang TKA Hebat",
    "passenger_email": "penumpang.tka@gmail.com",
    "passenger_phone": "081234567890",
    "passenger_nik": "3578012345670001",
    "train_number": "KA-102",
    "train_name": "Argo Parahyangan",
    "train_class": "Eksekutif",
    "wagon_class": "EKS-1",
    "route": "GMR -> BD",
    "origin_code": "GMR",
    "origin_name": "Stasiun Gambir",
    "origin_city": "Jakarta",
    "dest_code": "BD",
    "dest_name": "Stasiun Bandung",
    "dest_city": "Bandung",
    "travel_date": "2026-11-25",
    "departure_time": "08:00:00",
    "arrival_time": "11:00:00",
    "seat_number": "4B",
    "amount": 150000,
    "total_amount": 150000,
    "status": "Lunas",
    "payment_method": "TKAPay",
    "va_number": "-"
  }
  ```

#### 4. PATCH (Update Status Booking, misal saat dibatalkan)
- **Method**: `PATCH`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/bookings?booking_id=eq.TKA-20261124-001`
- **Body (JSON)**:
  ```json
  {
    "status": "Dibatalkan",
    "cancel_reason": "Perubahan rencana jadwal kerja",
    "refund_amount": 112500
  }
  ```

#### 5. DELETE Booking
- **Method**: `DELETE`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/bookings?booking_id=eq.TKA-20261124-001`

---

### TABEL 5: `payments` (Catatan Pembayaran)

#### 1. GET Semua Riwayat Pembayaran
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/payments?select=*`

#### 2. POST (Tambah Catatan Pembayaran Baru)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/payments`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Content-Type: application/json
  Prefer: return=representation
  ```
- **Body (JSON)**:
  ```json
  {
    "payment_id": "PAY-20261124-8899",
    "booking_id": "TKA-20261124-001",
    "user_id": "3b75f548-64a4-4595-acd0-16d8d3c1f4ae",
    "payment_method": "TKAPay",
    "payment_channel": "Saldo Akun",
    "reference_number": "REF-99887766",
    "amount": 150000,
    "status": "SUCCESS"
  }
  ```

---

### TABEL 6: `cancellations` (Pengajuan Pembatalan & Refund)

#### 1. GET Riwayat Pembatalan
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/cancellations?select=*`

#### 2. POST (Ajukan Pembatalan Tiket)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/cancellations`
- **Headers**:
  ```http
  apikey: sb_publishable_hjlSBckeJ06uoUd6BOdTHA_WhNjy8u1
  Content-Type: application/json
  Prefer: return=representation
  ```
- **Body (JSON)**:
  ```json
  {
    "booking_id": "TKA-20261124-001",
    "user_id": "3b75f548-64a4-4595-acd0-16d8d3c1f4ae",
    "reason": "Salah memilih jam keberangkatan",
    "refund_amount": 112500,
    "status": "DIPROSES"
  }
  ```

---

### TABEL 7: `recent_searches` (Riwayat Pencarian Rute Pengguna)

#### 1. GET Riwayat Pencarian User
- **Method**: `GET`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/recent_searches?user_id=eq.3b75f548-64a4-4595-acd0-16d8d3c1f4ae`

#### 2. POST (Simpan Riwayat Pencarian Baru)
- **Method**: `POST`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/recent_searches`
- **Body (JSON)**:
  ```json
  {
    "user_id": "3b75f548-64a4-4595-acd0-16d8d3c1f4ae",
    "origin_code": "GMR",
    "origin_name": "Stasiun Gambir",
    "dest_code": "BD",
    "dest_name": "Stasiun Bandung",
    "travel_date": "2026-11-25",
    "passengers": "1 Dewasa"
  }
  ```

#### 3. DELETE Riwayat Pencarian User
- **Method**: `DELETE`
- **URL**: `https://lbjpvbwmctzuhkqdidpt.supabase.co/rest/v1/recent_searches?user_id=eq.3b75f548-64a4-4595-acd0-16d8d3c1f4ae`

---

## 📌 6. Tips Filter & Query PostgREST Lanjutan di URL

Supabase PostgREST mendukung query canggih langsung pada URL tanpa perlu query SQL manual:

| Kebutuhan Query | Sintaks URL |
| :--- | :--- |
| **Pilih Kolom Tertentu** | `?select=id,full_name,email` |
| **Sama Dengan (`=`)** | `?origin_code=eq.GMR` |
| **Tidak Sama Dengan (`!=`)** | `?status=neq.Dibatalkan` |
| **Lebih Besar (`>`)** | `?fare=gt.100000` |
| **Lebih Kecil (`<`)** | `?available_seats=lt.10` |
| **Pencarian Teks / Search (`LIKE / ILIKE`)** | `?name=ilike.*Gambir*` |
| **Urutan Data (Sorting)** | `?order=created_at.desc` atau `?order=fare.asc` |
| **Paginasi (Limit & Offset)** | `?limit=10&offset=0` |
| **Relasi / Join Antar Tabel** | `?select=*,bookings(*)` |

---
**Dokumentasi ini siap digunakan langsung di Thunder Client, Postman, maupun pengujian API otomatis.**

