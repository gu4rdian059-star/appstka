-- ========================================================
-- SKEMA DATABASE TKA (TIKET KERETA API) UNTUK SUPABASE
-- Buka Dashboard Supabase -> Masuk menu "SQL Editor" -> Tempel & Jalankan (Run)
-- ========================================================

-- 1. Tabel Stasiun Kereta
CREATE TABLE IF NOT EXISTS stations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(10) NOT NULL UNIQUE,       -- Contoh: GMR, BD, SGU
    name VARCHAR(100) NOT NULL,             -- Contoh: Gambir, Bandung
    city VARCHAR(100) NOT NULL,             -- Contoh: Jakarta, Bandung
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Tabel Kereta Api
CREATE TABLE IF NOT EXISTS trains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    train_name VARCHAR(100) NOT NULL,       -- Contoh: Argo Parahyangan, Taksaka
    train_number VARCHAR(20) NOT NULL,      -- Contoh: KA 24, KA 40
    train_class VARCHAR(50) NOT NULL,       -- Contoh: Eksekutif, Bisnis, Ekonomi
    total_seats INT DEFAULT 400 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Tabel Jadwal & Rute Perjalanan
CREATE TABLE IF NOT EXISTS schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    train_id UUID REFERENCES trains(id) ON DELETE CASCADE,
    origin_station_id UUID REFERENCES stations(id) ON DELETE CASCADE,
    destination_station_id UUID REFERENCES stations(id) ON DELETE CASCADE,
    departure_time TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_time TIMESTAMP WITH TIME ZONE NOT NULL,
    price DECIMAL(12, 2) NOT NULL,          -- Contoh: 150000
    available_seats INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Tabel Pemesanan & E-Tiket
CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_code VARCHAR(20) NOT NULL UNIQUE, -- Contoh: TKA-20261115-001
    user_id UUID,                             -- Terhubung ke Supabase Auth Users jika login
    schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
    passenger_name VARCHAR(150) NOT NULL,
    passenger_id_number VARCHAR(50) NOT NULL, -- NIK / KTP / Paspor
    seat_number VARCHAR(10) NOT NULL,         -- Contoh: 7A, 7B
    qr_code_data TEXT NOT NULL,
    status VARCHAR(30) DEFAULT 'ACTIVE',      -- ACTIVE, CANCELLED, COMPLETED
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Data Contoh Awal (Seed Data)
INSERT INTO stations (code, name, city) VALUES
    ('GMR', 'Gambir', 'Jakarta'),
    ('BD', 'Bandung', 'Bandung'),
    ('YK', 'Yogyakarta', 'Yogyakarta'),
    ('SGU', 'Surabaya Gubeng', 'Surabaya')
ON CONFLICT (code) DO NOTHING;

INSERT INTO trains (train_name, train_number, train_class, total_seats) VALUES
    ('Argo Parahyangan', 'KA 40', 'Eksekutif', 350),
    ('Parahyangan', 'KA 42', 'Ekonomi', 420)
ON CONFLICT DO NOTHING;

