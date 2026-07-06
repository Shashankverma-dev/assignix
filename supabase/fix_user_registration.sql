-- ==========================================
-- 1. Create a function to handle new user registration
-- ==========================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    base_username TEXT;
    final_username TEXT;
    counter INTEGER := 0;
BEGIN
    -- 1. Handle Username Collisions
    base_username := COALESCE(new.raw_user_meta_data->>'username', LOWER(REPLACE(new.email, '@', '_')));
    final_username := base_username;

    WHILE EXISTS (SELECT 1 FROM public.users WHERE username = final_username AND id != new.id) LOOP
        counter := counter + 1;
        final_username := base_username || counter::text;
    END LOOP;

    -- 2. Upsert Logic: Handle pre-existing profiles created by Admins
    -- We use ON CONFLICT (email) to link the new Auth ID to the existing profile.
    -- Thanks to ON UPDATE CASCADE, all references will be preserved.
    
    INSERT INTO public.users (id, email, name, username, role)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'name', ''),
        final_username,
        new.raw_user_meta_data->>'role' -- Keep NULL if not provided in raw_user_meta_data (e.g. Google Sign-in)
    )
    ON CONFLICT (email) DO UPDATE SET
        id = EXCLUDED.id,
        name = CASE WHEN public.users.name = '' OR public.users.name IS NULL THEN EXCLUDED.name ELSE public.users.name END,
        username = CASE WHEN public.users.username LIKE 'user_%' THEN EXCLUDED.username ELSE public.users.username END,
        role = COALESCE(public.users.role, EXCLUDED.role), -- Preserve existing role, don't overwrite if already set
        updated_at = now();

    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- 2. Create the trigger on auth.users
-- ==========================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- 3. Update RLS Policies for Users Table
-- ==========================================

-- Allow anyone to check if a username exists during signup
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
CREATE POLICY "Public profiles are viewable by everyone" ON users
  FOR SELECT USING (true);

-- Allow users to update their own profile EXCEPT the role (unless current role is NULL)
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND 
    (
      role IS NOT DISTINCT FROM (SELECT role FROM users WHERE id = auth.uid())
      OR
      (SELECT role FROM users WHERE id = auth.uid()) IS NULL
    )
  );

-- Admin override for updates
DROP POLICY IF EXISTS "Admins can update users" ON users;
CREATE POLICY "Admins can update users" ON users 
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
