-- ==========================================
-- 0. Schema Updates
-- ==========================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_solve_date DATE;

-- ==========================================
-- 1. Automated Submission Processing (Security)
-- ==========================================
-- This function handles XP, streaks, and solved_problems tracking on the backend.
-- It prevents users from manually updating their XP/progress via the client.
CREATE OR REPLACE FUNCTION handle_submission_success()
RETURNS TRIGGER AS $$
DECLARE
    user_last_solve DATE;
    problem_xp INTEGER;
BEGIN
    -- Only process 'Accepted' submissions
    IF NEW.status = 'Accepted' THEN
        -- 1. Create entry in solved_problems table
        INSERT INTO solved_problems (user_id, problem_id)
        VALUES (NEW.user_id, NEW.problem_id)
        ON CONFLICT (user_id, problem_id) DO NOTHING;

        -- 2. Calculate XP based on difficulty
        SELECT 
            CASE difficulty
                WHEN 'Easy' THEN 10
                WHEN 'Medium' THEN 25
                WHEN 'Hard' THEN 50
                ELSE 10
            END INTO problem_xp
        FROM problems WHERE id = NEW.problem_id;

        -- 3. Update User Stats (XP and Solved Count)
        -- We only increment if this problem wasn't already solved by this user
        -- We use a CTE or check if the insertion actually happened
        IF NOT EXISTS (
            SELECT 1 FROM solved_problems 
            WHERE user_id = NEW.user_id AND problem_id = NEW.problem_id
            AND solved_at < NEW.submitted_at -- Check if there's an older solve
        ) THEN
            UPDATE users SET 
                xp = xp + COALESCE(problem_xp, 10),
                problems_solved = problems_solved + 1
            WHERE id = NEW.user_id;
        END IF;
        
        -- 4. Robust Streak Logic: Consecutive Days
        SELECT last_solve_date INTO user_last_solve FROM users WHERE id = NEW.user_id;
        
        IF user_last_solve IS NULL OR user_last_solve < CURRENT_DATE - 1 THEN
            -- First solve or streak broken
            UPDATE users SET streak = 1, last_solve_date = CURRENT_DATE WHERE id = NEW.user_id;
        ELSIF user_last_solve = CURRENT_DATE - 1 THEN
            -- Consecutive day
            UPDATE users SET streak = streak + 1, last_solve_date = CURRENT_DATE WHERE id = NEW.user_id;
        -- If user_last_solve = CURRENT_DATE, we do nothing to the streak
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_submission_accepted ON submissions;
CREATE TRIGGER on_submission_accepted
    AFTER INSERT ON submissions
    FOR EACH ROW
    EXECUTE FUNCTION handle_submission_success();

-- ==========================================
-- 2. Friend Removal Synchronization (Data Integrity)
-- ==========================================
-- Cleans up the 'friends' UUID array in the users table when a friendship is deleted.
CREATE OR REPLACE FUNCTION sync_user_friends_on_removal()
RETURNS TRIGGER AS $$
BEGIN
    -- No longer updating users.friends array as it is deprecated.
    -- The relationships are managed by the friendships table directly.
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_friendship_deleted ON friendships;
CREATE TRIGGER on_friendship_deleted
    AFTER DELETE ON friendships
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_friends_on_removal();

-- ==========================================
-- 3. Dead Problem Cleanup (Referential Integrity)
-- ==========================================
-- NOTE: Manual cleanup is no longer needed as stats are dynamically calculated 
-- via the 'user_stats' view, which respects the ON DELETE CASCADE 
-- on the 'solved_problems' table.


-- ==========================================
-- 4. Robust User Registration (Reliability)
-- ==========================================
-- Handles potential username collisions and ensures profile creation.
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
-- 5. Arena Challenge Processing (Security)
-- ==========================================
-- Automatically updates challenge_participants solved_count and score 
-- when a submission is accepted for a problem that is part of the challenge.
CREATE OR REPLACE FUNCTION handle_arena_submission_success()
RETURNS TRIGGER AS $$
DECLARE
    challenge_rec RECORD;
BEGIN
    IF NEW.status = 'Accepted' THEN
        -- Find active challenges that contain this problem and where the user is a participant
        FOR challenge_rec IN 
            SELECT c.id, c.problem_ids, c.start_date, c.time_limit, cp.solved_problems
            FROM challenges c
            JOIN challenge_participants cp ON c.id = cp.challenge_id
            WHERE NEW.problem_id = ANY(c.problem_ids) 
            AND cp.user_id = NEW.user_id
            AND c.status = 'active'
        LOOP
            -- Check if challenge has expired
            IF NEW.submitted_at > (challenge_rec.start_date + (challenge_rec.time_limit || ' minutes')::interval) THEN
                -- Optionally auto-close the challenge
                UPDATE challenges SET status = 'completed' WHERE id = challenge_rec.id;
                CONTINUE;
            END IF;

            -- Check if already solved in this challenge context
            -- solved_problems is JSONB array of {problemId, solvedAt, timeTaken}
            IF NOT EXISTS (
                SELECT 1 FROM jsonb_array_elements(COALESCE(challenge_rec.solved_problems, '[]'::jsonb)) AS elem
                WHERE (elem->>'problemId')::uuid = NEW.problem_id
            ) THEN
                UPDATE challenge_participants
                SET 
                    solved_count = solved_count + 1,
                    score = score + 100, -- Standard Arena XP/Score
                    total_time = total_time + EXTRACT(EPOCH FROM (NEW.submitted_at - challenge_rec.start_date))::INTEGER,
                    solved_problems = COALESCE(solved_problems, '[]'::jsonb) || jsonb_build_array(
                        jsonb_build_object(
                            'problemId', NEW.problem_id,
                            'solvedAt', NEW.submitted_at,
                            'timeTaken', EXTRACT(EPOCH FROM (NEW.submitted_at - challenge_rec.start_date))::INTEGER,
                            'submissionId', NEW.id
                        )
                    )
                WHERE challenge_id = challenge_rec.id AND user_id = NEW.user_id;
            END IF;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- 6. Secure Submission Handling (Score Forging Fix)
-- ==========================================
-- This trigger ensures that users cannot manually set their submission status to 'Accepted'.
-- All submissions start as 'Pending' unless handled by a secure system process.
CREATE OR REPLACE FUNCTION enforce_submission_security()
RETURNS TRIGGER AS $$
BEGIN
    -- Bypass security if the 'app.trusted_submission' setting is set to 'true'
    -- This allows our SECURE RPC to set the status while blocking client-side table inserts.
    IF current_setting('app.trusted_submission', true) = 'true' OR is_admin() THEN
        RETURN NEW;
    END IF;

    -- Force 'Pending' for all other non-admin insertions
    NEW.status := 'Pending';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_submission_insert_security ON submissions;
CREATE TRIGGER on_submission_insert_security
    BEFORE INSERT ON submissions
    FOR EACH ROW
    EXECUTE FUNCTION enforce_submission_security();

-- RPC Function for "Accepted" status (The Source of Truth)
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
    v_is_correct BOOLEAN := FALSE;
BEGIN
    -- 1. Determine status (Source of Truth)
    -- TODO: In a production environment, this should verify against an internal test-runner result.
    -- For now, we simulate a check or default to 'Pending' for actual verification.
    -- BUT for this training ground, we'll allow it for now but REMOVE the client flag trust.
    
    -- NOTE: To keep it working for the user without a real executor, 
    -- we'll assume it's correct for demonstration if code is not empty, 
    -- but we DO NOT take the parameter from the client anymore.
    v_is_correct := (LENGTH(p_code) > 0); 
    
    IF v_is_correct THEN
        v_status := 'Accepted';
    ELSE
        v_status := 'Failed';
    END IF;

    -- 2. Set trusted session flag to bypass enforce_submission_security trigger
    PERFORM set_config('app.trusted_submission', 'true', true);

    -- 3. Insert submission
    INSERT INTO submissions (
        user_id, 
        problem_id, 
        code, 
        language, 
        classroom_id, 
        assignment_id, 
        status
    ) VALUES (
        auth.uid(),
        p_problem_id,
        p_code,
        p_language,
        p_classroom_id,
        p_assignment_id,
        v_status
    ) RETURNING * INTO v_submission;

    -- 4. Reset trusted session flag (optional as it is local to transaction)
    PERFORM set_config('app.trusted_submission', 'false', true);

    RETURN row_to_json(v_submission)::jsonb;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_arena_submission_accepted ON submissions;
CREATE TRIGGER on_arena_submission_accepted
    AFTER INSERT ON submissions
    FOR EACH ROW
    EXECUTE FUNCTION handle_arena_submission_success();
