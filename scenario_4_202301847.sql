--Scenario 4: Campus Clinic Medicine Dispensing

DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
        CHECK (status IN ('DISPENSED','REVERSED'))
);

INSERT INTO medicines(medicine_name, stock_quantity) VALUES
('Paracetamol', 50),
('Amoxicillin', 10),
('ORS', 0);

DO $$
DECLARE
    stock INT;
BEGIN
    SELECT stock_quantity INTO stock
    FROM medicines WHERE medicine_id = 1;

    IF stock = 0 THEN
        RAISE NOTICE 'Medicine is out of stock.';
    ELSIF stock <= 10 THEN
        RAISE NOTICE 'Medicine is low on stock.';
    ELSE
        RAISE NOTICE 'Medicine is sufficiently stocked.';
    END IF;
END $$;

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock review day %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection %', i;
    END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Dispensing quantity must be greater than zero.';
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine does not exist.';
    END IF;

    IF v_stock < p_quantity THEN
        RAISE NOTICE 'Dispensing rejected: only % units available.', v_stock;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records(medicine_id, student_number, quantity)
    VALUES (p_medicine_id, p_student_number, p_quantity);

    RAISE NOTICE 'Dispensing recorded.';
END $$;

CALL dispense_medicine(1, 'STU001', 5);
CALL dispense_medicine(2, 'STU002', 4);
CALL dispense_medicine(2, 'STU003', 20);

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INT;
    v_quantity INT;
BEGIN
    SELECT medicine_id, quantity INTO v_medicine_id, v_quantity
    FROM dispensing_records
    WHERE record_id = p_record_id
      AND status = 'DISPENSED'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Record % is already reversed or does not exist.', p_record_id;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records
    SET status = 'REVERSED'
    WHERE record_id = p_record_id;
END $$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

DO $$
DECLARE
    rec RECORD;
    medicine_cursor CURSOR FOR
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity < 10;
BEGIN
    OPEN medicine_cursor;
    LOOP
        FETCH medicine_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: % - % units',
            rec.medicine_name, rec.stock_quantity;
    END LOOP;
    CLOSE medicine_cursor;
END $$;

DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(1, 'STU004', -2);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Exception handled: %', SQLERRM;
    END;
END $$;

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;
