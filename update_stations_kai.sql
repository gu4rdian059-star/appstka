-- ============================================================================
-- SINKRONISASI LENGKAP 80 STASIUN KAI & JADWAL KERETA API DI SUPABASE
-- Silakan jalankan (Run) script ini di Supabase SQL Editor:
-- Dashboard Supabase -> Project Anda (lbjpvbwmctzuhkqdidpt) -> SQL Editor -> New Query -> Tempel & Run
-- ============================================================================

-- 1. Buka Hak Akses RLS untuk Stations agar Aplikasi Flutter & Dashboard dapat Menyimpan/Mengupdate Stasiun
ALTER TABLE IF EXISTS public.stations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read stations" ON public.stations;
DROP POLICY IF EXISTS "Allow public all stations" ON public.stations;
CREATE POLICY "Allow public all stations" ON public.stations FOR ALL TO public USING (true) WITH CHECK (true);

-- 2. Input / Update 80 Stasiun Resmi KAI Se-Indonesia (Jawa & Sumatera)
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
('PDL', 'Padalarang', 'Bandung Barat', 'Jawa Barat'),
('CN', 'Cirebon', 'Cirebon', 'Jawa Barat'),
('CNP', 'Cirebon Prujakan', 'Cirebon', 'Jawa Barat'),
('JTB', 'Jatibarang', 'Indramayu', 'Jawa Barat'),
('HGL', 'Haurgeulis', 'Indramayu', 'Jawa Barat'),
('CKR', 'Cikarang', 'Bekasi', 'Jawa Barat'),
('KW', 'Karawang', 'Karawang', 'Jawa Barat'),
('PWK', 'Purwakarta', 'Purwakarta', 'Jawa Barat'),
('TSM', 'Tasikmalaya', 'Tasikmalaya', 'Jawa Barat'),
('CI', 'Ciamis', 'Ciamis', 'Jawa Barat'),
('BJR', 'Banjar', 'Banjar', 'Jawa Barat'),
('RK', 'Rangkasbitung', 'Lebak', 'Banten'),
('SG', 'Serang', 'Serang', 'Banten'),
('MER', 'Merak', 'Cilegon', 'Banten'),
('YK', 'Yogyakarta', 'Yogyakarta', 'Jawa Tengah & DIY'),
('LPN', 'Lempuyangan', 'Yogyakarta', 'Jawa Tengah & DIY'),
('WT', 'Wates', 'Kulon Progo', 'Jawa Tengah & DIY'),
('SLO', 'Solo Balapan', 'Surakarta', 'Jawa Tengah & DIY'),
('PWS', 'Purwosari', 'Surakarta', 'Jawa Tengah & DIY'),
('SK', 'Solo Jebres', 'Surakarta', 'Jawa Tengah & DIY'),
('KT', 'Klaten', 'Klaten', 'Jawa Tengah & DIY'),
('SMT', 'Semarang Tawang', 'Semarang', 'Jawa Tengah & DIY'),
('SMC', 'Semarang Poncol', 'Semarang', 'Jawa Tengah & DIY'),
('WLR', 'Weleri', 'Kendal', 'Jawa Tengah & DIY'),
('PK', 'Pekalongan', 'Pekalongan', 'Jawa Tengah & DIY'),
('PML', 'Pemalang', 'Pemalang', 'Jawa Tengah & DIY'),
('TG', 'Tegal', 'Tegal', 'Jawa Tengah & DIY'),
('BB', 'Brebes', 'Brebes', 'Jawa Tengah & DIY'),
('PWT', 'Purwokerto', 'Banyumas', 'Jawa Tengah & DIY'),
('KYA', 'Kroya', 'Cilacap', 'Jawa Tengah & DIY'),
('CP', 'Cilacap', 'Cilacap', 'Jawa Tengah & DIY'),
('GB', 'Gombong', 'Kebumen', 'Jawa Tengah & DIY'),
('KM', 'Kebumen', 'Kebumen', 'Jawa Tengah & DIY'),
('KTA', 'Kutoarjo', 'Purworejo', 'Jawa Tengah & DIY'),
('CU', 'Cepu', 'Blora', 'Jawa Tengah & DIY'),
('SBI', 'Surabaya Pasarturi', 'Surabaya', 'Jawa Timur'),
('SGU', 'Surabaya Gubeng', 'Surabaya', 'Jawa Timur'),
('WO', 'Wonokromo', 'Surabaya', 'Jawa Timur'),
('SDA', 'Sidoarjo', 'Sidoarjo', 'Jawa Timur'),
('BG', 'Bangil', 'Pasuruan', 'Jawa Timur'),
('PS', 'Pasuruan', 'Pasuruan', 'Jawa Timur'),
('PB', 'Probolinggo', 'Probolinggo', 'Jawa Timur'),
('KK', 'Klakah', 'Lumajang', 'Jawa Timur'),
('TGL', 'Tanggul', 'Jember', 'Jawa Timur'),
('JR', 'Jember', 'Jember', 'Jawa Timur'),
('KBR', 'Kalibaru', 'Banyuwangi', 'Jawa Timur'),
('RGP', 'Rogojampi', 'Banyuwangi', 'Jawa Timur'),
('BWI', 'Banyuwangi Kota', 'Banyuwangi', 'Jawa Timur'),
('KTG', 'Ketapang', 'Banyuwangi', 'Jawa Timur'),
('ML', 'Malang', 'Malang', 'Jawa Timur'),
('MLK', 'Malang Kota Lama', 'Malang', 'Jawa Timur'),
('LW', 'Lawang', 'Malang', 'Jawa Timur'),
('KPN', 'Kepanjen', 'Malang', 'Jawa Timur'),
('MR', 'Mojokerto', 'Mojokerto', 'Jawa Timur'),
('JG', 'Jombang', 'Jombang', 'Jawa Timur'),
('KTS', 'Kertosono', 'Nganjuk', 'Jawa Timur'),
('NJ', 'Nganjuk', 'Nganjuk', 'Jawa Timur'),
('MN', 'Madiun', 'Madiun', 'Jawa Timur'),
('CRB', 'Caruban', 'Madiun', 'Jawa Timur'),
('KD', 'Kediri', 'Kediri', 'Jawa Timur'),
('TA', 'Tulungagung', 'Tulungagung', 'Jawa Timur'),
('BL', 'Blitar', 'Blitar', 'Jawa Timur'),
('LMG', 'Lamongan', 'Lamongan', 'Jawa Timur'),
('BBT', 'Babat', 'Lamongan', 'Jawa Timur'),
('BJN', 'Bojonegoro', 'Bojonegoro', 'Jawa Timur'),
('MDN', 'Medan', 'Medan', 'Sumatera'),
('KNM', 'Kualanamu', 'Deli Serdang', 'Sumatera'),
('TNK', 'Tanjung Karang', 'Bandar Lampung', 'Sumatera'),
('KPT', 'Kertapati', 'Palembang', 'Sumatera'),
('PD', 'Padang', 'Padang', 'Sumatera')
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  city = EXCLUDED.city,
  region = EXCLUDED.region;

-- 3. Input / Update Jadwal Kereta Api (Termasuk Mutiara Timur, Sri Tanjung, Logawa, Malang Express, Penataran, Probowangi)
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
('SCH-010', 'KA 112', 'KA Sancaka', 'KA Sancaka', 'Ekonomi', 'Yogyakarta (YK)', 'Surabaya Gubeng (SGU)', 'YK', 'Yogyakarta', 'Yogyakarta', 'SGU', 'Surabaya Gubeng', 'Surabaya', '06:50 WIB', '10:55 WIB', '4j 05m', 210000, 210000, ARRAY['Ekonomi', 'Eksekutif'], 90),
('SCH-011', '209A', 'MUTIARA TIMUR (209A)', 'MUTIARA TIMUR (209A)', 'Ekonomi', 'Surabaya Gubeng (SGU)', 'Pasuruan (PS)', 'SGU', 'Surabaya Gubeng', 'Surabaya', 'PS', 'Pasuruan', 'Pasuruan', '09.24 WIB', '10.43 WIB', '01j 19m', 150000, 150000, ARRAY['Ekonomi', 'Eksekutif'], 37),
('SCH-012', '278', 'SRI TANJUNG (278)', 'SRI TANJUNG (278)', 'Ekonomi', 'Surabaya Gubeng (SGU)', 'Pasuruan (PS)', 'SGU', 'Surabaya Gubeng', 'Surabaya', 'PS', 'Pasuruan', 'Pasuruan', '13.34 WIB', '14.52 WIB', '01j 18m', 88000, 88000, ARRAY['Ekonomi'], 9),
('SCH-013', '248C', 'LOGAWA (248C)', 'LOGAWA (248C)', 'Ekonomi', 'Surabaya Gubeng (SGU)', 'Pasuruan (PS)', 'SGU', 'Surabaya Gubeng', 'Surabaya', 'PS', 'Pasuruan', 'Pasuruan', '14.45 WIB', '16.18 WIB', '01j 33m', 100000, 100000, ARRAY['Ekonomi'], 25),
('SCH-014', 'KA Express 1', 'KA Malang Express (KA Express 1)', 'KA Malang Express (KA Express 1)', 'Ekonomi', 'Malang Kota Lama (MLK)', 'Surabaya Gubeng (SGU)', 'MLK', 'Malang Kota Lama', 'Malang', 'SGU', 'Surabaya Gubeng', 'Surabaya', '08:00 WIB', '14:30 WIB', '6j 30m', 224000, 224000, ARRAY['Ekonomi', 'Eksekutif'], 30),
('SCH-015', '371', 'KA Penataran (371)', 'KA Penataran (371)', 'Ekonomi', 'Malang Kota Lama (MLK)', 'Surabaya Gubeng (SGU)', 'MLK', 'Malang Kota Lama', 'Malang', 'SGU', 'Surabaya Gubeng', 'Surabaya', '11:15 WIB', '13:45 WIB', '2j 30m', 18000, 18000, ARRAY['Ekonomi'], 40),
('SCH-016', '266', 'KA Probowangi (266)', 'KA Probowangi (266)', 'Ekonomi', 'Surabaya Gubeng (SGU)', 'Bangil (BG)', 'SGU', 'Surabaya Gubeng', 'Surabaya', 'BG', 'Bangil', 'Pasuruan', '05:30 WIB', '06:40 WIB', '1j 10m', 29000, 29000, ARRAY['Ekonomi'], 20)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  fare = EXCLUDED.fare,
  available_seats = EXCLUDED.available_seats;

