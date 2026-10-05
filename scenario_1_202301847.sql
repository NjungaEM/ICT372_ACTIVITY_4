DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL REFERENCES books(book_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INT NOT NULL,
    loan_status VARCHAR(20) NOT NULL DEFAULT 'BORROWED'
        CHECK (loan_status IN ('BORROWED','RETURNED'))
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 5),
('Computer Networks', 2),
('Operating Systems', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    copies INT;
BEGIN
    SELECT available_copies INTO copies FROM books WHERE book_id = 1;

    IF copies = 0 THEN
        RAISE NOTICE 'Book is unavailable.';
    ELSIF copies <= 2 THEN
        RAISE NOTICE 'Book has low copies.';
    ELSE
        RAISE NOTICE 'Book is sufficiently stocked.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number %', i;
    END LOOP;
END $$;

-- 4. Borrow procedure
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_copies INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: quantity must be greater than zero.';
    END IF;

    SELECT available_copies INTO v_copies
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book ID % does not exist.', p_book_id;
    END IF;

    IF v_copies < p_quantity THEN
        RAISE NOTICE 'Loan rejected: only % copies available.', v_copies;
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans(book_id, student_number, quantity)
    VALUES (p_book_id, p_student_number, p_quantity);

    RAISE NOTICE 'Loan recorded successfully.';
END $$;

-- 5. Two valid loans and one exceeding available copies
CALL borrow_book(1, 'STU001', 2);
CALL borrow_book(2, 'STU002', 1);
CALL borrow_book(2, 'STU003', 5);

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- 6. Return procedure
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INT;
    v_quantity INT;
BEGIN
    SELECT book_id, quantity INTO v_book_id, v_quantity
    FROM book_loans
    WHERE loan_id = p_loan_id
      AND loan_status = 'BORROWED'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan % is already returned or does not exist.', p_loan_id;
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies + v_quantity
    WHERE book_id = v_book_id;

    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    RAISE NOTICE 'Loan % returned successfully.', p_loan_id;
END $$;

CALL return_book(1);
CALL return_book(1);

-- 7. Explicit cursor: books with few copies
DO $$
DECLARE
    rec RECORD;
    book_cursor CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books
        WHERE available_copies <= 2;
BEGIN
    OPEN book_cursor;
    LOOP
        FETCH book_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few copies: ID %, %, copies %',
            rec.book_id, rec.title, rec.available_copies;
    END LOOP;
    CLOSE book_cursor;
END $$;

-- 8. Invalid zero quantity handled with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL borrow_book(1, 'STU004', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Exception handled: %', SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
