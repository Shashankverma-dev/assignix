-- ==========================================
-- DEEP PLATFORM HARDENING
-- ==========================================

-- 1. HARDEN RLS POLICIES
-- ==========================================

-- 1.1 Tighten Classroom Student Management
-- Only the teacher of the classroom or the student themselves can manage memberships.
DROP POLICY IF EXISTS "Users can join and teachers can manage students" ON classroom_students;
CREATE POLICY "Users can join and teachers can manage students" ON classroom_students
  FOR ALL USING (
    auth.uid() = student_id OR 
    EXISTS (
      SELECT 1 FROM classrooms 
      WHERE id = classroom_students.classroom_id AND teacher_id = auth.uid()
    ) OR
    is_admin()
  );

-- 1.2 Tighten Course Management
-- Only the instructor or an admin can manage courses.
DROP POLICY IF EXISTS "Teachers and Admins can manage courses" ON courses;
CREATE POLICY "Teachers and Admins can manage courses" ON courses 
  FOR ALL USING (instructor_id = auth.uid() OR is_admin());

-- 1.3 Tighten Problem Management
-- Only the creator or an admin can manage problems.
DROP POLICY IF EXISTS "Admins and Teachers can manage problems" ON problems;
CREATE POLICY "Admins and Teachers can manage problems" ON problems 
  FOR ALL USING (creator_id = auth.uid() OR is_admin());

-- 1.4 Secure Notifications (Prevent Spam)
-- Only system/admin/teachers can insert notifications.
DROP POLICY IF EXISTS "Admins and Teachers can insert notifications" ON notifications;
CREATE POLICY "Admins and Teachers can insert notifications" ON notifications 
  FOR INSERT WITH CHECK (is_admin() OR is_teacher());

-- 1.5 Column-Level Security (LEAK PREVENTION)
-- Prevent students from querying test_cases and starter_code directly.
REVOKE SELECT (test_cases, starter_code) ON problems FROM authenticated;
-- Grant it back to teachers/admins (handled via RPCs and views or explicit grants if roles existed)
-- In Supabase, we use SECURITY DEFINER RPCs to bypass this for authorized users.

-- ==========================================
-- 2. HARDENED RPC FUNCTIONS
-- ==========================================

-- 2.1 Secure Problem Fetching
-- Students see only public test cases. Teachers see everything.
DROP FUNCTION IF EXISTS get_problem_for_student(TEXT);
CREATE OR REPLACE FUNCTION get_problem_for_student(p_id_or_slug TEXT)
RETURNS JSONB AS $$
DECLARE
    v_problem JSONB;
BEGIN
    -- Support lookup by both slug and UUID id
    SELECT row_to_json(p)::jsonb INTO v_problem
    FROM problems p
    WHERE p.slug = p_id_or_slug OR p.id::text = p_id_or_slug;

    IF v_problem IS NULL THEN
        RETURN NULL;
    END IF;

    -- If user is NOT a teacher, filter hidden test cases
    IF NOT is_teacher() THEN
        v_problem := v_problem || jsonb_build_object(
            'test_cases', (
                SELECT jsonb_agg(tc)
                FROM jsonb_array_elements(CASE 
                    WHEN jsonb_typeof(v_problem->'test_cases') = 'array' THEN v_problem->'test_cases' 
                    ELSE '[]'::jsonb 
                END) tc
                WHERE (tc->>'isHidden')::boolean = false
            )
        );
    END IF;

    RETURN v_problem;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2.2 Secure XP and Submission Verification
-- Server determines success and awards XP atomically.
CREATE OR REPLACE FUNCTION handle_arena_submission_success()
RETURNS TRIGGER AS $$
DECLARE
    v_xp_to_add INTEGER;
    v_challenge_id UUID;
BEGIN
    -- Only process if status is 'Accepted' and it's a new acceptance
    IF (NEW.status = 'Accepted' AND (OLD.status IS NULL OR OLD.status != 'Accepted')) THEN
        -- 1. Calculate XP based on difficulty
        SELECT CASE 
            WHEN p.difficulty = 'Easy' THEN 10
            WHEN p.difficulty = 'Medium' THEN 25
            WHEN p.difficulty = 'Hard' THEN 50
            ELSE 5
        END INTO v_xp_to_add
        FROM problems p WHERE p.id = NEW.problem_id;

        -- 2. Update User Stats atomically
        UPDATE users SET 
            xp = xp + v_xp_to_add,
            problems_solved = problems_solved + 1,
            last_activity = now()
        WHERE id = NEW.user_id;

        -- 3. Update Challenge stats if applicable
        FOR v_challenge_id IN 
            SELECT challenge_id FROM challenge_problems WHERE problem_id = NEW.problem_id
        LOOP
            UPDATE challenge_participants SET 
                solved_problems = COALESCE(solved_problems, '[]'::jsonb) || jsonb_build_object(
                    'problemId', NEW.problem_id,
                    'solvedAt', now()
                ),
                updated_at = now()
            WHERE challenge_id = v_challenge_id 
              AND user_id = NEW.user_id
              AND NOT EXISTS (
                  -- Crucial: Prevent double-counting
                  SELECT 1 FROM jsonb_array_elements(COALESCE(solved_problems, '[]'::jsonb)) AS elem
                  WHERE (elem->>'problemId')::uuid = NEW.problem_id
              );
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for the above
DROP TRIGGER IF EXISTS on_submission_accepted ON submissions;
CREATE TRIGGER on_submission_accepted
AFTER UPDATE OR INSERT ON submissions
FOR EACH ROW EXECUTE FUNCTION handle_arena_submission_success();

-- 2.3 Hardened Submission Flow
DROP FUNCTION IF EXISTS public.submit_problem_solution(uuid, text, text, uuid, uuid);
DROP FUNCTION IF EXISTS public.submit_problem_solution(uuid, text, text, uuid, uuid, boolean);

CREATE OR REPLACE FUNCTION submit_problem_solution(
    p_problem_id UUID,
    p_code TEXT,
    p_language TEXT,
    p_classroom_id UUID DEFAULT NULL,
    p_assignment_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_status TEXT;
    v_submission submissions%ROWTYPE;
    v_user_stats JSONB;
BEGIN
    -- In a real system, we'd run the code here. For now, we simulate 'Accepted'
    -- but we DO NOT take a boolean from the client.
    v_status := 'Accepted'; 

    -- Trusted session
    PERFORM set_config('app.trusted_submission', 'true', true);

    -- Insert submission
    INSERT INTO submissions (
        user_id, problem_id, code, language, 
        classroom_id, assignment_id, status
    ) VALUES (
        auth.uid(), p_problem_id, p_code, p_language, 
        p_classroom_id, p_assignment_id, v_status
    ) RETURNING * INTO v_submission;

    PERFORM set_config('app.trusted_submission', 'false', true);

    -- Fetch updated user stats to return to frontend
    SELECT jsonb_build_object(
        'xp', xp,
        'streak', streak,
        'problems_solved', problems_solved
    ) INTO v_user_stats
    FROM users WHERE id = auth.uid();

    RETURN jsonb_build_object(
        'submission', row_to_json(v_submission),
        'user_stats', v_user_stats
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.4 Admin Problem Management (Bypasses REVOKE)
CREATE OR REPLACE FUNCTION admin_manage_problem(
    p_op TEXT, -- 'SELECT', 'INSERT', 'UPDATE'
    p_id UUID DEFAULT NULL,
    p_data JSONB DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    IF NOT is_teacher() THEN
        RAISE EXCEPTION 'Unauthorized: Teacher or Admin role required';
    END IF;

    IF p_op = 'SELECT' THEN
        IF p_id IS NULL THEN
            SELECT jsonb_agg(row_to_json(p)) INTO v_result FROM problems p;
        ELSE
            SELECT row_to_json(p)::jsonb INTO v_result FROM problems p WHERE id = p_id;
        END IF;
    ELSIF p_op = 'INSERT' THEN
        INSERT INTO problems (
            title, slug, difficulty, category, course, description, 
            test_cases, starter_code, is_practice, is_approved, 
            is_arena_problem, hardness_score, tags, examples, constraints,
            creator_id
        ) VALUES (
            p_data->>'title', 
            COALESCE(p_data->>'slug', LOWER(REGEXP_REPLACE(p_data->>'title', '[^a-zA-Z0-9]+', '-', 'g'))),
            p_data->>'difficulty', p_data->>'category', p_data->>'course', p_data->>'description',
            p_data->'test_cases', p_data->'starter_code', (p_data->>'is_practice')::boolean, 
            (p_data->>'is_approved')::boolean, (p_data->>'is_arena_problem')::boolean, 
            (p_data->>'hardness_score')::integer, 
            (SELECT array_agg(x) FROM jsonb_array_elements_text(p_data->'tags') x),
            p_data->'examples', (SELECT array_agg(x) FROM jsonb_array_elements_text(p_data->'constraints') x),
            auth.uid()
        ) RETURNING row_to_json(problems)::jsonb INTO v_result;
    ELSIF p_op = 'UPDATE' THEN
        UPDATE problems SET
            title = COALESCE(p_data->>'title', title),
            difficulty = COALESCE(p_data->>'difficulty', difficulty),
            category = COALESCE(p_data->>'category', category),
            course = COALESCE(p_data->>'course', course),
            description = COALESCE(p_data->>'description', description),
            test_cases = COALESCE(p_data->'test_cases', test_cases),
            starter_code = COALESCE(p_data->'starter_code', starter_code),
            is_practice = COALESCE((p_data->>'is_practice')::boolean, is_practice),
            is_approved = COALESCE((p_data->>'is_approved')::boolean, is_approved),
            is_arena_problem = COALESCE((p_data->>'is_arena_problem')::boolean, is_arena_problem),
            hardness_score = COALESCE((p_data->>'hardness_score')::integer, hardness_score),
            tags = COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(p_data->'tags') x), tags),
            examples = COALESCE(p_data->'examples', examples),
            constraints = COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(p_data->'constraints') x), constraints),
            updated_at = now()
        WHERE id = p_id
        RETURNING row_to_json(problems)::jsonb INTO v_result;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
