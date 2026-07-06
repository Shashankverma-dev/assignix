-- ==========================================
-- SUPABASE RLS POLICIES - FINAL STABILIZATION
-- Run this in the Supabase SQL Editor
-- ==========================================

-- 0. Cleanup ALL potential legacy policies to prevent recursion
-- This is critical because old recursive policies might still exist under different names
DO $$ 
BEGIN
    -- Drop all known names we've used for users table
    DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
    DROP POLICY IF EXISTS "Users can update their own profile" ON users;
    DROP POLICY IF EXISTS "Admins can do everything with users" ON users;
    DROP POLICY IF EXISTS "Admins can manage all users" ON users;
    DROP POLICY IF EXISTS "Admins can insert users" ON users;
    DROP POLICY IF EXISTS "Admins can update users" ON users;
    DROP POLICY IF EXISTS "Admins can delete users" ON users;
    
    -- Drop all known names for challenges
    DROP POLICY IF EXISTS "Challenges are viewable by everyone" ON challenges;
    DROP POLICY IF EXISTS "Users can manage challenges they created" ON challenges;
    DROP POLICY IF EXISTS "Admins can manage all challenges" ON challenges;
    
    -- Drop all known names for submissions
    DROP POLICY IF EXISTS "Users can view their own submissions" ON submissions;
    DROP POLICY IF EXISTS "Users can insert their own submissions" ON submissions;
    DROP POLICY IF EXISTS "Admins can view all submissions" ON submissions;
END $$;

-- 1. Helper Functions (Security Definer to avoid recursion)
CREATE OR REPLACE FUNCTION is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND LOWER(role) = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION is_teacher() 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND LOWER(role) IN ('teacher', 'admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE problems ENABLE ROW LEVEL SECURITY;
ALTER TABLE solved_problems ENABLE ROW LEVEL SECURITY;
ALTER TABLE classrooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE classroom_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_participants ENABLE ROW LEVEL SECURITY;

-- 3. USERS Table Policies (The most critical ones)
-- This policy allows EVERYONE to select, and because it's just 'true', it's NOT recursive.
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
CREATE POLICY "Public profiles are viewable by everyone" ON users
  FOR SELECT USING (true);

-- Users can update their own profile (basic metadata only, role handled below)
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
-- This policy is redundant now, we use the restrictive one below

-- Write policies for admins (only trigger on insert/update/delete)
DROP POLICY IF EXISTS "Admins can insert users" ON users;
CREATE POLICY "Admins can insert users" ON users FOR INSERT WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Admins can update users" ON users;
CREATE POLICY "Admins can update users" ON users FOR UPDATE USING (is_admin());

DROP POLICY IF EXISTS "Admins can delete users" ON users;
CREATE POLICY "Admins can delete users" ON users FOR DELETE USING (is_admin());

-- 4. Prevent users from changing their own role during update (unless current role is NULL)
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

-- 4. CHALLENGES (Arena) Policies
DROP POLICY IF EXISTS "Challenges are viewable by everyone" ON challenges;
CREATE POLICY "Challenges are viewable by everyone" ON challenges
  FOR SELECT USING (
    is_private = false OR 
    auth.uid() = created_by OR 
    EXISTS (SELECT 1 FROM challenge_participants WHERE challenge_id = challenges.id AND user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Users and admins can manage challenges" ON challenges;
CREATE POLICY "Users and admins can manage challenges" ON challenges
  FOR ALL USING (auth.uid() = created_by OR is_admin());

-- 5. CHALLENGE_PARTICIPANTS Policies
DROP POLICY IF EXISTS "Participants are viewable by everyone" ON challenge_participants;
CREATE POLICY "Participants are viewable by everyone" ON challenge_participants
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can join challenges" ON challenge_participants;
CREATE POLICY "Users can join challenges" ON challenge_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own progress" ON challenge_participants;
CREATE POLICY "Users can update their own progress" ON challenge_participants
  FOR UPDATE USING (is_teacher())
  WITH CHECK (is_teacher());

DROP POLICY IF EXISTS "Admins can manage all participants" ON challenge_participants;
CREATE POLICY "Admins can manage all participants" ON challenge_participants
  FOR ALL USING (is_teacher());

-- 6. SUBMISSIONS Table Policies
DROP POLICY IF EXISTS "Users can view their own submissions" ON submissions;
CREATE POLICY "Users can view their own submissions" ON submissions
  FOR SELECT USING (
    auth.uid() = user_id OR 
    is_admin() OR
    (is_teacher() AND EXISTS (
      SELECT 1 FROM classrooms c
      JOIN classroom_students cs ON c.id = cs.classroom_id
      WHERE c.teacher_id = auth.uid() AND cs.student_id = submissions.user_id
    ))
  );

DROP POLICY IF EXISTS "Users can insert their own submissions" ON submissions;
CREATE POLICY "Users can insert their own submissions" ON submissions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 7. Remaining Tables (Standard Policies)
DROP POLICY IF EXISTS "Courses are viewable by everyone" ON courses;
CREATE POLICY "Courses are viewable by everyone" ON courses FOR SELECT USING (true);

DROP POLICY IF EXISTS "Teachers and Admins can manage courses" ON courses;
CREATE POLICY "Teachers and Admins can manage courses" ON courses 
  FOR ALL USING (is_teacher());

-- Harden problems table: hide sensitive columns from public/authenticated roles
REVOKE SELECT (test_cases, starter_code) ON problems FROM authenticated;
REVOKE SELECT (test_cases, starter_code) ON problems FROM anon;

DROP POLICY IF EXISTS "Problems are viewable by everyone" ON problems;
CREATE POLICY "Problems are viewable by everyone" ON problems 
  FOR SELECT USING (is_approved = true OR is_admin() OR is_teacher());

DROP POLICY IF EXISTS "Users can insert their own problems" ON problems;
CREATE POLICY "Users can insert their own problems" ON problems 
  FOR INSERT WITH CHECK (
    (is_teacher()) OR 
    (auth.uid() = creator_id AND is_arena_problem = true AND is_approved = false)
  );

DROP POLICY IF EXISTS "Admins and Teachers can manage problems" ON problems;
CREATE POLICY "Admins and Teachers can manage problems" ON problems 
  FOR ALL USING (is_teacher());

DROP POLICY IF EXISTS "Users can see classrooms they belong to" ON classrooms;
CREATE POLICY "Users can see classrooms they belong to" ON classrooms 
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Teachers and Admins can manage classrooms" ON classrooms;
CREATE POLICY "Teachers and Admins can manage classrooms" ON classrooms
  FOR ALL USING (teacher_id = auth.uid() OR is_admin());

-- NEW POLICIES FOR STABILITY

-- Allow users to insert their own profile during signup (kept as fallback, but trigger is primary)
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
CREATE POLICY "Users can insert their own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id OR (SELECT count(*) FROM users) = 0);

-- Classroom Students (Joining & Management)
DROP POLICY IF EXISTS "Users can see their own classroom memberships" ON classroom_students;
CREATE POLICY "Users can see their own classroom memberships" ON classroom_students
  FOR SELECT USING (auth.uid() = student_id OR is_teacher());

DROP POLICY IF EXISTS "Users can join and teachers can manage students" ON classroom_students;
CREATE POLICY "Users can join and teachers can manage students" ON classroom_students
  FOR ALL USING (
    (auth.uid() = student_id AND EXISTS (
      -- Check if they are joining with a valid code (this is a simplified check)
      -- In a real scenario, this would be handled by the joinClassroom service calling an RPC
      SELECT 1 FROM classrooms WHERE id = classroom_students.classroom_id
    )) OR 
    is_teacher() OR 
    is_admin()
  );

-- Friendships
DROP POLICY IF EXISTS "Users can see their own friendships" ON friendships;
CREATE POLICY "Users can see their own friendships" ON friendships
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

DROP POLICY IF EXISTS "Users can manage their own friendships" ON friendships;
CREATE POLICY "Users can manage their own friendships" ON friendships
  FOR ALL USING (auth.uid() = user_id);

-- Friend Requests
DROP POLICY IF EXISTS "Users can see their own friend requests" ON friend_requests;
CREATE POLICY "Users can see their own friend requests" ON friend_requests
  FOR SELECT USING (auth.uid() = from_id OR auth.uid() = to_id);

DROP POLICY IF EXISTS "Users can send friend requests" ON friend_requests;
CREATE POLICY "Users can send friend requests" ON friend_requests
  FOR INSERT WITH CHECK (auth.uid() = from_id);

DROP POLICY IF EXISTS "Users can manage their own friend requests" ON friend_requests;
CREATE POLICY "Users can manage their own friend requests" ON friend_requests
  FOR ALL USING (auth.uid() = from_id OR auth.uid() = to_id);

-- Notifications
DROP POLICY IF EXISTS "Users can see their own notifications" ON notifications;
CREATE POLICY "Users can see their own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id OR is_teacher());

DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- Allow notifications to be created by the system/triggers
DROP POLICY IF EXISTS "Anyone can create notifications" ON notifications;
CREATE POLICY "Anyone can create notifications" ON notifications
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can send notifications" ON notifications;

-- Assignments
DROP POLICY IF EXISTS "Assignments are viewable by classroom members" ON assignments;
CREATE POLICY "Assignments are viewable by classroom members" ON assignments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM classroom_students 
      WHERE classroom_id = assignments.classroom_id AND student_id = auth.uid()
    ) OR 
    EXISTS (
      SELECT 1 FROM classrooms
      WHERE id = assignments.classroom_id AND teacher_id = auth.uid()
    ) OR
    is_admin()
  );

DROP POLICY IF EXISTS "Teachers and Admins can manage assignments" ON assignments;
CREATE POLICY "Teachers and Admins can manage assignments" ON assignments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM classrooms
      WHERE id = assignments.classroom_id AND teacher_id = auth.uid()
    ) OR is_admin()
  );

-- Solved Problems
DROP POLICY IF EXISTS "Users can manage their own solved problems" ON solved_problems;
CREATE POLICY "Users can manage their own solved problems" ON solved_problems
  FOR SELECT USING (
    auth.uid() = user_id OR 
    is_admin() OR
    (is_teacher() AND EXISTS (
      SELECT 1 FROM classrooms c
      JOIN classroom_students cs ON c.id = cs.classroom_id
      WHERE c.teacher_id = auth.uid() AND cs.student_id = solved_problems.user_id
    ))
  );

DROP POLICY IF EXISTS "Admins can manage all solved problems" ON solved_problems;
CREATE POLICY "Admins can manage all solved problems" ON solved_problems
  FOR ALL USING (is_admin());

-- Arena Registrations
ALTER TABLE arena_registrations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own registrations" ON arena_registrations;
CREATE POLICY "Users can manage their own registrations" ON arena_registrations
  FOR ALL USING (auth.uid() = user_id OR is_admin());
