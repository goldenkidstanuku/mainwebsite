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
