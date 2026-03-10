-- ============================================================
-- LINKMATE — Supabase Database Setup
-- ============================================================
-- Paste this entire script into the Supabase SQL Editor and
-- click "Run". It is fully idempotent — safe to run multiple
-- times on an existing database without errors.
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Tables ──────────────────────────────────────────────────

-- Users (mirrors auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT        NOT NULL UNIQUE,
  full_name   TEXT,
  role        TEXT        NOT NULL DEFAULT 'citizen'
                          CHECK (role IN ('citizen', 'owner', 'admin')),
  phone       TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rooms
CREATE TABLE IF NOT EXISTS public.rooms (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title        TEXT        NOT NULL,
  description  TEXT        NOT NULL DEFAULT '',
  rent_price   NUMERIC     NOT NULL DEFAULT 0 CHECK (rent_price >= 0),
  location     TEXT        NOT NULL DEFAULT '',
  city         TEXT        NOT NULL DEFAULT '',
  room_type    TEXT        NOT NULL DEFAULT 'Single Room',
  amenities    TEXT[]      DEFAULT '{}',
  num_beds     INTEGER     NOT NULL DEFAULT 1,
  is_available BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Room images
CREATE TABLE IF NOT EXISTS public.room_images (
  id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id    UUID        NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  url        TEXT        NOT NULL,
  is_primary BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Favourites
CREATE TABLE IF NOT EXISTS public.favorites (
  id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  room_id    UUID        NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, room_id)
);

-- ── Indexes ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_rooms_owner  ON public.rooms(owner_id);
CREATE INDEX IF NOT EXISTS idx_rooms_city   ON public.rooms(city);
CREATE INDEX IF NOT EXISTS idx_rooms_avail  ON public.rooms(is_available);
CREATE INDEX IF NOT EXISTS idx_room_images  ON public.room_images(room_id);
CREATE INDEX IF NOT EXISTS idx_favs_user    ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favs_room    ON public.favorites(room_id);

-- ── Auto-update trigger ───────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_updated_at ON public.users;
CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS rooms_updated_at ON public.rooms;
CREATE TRIGGER rooms_updated_at
  BEFORE UPDATE ON public.rooms
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Auto-create profile on signup ─────────────────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'citizen')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE public.users       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites   ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies so we can recreate cleanly
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname, tablename FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('users','rooms','room_images','favorites')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- Users policies
CREATE POLICY "users_select" ON public.users
  FOR SELECT USING (true);

CREATE POLICY "users_insert" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Rooms policies
CREATE POLICY "rooms_select" ON public.rooms
  FOR SELECT USING (true);

CREATE POLICY "rooms_insert" ON public.rooms
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "rooms_update" ON public.rooms
  FOR UPDATE USING (
    auth.uid() = owner_id
    OR EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "rooms_delete" ON public.rooms
  FOR DELETE USING (
    auth.uid() = owner_id
    OR EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Room images policies
CREATE POLICY "images_select" ON public.room_images
  FOR SELECT USING (true);

CREATE POLICY "images_insert" ON public.room_images
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.rooms
      WHERE id = room_id AND owner_id = auth.uid()
    )
  );

CREATE POLICY "images_update" ON public.room_images
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.rooms
      WHERE id = room_id AND owner_id = auth.uid()
    )
  );

CREATE POLICY "images_delete" ON public.room_images
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.rooms
      WHERE id = room_id AND owner_id = auth.uid()
    )
  );

-- Favorites policies
CREATE POLICY "favs_select" ON public.favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favs_insert" ON public.favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favs_delete" ON public.favorites
  FOR DELETE USING (auth.uid() = user_id);

-- ── Storage bucket ────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('room-images', 'room-images', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname IN ('storage_select','storage_insert','storage_delete','storage_update')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
  END LOOP;
END $$;

CREATE POLICY "storage_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'room-images');

CREATE POLICY "storage_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'room-images'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "storage_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'room-images'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "storage_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'room-images'
    AND auth.role() = 'authenticated'
  );

-- ============================================================
-- DONE ✓
-- ============================================================
-- To grant yourself admin access after signing up, run:
--
--   UPDATE public.users
--   SET role = 'admin'
--   WHERE email = 'your@email.com';
--
-- ============================================================
