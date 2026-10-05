-- Scenario 3: Student Hostel Room Allocation

DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL,
    available_bed_spaces INT NOT NULL CHECK (available_bed_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(30) NOT NULL,
    room_id INT NOT NULL REFERENCES hostel_rooms(room_id),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE','COMPLETED'))
);

INSERT INTO hostel_rooms(room_number, available_bed_spaces) VALUES
('A101', 4),
('A102', 1),
('A103', 0);

DO $$
DECLARE
    spaces INT;
BEGIN
    SELECT available_bed_spaces INTO spaces
    FROM hostel_rooms WHERE room_id = 1;

    IF spaces = 0 THEN
        RAISE NOTICE 'Room is full.';
    ELSIF spaces = 1 THEN
        RAISE NOTICE 'Room has one space left.';
    ELSE
        RAISE NOTICE 'Room has several spaces.';
    END IF;
END $$;

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Room check %', i;
    END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student_number IS NULL OR btrim(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT available_bed_spaces INTO v_spaces
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room does not exist.';
    END IF;

    IF v_spaces <= 0 THEN
        RAISE NOTICE 'Allocation rejected: room is full.';
        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces = available_bed_spaces - 1
    WHERE room_id = p_room_id;

    INSERT INTO allocations(student_number, room_id)
    VALUES (p_student_number, p_room_id);

    RAISE NOTICE 'Student allocated successfully.';
END $$;

CALL allocate_room('STU001', 1);
CALL allocate_room('STU002', 2);
CALL allocate_room('STU003', 3);

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INT;
BEGIN
    SELECT room_id INTO v_room_id
    FROM allocations
    WHERE allocation_id = p_allocation_id
      AND status = 'ACTIVE'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Allocation % is already completed or does not exist.', p_allocation_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces = available_bed_spaces + 1
    WHERE room_id = v_room_id;

    UPDATE allocations
    SET status = 'COMPLETED'
    WHERE allocation_id = p_allocation_id;
END $$;

CALL check_out(1);
CALL check_out(1);

DO $$
DECLARE
    rec RECORD;
    room_cursor CURSOR FOR
        SELECT room_id, room_number, available_bed_spaces
        FROM hostel_rooms
        WHERE available_bed_spaces <= 1;
BEGIN
    OPEN room_cursor;
    LOOP
        FETCH room_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/nearly full room: % - % spaces',
            rec.room_number, rec.available_bed_spaces;
    END LOOP;
    CLOSE room_cursor;
END $$;

DO $$
BEGIN
    BEGIN
        CALL allocate_room('', 1);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Exception handled: %', SQLERRM;
    END;
END $$;

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
