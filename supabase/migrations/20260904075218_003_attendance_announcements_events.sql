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
