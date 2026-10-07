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
