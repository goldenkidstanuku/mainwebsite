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
