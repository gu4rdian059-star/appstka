-- ============================================================================
-- TEMPLATE LENGKAP SKEMA DATABASE TIKET KERETA API (TKA)
-- ============================================================================
-- Petunjuk Penggunaan:
-- 1. File ini adalah TEMPLATE yang bisa Anda sesuaikan/edit terlebih dahulu.
-- 2. Anda bisa menambah kolom baru, tabel baru, atau mengubah tipe datanya.
-- 3. Jika sudah sesuai, salin seluruh isi file ini -> Buka Dashboard Supabase
--    -> Menu "SQL Editor" -> "New Query" -> Tempel (Paste) -> Klik "Run".
-- ============================================================================

-- Ekstensi untuk UUID otomatis (jika belum aktif)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. TABEL MASTER STASIUN (stations)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.stations (
    code VARCHAR(10) PRIMARY KEY,              -- Contoh: GMR, BD, YK, SGU, ML
    name VARCHAR(100) NOT NULL,                -- Contoh: Gambir, Bandung, Malang
    city VARCHAR(100) NOT NULL,                -- Contoh: Jakarta Pusat, Bandung
    region VARCHAR(100) NOT NULL,              -- Contoh: Jabodetabek, Jawa Barat
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
    -- Contoh: latitude DOUBLE PRECISION, longitude DOUBLE PRECISION
);

-- ============================================================================
-- 2. TABEL MASTER KERETA (trains) - Opsional jika ingin pisah master kereta
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.trains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    train_code VARCHAR(50) NOT NULL UNIQUE,    -- Contoh: KA-2, KA-BRAWIJAYA
    train_name VARCHAR(100) NOT NULL,          -- Contoh: Argo Bromo Anggrek, Brawijaya
    train_type VARCHAR(50) DEFAULT 'ANTAR_KOTA',-- ANTAR_KOTA, LOKAL, BANDARA
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
);

-- ============================================================================
-- 3. TABEL JADWAL KERETA API (train_schedules)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.train_schedules (
    id VARCHAR(50) PRIMARY KEY,                -- Contoh: SCH-001 atau UUID
    train_number VARCHAR(50) NOT NULL,         -- Contoh: KA 24, KA 40
    train_name VARCHAR(100) NOT NULL,          -- Contoh: Argo Parahyangan
    category VARCHAR(50) DEFAULT 'Eksekutif',  -- Eksekutif, Bisnis, Ekonomi, Luxury
    
    -- Rute & Stasiun
    origin_code VARCHAR(10) REFERENCES public.stations(code) ON UPDATE CASCADE,
    origin_name VARCHAR(100) NOT NULL,
    origin_city VARCHAR(100) NOT NULL,
    dest_code VARCHAR(10) REFERENCES public.stations(code) ON UPDATE CASCADE,
    dest_name VARCHAR(100) NOT NULL,
    dest_city VARCHAR(100) NOT NULL,
    
    -- Waktu & Tarif
    departure_time VARCHAR(20) NOT NULL,       -- Contoh: '08:00' atau timestamp
    arrival_time VARCHAR(20) NOT NULL,         -- Contoh: '11:30'
    duration VARCHAR(30) NOT NULL,             -- Contoh: '3j 30m'
    base_fare INTEGER NOT NULL,                -- Contoh: 250000
    fare NUMERIC DEFAULT 250000,
    
    -- Kapasitas Kursi & Status
    capacity INTEGER DEFAULT 500,
    booked_seats INTEGER DEFAULT 0,
    available_seats INTEGER DEFAULT 500,
    status VARCHAR(50) DEFAULT 'Tepat Waktu',  -- Tepat Waktu, Terlambat, Dibatalkan
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
);

-- ============================================================================
-- 4. TABEL PROFIL PENGGUNA / PENUMPANG (profiles)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Terhubung dengan auth.users(id) jika ada
    email VARCHAR(150) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(30),
    role VARCHAR(50) DEFAULT 'passenger',      -- passenger, admin
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
    -- Contoh: avatar_url TEXT, id_card_number VARCHAR(50)
);

-- ============================================================================
-- 5. TABEL PEMESANAN TIKET (bookings)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.bookings (
    booking_id VARCHAR(50) PRIMARY KEY,        -- Contoh: TKA-20261117-001
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    -- Data Penumpang
    passenger_name VARCHAR(150) NOT NULL,
    passenger_email VARCHAR(150),
    passenger_phone VARCHAR(30),
    passenger_nik VARCHAR(50),                 -- NIK / KTP / Paspor
    
    -- Detail Perjalanan
    train_number VARCHAR(50) NOT NULL,
    train_name VARCHAR(100) NOT NULL,
    train_class VARCHAR(100) NOT NULL,         -- Eksekutif • Kursi 4A
    wagon_class VARCHAR(50) DEFAULT 'Eksekutif',
    seat_number VARCHAR(20) NOT NULL,          -- 4A, 7B
    origin_code VARCHAR(10) NOT NULL,
    origin_name VARCHAR(100) NOT NULL,
    origin_city VARCHAR(100) NOT NULL,
    dest_code VARCHAR(10) NOT NULL,
    dest_name VARCHAR(100) NOT NULL,
    dest_city VARCHAR(100) NOT NULL,
    travel_date VARCHAR(50) NOT NULL,          -- Contoh: 'Sel, 17 Nov 2026'
    departure_time VARCHAR(20) NOT NULL,
    arrival_time VARCHAR(20) NOT NULL,
    
    -- Keuangan & Status Pemesanan
    amount INTEGER NOT NULL,
    total_amount INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'Lunas',        -- Menunggu Pembayaran, Lunas, Dibatalkan, Selesai
    payment_method VARCHAR(50) DEFAULT 'QRIS', -- QRIS, Virtual Account, Gerai
    va_number VARCHAR(100),
    
    -- Data Pembatalan (jika ada pembatalan)
    cancel_reason TEXT,
    refund_amount INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
);

-- ============================================================================
-- 6. TABEL RIWAYAT TRANSAKSI / PEMBAYARAN (payments)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id VARCHAR(50) REFERENCES public.bookings(booking_id) ON DELETE CASCADE,
    payment_method VARCHAR(50) NOT NULL,       -- QRIS, BCA VA, Mandiri VA, Indomaret
    amount INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'Success',      -- Pending, Success, Failed, Expired
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    payment_proof_url TEXT                     -- URL bukti transfer / QR
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
);

-- ============================================================================
-- 7. TABEL PEMBATALAN & REFUND (cancellations)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cancellations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id VARCHAR(50) REFERENCES public.bookings(booking_id) ON DELETE CASCADE,
    user_id UUID,
    reason TEXT NOT NULL,                      -- Alasan pembatalan
    refund_amount INTEGER NOT NULL,            -- Jumlah pengembalian dana
    bank_name VARCHAR(50),                     -- Bank tujuan refund
    account_number VARCHAR(50),                -- No Rekening refund
    account_holder VARCHAR(100),               -- Nama pemilik rekening
    status VARCHAR(50) DEFAULT 'Diproses',     -- Diproses, Selesai, Ditolak
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
);

-- ============================================================================
-- 8. TABEL RIWAYAT PENCARIAN TERAKHIR (recent_searches)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.recent_searches (
    id VARCHAR(50) PRIMARY KEY,
    user_id UUID,
    origin_code VARCHAR(10) NOT NULL,
    origin_name VARCHAR(100) NOT NULL,
    dest_code VARCHAR(10) NOT NULL,
    dest_name VARCHAR(100) NOT NULL,
    travel_date VARCHAR(50) NOT NULL,
    passengers VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- [TAMBAHKAN KOLOM LAIN DI SINI JIKA PERLU]
);

-- ============================================================================
-- 9. TABEL ADMIN PENGELOLA (admin_users & audit_logs)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(150) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    role VARCHAR(50) DEFAULT 'admin',          -- superadmin, operator, finance
    status VARCHAR(50) DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,              -- UPDATE_SCHEDULE, CANCEL_TICKET, DLL
    details TEXT,
    ip_address VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 10. KEBIJAKAN KEAMANAN (ROW LEVEL SECURITY - RLS)
-- ============================================================================
-- Mengaktifkan RLS pada seluruh tabel
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trains ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.train_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recent_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy Testing: Izinkan akses penuh untuk anon/public saat pengembangan
CREATE POLICY "Allow all stations" ON public.stations FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all trains" ON public.trains FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all train_schedules" ON public.train_schedules FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all profiles" ON public.profiles FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all bookings" ON public.bookings FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all payments" ON public.payments FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all cancellations" ON public.cancellations FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all recent_searches" ON public.recent_searches FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all admin_users" ON public.admin_users FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow all admin_audit_logs" ON public.admin_audit_logs FOR ALL TO public USING (true) WITH CHECK (true);

