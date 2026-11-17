; -- Semicolon pengaman untuk menutup query apapun yang menggantung di baris atasnya

-- ============================================================================
-- TKA MOBILE (TIKET KERETA API) - SUPABASE COMPLETE DATABASE MIGRATION SCRIPT
-- Jalankan skrip SQL ini di Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ============================================================================

-- Langkah 0: Bersihkan tabel lama yang strukturnya belum sinkron / bentrok
DROP TABLE IF EXISTS public.cancellations CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.admin_audit_logs CASCADE;
DROP TABLE IF EXISTS public.admin_users CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.recent_searches CASCADE;
DROP TABLE IF EXISTS public.bookings CASCADE;
DROP TABLE IF EXISTS public.train_schedules CASCADE;
DROP TABLE IF EXISTS public.stations CASCADE;

-- Hapus trigger auth yang berpotensi menyebabkan error 'Database error saving new user'
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- ============================================================================
-- 1. TABEL STASIUN KERETA API SE-INDONESIA
-- ============================================================================
CREATE TABLE public.stations (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Master Stasiun Seluruh Indonesia
INSERT INTO public.stations (code, name, city, region) VALUES
('GMR', 'Gambir', 'Jakarta Pusat', 'Jabodetabek'),
('PSE', 'Pasar Senen', 'Jakarta Pusat', 'Jabodetabek'),
('JNG', 'Jatinegara', 'Jakarta Timur', 'Jabodetabek'),
('MRI', 'Manggarai', 'Jakarta Selatan', 'Jabodetabek'),
('JAKK', 'Jakarta Kota', 'Jakarta Barat', 'Jabodetabek'),
('BKS', 'Bekasi', 'Bekasi', 'Jabodetabek'),
('BOO', 'Bogor', 'Bogor', 'Jabodetabek'),
('BD', 'Bandung', 'Bandung', 'Jawa Barat'),
('KAC', 'Kiaracondong', 'Bandung', 'Jawa Barat'),
('CMI', 'Cimahi', 'Cimahi', 'Jawa Barat'),
('CN', 'Cirebon', 'Cirebon', 'Jawa Barat'),
('CNP', 'Cirebon Prujakan', 'Cirebon', 'Jawa Barat'),
('PWK', 'Purwakarta', 'Purwakarta', 'Jawa Barat'),
('TSM', 'Tasikmalaya', 'Tasikmalaya', 'Jawa Barat'),
('BJR', 'Banjar', 'Banjar', 'Jawa Barat'),
('YK', 'Yogyakarta', 'Yogyakarta', 'Jawa Tengah & DIY'),
('LPN', 'Lempuyangan', 'Yogyakarta', 'Jawa Tengah & DIY'),
('SLO', 'Solo Balapan', 'Surakarta', 'Jawa Tengah & DIY'),
('PWS', 'Purwosari', 'Surakarta', 'Jawa Tengah & DIY'),
('SMT', 'Semarang Tawang', 'Semarang', 'Jawa Tengah & DIY'),
('SMC', 'Semarang Poncol', 'Semarang', 'Jawa Tengah & DIY'),
('PWT', 'Purwokerto', 'Banyumas', 'Jawa Tengah & DIY'),
('KYA', 'Kroya', 'Cilacap', 'Jawa Tengah & DIY'),
('KTA', 'Kutoarjo', 'Purworejo', 'Jawa Tengah & DIY'),
('TG', 'Tegal', 'Tegal', 'Jawa Tengah & DIY'),
('PK', 'Pekalongan', 'Pekalongan', 'Jawa Tengah & DIY'),
('KT', 'Klaten', 'Klaten', 'Jawa Tengah & DIY'),
('CU', 'Cepu', 'Blora', 'Jawa Tengah & DIY'),
('SBI', 'Surabaya Pasarturi', 'Surabaya', 'Jawa Timur'),
('SGU', 'Surabaya Gubeng', 'Surabaya', 'Jawa Timur'),
('WO', 'Wonokromo', 'Surabaya', 'Jawa Timur'),
('ML', 'Malang', 'Malang', 'Jawa Timur'),
('MLK', 'Malang Kota Lama', 'Malang', 'Jawa Timur'),
('MN', 'Madiun', 'Madiun', 'Jawa Timur'),
('KTS', 'Kertosono', 'Nganjuk', 'Jawa Timur'),
('KD', 'Kediri', 'Kediri', 'Jawa Timur'),
('BL', 'Blitar', 'Blitar', 'Jawa Timur'),
('JR', 'Jember', 'Jember', 'Jawa Timur'),
('BWI', 'Banyuwangi Kota', 'Banyuwangi', 'Jawa Timur'),
('KTG', 'Ketapang', 'Banyuwangi', 'Jawa Timur'),
('PB', 'Probolinggo', 'Probolinggo', 'Jawa Timur'),
('MDN', 'Medan', 'Medan', 'Sumatera'),
('KNM', 'Kualanamu', 'Deli Serdang', 'Sumatera'),
('TNK', 'Tanjung Karang', 'Bandar Lampung', 'Sumatera'),
('KPT', 'Kertapati', 'Palembang', 'Sumatera'),
('PD', 'Padang', 'Padang', 'Sumatera')
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- 2. TABEL JADWAL KERETA API (Mendukung User App & Admin Dashboard)
-- ============================================================================
CREATE TABLE public.train_schedules (
    id VARCHAR(50) PRIMARY KEY,
    train_number VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    train_name VARCHAR(100),
    category VARCHAR(50) DEFAULT 'Eksekutif',
    origin VARCHAR(100),
    destination VARCHAR(100),
    origin_code VARCHAR(10) NOT NULL,
    origin_name VARCHAR(100) NOT NULL,
    origin_city VARCHAR(100) NOT NULL,
    dest_code VARCHAR(10) NOT NULL,
    dest_name VARCHAR(100) NOT NULL,
    dest_city VARCHAR(100) NOT NULL,
    departure_time VARCHAR(20) NOT NULL,
    arrival_time VARCHAR(20) NOT NULL,
    duration VARCHAR(30) NOT NULL,
    base_fare INTEGER NOT NULL,
    fare NUMERIC DEFAULT 250000,
    status VARCHAR(50) DEFAULT 'Tepat Waktu',
    capacity INTEGER DEFAULT 500,
    booked_seats INTEGER DEFAULT 450,
    available_classes TEXT[] NOT NULL DEFAULT ARRAY['Ekonomi', 'Eksekutif'],
    available_seats INTEGER NOT NULL DEFAULT 50,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Master Jadwal
INSERT INTO public.train_schedules (
    id, train_number, name, train_name, category, origin, destination,
    origin_code, origin_name, origin_city, dest_code, dest_name, dest_city,
    departure_time, arrival_time, duration, base_fare, fare, available_classes, available_seats
) VALUES
('SCH-001', 'KA 2', 'KA Argo Bromo Anggrek', 'KA Argo Bromo Anggrek', 'Luxury', 'Gambir (GMR)', 'Surabaya Pasarturi (SBI)', 'GMR', 'Gambir', 'Jakarta Pusat', 'SBI', 'Surabaya Pasarturi', 'Surabaya', '08:20 WIB', '16:25 WIB', '8j 05m', 640000, 640000, ARRAY['Eksekutif', 'Luxury'], 32),
('SCH-002', 'KA 68', 'KA Taksaka', 'KA Taksaka', 'Eksekutif', 'Gambir (GMR)', 'Yogyakarta (YK)', 'GMR', 'Gambir', 'Jakarta Pusat', 'YK', 'Yogyakarta', 'Yogyakarta', '09:10 WIB', '15:20 WIB', '6j 10m', 550000, 550000, ARRAY['Eksekutif', 'Luxury'], 45),
('SCH-003', 'KA 44', 'KA Argo Parahyangan', 'KA Argo Parahyangan', 'Bisnis', 'Gambir (GMR)', 'Bandung (BD)', 'GMR', 'Gambir', 'Jakarta Pusat', 'BD', 'Bandung', 'Bandung', '06:30 WIB', '09:15 WIB', '2j 45m', 150000, 150000, ARRAY['Ekonomi', 'Eksekutif'], 120),
('SCH-004', 'KA 66', 'KA Turangga', 'KA Turangga', 'Eksekutif', 'Bandung (BD)', 'Surabaya Gubeng (SGU)', 'BD', 'Bandung', 'Bandung', 'SGU', 'Surabaya Gubeng', 'Surabaya', '18:10 WIB', '04:50 WIB', '10j 40m', 490000, 490000, ARRAY['Eksekutif'], 28),
('SCH-005', 'KA 92', 'KA Lodaya', 'KA Lodaya', 'Ekonomi', 'Bandung (BD)', 'Solo Balapan (SLO)', 'BD', 'Bandung', 'Bandung', 'SLO', 'Solo Balapan', 'Surakarta', '07:05 WIB', '15:40 WIB', '8j 35m', 295000, 295000, ARRAY['Ekonomi', 'Eksekutif'], 64),
('SCH-006', 'KA 134', 'KA Fajar Utama Solo', 'KA Fajar Utama Solo', 'Ekonomi', 'Pasar Senen (PSE)', 'Solo Balapan (SLO)', 'PSE', 'Pasar Senen', 'Jakarta Pusat', 'SLO', 'Solo Balapan', 'Surakarta', '05:55 WIB', '13:45 WIB', '7j 50m', 240000, 240000, ARRAY['Ekonomi', 'Eksekutif'], 88),
('SCH-007', 'KA 56', 'KA Gajayana', 'KA Gajayana', 'Luxury', 'Gambir (GMR)', 'Malang (ML)', 'GMR', 'Gambir', 'Jakarta Pusat', 'ML', 'Malang', 'Malang', '18:40 WIB', '07:15 WIB', '12j 35m', 680000, 680000, ARRAY['Eksekutif', 'Luxury'], 18),
('SCH-008', 'KA 108', 'KA Malabar', 'KA Malabar', 'Bisnis', 'Bandung (BD)', 'Malang (ML)', 'BD', 'Bandung', 'Bandung', 'ML', 'Malang', 'Malang', '17:20 WIB', '06:30 WIB', '13j 10m', 380000, 380000, ARRAY['Ekonomi', 'Eksekutif'], 40),
('SCH-009', 'KA 80', 'KA Bima', 'KA Bima', 'Eksekutif', 'Gambir (GMR)', 'Surabaya Gubeng (SGU)', 'GMR', 'Gambir', 'Jakarta Pusat', 'SGU', 'Surabaya Gubeng', 'Surabaya', '17:00 WIB', '03:30 WIB', '10j 30m', 590000, 590000, ARRAY['Eksekutif'], 52),
('SCH-010', 'KA 112', 'KA Sancaka', 'KA Sancaka', 'Ekonomi', 'Yogyakarta (YK)', 'Surabaya Gubeng (SGU)', 'YK', 'Yogyakarta', 'Yogyakarta', 'SGU', 'Surabaya Gubeng', 'Surabaya', '06:50 WIB', '10:55 WIB', '4j 05m', 210000, 210000, ARRAY['Ekonomi', 'Eksekutif'], 90)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 3. TABEL PEMESANAN TIKET (BOOKINGS / TRANSAKSI)
-- ============================================================================
CREATE TABLE public.bookings (
    booking_id VARCHAR(50) PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    passenger_name VARCHAR(150) NOT NULL,
    passenger_email VARCHAR(150) NOT NULL,
    passenger_phone VARCHAR(50) NOT NULL,
    passenger_nik VARCHAR(50) NOT NULL,
    train_number VARCHAR(50) DEFAULT 'KA 2',
    train_name VARCHAR(100) NOT NULL,
    train_class VARCHAR(100) NOT NULL,
    wagon_class VARCHAR(100) DEFAULT 'Eksekutif',
    route VARCHAR(150),
    origin_code VARCHAR(10) NOT NULL,
    origin_name VARCHAR(100) NOT NULL,
    origin_city VARCHAR(100) NOT NULL,
    dest_code VARCHAR(10) NOT NULL,
    dest_name VARCHAR(100) NOT NULL,
    dest_city VARCHAR(100) NOT NULL,
    travel_date VARCHAR(50) NOT NULL,
    departure_time VARCHAR(20) NOT NULL,
    arrival_time VARCHAR(20) NOT NULL,
    seat_number VARCHAR(50) NOT NULL,
    amount NUMERIC DEFAULT 640000,
    total_amount INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'Sudah Dibayar',
    payment_method VARCHAR(50) DEFAULT 'BCA Virtual Account',
    va_number VARCHAR(50),
    cancel_reason TEXT,
    refund_amount INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Data Awal Tiket Kereta untuk Pengguna Login Aktif (Samuel)
INSERT INTO public.bookings (
    booking_id, passenger_name, passenger_email, passenger_phone, passenger_nik,
    train_number, train_name, train_class, wagon_class, route,
    origin_code, origin_name, origin_city, dest_code, dest_name, dest_city,
    travel_date, departure_time, arrival_time, seat_number,
    amount, total_amount, status, payment_method, va_number, cancel_reason, refund_amount
) VALUES
(
    'TKA-9921XB', 'Samuel', 'kocak@co.id', '+62 887-1287-18', '3514062607090001',
    'KA 2', 'KA Argo Bromo Anggrek', 'Luxury • Kursi 5C • EKS-1', 'Luxury', 'Gambir (GMR) -> Surabaya Pasarturi (SBI)',
    'GMR', 'Gambir', 'Jakarta Pusat', 'SBI', 'Surabaya Pasarturi', 'Surabaya',
    '25 Okt 2026', '08:20 WIB', '16:25 WIB', 'Gerbong EKS-2 / Kursi 5C',
    640000, 640000, 'Sudah Dibayar', 'BCA Virtual Account', 'VA-9001842910', NULL, NULL
),
(
    'TKA-8832KL', 'Samuel', 'kocak@co.id', '+62 887-1287-18', '3514062607090001',
    'KA 68', 'KA Taksaka', 'Eksekutif • Kursi EKS-1 / 8A', 'Eksekutif', 'Yogyakarta (YK) -> Gambir (GMR)',
    'YK', 'Yogyakarta', 'Yogyakarta', 'GMR', 'Gambir', 'Jakarta Pusat',
    '24 Okt 2026', '08:45 WIB', '15:15 WIB', 'Gerbong EKS-1 / Kursi 3A',
    550000, 550000, 'Menunggu Pembayaran', 'Mandiri Virtual Account', 'VA-8832019482', NULL, NULL
),
(
    'TKA-7104MN', 'Samuel', 'kocak@co.id', '+62 887-1287-18', '3514062607090001',
    'KA 66', 'KA Turangga', 'Eksekutif • Kursi EKS-3 / 4B', 'Eksekutif', 'Bandung (BD) -> Surabaya Gubeng (SGU)',
    'BD', 'Bandung', 'Bandung', 'SGU', 'Surabaya Gubeng', 'Surabaya',
    '10 Okt 2026', '18:10 WIB', '04:50 WIB', 'Gerbong EKS-3 / Kursi 4B',
    490000, 490000, 'Perjalanan Selesai', 'BCA Virtual Account', 'VA-7104928104', NULL, NULL
),
(
    'TKA-5021PQ', 'Samuel', 'kocak@co.id', '+62 887-1287-18', '3514062607090001',
    'KA 92', 'KA Lodaya', 'Ekonomi Premium • Kursi PRE-1 / 14D', 'Ekonomi', 'Solo Balapan (SLO) -> Bandung (BD)',
    'SLO', 'Solo Balapan', 'Surakarta', 'BD', 'Bandung', 'Bandung',
    '05 Okt 2026', '07:05 WIB', '15:40 WIB', 'Gerbong PRE-1 / Kursi 14D',
    295000, 295000, 'Dibatalkan', 'BCA Virtual Account', 'VA-5021948201', 'Perubahan rencana perjalanan', 221250
),
(
    'TKA-3319TR', 'Samuel', 'kocak@co.id', '+62 887-1287-18', '3514062607090001',
    'KA 134', 'KA Fajar Utama Solo', 'Ekonomi Premium • Kursi PRE-2 / 10A', 'Ekonomi', 'Pasar Senen (PSE) -> Solo Balapan (SLO)',
    'PSE', 'Pasar Senen', 'Jakarta Pusat', 'SLO', 'Solo Balapan', 'Surakarta',
    '12 Okt 2026', '05:55 WIB', '13:45 WIB', 'Gerbong PRE-2 / Kursi 10A',
    240000, 240000, 'Kedaluwarsa', 'BRI Virtual Account', 'VA-3319201940', NULL, NULL
)
ON CONFLICT (booking_id) DO NOTHING;

-- ============================================================================
-- 3B. TABEL TRANSAKSI PEMBAYARAN (PAYMENTS GATEWAY & AUDIT)
-- ============================================================================
CREATE TABLE public.payments (
    payment_id VARCHAR(50) PRIMARY KEY,
    booking_id VARCHAR(50) REFERENCES public.bookings(booking_id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    payment_method VARCHAR(50) NOT NULL, -- 'QRIS', 'TKAPay', 'BCA Virtual Account', 'Mandiri Virtual Account', 'BRI Virtual Account', 'BNI Virtual Account', 'GoPay', 'OVO', 'DANA'
    payment_channel VARCHAR(50) NOT NULL, -- 'QRIS', 'Saldo Akun', 'Virtual Account', 'E-Wallet'
    reference_number VARCHAR(100) NOT NULL,
    amount INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Sudah Dibayar', -- 'Menunggu Pembayaran', 'Sudah Dibayar', 'Gagal', 'Kedaluwarsa'
    paid_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Data Pembayaran Awal
INSERT INTO public.payments (
    payment_id, booking_id, payment_method, payment_channel, reference_number, amount, status, paid_at
) VALUES
('PAY-9921001', 'TKA-9921XB', 'BCA Virtual Account', 'Virtual Account', 'VA-9001842910', 640000, 'Sudah Dibayar', NOW() - INTERVAL '1 day'),
('PAY-7104002', 'TKA-7104MN', 'BCA Virtual Account', 'Virtual Account', 'VA-7104928104', 490000, 'Sudah Dibayar', NOW() - INTERVAL '3 days')
ON CONFLICT (payment_id) DO NOTHING;

-- ============================================================================
-- 3C. TABEL PEMBATALAN TIKET (CANCELLATIONS / REFUND)
-- ============================================================================
CREATE TABLE public.cancellations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id VARCHAR(50) REFERENCES public.bookings(booking_id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    refund_amount INTEGER,
    status VARCHAR(50) DEFAULT 'Dibatalkan',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Contoh Data Pembatalan
INSERT INTO public.cancellations (booking_id, reason, refund_amount, status) VALUES
('TKA-5021PQ', 'Perubahan rencana perjalanan', 221250, 'Dibatalkan')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 4. TABEL PENCARIAN TERAKHIR (RECENT SEARCHES)
-- ============================================================================
CREATE TABLE public.recent_searches (
    id VARCHAR(50) PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    origin_code VARCHAR(10) NOT NULL,
    origin_name VARCHAR(100) NOT NULL,
    dest_code VARCHAR(10) NOT NULL,
    dest_name VARCHAR(100) NOT NULL,
    travel_date VARCHAR(50) NOT NULL,
    passengers VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 5. TABEL PROFILES (PENGGUNA & PENUMPANG)
-- ============================================================================
CREATE TABLE public.profiles (
    id TEXT PRIMARY KEY,
    email VARCHAR(150),
    full_name VARCHAR(150),
    phone VARCHAR(50),
    role VARCHAR(50) DEFAULT 'passenger',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Profile User Aktif
INSERT INTO public.profiles (id, email, full_name, phone, role) VALUES
('usr-samuel-01', 'kocak@co.id', 'Samuel', '+62 887-1287-18', 'passenger')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 6. TABEL ADMIN USERS & AUDIT LOGS
-- ============================================================================
CREATE TABLE public.admin_users (
    id VARCHAR(100) PRIMARY KEY,
    email VARCHAR(150) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'Aktif',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_id VARCHAR(100),
    admin_email VARCHAR(150),
    action VARCHAR(100),
    entity_type VARCHAR(100),
    entity_id VARCHAR(100),
    entity_label VARCHAR(150),
    new_value JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Default Admin
INSERT INTO public.admin_users (id, email, full_name, role, status) VALUES
('adm-001', 'admin@tka.co.id', 'Super Admin TKA', 'Super Admin', 'Aktif')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 7. KONFIGURASI ROW LEVEL SECURITY (RLS) - PERMISIF & AMAN
-- ============================================================================
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.train_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recent_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Stations
DROP POLICY IF EXISTS "Allow public read stations" ON public.stations;
CREATE POLICY "Allow public read stations" ON public.stations FOR SELECT TO public USING (true);

-- Train Schedules
DROP POLICY IF EXISTS "Allow public all train_schedules" ON public.train_schedules;
CREATE POLICY "Allow public all train_schedules" ON public.train_schedules FOR ALL TO public USING (true) WITH CHECK (true);

-- Bookings (Select, Insert, Update, Delete)
DROP POLICY IF EXISTS "Allow public all bookings" ON public.bookings;
CREATE POLICY "Allow public all bookings" ON public.bookings FOR ALL TO public USING (true) WITH CHECK (true);

-- Payments (Select, Insert, Update, Delete)
DROP POLICY IF EXISTS "Allow public all payments" ON public.payments;
CREATE POLICY "Allow public all payments" ON public.payments FOR ALL TO public USING (true) WITH CHECK (true);

-- Cancellations (Select, Insert, Update, Delete)
DROP POLICY IF EXISTS "Allow public all cancellations" ON public.cancellations;
CREATE POLICY "Allow public all cancellations" ON public.cancellations FOR ALL TO public USING (true) WITH CHECK (true);

-- Recent Searches
DROP POLICY IF EXISTS "Allow public all recent_searches" ON public.recent_searches;
CREATE POLICY "Allow public all recent_searches" ON public.recent_searches FOR ALL TO public USING (true) WITH CHECK (true);

-- Profiles
DROP POLICY IF EXISTS "Allow public all profiles" ON public.profiles;
CREATE POLICY "Allow public all profiles" ON public.profiles FOR ALL TO public USING (true) WITH CHECK (true);

-- Admin Users & Audit Logs
DROP POLICY IF EXISTS "Allow public all admin_users" ON public.admin_users;
CREATE POLICY "Allow public all admin_users" ON public.admin_users FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public all admin_audit_logs" ON public.admin_audit_logs;
CREATE POLICY "Allow public all admin_audit_logs" ON public.admin_audit_logs FOR ALL TO public USING (true) WITH CHECK (true);
