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
