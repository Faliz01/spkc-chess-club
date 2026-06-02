-- ═══════════════════════════════════════════════════════════════════════════
-- SPKC Chess Club — Full Migration (safe to re-run, all IF NOT EXISTS)
-- Run the ENTIRE file in one go in Supabase SQL editor.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── season_settings ──────────────────────────────────────────────────────────
-- Core table: Supabase creates this automatically, but this block is safe
-- if it doesn't exist yet.
CREATE TABLE IF NOT EXISTS season_settings (
  season_key   text PRIMARY KEY,
  season_label text,
  registration_enabled    boolean NOT NULL DEFAULT false,
  registration_opens_at   timestamptz,
  registration_closes_at  timestamptz,
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- Add extra columns (safe to re-run)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='file_path') THEN
    ALTER TABLE season_settings ADD COLUMN file_path text NOT NULL DEFAULT 'latest/season-standings.xlsx';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='sheet_name') THEN
    ALTER TABLE season_settings ADD COLUMN sheet_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='sheet_hints') THEN
    ALTER TABLE season_settings ADD COLUMN sheet_hints text; -- JSON string e.g. '["2026 Season","2026"]'
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='summary') THEN
    ALTER TABLE season_settings ADD COLUMN summary text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='notes') THEN
    ALTER TABLE season_settings ADD COLUMN notes text; -- JSON string e.g. '["Note 1","Note 2"]'
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='round_count') THEN
    ALTER TABLE season_settings ADD COLUMN round_count integer NOT NULL DEFAULT 6;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='round_time') THEN
    ALTER TABLE season_settings ADD COLUMN round_time text DEFAULT 'Sundays 20:00';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='season_window') THEN
    ALTER TABLE season_settings ADD COLUMN season_window text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='season_settings' AND column_name='format_cycle') THEN
    ALTER TABLE season_settings ADD COLUMN format_cycle text DEFAULT 'Bullet / Blitz / Rapid';
  END IF;
END $$;

-- RLS for season_settings
ALTER TABLE season_settings ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='season_settings' AND policyname='anon_read_seasons') THEN
    CREATE POLICY "anon_read_seasons" ON season_settings FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='season_settings' AND policyname='auth_insert_seasons') THEN
    CREATE POLICY "auth_insert_seasons" ON season_settings FOR INSERT TO authenticated WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='season_settings' AND policyname='auth_update_seasons') THEN
    CREATE POLICY "auth_update_seasons" ON season_settings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='season_settings' AND policyname='auth_delete_seasons') THEN
    CREATE POLICY "auth_delete_seasons" ON season_settings FOR DELETE TO authenticated USING (true);
  END IF;
END $$;

-- ── announcements ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS announcements (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title      text NOT NULL,
  body       text,
  pinned     boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='announcements' AND policyname='Public read announcements') THEN
    CREATE POLICY "Public read announcements" ON announcements FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='announcements' AND policyname='Auth insert announcements') THEN
    CREATE POLICY "Auth insert announcements" ON announcements FOR INSERT TO authenticated WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='announcements' AND policyname='Auth delete announcements') THEN
    CREATE POLICY "Auth delete announcements" ON announcements FOR DELETE TO authenticated USING (true);
  END IF;
END $$;

-- ── snapshot_overrides ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS snapshot_overrides (
  id         text PRIMARY KEY,
  items      jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE snapshot_overrides ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='snapshot_overrides' AND policyname='anon_read_snapshot') THEN
    CREATE POLICY "anon_read_snapshot" ON snapshot_overrides FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='snapshot_overrides' AND policyname='auth_write_snapshot') THEN
    CREATE POLICY "auth_write_snapshot" ON snapshot_overrides FOR ALL USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ── round_tournament_links ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS round_tournament_links (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_key         text NOT NULL,
  round_number       integer NOT NULL,
  tournament_url_id  text,
  pgn_cache          jsonb,        -- cached game list: [{url,uuid,white,black,pgn}, ...]
  pgn_synced_at      timestamptz,  -- when pgn_cache was last populated
  updated_at         timestamptz DEFAULT now(),
  UNIQUE(season_key, round_number)
);
-- Add columns to existing deployments (idempotent)
ALTER TABLE round_tournament_links ADD COLUMN IF NOT EXISTS pgn_cache     jsonb;
ALTER TABLE round_tournament_links ADD COLUMN IF NOT EXISTS pgn_synced_at timestamptz;
ALTER TABLE round_tournament_links ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='round_tournament_links' AND policyname='anon_read_tourney_links') THEN
    CREATE POLICY "anon_read_tourney_links" ON round_tournament_links FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='round_tournament_links' AND policyname='auth_write_tourney_links') THEN
    CREATE POLICY "auth_write_tourney_links" ON round_tournament_links FOR ALL USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ── brilliant_moves ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS brilliant_moves (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_key     text NOT NULL,
  round_number   integer NOT NULL,
  player_name    text NOT NULL,
  chess_username text NOT NULL,
  match_desc     text,
  game_link      text,
  caption        text,
  screenshot_url text,
  created_at     timestamptz DEFAULT now()
);
ALTER TABLE brilliant_moves ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='brilliant_moves' AND policyname='anon_read_brilliants') THEN
    CREATE POLICY "anon_read_brilliants" ON brilliant_moves FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='brilliant_moves' AND policyname='auth_write_brilliants') THEN
    CREATE POLICY "auth_write_brilliants" ON brilliant_moves FOR ALL USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ── admin_log ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admin_log (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action       text NOT NULL,
  detail       text,
  performed_by text,
  created_at   timestamptz DEFAULT now()
);
ALTER TABLE admin_log ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='admin_log' AND policyname='auth_read_log') THEN
    CREATE POLICY "auth_read_log" ON admin_log FOR SELECT USING (auth.role() = 'authenticated');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='admin_log' AND policyname='auth_insert_log') THEN
    CREATE POLICY "auth_insert_log" ON admin_log FOR INSERT TO authenticated WITH CHECK (true);
  END IF;
END $$;

-- ── registrations ────────────────────────────────────────────────────────────
-- register.html inserts rows (status='pending').
-- admin.html reads, updates status, bulk-accepts/rejects, exports CSV.
--
-- Privacy design:
--   - contact_text (WhatsApp etc.) is stored in registration_contacts (auth-only)
--   - registrations itself stores only non-sensitive fields
--   - anon users can read ONLY their own row via lookup_token (given at signup)
--   - removing anon full-table SELECT prevents scraping all player data
CREATE TABLE IF NOT EXISTS registrations (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_key     text NOT NULL,
  full_name      text NOT NULL,
  class_name     text,
  chess_username text NOT NULL,
  lookup_token   text NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'),  -- shown to user at signup for status checks
  status         text NOT NULL DEFAULT 'pending', -- 'pending' | 'accepted' | 'rejected'
  notes          text,
  created_at     timestamptz DEFAULT now()
);
-- Add lookup_token to existing deployments
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='registrations' AND column_name='lookup_token') THEN
    ALTER TABLE registrations ADD COLUMN lookup_token text NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex');
  END IF;
END $$;
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  -- Anyone can submit the signup form
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='registrations' AND policyname='anon_insert_registrations') THEN
    CREATE POLICY "anon_insert_registrations" ON registrations FOR INSERT TO anon WITH CHECK (true);
  END IF;
  -- Remove old unrestricted anon read policy if it exists
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename='registrations' AND policyname='anon_read_registrations') THEN
    DROP POLICY "anon_read_registrations" ON registrations;
  END IF;
  -- Remove old header-based policy if it exists (replaced by RPC below)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename='registrations' AND policyname='anon_read_own_registration') THEN
    DROP POLICY "anon_read_own_registration" ON registrations;
  END IF;
  -- No anon SELECT on registrations at all — status checks go through get_registration_status() RPC
  -- Admin can read all, update status, delete
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='registrations' AND policyname='auth_all_registrations') THEN
    CREATE POLICY "auth_all_registrations" ON registrations FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ── registration_contacts ─────────────────────────────────────────────────────
-- Stores sensitive contact info (WhatsApp etc.) separately from registrations.
-- Only authenticated (admin) users can read this.
CREATE TABLE IF NOT EXISTS registration_contacts (
  registration_id uuid PRIMARY KEY REFERENCES registrations(id) ON DELETE CASCADE,
  contact_text    text,
  created_at      timestamptz DEFAULT now()
);
ALTER TABLE registration_contacts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  -- Only admin (authenticated) can read or write contact info
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='registration_contacts' AND policyname='auth_all_contacts') THEN
    CREATE POLICY "auth_all_contacts" ON registration_contacts FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ── rules_content ──────────────────────────────────────────────────────────
-- Stores editable rules for rules.html, managed by admin.html Rules Editor.
-- One row per document version snapshot; the latest is determined by updated_at.
-- Structure of 'sections' column (jsonb array):
--   [ { "num": 1, "title": "Platform & Schedule", "rules": [ { "num": "1.1", "text": "..." }, ... ] }, ... ]
CREATE TABLE IF NOT EXISTS rules_content (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version     text NOT NULL DEFAULT '9.7',    -- e.g. "9.7", "9.8", "10.0"
  sections    jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  text
);
ALTER TABLE rules_content ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='rules_content' AND policyname='anon_read_rules') THEN
    CREATE POLICY "anon_read_rules" ON rules_content FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='rules_content' AND policyname='auth_write_rules') THEN
    CREATE POLICY "auth_write_rules" ON rules_content FOR ALL USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ── storage: private_uploads bucket policies ─────────────────────────────────
-- Authenticated users can upload, update, and read files.
-- Anon users can READ (needed for public pages: tournaments.html, home page, etc.)
-- createSignedUrl requires a SELECT policy for the calling role.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='objects' AND schemaname='storage' AND policyname='Auth upload private_uploads'
  ) THEN
    CREATE POLICY "Auth upload private_uploads"
      ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'private_uploads');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='objects' AND schemaname='storage' AND policyname='Auth update private_uploads'
  ) THEN
    CREATE POLICY "Auth update private_uploads"
      ON storage.objects FOR UPDATE TO authenticated
      USING (bucket_id = 'private_uploads');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='objects' AND schemaname='storage' AND policyname='Auth read private_uploads'
  ) THEN
    CREATE POLICY "Auth read private_uploads"
      ON storage.objects FOR SELECT TO authenticated
      USING (bucket_id = 'private_uploads');
  END IF;

  -- Allow anon users to read (required for createSignedUrl on public pages)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='objects' AND schemaname='storage' AND policyname='Anon read private_uploads'
  ) THEN
    CREATE POLICY "Anon read private_uploads"
      ON storage.objects FOR SELECT TO anon
      USING (bucket_id = 'private_uploads');
  END IF;
END $$;

-- ── live_games ────────────────────────────────────────────────────────────────
-- Stores current live game state for realtime broadcast during match nights.
-- Admin syncs PGN/FEN from Chess.com; viewers subscribe via Supabase Realtime.
-- One row per active game per round. Cleared/reset each round by admin.
CREATE TABLE IF NOT EXISTS live_games (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_key   text NOT NULL,
  round_number integer NOT NULL,
  board_slot   integer NOT NULL DEFAULT 1,  -- display order (1=feature, 2-N=arena)
  white_name   text,
  black_name   text,
  white_username text,
  black_username text,
  pgn          text,
  fen          text DEFAULT 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  status       text NOT NULL DEFAULT 'waiting',  -- 'waiting' | 'live' | 'done'
  result       text,  -- '1-0' | '0-1' | '1/2-1/2' | null
  game_link    text,
  is_featured  boolean NOT NULL DEFAULT false,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(season_key, round_number, board_slot)
);
-- Enable realtime for this table (run ALTER PUBLICATION in Supabase dashboard too)
ALTER TABLE live_games REPLICA IDENTITY FULL;
ALTER TABLE live_games ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='live_games' AND policyname='anon_read_live_games') THEN
    CREATE POLICY "anon_read_live_games" ON live_games FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='live_games' AND policyname='auth_write_live_games') THEN
    CREATE POLICY "auth_write_live_games" ON live_games FOR ALL USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ── live_chat ─────────────────────────────────────────────────────────────────
-- Spectator chat for live-match-viewer.html
CREATE TABLE IF NOT EXISTS live_chat (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_key   text NOT NULL,
  round_number integer NOT NULL,
  username     text NOT NULL,
  message      text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE live_chat REPLICA IDENTITY FULL;
ALTER TABLE live_chat ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='live_chat' AND policyname='anon_read_chat') THEN
    CREATE POLICY "anon_read_chat" ON live_chat FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='live_chat' AND policyname='anon_insert_chat') THEN
    CREATE POLICY "anon_insert_chat" ON live_chat FOR INSERT TO anon
      WITH CHECK (
        char_length(trim(username)) BETWEEN 1 AND 50
        AND char_length(trim(message)) BETWEEN 1 AND 300
      );
  END IF;
  -- Replace old unbounded policy if it exists (idempotent upgrade)
  -- Run this once manually if the old policy was already created:
  -- DROP POLICY "anon_insert_chat" ON live_chat;
  -- Then re-run this migration to recreate it with bounds.
END $$;

-- ── hall_of_fame ──────────────────────────────────────────────────────────────
-- Stores historic season champions and notable games for hall-of-fame.html
CREATE TABLE IF NOT EXISTS hall_of_fame (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_key   text NOT NULL,
  season_label text NOT NULL,
  champion     text NOT NULL,         -- player display name
  chess_username text,
  podium       jsonb DEFAULT '[]',    -- [{place:2,name:'...',username:'...'},{place:3,...}]
  best_game_pgn text,
  best_game_link text,
  best_game_desc text,
  season_year  integer,
  display_order integer DEFAULT 0,
  created_at   timestamptz DEFAULT now()
);
ALTER TABLE hall_of_fame ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='hall_of_fame' AND policyname='anon_read_hof') THEN
    CREATE POLICY "anon_read_hof" ON hall_of_fame FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='hall_of_fame' AND policyname='auth_write_hof') THEN
    CREATE POLICY "auth_write_hof" ON hall_of_fame FOR ALL USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ── get_registration_status (RPC) ────────────────────────────────────────────
-- Safe token-based status lookup for register.html.
-- Callable by anon via supabaseClient.rpc('get_registration_status', { token }).
-- Returns only non-sensitive fields: season_key, full_name, status, created_at.
-- Never exposes contact_text, notes, or other private columns.
CREATE OR REPLACE FUNCTION get_registration_status(token text)
RETURNS TABLE (
  season_key  text,
  full_name   text,
  status      text,
  created_at  timestamptz
)
LANGUAGE sql
SECURITY DEFINER  -- runs as DB owner, bypasses RLS for this query only
STABLE
AS $$
  SELECT season_key, full_name, status, created_at
  FROM registrations
  WHERE lookup_token = token
  ORDER BY created_at DESC;
$$;

-- Allow anon to call this function
GRANT EXECUTE ON FUNCTION get_registration_status(text) TO anon;
