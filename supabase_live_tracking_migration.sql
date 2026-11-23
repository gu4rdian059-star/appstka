-- ============================================================================
-- TKA MOBILE - LIVE TRAIN TRACKING, SCHEDULE, STATION, FAVORITES & BREVO NOTIF
-- Supabase PostgreSQL Migration Script (Idempotent & Safe to Re-run)
-- Jalankan di Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. ENHANCE TABEL STATIONS (Koordinat GPS, Alamat, Zona Waktu, Fasilitas)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.stations (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS timezone VARCHAR(10) DEFAULT 'WIB';
ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS facilities TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_stations_region ON public.stations (region);
CREATE INDEX IF NOT EXISTS idx_stations_name ON public.stations (LOWER(name));
CREATE INDEX IF NOT EXISTS idx_stations_city ON public.stations (LOWER(city));

-- Seed / Update Stasiun Kereta Api Indonesia dengan koordinat akurat & fasilitas
INSERT INTO public.stations (code, name, city, region, address, latitude, longitude, timezone, facilities) VALUES
('GMR', 'Stasiun Gambir', 'Jakarta Pusat', 'Jabodetabek', 'Jl. Medan Merdeka Timur No.1, Gambir, Jakarta Pusat', -6.176655, 106.830583, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Akses Disabilitas','Klinik Mediska','Parkir Luas','Minimarket','Charging Station']),
('PSE', 'Stasiun Pasar Senen', 'Jakarta Pusat', 'Jabodetabek', 'Jl. Stasiun Senen No.14, Senen, Jakarta Pusat', -6.174208, 106.844406, 'WIB', ARRAY['Ruang Tunggu AC','Mushola','ATM Center','Toilet Bersih','Akses Disabilitas','Klinik Mediska','Food Court','Charging Station']),
('JNG', 'Stasiun Jatinegara', 'Jakarta Timur', 'Jabodetabek', 'Jl. Bekasi Barat Raya, Jatinegara, Jakarta Timur', -6.215192, 106.870251, 'WIB', ARRAY['Mushola','Toilet','ATM','Minimarket','Integrasi TransJakarta','Akses Disabilitas']),
('MRI', 'Stasiun Manggarai', 'Jakarta Selatan', 'Jabodetabek', 'Jl. Manggarai Utara 1, Tebet, Jakarta Selatan', -6.209911, 106.850262, 'WIB', ARRAY['Stasiun Sentral KRL & KA Bandara','Eskalator & Lift','Mushola','Minimarket','ATM Center','Akses Disabilitas']),
('JAKK', 'Stasiun Jakarta Kota', 'Jakarta Barat', 'Jabodetabek', 'Jl. Stasiun Kota No.1, Pinangsia, Taman Sari, Jakarta Barat', -6.137563, 106.814658, 'WIB', ARRAY['Bangunan Cagar Budaya','Mushola','ATM Center','Kantin','Toilet','Integrasi TransJakarta']),
('BKS', 'Stasiun Bekasi', 'Bekasi', 'Jabodetabek', 'Jl. Ir. H. Juanda, Bekasi Timur, Kota Bekasi', -6.236185, 106.999451, 'WIB', ARRAY['Eskalator & Lift','Mushola','Parkir Motor & Mobil','Minimarket','ATM Center']),
('BOO', 'Stasiun Bogor', 'Bogor', 'Jabodetabek', 'Jl. Nyi Raja Permas No.1, Cibogor, Kota Bogor', -6.595716, 106.790531, 'WIB', ARRAY['Mushola','Area Kuliner','ATM Center','Toilet','Integrasi Angkot & Biskita']),
('PWK', 'Stasiun Purwakarta', 'Purwakarta', 'Jawa Barat', 'Jl. Kolonel Kornel Singawinata No.1, Purwakarta', -6.552906, 107.446669, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','Parkir','Kantin']),
('CMI', 'Stasiun Cimahi', 'Cimahi', 'Jawa Barat', 'Jl. Stasiun Cimahi, Baros, Kota Cimahi', -6.885654, 107.535995, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Parkir']),
('BD', 'Stasiun Bandung', 'Bandung', 'Jawa Barat', 'Jl. Stasiun Barat, Kebon Jeruk, Andir, Kota Bandung', -6.912606, 107.602418, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Klinik Mediska','Akses Disabilitas','Charging Station','Minimarket']),
('KAC', 'Stasiun Kiaracondong', 'Bandung', 'Jawa Barat', 'Jl. Stasiun Kiaracondong, Babakan Surabaya, Kota Bandung', -6.925077, 107.646217, 'WIB', ARRAY['Ruang Tunggu','Mushola','ATM','Toilet','Parkir','Kantin']),
('TSM', 'Stasiun Tasikmalaya', 'Tasikmalaya', 'Jawa Barat', 'Jl. Stasiun No.8, Lengkongsari, Tawang, Kota Tasikmalaya', -7.322706, 108.224056, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Parkir']),
('CN', 'Stasiun Cirebon', 'Cirebon', 'Jawa Barat', 'Jl. Siliwangi, Kebonbaru, Kejaksan, Kota Cirebon', -6.705469, 108.555377, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Klinik Mediska','Parkir Luas','Minimarket']),
('CNP', 'Stasiun Cirebon Prujakan', 'Cirebon', 'Jawa Barat', 'Jl. Nyi Mas Gandasari No.1, Pekalangan, Kota Cirebon', -6.718678, 108.559283, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Minimarket']),
('TG', 'Stasiun Tegal', 'Tegal', 'Jawa Tengah & DIY', 'Jl. Semeru No.16, Slerok, Tegal Timur, Kota Tegal', -6.867306, 109.142667, 'WIB', ARRAY['Ruang Tunggu','Mushola','ATM','Toilet','Parkir']),
('PK', 'Stasiun Pekalongan', 'Pekalongan', 'Jawa Tengah & DIY', 'Jl. Gajah Mada No.10, Bendan, Kota Pekalongan', -6.889779, 109.664183, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Parkir']),
('SMT', 'Stasiun Semarang Tawang', 'Semarang', 'Jawa Tengah & DIY', 'Jl. Taman Tawang No.1, Tanjung Mas, Kota Semarang', -6.964444, 110.427975, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Akses Disabilitas','Charging Station','Klinik Mediska']),
('SMC', 'Stasiun Semarang Poncol', 'Semarang', 'Jawa Tengah & DIY', 'Jl. Imam Bonjol No.115, Purwosari, Kota Semarang', -6.972969, 110.414633, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Parkir','Minimarket']),
('PWT', 'Stasiun Purwokerto', 'Banyumas', 'Jawa Tengah & DIY', 'Jl. Stasiun Purwokerto, Kober, Purwokerto Barat', -7.419283, 109.222111, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Klinik Mediska','Parkir Luas','Skybridge']),
('KYA', 'Stasiun Kroya', 'Cilacap', 'Jawa Tengah & DIY', 'Jl. Stasiun Kroya, Bajing, Kroya, Cilacap', -7.630519, 109.253528, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Kantin']),
('KTA', 'Stasiun Kutoarjo', 'Purworejo', 'Jawa Tengah & DIY', 'Jl. Merpati No.1, Semawung Daleman, Kutoarjo', -7.725925, 109.907342, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Integrasi KA Prameks']),
('YK', 'Stasiun Yogyakarta', 'Yogyakarta', 'Jawa Tengah & DIY', 'Jl. Pasar Kembang, Sosromenduran, Gedongtengen, Yogyakarta', -7.789217, 110.363506, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Integrasi KA Bandara YIA','Akses Disabilitas','Charging Station','Klinik Mediska']),
('LPN', 'Stasiun Lempuyangan', 'Yogyakarta', 'Jawa Tengah & DIY', 'Jl. Lempuyangan No.1, Bausasran, Danurejan, Yogyakarta', -7.790256, 110.375503, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Minimarket','Parkir']),
('SLO', 'Stasiun Solo Balapan', 'Surakarta', 'Jawa Tengah & DIY', 'Jl. Wolter Monginsidi No.112, Kestalan, Banjarsari, Surakarta', -7.557042, 110.821361, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Skybridge Terminal Tirtonadi','Integrasi KRL & KA Bandara','Mushola','WiFi Gratis','ATM Center','Akses Disabilitas']),
('PWS', 'Stasiun Purwosari', 'Surakarta', 'Jawa Tengah & DIY', 'Jl. Slamet Riyadi No.502, Purwosari, Laweyan, Surakarta', -7.564403, 110.801219, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Parkir']),
('MN', 'Stasiun Madiun', 'Madiun', 'Jawa Timur', 'Jl. Kompol Sunaryo No.14, Madiun Lor, Manguharjo, Kota Madiun', -7.619236, 111.524064, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Parkir','Minimarket']),
('KD', 'Stasiun Kediri', 'Kediri', 'Jawa Timur', 'Jl. Stasiun No.1, Balowerti, Kota Kediri', -7.817411, 112.015528, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Parkir']),
('SBI', 'Stasiun Surabaya Pasarturi', 'Surabaya', 'Jawa Timur', 'Jl. Semarang No.1, Tembok Dukuh, Bubutan, Kota Surabaya', -7.248511, 112.731161, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Akses Disabilitas','Klinik Mediska','Parkir Luas','Charging Station']),
('SGU', 'Stasiun Surabaya Gubeng', 'Surabaya', 'Jawa Timur', 'Jl. Gubeng Masjid No.1, Pacar Keling, Tambaksari, Kota Surabaya', -7.265464, 112.752056, 'WIB', ARRAY['Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Akses Disabilitas','Klinik Mediska','Minimarket','Charging Station']),
('ML', 'Stasiun Malang', 'Malang', 'Jawa Timur', 'Jl. Trunojoyo No.10, Kiduldalem, Klojen, Kota Malang', -7.977286, 112.637011, 'WIB', ARRAY['Skybridge Stasiun Baru','Ruang Tunggu Eksekutif','Mushola','ATM Center','WiFi Gratis','Akses Disabilitas','Parkir Luas']),
('JR', 'Stasiun Jember', 'Jember', 'Jawa Timur', 'Jl. Wijaya Kusuma No.5, Jemberlor, Patrang, Jember', -8.164625, 113.704225, 'WIB', ARRAY['Ruang Tunggu','Mushola','ATM','Toilet','Parkir']),
('KTG', 'Stasiun Ketapang', 'Banyuwangi', 'Jawa Timur', 'Jl. Gatot Subroto, Ketapang, Kalipuro, Banyuwangi', -8.144947, 114.397636, 'WIB', ARRAY['Dekat Pelabuhan Ketapang','Ruang Tunggu','Mushola','Toilet','ATM','Parkir']),
('MDN', 'Stasiun Medan', 'Medan', 'Sumatera', 'Jl. Stasiun Kereta Api No.1, Kesawan, Medan Barat, Kota Medan', 3.591278, 98.678478, 'WIB', ARRAY['Integrasi KA Bandara Kualanamu','Ruang Tunggu Eksekutif','Mushola','WiFi Gratis','ATM Center','Akses Disabilitas']),
('KNM', 'Stasiun Kualanamu', 'Deli Serdang', 'Sumatera', 'Kompleks Bandara Internasional Kualanamu, Deli Serdang', 3.638011, 98.876319, 'WIB', ARRAY['Akses Langsung Terminal Bandara','Ruang Tunggu AC','Mushola','WiFi Gratis','Eskalator & Lift']),
('KPT', 'Stasiun Kertapati', 'Palembang', 'Sumatera', 'Jl. Ki Merogan, Kemas Rindo, Kertapati, Kota Palembang', -3.025219, 104.741856, 'WIB', ARRAY['Ruang Tunggu','Mushola','Toilet','ATM','Parkir']),
('TNK', 'Stasiun Tanjung Karang', 'Bandar Lampung', 'Sumatera', 'Jl. Kotaraja No.1, Gunung Sari, Enggal, Bandar Lampung', -5.408503, 105.259781, 'WIB', ARRAY['Ruang Tunggu','Mushola','ATM Center','Toilet','Parkir'])
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    city = EXCLUDED.city,
    region = EXCLUDED.region,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    timezone = EXCLUDED.timezone,
    facilities = EXCLUDED.facilities;

-- ============================================================================
-- 2. TABEL TRAIN_TRIPS (Tracking Posisi, Status Jujur LIVE/DELAYED/SCHEDULED/DEMO/UNAVAILABLE)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.train_trips (
    id VARCHAR(64) PRIMARY KEY,
    schedule_id VARCHAR(50),
    train_number VARCHAR(30) NOT NULL,
    train_name VARCHAR(120) NOT NULL,
    service_type VARCHAR(60),
    region VARCHAR(80) NOT NULL DEFAULT 'Jawa',
    origin_station_code VARCHAR(10) NOT NULL REFERENCES public.stations(code) ON UPDATE CASCADE,
    destination_station_code VARCHAR(10) NOT NULL REFERENCES public.stations(code) ON UPDATE CASCADE,
    service_date DATE NOT NULL DEFAULT CURRENT_DATE,
    scheduled_departure TIMESTAMPTZ NOT NULL,
    scheduled_arrival TIMESTAMPTZ NOT NULL,
    estimated_arrival TIMESTAMPTZ,
    data_status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED'
        CHECK (data_status IN ('LIVE', 'DELAYED', 'SCHEDULED', 'DEMO', 'UNAVAILABLE')),
    trip_status VARCHAR(80) NOT NULL DEFAULT 'Terjadwal',
    is_simulated BOOLEAN NOT NULL DEFAULT FALSE,
    data_source_label VARCHAR(120) DEFAULT 'Jadwal Operasional',
    delay_minutes INTEGER NOT NULL DEFAULT 0,
    delay_reason TEXT,
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    speed_kmh DOUBLE PRECISION,
    current_station_code VARCHAR(10),
    next_station_code VARCHAR(10),
    route_geometry JSONB DEFAULT '[]'::JSONB,
    last_updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_train_trips_status ON public.train_trips (data_status);
CREATE INDEX IF NOT EXISTS idx_train_trips_region ON public.train_trips (region);
CREATE INDEX IF NOT EXISTS idx_train_trips_date ON public.train_trips (service_date);
CREATE INDEX IF NOT EXISTS idx_train_trips_origin_dest ON public.train_trips (origin_station_code, destination_station_code);
CREATE INDEX IF NOT EXISTS idx_train_trips_number ON public.train_trips (LOWER(train_number));
CREATE INDEX IF NOT EXISTS idx_train_trips_name ON public.train_trips (LOWER(train_name));

-- ============================================================================
-- 3. TABEL TRAIN_TRIP_STOPS (Daftar Stasiun Pemberhentian per Perjalanan)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.train_trip_stops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id VARCHAR(64) NOT NULL REFERENCES public.train_trips(id) ON DELETE CASCADE,
    station_code VARCHAR(10) NOT NULL REFERENCES public.stations(code) ON UPDATE CASCADE,
    stop_sequence INTEGER NOT NULL,
    scheduled_arrival TIMESTAMPTZ,
    scheduled_departure TIMESTAMPTZ,
    estimated_arrival TIMESTAMPTZ,
    estimated_departure TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    actual_departure TIMESTAMPTZ,
    platform VARCHAR(30),
    stop_status VARCHAR(20) NOT NULL DEFAULT 'UPCOMING'
        CHECK (stop_status IN ('PASSED', 'AT_STATION', 'UPCOMING', 'SKIPPED')),
    UNIQUE (trip_id, stop_sequence)
);

CREATE INDEX IF NOT EXISTS idx_train_trip_stops_trip ON public.train_trip_stops (trip_id, stop_sequence);
CREATE INDEX IF NOT EXISTS idx_train_trip_stops_station ON public.train_trip_stops (station_code);

-- ============================================================================
-- 4. TABEL USER_FAVORITES (Favorit Kereta / Perjalanan & Pengaturan Notif)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    user_email VARCHAR(150),
    trip_id VARCHAR(64),
    train_number VARCHAR(30) NOT NULL,
    train_name VARCHAR(120) NOT NULL,
    origin_station_code VARCHAR(10) NOT NULL,
    destination_station_code VARCHAR(10) NOT NULL,
    notify_delay BOOLEAN NOT NULL DEFAULT TRUE,
    notify_schedule_change BOOLEAN NOT NULL DEFAULT TRUE,
    notify_service_disruption BOOLEAN NOT NULL DEFAULT TRUE,
    notify_arrival_info BOOLEAN NOT NULL DEFAULT TRUE,
    notify_status_change BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, train_number, origin_station_code, destination_station_code)
);

CREATE INDEX IF NOT EXISTS idx_user_favorites_user ON public.user_favorites (user_id);

-- ============================================================================
-- 5. TABEL USER_NOTIFICATION_PREFERENCES (Preferensi Notifikasi & App Settings)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
    user_id TEXT PRIMARY KEY,
    user_email VARCHAR(150),
    email_notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    in_app_notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    notify_delay BOOLEAN NOT NULL DEFAULT TRUE,
    notify_schedule_change BOOLEAN NOT NULL DEFAULT TRUE,
    notify_service_disruption BOOLEAN NOT NULL DEFAULT TRUE,
    notify_arrival_info BOOLEAN NOT NULL DEFAULT TRUE,
    notify_status_change BOOLEAN NOT NULL DEFAULT TRUE,
    preferred_timezone VARCHAR(10) NOT NULL DEFAULT 'WIB'
        CHECK (preferred_timezone IN ('WIB', 'WITA', 'WIT')),
    auto_follow_train BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 6. TABEL TRAIN_NOTIFICATIONS (Notifikasi Brevo + Anti-Duplikasi Atomik)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.train_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    recipient_email VARCHAR(150),
    trip_id VARCHAR(64),
    train_number VARCHAR(30),
    train_name VARCHAR(120),
    event_type VARCHAR(40) NOT NULL
        CHECK (event_type IN ('TRAIN_DELAY', 'SCHEDULE_CHANGE', 'SERVICE_DISRUPTION', 'ARRIVAL_INFO', 'TRIP_STATUS_CHANGE')),
    event_dedup_key VARCHAR(220) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::JSONB,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    brevo_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (brevo_status IN ('PENDING', 'SENT', 'SKIPPED', 'FAILED')),
    brevo_message_id VARCHAR(150),
    brevo_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- JAMINAN ANTI-DUPLIKASI: Kejadian yang sama tidak akan pernah dikirim 2x ke user yang sama
    UNIQUE (user_id, event_dedup_key)
);

CREATE INDEX IF NOT EXISTS idx_train_notifications_user ON public.train_notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_train_notifications_event ON public.train_notifications (event_type);

-- ============================================================================
-- 7. SEED DATA AWAL PERJALANAN KERETA (JUJUR: DEMO / SCHEDULED / DELAYED / UNAVAILABLE)
-- CATATAN PENTING: Data simulasi diberi status DEMO & is_simulated=TRUE.
-- Status LIVE hanya boleh ditulis oleh feed telemetri GPS nyata (is_simulated=FALSE).
-- ============================================================================
INSERT INTO public.train_trips (
    id, schedule_id, train_number, train_name, service_type, region,
    origin_station_code, destination_station_code, service_date,
    scheduled_departure, scheduled_arrival, estimated_arrival,
    data_status, trip_status, is_simulated, data_source_label,
    delay_minutes, delay_reason, current_lat, current_lng, heading, speed_kmh,
    current_station_code, next_station_code, route_geometry, last_updated_at
) VALUES
(
    'TRIP-KA2-ABA', 'SCH-001', 'KA 2', 'KA Argo Bromo Anggrek', 'Eksekutif / Luxury', 'Jawa Timur',
    'GMR', 'SBI', CURRENT_DATE,
    (CURRENT_DATE + TIME '08:20:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '16:25:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '16:25:00') AT TIME ZONE 'Asia/Jakarta',
    'DEMO', 'Simulasi Perjalanan (Mode Demo)', TRUE, 'Simulasi Demo TKA (Bukan Real-Time)',
    0, NULL, -6.8780, 109.4200, 96.0, 112.0,
    'CN', 'SMT',
    '[[106.830583,-6.176655],[106.999451,-6.236185],[108.555377,-6.705469],[109.142667,-6.867306],[109.664183,-6.889779],[110.427975,-6.964444],[112.731161,-7.248511]]'::JSONB,
    NOW()
),
(
    'TRIP-KA40-AP', 'SCH-002', 'KA 40', 'KA Argo Parahyangan', 'Eksekutif / Ekonomi', 'Jawa Barat',
    'GMR', 'BD', CURRENT_DATE,
    (CURRENT_DATE + TIME '09:30:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '12:45:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '13:03:00') AT TIME ZONE 'Asia/Jakarta',
    'DELAYED', 'Terlambat 18 Menit (Antrean Sinyal)', TRUE, 'Simulasi Delay TKA (Bukan Real-Time)',
    18, 'Antrean persilangan jalur tunggal di lintas Purwakarta - Cimahi', -6.6850, 107.4820, 145.0, 64.0,
    'PWK', 'CMI',
    '[[106.830583,-6.176655],[106.870251,-6.215192],[106.999451,-6.236185],[107.446669,-6.552906],[107.535995,-6.885654],[107.602418,-6.912606]]'::JSONB,
    NOW()
),
(
    'TRIP-KA68-TKS', 'SCH-003', 'KA 68', 'KA Taksaka', 'Eksekutif / Luxury', 'Jawa Tengah & DIY',
    'GMR', 'YK', CURRENT_DATE,
    (CURRENT_DATE + TIME '09:20:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '15:35:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '15:35:00') AT TIME ZONE 'Asia/Jakarta',
    'DEMO', 'Simulasi Perjalanan (Mode Demo)', TRUE, 'Simulasi Demo TKA (Bukan Real-Time)',
    0, NULL, -7.4950, 109.2420, 130.0, 98.0,
    'PWT', 'KTA',
    '[[106.830583,-6.176655],[108.555377,-6.705469],[109.222111,-7.419283],[109.253528,-7.630519],[109.907342,-7.725925],[110.363506,-7.789217]]'::JSONB,
    NOW()
),
(
    'TRIP-KA56-GJY', 'SCH-004', 'KA 56', 'KA Gajayana', 'Eksekutif / Luxury', 'Jawa Timur',
    'GMR', 'ML', CURRENT_DATE,
    (CURRENT_DATE + TIME '18:50:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '07:10:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '07:10:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta',
    'SCHEDULED', 'Terjadwal Berangkat dari Stasiun Gambir', FALSE, 'Jadwal Resmi Operasional',
    0, NULL, -6.176655, 106.830583, 110.0, NULL,
    'GMR', 'CN',
    '[[106.830583,-6.176655],[108.555377,-6.705469],[109.222111,-7.419283],[110.363506,-7.789217],[110.821361,-7.557042],[111.524064,-7.619236],[112.015528,-7.817411],[112.637011,-7.977286]]'::JSONB,
    NOW()
),
(
    'TRIP-KA62-SWK', 'SCH-005', 'KA 62', 'KA Sancaka', 'Eksekutif / Ekonomi', 'Jawa Tengah & DIY',
    'YK', 'SGU', CURRENT_DATE,
    (CURRENT_DATE + TIME '11:30:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '15:30:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '15:30:00') AT TIME ZONE 'Asia/Jakarta',
    'DEMO', 'Simulasi Perjalanan (Mode Demo)', TRUE, 'Simulasi Demo TKA (Bukan Real-Time)',
    0, NULL, -7.5880, 111.1700, 88.0, 105.0,
    'SLO', 'MN',
    '[[110.363506,-7.789217],[110.821361,-7.557042],[111.524064,-7.619236],[112.752056,-7.265464]]'::JSONB,
    NOW()
),
(
    'TRIP-KRL1024', 'SCH-006', 'KRL 1024', 'Commuter Line Bogor', 'Komuter', 'Jabodetabek',
    'JAKK', 'BOO', CURRENT_DATE,
    (CURRENT_DATE + TIME '10:00:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '11:25:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '11:25:00') AT TIME ZONE 'Asia/Jakarta',
    'DEMO', 'Simulasi Perjalanan (Mode Demo)', TRUE, 'Simulasi Demo TKA (Bukan Real-Time)',
    0, NULL, -6.3420, 106.8320, 185.0, 58.0,
    'MRI', 'BOO',
    '[[106.814658,-6.137563],[106.830583,-6.176655],[106.850262,-6.209911],[106.790531,-6.595716]]'::JSONB,
    NOW()
),
(
    'TRIP-KA-ARS12', 'SCH-007', 'KA U12', 'KA Bandara Kualanamu (Srilelawangsa)', 'KA Bandara', 'Sumatera',
    'MDN', 'KNM', CURRENT_DATE,
    (CURRENT_DATE + TIME '10:15:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '10:50:00') AT TIME ZONE 'Asia/Jakarta',
    NULL,
    'UNAVAILABLE', 'Data Posisi Telemetri Tidak Tersedia', FALSE, 'Telemetri Offline',
    0, 'Perangkat pelacak GPS sedang tidak mengirimkan sinyal', NULL, NULL, NULL, NULL,
    'MDN', 'KNM',
    '[[98.678478,3.591278],[98.876319,3.638011]]'::JSONB,
    NOW()
),
(
    'TRIP-KA-SRJ1', 'SCH-008', 'KA S1', 'KA Sriwijaya', 'Eksekutif / Bisnis', 'Sumatera',
    'KPT', 'TNK', CURRENT_DATE,
    (CURRENT_DATE + TIME '21:00:00') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '05:30:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta',
    (CURRENT_DATE + TIME '05:30:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta',
    'SCHEDULED', 'Terjadwal Berangkat dari Stasiun Kertapati', FALSE, 'Jadwal Resmi Operasional',
    0, NULL, -3.025219, 104.741856, 165.0, NULL,
    'KPT', 'TNK',
    '[[104.741856,-3.025219],[105.259781,-5.408503]]'::JSONB,
    NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Seed Daftar Stasiun Pemberhentian (train_trip_stops)
INSERT INTO public.train_trip_stops (trip_id, station_code, stop_sequence, scheduled_arrival, scheduled_departure, estimated_arrival, platform, stop_status) VALUES
-- KA 2 Argo Bromo Anggrek (GMR -> SBI)
('TRIP-KA2-ABA', 'GMR', 1, NULL, (CURRENT_DATE + TIME '08:20:00') AT TIME ZONE 'Asia/Jakarta', NULL, 'Peron 2', 'PASSED'),
('TRIP-KA2-ABA', 'CN',  2, (CURRENT_DATE + TIME '10:55:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '11:01:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '10:55:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 1', 'PASSED'),
('TRIP-KA2-ABA', 'PK',  3, (CURRENT_DATE + TIME '12:25:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:29:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:25:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 2', 'UPCOMING'),
('TRIP-KA2-ABA', 'SMT', 4, (CURRENT_DATE + TIME '13:35:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '13:42:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '13:35:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 3', 'UPCOMING'),
('TRIP-KA2-ABA', 'SBI', 5, (CURRENT_DATE + TIME '16:25:00') AT TIME ZONE 'Asia/Jakarta', NULL, (CURRENT_DATE + TIME '16:25:00') AT TIME ZONE 'Asia/Jakarta', 'Peron 1', 'UPCOMING'),

-- KA 40 Argo Parahyangan (GMR -> BD, Delayed +18m)
('TRIP-KA40-AP', 'GMR', 1, NULL, (CURRENT_DATE + TIME '09:30:00') AT TIME ZONE 'Asia/Jakarta', NULL, 'Peron 3', 'PASSED'),
('TRIP-KA40-AP', 'BKS', 2, (CURRENT_DATE + TIME '09:58:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '10:00:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '10:05:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 4', 'PASSED'),
('TRIP-KA40-AP', 'PWK', 3, (CURRENT_DATE + TIME '11:10:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '11:14:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '11:28:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 2', 'PASSED'),
('TRIP-KA40-AP', 'CMI', 4, (CURRENT_DATE + TIME '12:30:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:32:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:48:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 1', 'UPCOMING'),
('TRIP-KA40-AP', 'BD',  5, (CURRENT_DATE + TIME '12:45:00') AT TIME ZONE 'Asia/Jakarta', NULL, (CURRENT_DATE + TIME '13:03:00') AT TIME ZONE 'Asia/Jakarta', 'Peron 2', 'UPCOMING'),

-- KA 68 Taksaka (GMR -> YK)
('TRIP-KA68-TKS', 'GMR', 1, NULL, (CURRENT_DATE + TIME '09:20:00') AT TIME ZONE 'Asia/Jakarta', NULL, 'Peron 1', 'PASSED'),
('TRIP-KA68-TKS', 'CN',  2, (CURRENT_DATE + TIME '12:00:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:05:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:00:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 2', 'PASSED'),
('TRIP-KA68-TKS', 'PWT', 3, (CURRENT_DATE + TIME '13:52:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '13:58:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '13:52:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 3', 'PASSED'),
('TRIP-KA68-TKS', 'KTA', 4, (CURRENT_DATE + TIME '14:50:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '14:53:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '14:50:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 1', 'UPCOMING'),
('TRIP-KA68-TKS', 'YK',  5, (CURRENT_DATE + TIME '15:35:00') AT TIME ZONE 'Asia/Jakarta', NULL, (CURRENT_DATE + TIME '15:35:00') AT TIME ZONE 'Asia/Jakarta', 'Peron 4', 'UPCOMING'),

-- KA 62 Sancaka (YK -> SGU)
('TRIP-KA62-SWK', 'YK',  1, NULL, (CURRENT_DATE + TIME '11:30:00') AT TIME ZONE 'Asia/Jakarta', NULL, 'Peron 3', 'PASSED'),
('TRIP-KA62-SWK', 'SLO', 2, (CURRENT_DATE + TIME '12:18:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:22:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '12:18:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 2', 'PASSED'),
('TRIP-KA62-SWK', 'MN',  3, (CURRENT_DATE + TIME '13:35:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '13:40:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '13:35:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 1', 'UPCOMING'),
('TRIP-KA62-SWK', 'SGU', 4, (CURRENT_DATE + TIME '15:30:00') AT TIME ZONE 'Asia/Jakarta', NULL, (CURRENT_DATE + TIME '15:30:00') AT TIME ZONE 'Asia/Jakarta', 'Peron 5', 'UPCOMING'),

-- KA 56 Gajayana (GMR -> ML)
('TRIP-KA56-GJY', 'GMR', 1, NULL, (CURRENT_DATE + TIME '18:50:00') AT TIME ZONE 'Asia/Jakarta', NULL, 'Peron 2', 'UPCOMING'),
('TRIP-KA56-GJY', 'CN',  2, (CURRENT_DATE + TIME '21:35:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '21:41:00') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '21:35:00') AT TIME ZONE 'Asia/Jakarta', 'Jalur 1', 'UPCOMING'),
('TRIP-KA56-GJY', 'YK',  3, (CURRENT_DATE + TIME '01:55:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '02:02:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', NULL, 'Jalur 4', 'UPCOMING'),
('TRIP-KA56-GJY', 'SLO', 4, (CURRENT_DATE + TIME '02:50:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '02:55:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', NULL, 'Jalur 2', 'UPCOMING'),
('TRIP-KA56-GJY', 'MN',  5, (CURRENT_DATE + TIME '04:08:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '04:13:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', NULL, 'Jalur 1', 'UPCOMING'),
('TRIP-KA56-GJY', 'KD',  6, (CURRENT_DATE + TIME '05:22:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', (CURRENT_DATE + TIME '05:26:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', NULL, 'Jalur 1', 'UPCOMING'),
('TRIP-KA56-GJY', 'ML',  7, (CURRENT_DATE + TIME '07:10:00' + INTERVAL '1 day') AT TIME ZONE 'Asia/Jakarta', NULL, NULL, 'Peron 1', 'UPCOMING')
ON CONFLICT (trip_id, stop_sequence) DO NOTHING;

-- ============================================================================
-- 8. ROW LEVEL SECURITY (RLS) & REALTIME PUBLICATION
-- ============================================================================
ALTER TABLE public.train_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.train_trip_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.train_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public all stations" ON public.stations;
CREATE POLICY "Allow public all stations" ON public.stations FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public all train_trips" ON public.train_trips;
CREATE POLICY "Allow public all train_trips" ON public.train_trips FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public all train_trip_stops" ON public.train_trip_stops;
CREATE POLICY "Allow public all train_trip_stops" ON public.train_trip_stops FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public all user_favorites" ON public.user_favorites;
CREATE POLICY "Allow public all user_favorites" ON public.user_favorites FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public all user_notification_preferences" ON public.user_notification_preferences;
CREATE POLICY "Allow public all user_notification_preferences" ON public.user_notification_preferences FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public all train_notifications" ON public.train_notifications;
CREATE POLICY "Allow public all train_notifications" ON public.train_notifications FOR ALL TO public USING (true) WITH CHECK (true);

-- Aktifkan Supabase Realtime agar perubahan posisi & notifikasi masuk secara instan
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.train_trips;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.train_trip_stops;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.train_notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- CONTOH UPDATE TELEMETRI GPS NYATA (STATUS 'LIVE', is_simulated = FALSE):
-- Jalankan ini hanya jika Anda menerima koordinat GPS real-time asli dari perangkat:
--
-- UPDATE public.train_trips
-- SET data_status = 'LIVE',
--     is_simulated = FALSE,
--     data_source_label = 'GPS Telemetry Live Feed',
--     trip_status = 'Dalam Perjalanan (Real-Time)',
--     current_lat = -6.9120,
--     current_lng = 109.9500,
--     speed_kmh = 115.0,
--     last_updated_at = NOW()
-- WHERE id = 'TRIP-KA2-ABA';
-- ============================================================================

