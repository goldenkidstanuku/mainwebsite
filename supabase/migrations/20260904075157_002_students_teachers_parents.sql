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
