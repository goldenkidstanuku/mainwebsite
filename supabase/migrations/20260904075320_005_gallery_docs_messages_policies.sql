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
