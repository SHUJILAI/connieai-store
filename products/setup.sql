-- ============================================================
-- 性感上岸 — Supabase 数据库初始化脚本
-- 在 Supabase Dashboard → SQL Editor 中运行此脚本
-- ============================================================

-- 1. 题库表
CREATE TABLE IF NOT EXISTS questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL CHECK (category IN ('drive', 'civil', 'ielts')),
  question TEXT NOT NULL,
  options JSONB NOT NULL,
  answer_index INTEGER NOT NULL CHECK (answer_index BETWEEN 0 AND 3),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_questions_category ON questions(category);

-- 2. 奖励图片表
CREATE TABLE IF NOT EXISTS reward_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gender TEXT NOT NULL CHECK (gender IN ('f', 'm')),
  style TEXT NOT NULL CHECK (style IN ('jp', 'kr', 'us', 'body')),
  tier TEXT NOT NULL CHECK (tier IN ('easy', 'medium', 'hard')),
  storage_path TEXT NOT NULL,
  is_preview BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_images_lookup ON reward_images(gender, style, tier);

-- 3. 启用 RLS
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_images ENABLE ROW LEVEL SECURITY;

-- 4. 公开读取 (游戏端匿名访问)
CREATE POLICY "anyone_read_questions" ON questions
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anyone_read_images" ON reward_images
  FOR SELECT TO anon, authenticated USING (true);

-- 5. 登录后写入 (管理后台)
CREATE POLICY "auth_insert_questions" ON questions
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "auth_update_questions" ON questions
  FOR UPDATE TO authenticated USING (true);
CREATE POLICY "auth_delete_questions" ON questions
  FOR DELETE TO authenticated USING (true);

CREATE POLICY "auth_insert_images" ON reward_images
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "auth_update_images" ON reward_images
  FOR UPDATE TO authenticated USING (true);
CREATE POLICY "auth_delete_images" ON reward_images
  FOR DELETE TO authenticated USING (true);

-- 6. Storage bucket (需要在 Dashboard → Storage 手动创建)
-- 创建名为 reward-images 的 public bucket
-- 或者用以下 SQL:
INSERT INTO storage.buckets (id, name, public) VALUES ('reward-images', 'reward-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: 公开读, 登录写
CREATE POLICY "public_read_storage" ON storage.objects
  FOR SELECT TO anon, authenticated USING (bucket_id = 'reward-images');
CREATE POLICY "auth_upload_storage" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'reward-images');
CREATE POLICY "auth_delete_storage" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'reward-images');
