-- Reset any aborted transaction
ROLLBACK;

-- 1. Create the necessary tables
CREATE TABLE IF NOT EXISTS TransactionFailureLog (
    log_id SERIAL PRIMARY KEY,
    error_message TEXT NOT NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- 2. Create a BEFORE trigger function that will run before the insert
CREATE OR REPLACE FUNCTION check_track_and_log()
RETURNS TRIGGER AS $$
BEGIN
    -- Check for NULL album_id
    IF NEW.album_id IS NULL THEN
        -- Log the failure attempt directly in TransactionFailureLog
        INSERT INTO TransactionFailureLog (error_message)
        VALUES ('Prevented insert of track: ' || NEW.track_name || ' (NULL album_id)');
        
        -- Return NULL to prevent the insert
        RETURN NULL;
    END IF;
    
    -- If album_id is not NULL, allow the insert to proceed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create the BEFORE INSERT trigger
DROP TRIGGER IF EXISTS track_before_insert ON Tracks;
CREATE TRIGGER track_before_insert
BEFORE INSERT ON Tracks
FOR EACH ROW
EXECUTE FUNCTION check_track_and_log();

-- 4. Clear existing logs for clean testing
TRUNCATE TransactionFailureLog;

-- 5. Test with a successful insert
INSERT INTO Tracks (track_id, track_name, album_id, explicit, popularity, duration_ms, track_genre)
VALUES ('simple_success_5', 'Good Track with Album', 1, FALSE, 80, 210000, 'Rock')
ON CONFLICT (track_id) DO NOTHING;

-- 6. Test with a failing insert (NULL album_id)
INSERT INTO Tracks (track_id, track_name, album_id, explicit, popularity, duration_ms, track_genre)
VALUES ('simple_fail', 'Bad Track No Album', NULL, FALSE, 75, 195000, 'Jazz')
ON CONFLICT (track_id) DO NOTHING;

-- 7. Check which tracks were inserted
SELECT * FROM Tracks WHERE track_id IN ('simple_success_5', 'simple_fail');

-- 8. Check if the error was logged
SELECT * FROM TransactionFailureLog ORDER BY logged_at DESC;
