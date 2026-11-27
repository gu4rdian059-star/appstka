-- ============================================================================
-- MIGRASI PENYATUAN: PROFILES DIJADIKAN SATU KE TABEL USERS
-- Proyek: TKA Kereta Api (Supabase: https://lbjpvbwmctzuhkqdidpt.supabase.co)
-- Cara Eksekusi: Buka Supabase Dashboard -> SQL Editor -> Tempel & Jalankan (Run)
-- ============================================================================

-- 1. Pastikan tabel public.users memiliki seluruh kolom data pengguna yang lengkap
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(150) UNIQUE,
    full_name VARCHAR(150),
    phone VARCHAR(50),
    role VARCHAR(50) DEFAULT 'passenger',
    password VARCHAR(255) DEFAULT '',
    balance BIGINT DEFAULT 0,
    avatar_url TEXT,
    nik VARCHAR(30),
    gender VARCHAR(20),
    document_type VARCHAR(50),
    birth_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tambahkan kolom opsional profil ke tabel users jika belum ada
ALTER TABLE public.users 
    ADD COLUMN IF NOT EXISTS balance BIGINT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS nik VARCHAR(30),
    ADD COLUMN IF NOT EXISTS gender VARCHAR(20),
    ADD COLUMN IF NOT EXISTS document_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS birth_date DATE,
    ADD COLUMN IF NOT EXISTS password VARCHAR(255) DEFAULT '',
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- HAPUS NOT-NULL CONSTRAINT PADA SEMUA KOLOM (KECUALI id) AGAR MIGRASI & AUTH TIDAK GAGAL (ERROR 23502)
DO $$
DECLARE
    col_rec RECORD;
BEGIN
    FOR col_rec IN (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'users' 
          AND column_name != 'id'
          AND is_nullable = 'NO'
    ) LOOP
        EXECUTE format('ALTER TABLE public.users ALTER COLUMN %I DROP NOT NULL', col_rec.column_name);
    END LOOP;
END $$;

ALTER TABLE public.users ALTER COLUMN password SET DEFAULT '';

-- 2. Migrasikan seluruh data dari profiles yang ada ke tabel users
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'profiles'
        AND table_type = 'BASE TABLE'
    ) THEN
        INSERT INTO public.users (
            id, 
            email, 
            full_name, 
            phone, 
            role, 
            created_at, 
            balance,
            updated_at,
            password
        )
        SELECT 
            id::uuid, 
            email, 
            full_name, 
            phone, 
            COALESCE(role, 'passenger'), 
            COALESCE(created_at, NOW()), 
            COALESCE(balance, 0),
            NOW(),
            ''
        FROM public.profiles
        WHERE id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
            phone = COALESCE(EXCLUDED.phone, public.users.phone),
            balance = GREATEST(COALESCE(public.users.balance, 0), COALESCE(EXCLUDED.balance, 0)),
            updated_at = NOW();
    END IF;
END $$;

-- 3. Sinkronkan semua akun dari auth.users yang belum masuk ke public.users
INSERT INTO public.users (id, email, full_name, phone, role, created_at, updated_at, balance, password)
SELECT
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name', split_part(au.email, '@', 1)),
    COALESCE(au.raw_user_meta_data->>'phone', au.phone, ''),
    COALESCE(au.raw_user_meta_data->>'role', 'passenger'),
    COALESCE(au.created_at, NOW()),
    NOW(),
    0,
    ''
FROM auth.users au
WHERE au.email IS NOT NULL
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(public.users.full_name, EXCLUDED.full_name),
    phone = CASE WHEN public.users.phone IS NULL OR public.users.phone = '' THEN EXCLUDED.phone ELSE public.users.phone END,
    updated_at = NOW();

-- 4. Lepas Foreign Key yang merujuk profiles lalu DROP TABLE profiles
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tc.table_name, tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu
          ON ccu.constraint_name = tc.constraint_name
         AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
          AND ccu.table_name = 'profiles'
    ) LOOP
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', r.table_name, r.constraint_name);
    END LOOP;
END $$;

DROP TABLE IF EXISTS public.profiles CASCADE;

-- 5. Trigger Otomatis: Setiap Register di auth.users otomatis masuk ke public.users
CREATE OR REPLACE FUNCTION public.handle_auth_user_to_public_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name, phone, role, balance, password, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone, ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'passenger'),
        0,
        '',
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
        phone = CASE WHEN EXCLUDED.phone <> '' THEN EXCLUDED.phone ELSE public.users.phone END,
        updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_sync_users ON auth.users;
CREATE TRIGGER on_auth_user_created_sync_users
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_auth_user_to_public_users();

-- 6. RLS & Grant
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own or public profile" ON public.users;
DROP POLICY IF EXISTS "Users insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users update own profile" ON public.users;
DROP POLICY IF EXISTS "Allow public all users" ON public.users;
DROP POLICY IF EXISTS "Users select policy" ON public.users;
DROP POLICY IF EXISTS "Users insert own row" ON public.users;
DROP POLICY IF EXISTS "Users update own row" ON public.users;

CREATE POLICY "Users select policy" ON public.users
    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Users insert own row" ON public.users
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Users update own row" ON public.users
    FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Anon insert users during signup" ON public.users
    FOR INSERT TO anon WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE ON TABLE public.users TO anon, authenticated;

-- Perbaiki tabel cancellations untuk pembatalan tiket
ALTER TABLE public.cancellations
    ADD COLUMN IF NOT EXISTS refund_amount BIGINT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS status VARCHAR(40) DEFAULT 'Dibatalkan',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

NOTIFY pgrst, 'reload schema';
