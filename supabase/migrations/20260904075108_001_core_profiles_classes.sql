/*
# Core Schema: Profiles, Classes, Sections, Subjects, School Settings

1. Purpose
   Establishes the foundational tables for Golden Kids School:
   - `profiles` — user accounts linked to Supabase Auth, with role-based access (founder, teacher, parent)
   - `classes` — school classes/grades (e.g., Grade 6A)
   - `sections` — sections within classes (e.g., A, B)
   - `subjects` — academic subjects (e.g., Mathematics, English)
   - `school_settings` — configurable school information (name, logo, colors, contact, timings)

2. New Tables
   - `profiles`: id (uuid PK, FK auth.users), full_name, email, phone, role, status, avatar_url, created_at, updated_at
   - `classes`: id (uuid PK), name, grade_level, description, created_at
   - `sections`: id (uuid PK), class_id (FK classes), name, created_at
   - `subjects`: id (uuid PK), name, code, description, created_at
   - `school_settings`: singleton (id=1) with school_name, logo_url, address, phone, email, website, timings, academic_year, primary_color, accent_color, tagline, hero_title, hero_subtitle

3. Security
   - RLS enabled on all tables.
   - `profiles`: users can read/update their own profile; founders can read all profiles; founders can update any profile.
   - `classes`, `sections`, `subjects`: readable by all authenticated users; writable by founders only.
   - `school_settings`: readable by all (including anon for public site); writable by founders only.
   - Helper functions: is_founder(), is_teacher(), is_parent(), current_user_role()

4. Notes
   - Role stored in `profiles.role` with CHECK constraint: 'founder', 'teacher', 'parent'.
   - Status stored as text with CHECK constraint: 'active', 'inactive', 'suspended'.
   - `school_settings` is a singleton row (id = 1).
*/

-- =============================================================
-- PROFILES TABLE (must exist before helper functions)
-- =============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  email text NOT NULL,
  phone text,
  role text NOT NULL DEFAULT 'parent' CHECK (role IN ('founder', 'teacher', 'parent')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- =============================================================
-- HELPER FUNCTIONS (after profiles table exists)
-- =============================================================
CREATE OR REPLACE FUNCTION public.is_founder()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'founder' AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'teacher' AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_parent()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'parent' AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- =============================================================
-- PROFILE POLICIES
-- =============================================================
DROP POLICY IF EXISTS "profiles_select_own_or_founder" ON public.profiles;
CREATE POLICY "profiles_select_own_or_founder" ON public.profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id OR public.is_founder());

DROP POLICY IF EXISTS "profiles_update_own_or_founder" ON public.profiles;
CREATE POLICY "profiles_update_own_or_founder" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id OR public.is_founder())
  WITH CHECK (auth.uid() = id OR public.is_founder());

DROP POLICY IF EXISTS "profiles_insert_founder_only" ON public.profiles;
CREATE POLICY "profiles_insert_founder_only" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS "profiles_delete_founder_only" ON public.profiles;
CREATE POLICY "profiles_delete_founder_only" ON public.profiles
  FOR DELETE TO authenticated
  USING (public.is_founder());

-- =============================================================
-- CLASSES TABLE
-- =============================================================
CREATE TABLE IF NOT EXISTS public.classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  grade_level int NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "classes_select_all" ON public.classes;
CREATE POLICY "classes_select_all" ON public.classes
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "classes_insert_founder" ON public.classes;
CREATE POLICY "classes_insert_founder" ON public.classes
  FOR INSERT TO authenticated
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS "classes_update_founder" ON public.classes;
CREATE POLICY "classes_update_founder" ON public.classes
  FOR UPDATE TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS "classes_delete_founder" ON public.classes;
CREATE POLICY "classes_delete_founder" ON public.classes
  FOR DELETE TO authenticated
  USING (public.is_founder());

-- =============================================================
-- SECTIONS TABLE
-- =============================================================
CREATE TABLE IF NOT EXISTS public.sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sections_select_all" ON public.sections;
CREATE POLICY "sections_select_all" ON public.sections
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "sections_insert_founder" ON public.sections;
CREATE POLICY "sections_insert_founder" ON public.sections
  FOR INSERT TO authenticated
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS "sections_update_founder" ON public.sections;
CREATE POLICY "sections_update_founder" ON public.sections
  FOR UPDATE TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS "sections_delete_founder" ON public.sections;
CREATE POLICY "sections_delete_founder" ON public.sections
  FOR DELETE TO authenticated
  USING (public.is_founder());

-- =============================================================
-- SUBJECTS TABLE
-- =============================================================
CREATE TABLE IF NOT EXISTS public.subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subjects_select_all" ON public.subjects;
CREATE POLICY "subjects_select_all" ON public.subjects
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "subjects_insert_founder" ON public.subjects;
CREATE POLICY "subjects_insert_founder" ON public.subjects
  FOR INSERT TO authenticated
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS "subjects_update_founder" ON public.subjects;
CREATE POLICY "subjects_update_founder" ON public.subjects
  FOR UPDATE TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS "subjects_delete_founder" ON public.subjects;
CREATE POLICY "subjects_delete_founder" ON public.subjects
  FOR DELETE TO authenticated
  USING (public.is_founder());

-- =============================================================
-- SCHOOL SETTINGS TABLE (singleton)
-- =============================================================
CREATE TABLE IF NOT EXISTS public.school_settings (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  school_name text NOT NULL DEFAULT 'Golden Kids School',
  logo_url text,
  address text,
  phone text,
  email text,
  website text,
  timings text,
  academic_year text NOT NULL DEFAULT '2026-27',
  primary_color text DEFAULT '#1e3a5f',
  accent_color text DEFAULT '#f59e0b',
  tagline text DEFAULT 'Discover. Learn. Grow.',
  hero_title text DEFAULT 'Where Curiosity Meets Excellence',
  hero_subtitle text DEFAULT 'Empowering young minds through knowledge, creativity, character and discovery.',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.school_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "settings_select_all" ON public.school_settings;
CREATE POLICY "settings_select_all" ON public.school_settings
  FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "settings_update_founder" ON public.school_settings;
CREATE POLICY "settings_update_founder" ON public.school_settings
  FOR UPDATE TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

INSERT INTO public.school_settings (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- =============================================================
-- UPDATED_AT TRIGGER
-- =============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS school_settings_updated_at ON public.school_settings;
CREATE TRIGGER school_settings_updated_at
  BEFORE UPDATE ON public.school_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
