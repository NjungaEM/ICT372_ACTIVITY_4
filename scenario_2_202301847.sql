--Scenario 2: Computer Laboratory Reservations

DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstations INT NOT NULL CHECK (workstations > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE','CANCELLED'))
);

INSERT INTO lab_sessions(session_name, available_workstations) VALUES
('Database Practical', 30),
('Networking Practical', 5),
('Programming Practical', 0);

DO $$
DECLARE
    available INT;
BEGIN
    SELECT available_workstations INTO available
    FROM lab_sessions WHERE session_id = 1;

    IF available = 0 THEN
        RAISE NOTICE 'Session is full.';
    ELSIF available <= 5 THEN
        RAISE NOTICE 'Session is nearly full.';
    ELSE
        RAISE NOTICE 'Session has enough workstations.';
    END IF;
END $$;

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation check %', i;
    END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_workstations INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid workstation quantity.';
    END IF;

    SELECT available_workstations INTO v_available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session does not exist.';
    END IF;

    IF v_available < p_workstations THEN
        RAISE NOTICE 'Reservation rejected: only % workstations available.', v_available;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations(session_id, lecturer, workstations)
    VALUES (p_session_id, p_lecturer, p_workstations);

    RAISE NOTICE 'Reservation recorded.';
END $$;

CALL reserve_workstations(1, 'Dr Banda', 10);
CALL reserve_workstations(2, 'Mr kaluba', 3);
CALL reserve_workstations(2, 'Ms Zulu', 5);

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INT;
    v_workstations INT;
BEGIN
    SELECT session_id, workstations
    INTO v_session_id, v_workstations
    FROM reservations
    WHERE reservation_id = p_reservation_id
      AND status = 'ACTIVE'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Reservation % is already cancelled or does not exist.', p_reservation_id;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations + v_workstations
    WHERE session_id = v_session_id;

    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;
END $$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

DO $$
DECLARE
    rec RECORD;
    session_cursor CURSOR FOR
        SELECT session_id, session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 5;
BEGIN
    OPEN session_cursor;
    LOOP
        FETCH session_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations: % - % available',
            rec.session_name, rec.available_workstations;
    END LOOP;
    CLOSE session_cursor;
END $$;

DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(1, 'Mr Invalid', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Exception handled: %', SQLERRM;
    END;
END $$;

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;
