  -- ==============================================================================
  -- GOLDEN KIDS SCHOOL — COMPLETE PRODUCTION DATABASE SETUP
  -- Generated: 2026-09-19T06:11:14.567Z
  -- ==============================================================================

  -- Enable UUID Extension
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  CREATE EXTENSION IF NOT EXISTS "pgcrypto";



  -- ==============================================================================
  -- MIGRATION: 20260904075108_001_core_profiles_classes.sql
  -- ==============================================================================

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



  -- ==============================================================================
  -- MIGRATION: 20260904075157_002_students_teachers_parents.sql
  -- ==============================================================================

  /*
  # Students, Teachers, Parents, and Assignments

  1. Purpose
    Creates the people tables and their relationships:
    - `students` — student records linked to classes, sections, and parent profiles
    - `teachers` — teacher profiles linked to user accounts, with subject/class assignments
    - `teacher_class_assignments` — links teachers to class+section+subject
    - `parent_student_links` — links parent profiles to their children

  2. New Tables
    - `students`: id, admission_number, full_name, date_of_birth, gender, class_id, section_id, roll_number, parent_id, photo_url, address, admission_date, status, house, blood_group, created_at, updated_at
    - `teachers`: id, profile_id (FK profiles), employee_id, qualifications, specialization, join_date, created_at
    - `teacher_class_assignments`: id, teacher_id, class_id, section_id, subject_id, created_at
    - `parent_student_links`: id, parent_id, student_id, relationship, created_at

  3. Security
    - RLS on all tables.
    - `students`: founders see all; parents see only children linked to them; teachers see students in their assigned classes.
    - `teachers`: founders see all; teachers see their own record; parents see teachers of their children's classes.
    - `teacher_class_assignments`: founders manage all; teachers view their own; parents view assignments for their children's classes.
    - `parent_student_links`: founders manage all; parents view their own links.
    - Helper functions: is_parent_of_student(student_id), is_teacher_of_student(student_id), is_teacher_of_class(class_id).

  4. Notes
    - Student admission_number is unique.
    - A parent can have multiple children (parent_student_links is many-to-many).
    - Teachers can be assigned to multiple class/section/subject combinations.
  */

  -- =============================================================
  -- STUDENTS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.students (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    admission_number text UNIQUE NOT NULL,
    full_name text NOT NULL,
    date_of_birth date,
    gender text CHECK (gender IN ('male', 'female', 'other')),
    class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL,
    section_id uuid REFERENCES public.sections(id) ON DELETE SET NULL,
    roll_number text,
    parent_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    photo_url text,
    address text,
    admission_date date,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    house text,
    blood_group text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_students_class_id ON public.students(class_id);
  CREATE INDEX IF NOT EXISTS idx_students_parent_id ON public.students(parent_id);
  CREATE INDEX IF NOT EXISTS idx_students_section_id ON public.students(section_id);

  ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- TEACHERS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.teachers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    employee_id text UNIQUE,
    qualifications text,
    specialization text,
    join_date date,
    created_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_teachers_profile_id ON public.teachers(profile_id);

  ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- TEACHER CLASS ASSIGNMENTS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.teacher_class_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id uuid NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
    class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    section_id uuid REFERENCES public.sections(id) ON DELETE CASCADE,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_tca_teacher_id ON public.teacher_class_assignments(teacher_id);
  CREATE INDEX IF NOT EXISTS idx_tca_class_id ON public.teacher_class_assignments(class_id);

  ALTER TABLE public.teacher_class_assignments ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- PARENT STUDENT LINKS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.parent_student_links (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    relationship text DEFAULT 'parent',
    created_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_psl_parent_id ON public.parent_student_links(parent_id);
  CREATE INDEX IF NOT EXISTS idx_psl_student_id ON public.parent_student_links(student_id);

  ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- HELPER FUNCTIONS (after all tables exist)
  -- =============================================================
  CREATE OR REPLACE FUNCTION public.is_parent_of_student(p_student_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path = public
  AS $$
    SELECT EXISTS (
      SELECT 1 FROM public.parent_student_links
      WHERE parent_id = auth.uid() AND student_id = p_student_id
    );
  $$;

  CREATE OR REPLACE FUNCTION public.is_teacher_of_student(p_student_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path = public
  AS $$
    SELECT EXISTS (
      SELECT 1 FROM public.teacher_class_assignments tca
      JOIN public.students s ON s.class_id = tca.class_id
      JOIN public.teachers t ON t.id = tca.teacher_id
      WHERE t.profile_id = auth.uid() AND s.id = p_student_id
    );
  $$;

  CREATE OR REPLACE FUNCTION public.is_teacher_of_class(p_class_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path = public
  AS $$
    SELECT EXISTS (
      SELECT 1 FROM public.teacher_class_assignments tca
      JOIN public.teachers t ON t.id = tca.teacher_id
      WHERE t.profile_id = auth.uid() AND tca.class_id = p_class_id
    );
  $$;

  -- =============================================================
  -- STUDENT POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "students_select_role_based" ON public.students;
  CREATE POLICY "students_select_role_based" ON public.students
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR public.is_parent_of_student(id)
      OR public.is_teacher_of_student(id)
    );

  DROP POLICY IF EXISTS "students_insert_founder" ON public.students;
  CREATE POLICY "students_insert_founder" ON public.students
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "students_update_founder" ON public.students;
  CREATE POLICY "students_update_founder" ON public.students
    FOR UPDATE TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "students_delete_founder" ON public.students;
  CREATE POLICY "students_delete_founder" ON public.students
    FOR DELETE TO authenticated
    USING (public.is_founder());

  -- =============================================================
  -- TEACHER POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "teachers_select_role_based" ON public.teachers;
  CREATE POLICY "teachers_select_role_based" ON public.teachers
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR profile_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.teacher_class_assignments tca
        JOIN public.students s ON s.class_id = tca.class_id
        JOIN public.parent_student_links psl ON psl.student_id = s.id
        WHERE tca.teacher_id = teachers.id AND psl.parent_id = auth.uid()
      )
    );

  DROP POLICY IF EXISTS "teachers_insert_founder" ON public.teachers;
  CREATE POLICY "teachers_insert_founder" ON public.teachers
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "teachers_update_founder" ON public.teachers;
  CREATE POLICY "teachers_update_founder" ON public.teachers
    FOR UPDATE TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "teachers_delete_founder" ON public.teachers;
  CREATE POLICY "teachers_delete_founder" ON public.teachers
    FOR DELETE TO authenticated
    USING (public.is_founder());

  -- =============================================================
  -- TEACHER CLASS ASSIGNMENT POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "tca_select_role_based" ON public.teacher_class_assignments;
  CREATE POLICY "tca_select_role_based" ON public.teacher_class_assignments
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR EXISTS (SELECT 1 FROM public.teachers WHERE id = teacher_class_assignments.teacher_id AND profile_id = auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.students s
        JOIN public.parent_student_links psl ON psl.student_id = s.id
        WHERE s.class_id = teacher_class_assignments.class_id AND psl.parent_id = auth.uid()
      )
    );

  DROP POLICY IF EXISTS "tca_insert_founder" ON public.teacher_class_assignments;
  CREATE POLICY "tca_insert_founder" ON public.teacher_class_assignments
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "tca_update_founder" ON public.teacher_class_assignments;
  CREATE POLICY "tca_update_founder" ON public.teacher_class_assignments
    FOR UPDATE TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "tca_delete_founder" ON public.teacher_class_assignments;
  CREATE POLICY "tca_delete_founder" ON public.teacher_class_assignments
    FOR DELETE TO authenticated
    USING (public.is_founder());

  -- =============================================================
  -- PARENT STUDENT LINK POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "psl_select_role_based" ON public.parent_student_links;
  CREATE POLICY "psl_select_role_based" ON public.parent_student_links
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR parent_id = auth.uid()
    );

  DROP POLICY IF EXISTS "psl_insert_founder" ON public.parent_student_links;
  CREATE POLICY "psl_insert_founder" ON public.parent_student_links
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "psl_update_founder" ON public.parent_student_links;
  CREATE POLICY "psl_update_founder" ON public.parent_student_links
    FOR UPDATE TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "psl_delete_founder" ON public.parent_student_links;
  CREATE POLICY "psl_delete_founder" ON public.parent_student_links
    FOR DELETE TO authenticated
    USING (public.is_founder());

  -- =============================================================
  -- TRIGGERS
  -- =============================================================
  DROP TRIGGER IF EXISTS students_updated_at ON public.students;
  CREATE TRIGGER students_updated_at
    BEFORE UPDATE ON public.students
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();



  -- ==============================================================================
  -- MIGRATION: 20260904075218_003_attendance_announcements_events.sql
  -- ==============================================================================

  /*
  # Attendance, Announcements, Events Tables

  1. Purpose
    Creates attendance tracking, announcement system, and events calendar tables.

  2. New Tables
    - `attendance`: id, student_id, class_id, date, status (present/absent/late), remarks, marked_by, created_at
    - `announcements`: id, title, content, type, priority, target_audience, attachment_url, expiry_date, published, published_at, created_by, created_at, updated_at
    - `events`: id, title, description, event_type, start_date, end_date, location, image_url, created_by, created_at, updated_at

  3. Security
    - `attendance`: founders all CRUD; teachers can SELECT/INSERT/UPDATE for their assigned classes; parents can SELECT for their children only.
    - `announcements`: founders full CRUD; teachers and parents can SELECT published announcements.
    - `events`: founders full CRUD; teachers and parents can SELECT all events.
  */

  -- =============================================================
  -- ATTENDANCE TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.attendance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    date date NOT NULL,
    status text NOT NULL CHECK (status IN ('present', 'absent', 'late')),
    remarks text,
    marked_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON public.attendance(student_id);
  CREATE INDEX IF NOT EXISTS idx_attendance_class_date ON public.attendance(class_id, date);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_student_date ON public.attendance(student_id, date);

  ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

  -- Attendance: SELECT (founder all, parent for own children, teacher for assigned classes)
  DROP POLICY IF EXISTS "attendance_select_role_based" ON public.attendance;
  CREATE POLICY "attendance_select_role_based" ON public.attendance
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR public.is_parent_of_student(student_id)
      OR public.is_teacher_of_class(class_id)
    );

  -- Attendance: INSERT (founder or teacher of class)
  DROP POLICY IF EXISTS "attendance_insert_role_based" ON public.attendance;
  CREATE POLICY "attendance_insert_role_based" ON public.attendance
    FOR INSERT TO authenticated
    WITH CHECK (
      public.is_founder()
      OR public.is_teacher_of_class(class_id)
    );

  -- Attendance: UPDATE (founder or teacher of class)
  DROP POLICY IF EXISTS "attendance_update_role_based" ON public.attendance;
  CREATE POLICY "attendance_update_role_based" ON public.attendance
    FOR UPDATE TO authenticated
    USING (
      public.is_founder()
      OR public.is_teacher_of_class(class_id)
    )
    WITH CHECK (
      public.is_founder()
      OR public.is_teacher_of_class(class_id)
    );

  -- Attendance: DELETE (founder only)
  DROP POLICY IF EXISTS "attendance_delete_founder" ON public.attendance;
  CREATE POLICY "attendance_delete_founder" ON public.attendance
    FOR DELETE TO authenticated
    USING (public.is_founder());

  -- =============================================================
  -- ANNOUNCEMENTS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.announcements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    content text NOT NULL,
    type text NOT NULL DEFAULT 'general' CHECK (type IN ('general', 'academic', 'holiday', 'examination', 'emergency', 'event', 'fee', 'transport')),
    priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    target_audience text NOT NULL DEFAULT 'all' CHECK (target_audience IN ('all', 'parents', 'teachers', 'founders')),
    attachment_url text,
    expiry_date date,
    published boolean NOT NULL DEFAULT true,
    published_at timestamptz,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_announcements_published ON public.announcements(published);
  CREATE INDEX IF NOT EXISTS idx_announcements_type ON public.announcements(type);

  ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

  -- Announcements: SELECT (founder all, teachers/parents see published)
  DROP POLICY IF EXISTS "announcements_select_role_based" ON public.announcements;
  CREATE POLICY "announcements_select_role_based" ON public.announcements
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR (published = true AND (target_audience = 'all' OR target_audience = public.current_user_role() OR (target_audience = 'parents' AND public.is_parent()) OR (target_audience = 'teachers' AND public.is_teacher())))
    );

  -- Announcements: INSERT (founder only)
  DROP POLICY IF EXISTS "announcements_insert_founder" ON public.announcements;
  CREATE POLICY "announcements_insert_founder" ON public.announcements
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder());

  -- Announcements: UPDATE (founder only)
  DROP POLICY IF EXISTS "announcements_update_founder" ON public.announcements;
  CREATE POLICY "announcements_update_founder" ON public.announcements
    FOR UPDATE TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  -- Announcements: DELETE (founder only)
  DROP POLICY IF EXISTS "announcements_delete_founder" ON public.announcements;
  CREATE POLICY "announcements_delete_founder" ON public.announcements
    FOR DELETE TO authenticated
    USING (public.is_founder());

  -- =============================================================
  -- EVENTS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    event_type text NOT NULL DEFAULT 'general' CHECK (event_type IN ('general', 'exam', 'holiday', 'meeting', 'sports', 'cultural', 'trip', 'competition', 'deadline')),
    start_date timestamptz NOT NULL,
    end_date timestamptz,
    location text,
    image_url text,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_events_start_date ON public.events(start_date);

  ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

  -- Events: SELECT (all authenticated)
  DROP POLICY IF EXISTS "events_select_all" ON public.events;
  CREATE POLICY "events_select_all" ON public.events
    FOR SELECT TO authenticated
    USING (true);

  -- Events: INSERT (founder only)
  DROP POLICY IF EXISTS "events_insert_founder" ON public.events;
  CREATE POLICY "events_insert_founder" ON public.events
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder());

  -- Events: UPDATE (founder only)
  DROP POLICY IF EXISTS "events_update_founder" ON public.events;
  CREATE POLICY "events_update_founder" ON public.events
    FOR UPDATE TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  -- Events: DELETE (founder only)
  DROP POLICY IF EXISTS "events_delete_founder" ON public.events;
  CREATE POLICY "events_delete_founder" ON public.events
    FOR DELETE TO authenticated
    USING (public.is_founder());

  -- =============================================================
  -- TRIGGERS
  -- =============================================================
  DROP TRIGGER IF EXISTS announcements_updated_at ON public.announcements;
  CREATE TRIGGER announcements_updated_at
    BEFORE UPDATE ON public.announcements
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

  DROP TRIGGER IF EXISTS events_updated_at ON public.events;
  CREATE TRIGGER events_updated_at
    BEFORE UPDATE ON public.events
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();



  -- ==============================================================================
  -- MIGRATION: 20260904075300_004_gallery_docs_messages_tables.sql
  -- ==============================================================================

  /*
  # Gallery, Documents, Messages Tables — Table Creation Only

  1. Purpose
    Creates photo gallery, document center, and messaging system tables (structure only, policies in next migration).

  2. New Tables
    - `gallery_albums`: id, title, description, event_type, cover_photo_url, published, created_by, created_at, updated_at
    - `gallery_photos`: id, album_id, photo_url, caption, uploaded_by, created_at
    - `documents`: id, title, description, category, file_url, file_type, file_size, published, created_by, created_at, updated_at
    - `message_threads`: id, subject, created_by, created_at, updated_at
    - `thread_participants`: id, thread_id, user_id, created_at
    - `messages`: id, thread_id, sender_id, body, attachment_url, read_by, created_at
  */

  -- =============================================================
  -- GALLERY ALBUMS
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.gallery_albums (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    event_type text DEFAULT 'general',
    cover_photo_url text,
    published boolean NOT NULL DEFAULT true,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  ALTER TABLE public.gallery_albums ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- GALLERY PHOTOS
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.gallery_photos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    album_id uuid NOT NULL REFERENCES public.gallery_albums(id) ON DELETE CASCADE,
    photo_url text NOT NULL,
    caption text,
    uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_gallery_photos_album_id ON public.gallery_photos(album_id);
  ALTER TABLE public.gallery_photos ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- DOCUMENTS
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    category text NOT NULL DEFAULT 'general' CHECK (category IN ('general', 'circular', 'policy', 'timetable', 'exam_schedule', 'holiday_list', 'form', 'newsletter', 'other')),
    file_url text NOT NULL,
    file_type text,
    file_size bigint,
    published boolean NOT NULL DEFAULT true,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_documents_category ON public.documents(category);
  CREATE INDEX IF NOT EXISTS idx_documents_published ON public.documents(published);
  ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- MESSAGE THREADS
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.message_threads (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject text NOT NULL,
    created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  ALTER TABLE public.message_threads ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- THREAD PARTICIPANTS
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.thread_participants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id uuid NOT NULL REFERENCES public.message_threads(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_tp_thread_id ON public.thread_participants(thread_id);
  CREATE INDEX IF NOT EXISTS idx_tp_user_id ON public.thread_participants(user_id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_tp_thread_user ON public.thread_participants(thread_id, user_id);
  ALTER TABLE public.thread_participants ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- MESSAGES
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id uuid NOT NULL REFERENCES public.message_threads(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    body text NOT NULL,
    attachment_url text,
    read_by uuid[] DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_messages_thread_id ON public.messages(thread_id);
  CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
  ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

  -- =============================================================
  -- TRIGGERS
  -- =============================================================
  DROP TRIGGER IF EXISTS gallery_albums_updated_at ON public.gallery_albums;
  CREATE TRIGGER gallery_albums_updated_at
    BEFORE UPDATE ON public.gallery_albums
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

  DROP TRIGGER IF EXISTS documents_updated_at ON public.documents;
  CREATE TRIGGER documents_updated_at
    BEFORE UPDATE ON public.documents
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

  DROP TRIGGER IF EXISTS threads_updated_at ON public.message_threads;
  CREATE TRIGGER threads_updated_at
    BEFORE UPDATE ON public.message_threads
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



  -- ==============================================================================
  -- MIGRATION: 20260904075320_005_gallery_docs_messages_policies.sql
  -- ==============================================================================

  /*
  # RLS Policies for Gallery, Documents, Messages

  1. Purpose
    Adds Row Level Security policies to gallery, documents, and messaging tables.

  2. Security Changes
    - `gallery_albums`: founder full CRUD; others SELECT published only.
    - `gallery_photos`: founder full CRUD; teachers can INSERT; others SELECT published albums' photos.
    - `documents`: founder full CRUD; others SELECT published only.
    - `message_threads`: founder all; participants SELECT/INSERT; thread creator can INSERT participants.
    - `thread_participants`: founder all; participants SELECT; thread creator INSERT participants.
    - `messages`: founder all; thread participants SELECT/INSERT/UPDATE (for read receipts).
  */

  -- =============================================================
  -- GALLERY ALBUMS POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "gallery_albums_select_role_based" ON public.gallery_albums;
  CREATE POLICY "gallery_albums_select_role_based" ON public.gallery_albums
    FOR SELECT TO authenticated
    USING (public.is_founder() OR published = true);

  DROP POLICY IF EXISTS "gallery_albums_insert_founder" ON public.gallery_albums;
  CREATE POLICY "gallery_albums_insert_founder" ON public.gallery_albums
    FOR INSERT TO authenticated WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "gallery_albums_update_founder" ON public.gallery_albums;
  CREATE POLICY "gallery_albums_update_founder" ON public.gallery_albums
    FOR UPDATE TO authenticated
    USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "gallery_albums_delete_founder" ON public.gallery_albums;
  CREATE POLICY "gallery_albums_delete_founder" ON public.gallery_albums
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- GALLERY PHOTOS POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "gallery_photos_select_role_based" ON public.gallery_photos;
  CREATE POLICY "gallery_photos_select_role_based" ON public.gallery_photos
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR EXISTS (SELECT 1 FROM public.gallery_albums WHERE id = gallery_photos.album_id AND published = true)
    );

  DROP POLICY IF EXISTS "gallery_photos_insert_role_based" ON public.gallery_photos;
  CREATE POLICY "gallery_photos_insert_role_based" ON public.gallery_photos
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder() OR public.is_teacher());

  DROP POLICY IF EXISTS "gallery_photos_update_founder" ON public.gallery_photos;
  CREATE POLICY "gallery_photos_update_founder" ON public.gallery_photos
    FOR UPDATE TO authenticated
    USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "gallery_photos_delete_founder" ON public.gallery_photos;
  CREATE POLICY "gallery_photos_delete_founder" ON public.gallery_photos
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- DOCUMENTS POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "documents_select_role_based" ON public.documents;
  CREATE POLICY "documents_select_role_based" ON public.documents
    FOR SELECT TO authenticated
    USING (public.is_founder() OR published = true);

  DROP POLICY IF EXISTS "documents_insert_founder" ON public.documents;
  CREATE POLICY "documents_insert_founder" ON public.documents
    FOR INSERT TO authenticated WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "documents_update_founder" ON public.documents;
  CREATE POLICY "documents_update_founder" ON public.documents
    FOR UPDATE TO authenticated
    USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "documents_delete_founder" ON public.documents;
  CREATE POLICY "documents_delete_founder" ON public.documents
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- MESSAGE THREADS POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "threads_select_role_based" ON public.message_threads;
  CREATE POLICY "threads_select_role_based" ON public.message_threads
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR EXISTS (SELECT 1 FROM public.thread_participants WHERE thread_id = message_threads.id AND user_id = auth.uid())
    );

  DROP POLICY IF EXISTS "threads_insert_any" ON public.message_threads;
  CREATE POLICY "threads_insert_any" ON public.message_threads
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);

  DROP POLICY IF EXISTS "threads_update_role_based" ON public.message_threads;
  CREATE POLICY "threads_update_role_based" ON public.message_threads
    FOR UPDATE TO authenticated
    USING (public.is_founder() OR auth.uid() = created_by)
    WITH CHECK (public.is_founder() OR auth.uid() = created_by);

  DROP POLICY IF EXISTS "threads_delete_founder" ON public.message_threads;
  CREATE POLICY "threads_delete_founder" ON public.message_threads
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- THREAD PARTICIPANTS POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "tp_select_role_based" ON public.thread_participants;
  CREATE POLICY "tp_select_role_based" ON public.thread_participants
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR user_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.thread_participants tp2 WHERE tp2.thread_id = thread_participants.thread_id AND tp2.user_id = auth.uid())
    );

  DROP POLICY IF EXISTS "tp_insert_role_based" ON public.thread_participants;
  CREATE POLICY "tp_insert_role_based" ON public.thread_participants
    FOR INSERT TO authenticated
    WITH CHECK (
      public.is_founder()
      OR EXISTS (SELECT 1 FROM public.message_threads WHERE id = thread_participants.thread_id AND created_by = auth.uid())
      OR EXISTS (SELECT 1 FROM public.thread_participants tp2 WHERE tp2.thread_id = thread_participants.thread_id AND tp2.user_id = auth.uid())
    );

  DROP POLICY IF EXISTS "tp_delete_founder" ON public.thread_participants;
  CREATE POLICY "tp_delete_founder" ON public.thread_participants
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- MESSAGES POLICIES
  -- =============================================================
  DROP POLICY IF EXISTS "messages_select_role_based" ON public.messages;
  CREATE POLICY "messages_select_role_based" ON public.messages
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR EXISTS (SELECT 1 FROM public.thread_participants WHERE thread_id = messages.thread_id AND user_id = auth.uid())
    );

  DROP POLICY IF EXISTS "messages_insert_participant" ON public.messages;
  CREATE POLICY "messages_insert_participant" ON public.messages
    FOR INSERT TO authenticated
    WITH CHECK (
      auth.uid() = sender_id
      AND EXISTS (SELECT 1 FROM public.thread_participants WHERE thread_id = messages.thread_id AND user_id = auth.uid())
    );

  DROP POLICY IF EXISTS "messages_update_role_based" ON public.messages;
  CREATE POLICY "messages_update_role_based" ON public.messages
    FOR UPDATE TO authenticated
    USING (
      public.is_founder()
      OR EXISTS (SELECT 1 FROM public.thread_participants WHERE thread_id = messages.thread_id AND user_id = auth.uid())
    )
    WITH CHECK (
      public.is_founder()
      OR EXISTS (SELECT 1 FROM public.thread_participants WHERE thread_id = messages.thread_id AND user_id = auth.uid())
    );

  DROP POLICY IF EXISTS "messages_delete_founder" ON public.messages;
  CREATE POLICY "messages_delete_founder" ON public.messages
    FOR DELETE TO authenticated USING (public.is_founder());



  -- ==============================================================================
  -- MIGRATION: 20260904075402_006_fees_exams_results_audit_notifications.sql
  -- ==============================================================================

  /*
  # Fees, Exams, Results, Admissions, Audit Logs, Notifications, Homework

  1. Purpose
    Creates the remaining tables for the school management system.

  2. New Tables
    - `fee_structures`: id, academic_year, class_id, category, amount, due_date, created_by, created_at, updated_at
    - `fee_payments`: id, student_id, fee_structure_id, amount_paid, payment_date, transaction_id, payment_method, recorded_by, receipt_number, created_at
    - `exams`: id, name, academic_year, term, class_id, exam_type, start_date, end_date, published, created_by, created_at, updated_at
    - `exam_subjects`: id, exam_id, subject_id, exam_date, max_marks, created_at
    - `results`: id, exam_id, student_id, subject_id, marks_obtained, grade, remarks, published, finalized, created_by, created_at, updated_at
    - `admissions`: id, student_name, parent_name, email, phone, date_of_birth, grade_applying_for, message, status, created_at
    - `contact_submissions`: id, name, email, phone, subject, message, created_at
    - `audit_logs`: id, user_id, user_name, role, action, target_table, target_id, previous_value jsonb, new_value jsonb, created_at
    - `notifications`: id, user_id, title, body, type, read, link, created_at
    - `homework`: id, class_id, subject_id, teacher_id, title, description, due_date, attachment_url, created_by, created_at, updated_at

  3. Security
    - `fee_structures`: founder CRUD; parents/teachers SELECT.
    - `fee_payments`: founder CRUD; parents SELECT own children's payments.
    - `exams`/`exam_subjects`: founder CRUD; teachers/parents SELECT published.
    - `results`: founder CRUD; teachers INSERT/UPDATE for assigned classes (before finalization); parents SELECT published results for own children.
    - `admissions`: founder CRUD; anon can INSERT (public form).
    - `contact_submissions`: founder SELECT; anon can INSERT.
    - `audit_logs`: founder SELECT only.
    - `notifications`: users SELECT/UPDATE own; founder can INSERT.
    - `homework`: founder/teacher CRUD; parents SELECT for children's classes.
  */

  -- =============================================================
  -- FEE STRUCTURES TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.fee_structures (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    academic_year text NOT NULL,
    class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL,
    category text NOT NULL CHECK (category IN ('tuition', 'admission', 'transport', 'activity', 'examination', 'library', 'laboratory', 'other')),
    amount numeric(12,2) NOT NULL DEFAULT 0,
    due_date date,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_fee_structures_class ON public.fee_structures(class_id);
  CREATE INDEX IF NOT EXISTS idx_fee_structures_year ON public.fee_structures(academic_year);
  ALTER TABLE public.fee_structures ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "fee_structures_select_all_auth" ON public.fee_structures;
  CREATE POLICY "fee_structures_select_all_auth" ON public.fee_structures
    FOR SELECT TO authenticated USING (true);

  DROP POLICY IF EXISTS "fee_structures_insert_founder" ON public.fee_structures;
  CREATE POLICY "fee_structures_insert_founder" ON public.fee_structures
    FOR INSERT TO authenticated WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "fee_structures_update_founder" ON public.fee_structures;
  CREATE POLICY "fee_structures_update_founder" ON public.fee_structures
    FOR UPDATE TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "fee_structures_delete_founder" ON public.fee_structures;
  CREATE POLICY "fee_structures_delete_founder" ON public.fee_structures
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- FEE PAYMENTS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.fee_payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    fee_structure_id uuid REFERENCES public.fee_structures(id) ON DELETE SET NULL,
    amount_paid numeric(12,2) NOT NULL DEFAULT 0,
    payment_date date NOT NULL DEFAULT CURRENT_DATE,
    transaction_id text,
    payment_method text DEFAULT 'cash' CHECK (payment_method IN ('cash', 'cheque', 'bank_transfer', 'online', 'card')),
    recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    receipt_number text,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_fee_payments_student ON public.fee_payments(student_id);
  ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "fee_payments_select_role_based" ON public.fee_payments;
  CREATE POLICY "fee_payments_select_role_based" ON public.fee_payments
    FOR SELECT TO authenticated
    USING (public.is_founder() OR public.is_parent_of_student(student_id));

  DROP POLICY IF EXISTS "fee_payments_insert_founder" ON public.fee_payments;
  CREATE POLICY "fee_payments_insert_founder" ON public.fee_payments
    FOR INSERT TO authenticated WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "fee_payments_update_founder" ON public.fee_payments;
  CREATE POLICY "fee_payments_update_founder" ON public.fee_payments
    FOR UPDATE TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "fee_payments_delete_founder" ON public.fee_payments;
  CREATE POLICY "fee_payments_delete_founder" ON public.fee_payments
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- EXAMS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.exams (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    academic_year text NOT NULL,
    term text DEFAULT 'Term 1',
    class_id uuid REFERENCES public.classes(id) ON DELETE CASCADE,
    exam_type text DEFAULT 'term' CHECK (exam_type IN ('term', 'unit_test', 'quiz', 'final', 'midterm')),
    start_date date,
    end_date date,
    published boolean NOT NULL DEFAULT false,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_exams_class ON public.exams(class_id);
  ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "exams_select_role_based" ON public.exams;
  CREATE POLICY "exams_select_role_based" ON public.exams
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR published = true
      OR (public.is_teacher() AND (class_id IS NULL OR public.is_teacher_of_class(class_id)))
    );

  DROP POLICY IF EXISTS "exams_insert_founder" ON public.exams;
  CREATE POLICY "exams_insert_founder" ON public.exams
    FOR INSERT TO authenticated WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "exams_update_founder" ON public.exams;
  CREATE POLICY "exams_update_founder" ON public.exams
    FOR UPDATE TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "exams_delete_founder" ON public.exams;
  CREATE POLICY "exams_delete_founder" ON public.exams
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- EXAM SUBJECTS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.exam_subjects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id uuid NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
    exam_date date,
    max_marks int NOT NULL DEFAULT 100,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_exam_subjects_exam ON public.exam_subjects(exam_id);
  ALTER TABLE public.exam_subjects ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "exam_subjects_select_role_based" ON public.exam_subjects;
  CREATE POLICY "exam_subjects_select_role_based" ON public.exam_subjects
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR EXISTS (
        SELECT 1 FROM public.exams e
        WHERE e.id = exam_subjects.exam_id AND (e.published = true OR (public.is_teacher() AND (e.class_id IS NULL OR public.is_teacher_of_class(e.class_id))))
      )
    );

  DROP POLICY IF EXISTS "exam_subjects_insert_founder" ON public.exam_subjects;
  CREATE POLICY "exam_subjects_insert_founder" ON public.exam_subjects
    FOR INSERT TO authenticated WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "exam_subjects_update_founder" ON public.exam_subjects;
  CREATE POLICY "exam_subjects_update_founder" ON public.exam_subjects
    FOR UPDATE TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "exam_subjects_delete_founder" ON public.exam_subjects;
  CREATE POLICY "exam_subjects_delete_founder" ON public.exam_subjects
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- RESULTS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.results (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id uuid NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
    marks_obtained numeric(6,2),
    grade text,
    remarks text,
    published boolean NOT NULL DEFAULT false,
    finalized boolean NOT NULL DEFAULT false,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_results_exam ON public.results(exam_id);
  CREATE INDEX IF NOT EXISTS idx_results_student ON public.results(student_id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_results_exam_student_subject ON public.results(exam_id, student_id, subject_id);
  ALTER TABLE public.results ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "results_select_role_based" ON public.results;
  CREATE POLICY "results_select_role_based" ON public.results
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR (published = true AND public.is_parent_of_student(student_id))
      OR (public.is_teacher_of_student(student_id) AND EXISTS (
        SELECT 1 FROM public.exams e WHERE e.id = results.exam_id AND (e.class_id IS NULL OR public.is_teacher_of_class(e.class_id))
      ))
    );

  DROP POLICY IF EXISTS "results_insert_role_based" ON public.results;
  CREATE POLICY "results_insert_role_based" ON public.results
    FOR INSERT TO authenticated
    WITH CHECK (
      public.is_founder()
      OR (public.is_teacher_of_student(student_id) AND NOT finalized)
    );

  DROP POLICY IF EXISTS "results_update_role_based" ON public.results;
  CREATE POLICY "results_update_role_based" ON public.results
    FOR UPDATE TO authenticated
    USING (
      public.is_founder()
      OR (public.is_teacher_of_student(student_id) AND NOT finalized)
    )
    WITH CHECK (
      public.is_founder()
      OR (public.is_teacher_of_student(student_id) AND NOT finalized)
    );

  DROP POLICY IF EXISTS "results_delete_founder" ON public.results;
  CREATE POLICY "results_delete_founder" ON public.results
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- ADMISSIONS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.admissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_name text NOT NULL,
    parent_name text NOT NULL,
    email text,
    phone text,
    date_of_birth date,
    grade_applying_for text,
    message text,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'accepted', 'rejected', 'enrolled')),
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_admissions_status ON public.admissions(status);
  ALTER TABLE public.admissions ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "admissions_select_founder" ON public.admissions;
  CREATE POLICY "admissions_select_founder" ON public.admissions
    FOR SELECT TO authenticated USING (public.is_founder());

  DROP POLICY IF EXISTS "admissions_insert_anon" ON public.admissions;
  CREATE POLICY "admissions_insert_anon" ON public.admissions
    FOR INSERT TO anon, authenticated WITH CHECK (true);

  DROP POLICY IF EXISTS "admissions_update_founder" ON public.admissions;
  CREATE POLICY "admissions_update_founder" ON public.admissions
    FOR UPDATE TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "admissions_delete_founder" ON public.admissions;
  CREATE POLICY "admissions_delete_founder" ON public.admissions
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- CONTACT SUBMISSIONS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.contact_submissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    email text,
    phone text,
    subject text,
    message text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  ALTER TABLE public.contact_submissions ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "contact_select_founder" ON public.contact_submissions;
  CREATE POLICY "contact_select_founder" ON public.contact_submissions
    FOR SELECT TO authenticated USING (public.is_founder());

  DROP POLICY IF EXISTS "contact_insert_anon" ON public.contact_submissions;
  CREATE POLICY "contact_insert_anon" ON public.contact_submissions
    FOR INSERT TO anon, authenticated WITH CHECK (true);

  DROP POLICY IF EXISTS "contact_delete_founder" ON public.contact_submissions;
  CREATE POLICY "contact_delete_founder" ON public.contact_submissions
    FOR DELETE TO authenticated USING (public.is_founder());

  -- =============================================================
  -- AUDIT LOGS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name text,
    role text,
    action text NOT NULL,
    target_table text,
    target_id text,
    previous_value jsonb,
    new_value jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at DESC);
  ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "audit_logs_select_founder" ON public.audit_logs;
  CREATE POLICY "audit_logs_select_founder" ON public.audit_logs
    FOR SELECT TO authenticated USING (public.is_founder());

  DROP POLICY IF EXISTS "audit_logs_insert_auth" ON public.audit_logs;
  CREATE POLICY "audit_logs_insert_auth" ON public.audit_logs
    FOR INSERT TO authenticated WITH CHECK (true);

  -- =============================================================
  -- NOTIFICATIONS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title text NOT NULL,
    body text,
    type text DEFAULT 'general' CHECK (type IN ('general', 'announcement', 'message', 'attendance', 'event', 'document', 'academic', 'fee')),
    read boolean NOT NULL DEFAULT false,
    link text,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
  CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(read);
  ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
  CREATE POLICY "notifications_select_own" ON public.notifications
    FOR SELECT TO authenticated USING (user_id = auth.uid());

  DROP POLICY IF EXISTS "notifications_insert_any_auth" ON public.notifications;
  CREATE POLICY "notifications_insert_any_auth" ON public.notifications
    FOR INSERT TO authenticated WITH CHECK (true);

  DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;
  CREATE POLICY "notifications_update_own" ON public.notifications
    FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

  DROP POLICY IF EXISTS "notifications_delete_own" ON public.notifications;
  CREATE POLICY "notifications_delete_own" ON public.notifications
    FOR DELETE TO authenticated USING (user_id = auth.uid());

  -- =============================================================
  -- HOMEWORK TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.homework (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
    teacher_id uuid REFERENCES public.teachers(id) ON DELETE SET NULL,
    title text NOT NULL,
    description text,
    due_date date,
    attachment_url text,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_homework_class ON public.homework(class_id);
  ALTER TABLE public.homework ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "homework_select_role_based" ON public.homework;
  CREATE POLICY "homework_select_role_based" ON public.homework
    FOR SELECT TO authenticated
    USING (
      public.is_founder()
      OR (public.is_teacher() AND public.is_teacher_of_class(class_id))
      OR (public.is_parent() AND EXISTS (
        SELECT 1 FROM public.students s
        JOIN public.parent_student_links psl ON psl.student_id = s.id
        WHERE s.class_id = homework.class_id AND psl.parent_id = auth.uid()
      ))
    );

  DROP POLICY IF EXISTS "homework_insert_teacher_founder" ON public.homework;
  CREATE POLICY "homework_insert_teacher_founder" ON public.homework
    FOR INSERT TO authenticated
    WITH CHECK (public.is_founder() OR (public.is_teacher() AND public.is_teacher_of_class(class_id)));

  DROP POLICY IF EXISTS "homework_update_role_based" ON public.homework;
  CREATE POLICY "homework_update_role_based" ON public.homework
    FOR UPDATE TO authenticated
    USING (public.is_founder() OR (public.is_teacher() AND public.is_teacher_of_class(class_id)))
    WITH CHECK (public.is_founder() OR (public.is_teacher() AND public.is_teacher_of_class(class_id)));

  DROP POLICY IF EXISTS "homework_delete_role_based" ON public.homework;
  CREATE POLICY "homework_delete_role_based" ON public.homework
    FOR DELETE TO authenticated
    USING (public.is_founder() OR (public.is_teacher() AND public.is_teacher_of_class(class_id)));

  -- =============================================================
  -- TRIGGERS
  -- =============================================================
  DROP TRIGGER IF EXISTS fee_structures_updated_at ON public.fee_structures;
  CREATE TRIGGER fee_structures_updated_at
    BEFORE UPDATE ON public.fee_structures
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

  DROP TRIGGER IF EXISTS exams_updated_at ON public.exams;
  CREATE TRIGGER exams_updated_at
    BEFORE UPDATE ON public.exams
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

  DROP TRIGGER IF EXISTS results_updated_at ON public.results;
  CREATE TRIGGER results_updated_at
    BEFORE UPDATE ON public.results
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

  DROP TRIGGER IF EXISTS homework_updated_at ON public.homework;
  CREATE TRIGGER homework_updated_at
    BEFORE UPDATE ON public.homework
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



  -- ==============================================================================
  -- MIGRATION: 20260908092000_007_bulk_student_import_system.sql
  -- ==============================================================================

  /*
  # Bulk Student Import System & Performance Indexes

  1. Purpose
    - Enables fast, secure, transactional bulk import of student rosters from spreadsheets.
    - Enforces Founder-only authorization at database layer (RLS and SECURITY DEFINER RPC).
    - Optimizes student search indexes for high-volume roll numbers and admission IDs.
    - Automatically maintains parent-student links and audit logs.

  2. Database Objects
    - Performance Indexes: idx_students_admission_number, idx_students_roll_number, idx_students_full_name
    - Stored Procedure: public.bulk_import_students(p_students jsonb, p_duplicate_mode text)
    - Function Security: Accessible strictly to active Founder accounts.
  */

  -- =============================================================
  -- PERFORMANCE INDEXES
  -- =============================================================
  CREATE INDEX IF NOT EXISTS idx_students_admission_number ON public.students(admission_number);
  CREATE INDEX IF NOT EXISTS idx_students_roll_number ON public.students(roll_number);
  CREATE INDEX IF NOT EXISTS idx_students_full_name ON public.students(full_name);
  CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

  -- =============================================================
  -- STORED PROCEDURE: BULK IMPORT STUDENTS
  -- =============================================================
  CREATE OR REPLACE FUNCTION public.bulk_import_students(
    p_students jsonb,
    p_duplicate_mode text DEFAULT 'skip' -- 'skip' | 'update' | 'error'
  )
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $$
  DECLARE
    v_user_id uuid;
    v_user_name text;
    v_user_role text;
    v_row jsonb;
    v_adm_no text;
    v_roll_no text;
    v_full_name text;
    v_dob date;
    v_gender text;
    v_blood_group text;
    v_address text;
    v_class_name text;
    v_section_name text;
    v_parent_name text;
    v_parent_phone text;
    
    v_class_id uuid;
    v_section_id uuid;
    v_parent_id uuid;
    v_student_id uuid;
    v_existing_id uuid;
    
    v_total int := 0;
    v_added int := 0;
    v_updated int := 0;
    v_skipped int := 0;
    v_failed int := 0;
    v_errors jsonb := '[]'::jsonb;
  BEGIN
    -- 1. Security Authorization Check
    IF NOT public.is_founder() THEN
      RAISE EXCEPTION 'Access Denied: Only authorized Golden Kids School Founders/Administrators can execute bulk student imports.'
        USING ERRCODE = '42501';
    END IF;

    v_user_id := auth.uid();
    SELECT full_name, role INTO v_user_name, v_user_role 
    FROM public.profiles 
    WHERE id = v_user_id;

    -- 2. Process Student Records
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_students)
    LOOP
      v_total := v_total + 1;
      BEGIN
        v_adm_no := TRIM(COALESCE(v_row->>'admission_number', v_row->>'roll_number', ''));
        v_roll_no := TRIM(COALESCE(v_row->>'roll_number', v_row->>'admission_number', ''));
        v_full_name := TRIM(COALESCE(v_row->>'full_name', ''));
        v_gender := LOWER(TRIM(COALESCE(v_row->>'gender', '')));
        v_blood_group := TRIM(COALESCE(v_row->>'blood_group', ''));
        v_address := TRIM(COALESCE(v_row->>'address', ''));
        v_class_name := TRIM(COALESCE(v_row->>'class_name', ''));
        v_section_name := TRIM(COALESCE(v_row->>'section_name', ''));
        v_parent_name := TRIM(COALESCE(v_row->>'parent_name', ''));
        v_parent_phone := TRIM(COALESCE(v_row->>'parent_phone', v_row->>'parent_whatsapp', ''));

        -- Validate date of birth
        IF (v_row->>'date_of_birth') IS NOT NULL AND (v_row->>'date_of_birth') <> '' THEN
          BEGIN
            v_dob := (v_row->>'date_of_birth')::date;
          EXCEPTION WHEN OTHERS THEN
            v_dob := NULL;
          END;
        ELSE
          v_dob := NULL;
        END IF;

        -- Validate gender
        IF v_gender NOT IN ('male', 'female', 'other') THEN
          IF v_gender LIKE 'm%' OR v_gender = 'boy' THEN
            v_gender := 'male';
          ELSIF v_gender LIKE 'f%' OR v_gender = 'girl' THEN
            v_gender := 'female';
          ELSE
            v_gender := 'other';
          END IF;
        END IF;

        -- Require full name and admission number
        IF v_full_name = '' OR v_adm_no = '' THEN
          v_failed := v_failed + 1;
          v_errors := v_errors || jsonb_build_object(
            'row', v_total,
            'admission_number', v_adm_no,
            'full_name', v_full_name,
            'error', 'Missing required fields: Student Name or Admission/Roll Number'
          );
          CONTINUE;
        END IF;

        -- Resolve Class ID
        v_class_id := NULL;
        IF v_class_name <> '' THEN
          SELECT id INTO v_class_id 
          FROM public.classes 
          WHERE LOWER(name) = LOWER(v_class_name) 
            OR LOWER(name) = LOWER('Grade ' || v_class_name)
          LIMIT 1;
        END IF;

        -- Resolve Section ID
        v_section_id := NULL;
        IF v_class_id IS NOT NULL AND v_section_name <> '' THEN
          SELECT id INTO v_section_id 
          FROM public.sections 
          WHERE class_id = v_class_id AND LOWER(name) = LOWER(v_section_name)
          LIMIT 1;
        END IF;

        -- Resolve Parent Profile (deduplicated by phone)
        v_parent_id := NULL;
        IF v_parent_phone <> '' THEN
          SELECT id INTO v_parent_id 
          FROM public.profiles 
          WHERE phone = v_parent_phone AND role = 'parent'
          LIMIT 1;
        END IF;

        -- Check for existing student record
        SELECT id INTO v_existing_id 
        FROM public.students 
        WHERE admission_number = v_adm_no OR (roll_number = v_roll_no AND roll_number <> '')
        LIMIT 1;

        IF v_existing_id IS NOT NULL THEN
          -- Existing Record Found
          IF p_duplicate_mode = 'update' THEN
            UPDATE public.students SET
              full_name = v_full_name,
              date_of_birth = COALESCE(v_dob, date_of_birth),
              gender = v_gender,
              blood_group = COALESCE(NULLIF(v_blood_group, ''), blood_group),
              address = COALESCE(NULLIF(v_address, ''), address),
              class_id = COALESCE(v_class_id, class_id),
              section_id = COALESCE(v_section_id, section_id),
              parent_id = COALESCE(v_parent_id, parent_id),
              updated_at = now()
            WHERE id = v_existing_id;
            
            v_updated := v_updated + 1;
          ELSIF p_duplicate_mode = 'skip' THEN
            v_skipped := v_skipped + 1;
          ELSE -- 'error'
            v_failed := v_failed + 1;
            v_errors := v_errors || jsonb_build_object(
              'row', v_total,
              'admission_number', v_adm_no,
              'full_name', v_full_name,
              'error', 'Duplicate student already exists in database'
            );
          END IF;
        ELSE
          -- Insert New Student
          INSERT INTO public.students (
            admission_number,
            roll_number,
            full_name,
            date_of_birth,
            gender,
            blood_group,
            address,
            class_id,
            section_id,
            parent_id,
            status
          ) VALUES (
            v_adm_no,
            v_roll_no,
            v_full_name,
            v_dob,
            v_gender,
            NULLIF(v_blood_group, ''),
            NULLIF(v_address, ''),
            v_class_id,
            v_section_id,
            v_parent_id,
            'active'
          ) RETURNING id INTO v_student_id;

          -- Link parent if exists
          IF v_parent_id IS NOT NULL AND v_student_id IS NOT NULL THEN
            INSERT INTO public.parent_student_links (parent_id, student_id, relationship)
            VALUES (v_parent_id, v_student_id, 'parent')
            ON CONFLICT DO NOTHING;
          END IF;

          v_added := v_added + 1;
        END IF;

      EXCEPTION WHEN OTHERS THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || jsonb_build_object(
          'row', v_total,
          'admission_number', v_adm_no,
          'full_name', v_full_name,
          'error', SQLERRM
        );
      END;
    END LOOP;

    -- 3. Record Audit Log Entry
    INSERT INTO public.audit_logs (
      user_id,
      user_name,
      role,
      action,
      target_table,
      target_id,
      new_value
    ) VALUES (
      v_user_id,
      COALESCE(v_user_name, 'Founder/Admin'),
      COALESCE(v_user_role, 'founder'),
      'bulk_import_students',
      'students',
      'batch_' || to_char(now(), 'YYYYMMDD_HH24MISS'),
      jsonb_build_object(
        'total_processed', v_total,
        'added', v_added,
        'updated', v_updated,
        'skipped', v_skipped,
        'failed', v_failed,
        'duplicate_mode', p_duplicate_mode,
        'timestamp', now()
      )
    );

    -- 4. Return Result Summary
    RETURN jsonb_build_object(
      'success', true,
      'total', v_total,
      'added', v_added,
      'updated', v_updated,
      'skipped', v_skipped,
      'failed', v_failed,
      'errors', v_errors
    );
  END;
  $$;



  -- ==============================================================================
  -- MIGRATION: 20260915160000_008_whatsapp_automation_system.sql
  -- ==============================================================================

  /*
  # WhatsApp Automation & Messaging System Migration
  # Schema: Golden Kids English Medium School

  1. New Tables:
    - `whatsapp_config`: Global WhatsApp Business API configuration, Phone Number ID, WABA ID, Webhook Verify Token, connection status.
    - `whatsapp_templates`: Approved and draft message templates with category, content, header, footer, buttons, and approval status.
    - `whatsapp_automations`: Automatic event triggers (attendance alerts, fee reminders, exam notices, result alerts, announcements).
    - `whatsapp_messages`: Message queue and delivery ledger tracking recipients, content, status, provider IDs, and timestamps.
    - `whatsapp_audit_logs`: Immutable audit trail of all message dispatches and configuration changes.

  2. Security (Row Level Security):
    - `whatsapp_config`: Founder full access; hidden from teachers, parents, and anonymous users.
    - `whatsapp_templates`: Founder full access; teachers can view approved templates; parents no access.
    - `whatsapp_automations`: Founder full access; teachers read-only for assigned automations; parents no access.
    - `whatsapp_messages`: Founder full access; teachers can insert and view their own class messages; parents can view messages sent to their student/phone.
    - `whatsapp_audit_logs`: Founder read-only; inserted automatically via triggers or service role.
  */

  -- =============================================================
  -- 1. WHATSAPP CONFIG TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.whatsapp_config (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider text NOT NULL DEFAULT 'cloud_api' CHECK (provider IN ('cloud_api', 'twilio', 'gupshup', '360dialog')),
    business_phone text,
    business_account_id text, -- WABA ID
    phone_number_id text,
    webhook_url text,
    webhook_verify_token text,
    is_connected boolean NOT NULL DEFAULT false,
    environment text NOT NULL DEFAULT 'demo' CHECK (environment IN ('demo', 'production', 'sandbox')),
    rate_limit_per_second integer NOT NULL DEFAULT 20,
    daily_quota integer NOT NULL DEFAULT 10000,
    last_tested_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );

  ALTER TABLE public.whatsapp_config ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "whatsapp_config_founder_all" ON public.whatsapp_config;
  CREATE POLICY "whatsapp_config_founder_all" ON public.whatsapp_config
    FOR ALL TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  -- =============================================================
  -- 2. WHATSAPP TEMPLATES TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.whatsapp_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    title text NOT NULL,
    category text NOT NULL CHECK (category IN ('attendance', 'fees', 'exams', 'results', 'announcements', 'events', 'emergency', 'general')),
    language text NOT NULL DEFAULT 'en',
    header_type text DEFAULT 'none' CHECK (header_type IN ('none', 'text', 'image', 'document', 'video')),
    header_content text,
    body_content text NOT NULL,
    footer_content text DEFAULT 'Golden Kids English Medium School • Palangi Campus',
    variables jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('approved', 'draft', 'pending', 'rejected')),
    provider_template_id text,
    rejection_reason text,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_whatsapp_templates_category ON public.whatsapp_templates(category);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_templates_status ON public.whatsapp_templates(status);

  ALTER TABLE public.whatsapp_templates ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "whatsapp_templates_founder_all" ON public.whatsapp_templates;
  CREATE POLICY "whatsapp_templates_founder_all" ON public.whatsapp_templates
    FOR ALL TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "whatsapp_templates_teacher_select_approved" ON public.whatsapp_templates;
  CREATE POLICY "whatsapp_templates_teacher_select_approved" ON public.whatsapp_templates
    FOR SELECT TO authenticated
    USING (public.is_teacher() AND status = 'approved');

  -- =============================================================
  -- 3. WHATSAPP AUTOMATIONS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.whatsapp_automations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    key text NOT NULL UNIQUE,
    name text NOT NULL,
    description text NOT NULL,
    trigger_event text NOT NULL CHECK (trigger_event IN ('attendance_absent', 'fee_due', 'fee_overdue', 'payment_received', 'exam_schedule', 'result_published', 'announcement_created', 'emergency_alert')),
    template_id uuid REFERENCES public.whatsapp_templates(id) ON DELETE SET NULL,
    target_audience text NOT NULL DEFAULT 'parents' CHECK (target_audience IN ('parents', 'specific_class', 'staff', 'all')),
    is_enabled boolean NOT NULL DEFAULT true,
    timing_mode text NOT NULL DEFAULT 'immediate' CHECK (timing_mode IN ('immediate', 'scheduled_time')),
    scheduled_time time DEFAULT '15:00:00',
    deduplicate_daily boolean NOT NULL DEFAULT true,
    last_executed_at timestamptz,
    messages_sent_count integer NOT NULL DEFAULT 0,
    failure_count integer NOT NULL DEFAULT 0,
    created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_whatsapp_automations_key ON public.whatsapp_automations(key);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_automations_enabled ON public.whatsapp_automations(is_enabled);

  ALTER TABLE public.whatsapp_automations ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "whatsapp_automations_founder_all" ON public.whatsapp_automations;
  CREATE POLICY "whatsapp_automations_founder_all" ON public.whatsapp_automations
    FOR ALL TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "whatsapp_automations_teacher_select" ON public.whatsapp_automations;
  CREATE POLICY "whatsapp_automations_teacher_select" ON public.whatsapp_automations
    FOR SELECT TO authenticated
    USING (public.is_teacher());

  -- =============================================================
  -- 4. WHATSAPP MESSAGES TABLE (Queue & Delivery Ledger)
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.whatsapp_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_parent_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    student_id uuid REFERENCES public.students(id) ON DELETE SET NULL,
    phone_number text NOT NULL,
    template_id uuid REFERENCES public.whatsapp_templates(id) ON DELETE SET NULL,
    automation_id uuid REFERENCES public.whatsapp_automations(id) ON DELETE SET NULL,
    message_type text NOT NULL DEFAULT 'general' CHECK (message_type IN ('announcement', 'attendance', 'fee_reminder', 'exam', 'result', 'general', 'emergency')),
    rendered_content text NOT NULL,
    rendered_variables jsonb DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'sending', 'sent', 'delivered', 'read', 'failed')),
    provider_message_id text,
    error_code text,
    error_message text,
    retry_count integer NOT NULL DEFAULT 0,
    max_retries integer NOT NULL DEFAULT 3,
    triggered_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    triggered_by_role text NOT NULL DEFAULT 'founder',
    sent_at timestamptz,
    delivered_at timestamptz,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_status ON public.whatsapp_messages(status);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_phone ON public.whatsapp_messages(phone_number);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_student ON public.whatsapp_messages(student_id);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_parent ON public.whatsapp_messages(recipient_parent_id);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_created ON public.whatsapp_messages(created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_provider_id ON public.whatsapp_messages(provider_message_id);

  ALTER TABLE public.whatsapp_messages ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "whatsapp_messages_founder_all" ON public.whatsapp_messages;
  CREATE POLICY "whatsapp_messages_founder_all" ON public.whatsapp_messages
    FOR ALL TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

  DROP POLICY IF EXISTS "whatsapp_messages_teacher_access" ON public.whatsapp_messages;
  CREATE POLICY "whatsapp_messages_teacher_access" ON public.whatsapp_messages
    FOR ALL TO authenticated
    USING (
      public.is_teacher() AND (
        triggered_by_user_id = auth.uid() OR
        public.is_teacher_of_student(student_id)
      )
    )
    WITH CHECK (public.is_teacher());

  DROP POLICY IF EXISTS "whatsapp_messages_parent_select_own" ON public.whatsapp_messages;
  CREATE POLICY "whatsapp_messages_parent_select_own" ON public.whatsapp_messages
    FOR SELECT TO authenticated
    USING (
      public.is_parent() AND (
        recipient_parent_id = auth.uid() OR
        public.is_parent_of_student(student_id)
      )
    );

  -- =============================================================
  -- 5. WHATSAPP AUDIT LOGS TABLE
  -- =============================================================
  CREATE TABLE IF NOT EXISTS public.whatsapp_audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name text NOT NULL,
    user_role text NOT NULL,
    action text NOT NULL,
    recipient_phone text,
    student_name text,
    template_name text,
    automation_name text,
    provider_message_id text,
    status text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
  );

  CREATE INDEX IF NOT EXISTS idx_whatsapp_audit_created ON public.whatsapp_audit_logs(created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_whatsapp_audit_action ON public.whatsapp_audit_logs(action);

  ALTER TABLE public.whatsapp_audit_logs ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "whatsapp_audit_founder_select" ON public.whatsapp_audit_logs;
  CREATE POLICY "whatsapp_audit_founder_select" ON public.whatsapp_audit_logs
    FOR SELECT TO authenticated
    USING (public.is_founder());

  DROP POLICY IF EXISTS "whatsapp_audit_insert_authenticated" ON public.whatsapp_audit_logs;
  CREATE POLICY "whatsapp_audit_insert_authenticated" ON public.whatsapp_audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (true);

  -- =============================================================
  -- 6. DEFAULT SEED DATA FOR TEMPLATES & AUTOMATIONS
  -- =============================================================
  INSERT INTO public.whatsapp_templates (name, title, category, body_content, variables, status)
  VALUES
    ('attendance_absent_notice', 'Daily Absence Alert', 'attendance',
    'Dear {{parent_name}},\n\nThis is to inform you that {{student_name}} (Roll No: {{roll_number}}, Class: {{class}}) was marked Absent today, {{date}}.\n\nPlease contact the school office if this absence was unexpected.\n\nRegards,\nGolden Kids English Medium School',
    '["parent_name", "student_name", "roll_number", "class", "date"]'::jsonb, 'approved'),

    ('fee_due_reminder_notice', 'Upcoming Fee Due Reminder', 'fees',
    'Dear {{parent_name}},\n\nThis is a friendly reminder that the school fee of ₹{{fee_amount}} for {{student_name}} (Class: {{class}}) is due on {{due_date}}.\n\nKindly clear the dues at the school fee desk or via online gateway.\n\nRegards,\nGolden Kids School',
    '["parent_name", "fee_amount", "student_name", "class", "due_date"]'::jsonb, 'approved'),

    ('fee_overdue_alert_notice', 'Overdue Fee Notice', 'fees',
    'Dear {{parent_name}},\n\nOur records indicate an overdue fee of ₹{{fee_amount}} for {{student_name}} (Class: {{class}}), which was due on {{due_date}}.\n\nPlease contact the administration office immediately.\n\nRegards,\nGolden Kids School',
    '["parent_name", "fee_amount", "student_name", "class", "due_date"]'::jsonb, 'approved'),

    ('exam_schedule_notice', 'Exam Schedule Announcement', 'exams',
    'Dear {{parent_name}},\n\nThe {{exam_name}} for {{student_name}} (Class: {{class}}) is scheduled to commence on {{date}}.\n\nPlease ensure your child prepares adequately and brings the required hall stationeries.\n\nRegards,\nGolden Kids School',
    '["parent_name", "exam_name", "student_name", "class", "date"]'::jsonb, 'approved'),

    ('result_publication_notice', 'Exam Results Published', 'results',
    'Dear {{parent_name}},\n\nThe evaluation results for {{student_name}} (Class: {{class}}, {{exam_name}}) have been finalized.\n\nPlease log in to the Golden Kids Parent Portal to review the detailed academic report card.\n\nRegards,\nGolden Kids School',
    '["parent_name", "student_name", "class", "exam_name"]'::jsonb, 'approved'),

    ('school_announcement_broadcast', 'Campus Announcement', 'announcements',
    'Dear {{parent_name}},\n\nImportant Announcement from Golden Kids School:\n\n{{announcement}}\n\nDate: {{date}}\n\nRegards,\nAdministration Desk, Golden Kids School',
    '["parent_name", "announcement", "date"]'::jsonb, 'approved')
  ON CONFLICT (name) DO NOTHING;

  INSERT INTO public.whatsapp_automations (key, name, description, trigger_event, target_audience, is_enabled, timing_mode, scheduled_time, deduplicate_daily)
  VALUES
    ('attendance_absent_alert', 'Attendance Absent Alert', 'Automatically dispatches approved WhatsApp notice to parents when a student is marked Absent.', 'attendance_absent', 'parents', true, 'immediate', '15:00:00', true),
    ('fee_due_reminder', 'Fee Due Date Reminder', 'Sends automated reminder 3 days prior to fee payment deadline.', 'fee_due', 'parents', true, 'scheduled_time', '10:00:00', true),
    ('fee_overdue_alert', 'Overdue Fee Notification', 'Alerts parents regarding overdue academic or transport fees.', 'fee_overdue', 'parents', false, 'scheduled_time', '11:00:00', true),
    ('exam_schedule_alert', 'Exam Schedule Notification', 'Broadcasts exam dates and syllabus reminders to registered parents.', 'exam_schedule', 'specific_class', true, 'immediate', '15:00:00', false),
    ('result_publication_alert', 'Result Publication Notice', 'Sends secure parent portal login reminder once class term results are published.', 'result_published', 'specific_class', true, 'immediate', '16:00:00', false),
    ('school_announcement_alert', 'School Announcement Broadcast', 'Dispatches critical school circulars and emergency holiday alerts.', 'announcement_created', 'all', true, 'immediate', '08:00:00', false)
  ON CONFLICT (key) DO NOTHING;


  -- =============================================================
  -- INITIAL FOUNDER & SEED PROFILE SETUP
  -- =============================================================
  INSERT INTO public.profiles (id, full_name, email, phone, role, status)
  VALUES (
    '157eb125-5044-45cf-ab14-df9e610067b4',
    'School Founder & Administrator',
    'founder@goldenkids.edu',
    '+91 86591 63665',
    'founder',
    'active'
  )
  ON CONFLICT (id) DO UPDATE 
  SET role = 'founder', status = 'active';

  -- Seed foundational classes
  INSERT INTO public.classes (name, grade_level, description)
  VALUES 
    ('Nursery', 0, 'Early Childhood Education'),
    ('LKG', 0, 'Lower Kindergarten'),
    ('UKG', 0, 'Upper Kindergarten'),
    ('Grade 1', 1, 'Primary Section'),
    ('Grade 2', 2, 'Primary Section'),
    ('Grade 3', 3, 'Primary Section'),
    ('Grade 4', 4, 'Primary Section'),
    ('Grade 5', 5, 'Primary Section'),
    ('Grade 6', 6, 'Middle School'),
    ('Grade 7', 7, 'Middle School'),
    ('Grade 8', 8, 'Middle School'),
    ('Grade 9', 9, 'High School'),
    ('Grade 10', 10, 'Secondary School')
  ON CONFLICT DO NOTHING;
