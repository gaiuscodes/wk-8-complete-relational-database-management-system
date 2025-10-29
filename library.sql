-- =============================================
-- COMPLETE RELATIONAL DATABASE MANAGEMENT SYSTEM
-- USE CASE: Library Management System
-- Author: Timothy Gaius Odhiambo
-- Date: October 29, 2025
-- Description: Full-featured library system with members, books, 
--              authors, categories, borrowing, reservations, and fines.
-- =============================================

-- Create the database
CREATE DATABASE IF NOT EXISTS library_management_system
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE library_management_system;

-- =============================================
-- 1. Authors Table
-- =============================================
CREATE TABLE authors (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    biography TEXT,
    date_of_birth DATE,
    nationality VARCHAR(50),
    email VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_last_name (last_name),
    INDEX idx_full_name (last_name, first_name)
);

-- =============================================
-- 2. Categories Table
-- =============================================
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id INT NULL,
    
    -- Self-referencing for subcategories (e.g., Science > Physics)
    FOREIGN KEY (parent_category_id) 
        REFERENCES categories(category_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
        
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 3. Publishers Table
-- =============================================
CREATE TABLE publishers (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    established_year YEAR,
    address TEXT,
    website VARCHAR(150),
    email VARCHAR(100),
    phone VARCHAR(20),
    
    INDEX idx_name (name)
);

-- =============================================
-- 4. Books Table
-- =============================================
CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(17) NOT NULL UNIQUE, -- ISBN-13 format: 978-3-16-148410-0
    title VARCHAR(255) NOT NULL,
    author_id INT NOT NULL,
    publisher_id INT NOT NULL,
    publication_year YEAR NOT NULL,
    edition VARCHAR(20),
    total_copies INT NOT NULL DEFAULT 1 CHECK (total_copies >= 0),
    available_copies INT NOT NULL DEFAULT 1 CHECK (available_copies >= 0),
    pages INT CHECK (pages > 0),
    language VARCHAR(30) DEFAULT 'English',
    summary TEXT,
    cover_image_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Relationships
    FOREIGN KEY (author_id) 
        REFERENCES authors(author_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
        
    FOREIGN KEY (publisher_id) 
        REFERENCES publishers(publisher_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
        
    -- Ensure available copies never exceed total copies
    CONSTRAINT chk_copies CHECK (available_copies <= total_copies),
    
    INDEX idx_title (title),
    INDEX idx_isbn (isbn),
    INDEX idx_year (publication_year)
);

-- =============================================
-- 5. Book-Category Junction (Many-to-Many)
-- =============================================
CREATE TABLE book_categories (
    book_id INT NOT NULL,
    category_id INT NOT NULL,
    
    PRIMARY KEY (book_id, category_id),
    
    FOREIGN KEY (book_id) 
        REFERENCES books(book_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
        
    FOREIGN KEY (category_id) 
        REFERENCES categories(category_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- =============================================
-- 6. Members Table
-- =============================================
CREATE TABLE members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    membership_id VARCHAR(15) NOT NULL UNIQUE, -- e.g., LIB-2025-00123
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    date_of_birth DATE NOT NULL,
    membership_start_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    membership_expiry_date DATE NOT NULL,
    membership_type ENUM('Student', 'Regular', 'Premium', 'Staff') NOT NULL,
    status ENUM('Active', 'Suspended', 'Expired', 'Banned') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_email (email),
    INDEX idx_membership_id (membership_id),
    INDEX idx_status (status),
    
    -- Ensure expiry is after start
    CONSTRAINT chk_membership_dates 
        CHECK (membership_expiry_date > membership_start_date)
);

-- =============================================
-- 7. Borrowing Records
-- =============================================
CREATE TABLE borrowings (
    borrow_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    book_id INT NOT NULL,
    borrow_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    due_date DATE NOT NULL,
    return_date DATE NULL,
    status ENUM('Borrowed', 'Returned', 'Overdue', 'Lost') DEFAULT 'Borrowed',
    fine_amount DECIMAL(6,2) DEFAULT 0.00 CHECK (fine_amount >= 0),
    notes TEXT,
    
    FOREIGN KEY (member_id) 
        REFERENCES members(member_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
        
    FOREIGN KEY (book_id) 
        REFERENCES books(book_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
        
    -- Prevent borrowing if book is not available
    -- (Handled via trigger below)
    
    INDEX idx_member (member_id),
    INDEX idx_book (book_id),
    INDEX idx_status (status),
    INDEX idx_due_date (due_date),
    
    CONSTRAINT chk_dates 
        CHECK (due_date > borrow_date),
    CONSTRAINT chk_return 
        CHECK (return_date IS NULL OR return_date >= borrow_date)
);

-- =============================================
-- 8. Reservations Table
-- =============================================
CREATE TABLE reservations (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    book_id INT NOT NULL,
    reservation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date DATETIME NOT NULL, -- Reservation expires after X days
    status ENUM('Active', 'Fulfilled', 'Cancelled', 'Expired') DEFAULT 'Active',
    
    FOREIGN KEY (member_id) 
        REFERENCES members(member_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
        
    FOREIGN KEY (book_id) 
        REFERENCES books(book_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
        
    UNIQUE KEY unique_active_reservation (member_id, book_id, status), -- One active reservation per book per member
    
    INDEX idx_expiry (expiry_date),
    INDEX idx_status (status)
);

-- =============================================
-- 9. Fines Table (Separate for audit trail)
-- =============================================
CREATE TABLE fines (
    fine_id INT AUTO_INCREMENT PRIMARY KEY,
    borrow_id INT NOT NULL,
    member_id INT NOT NULL,
    amount DECIMAL(6,2) NOT NULL CHECK (amount > 0),
    reason ENUM('Overdue', 'Damage', 'Lost') NOT NULL,
    issued_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    paid_date DATE NULL,
    status ENUM('Unpaid', 'Paid', 'Waived') DEFAULT 'Unpaid',
    
    FOREIGN KEY (borrow_id) 
        REFERENCES borrowings(borrow_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
        
    FOREIGN KEY (member_id) 
        REFERENCES members(member_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
        
    INDEX idx_member (member_id),
    INDEX idx_status (status),
    INDEX idx_paid (paid_date)
);

-- =============================================
-- TRIGGERS
-- =============================================

-- Trigger: Decrease available copies when a book is borrowed
DELIMITER //
CREATE TRIGGER trg_after_borrow_insert
AFTER INSERT ON borrowings
FOR EACH ROW
BEGIN
    IF NEW.status = 'Borrowed' THEN
        UPDATE books 
        SET available_copies = available_copies - 1
        WHERE book_id = NEW.book_id 
          AND available_copies > 0;
          
        -- Optional: Raise error if no copies available (prevents inconsistency)
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'No copies available for borrowing';
        END IF;
    END IF;
END//
DELIMITER ;

-- Trigger: Increase available copies when returned
DELIMITER //
CREATE TRIGGER trg_after_borrow_update
AFTER UPDATE ON borrowings
FOR EACH ROW
BEGIN
    IF OLD.status = 'Borrowed' AND NEW.status = 'Returned' AND NEW.return_date IS NOT NULL THEN
        UPDATE books 
        SET available_copies = available_copies + 1
        WHERE book_id = NEW.book_id;
    END IF;
END//
DELIMITER ;

-- Trigger: Auto-generate membership ID
DELIMITER //
CREATE TRIGGER trg_before_member_insert
BEFORE INSERT ON members
FOR EACH ROW
BEGIN
    SET NEW.membership_id = CONCAT(
        'LIB-', 
        YEAR(CURDATE()), '-',
        LPAD((SELECT COALESCE(MAX(CAST(SUBSTRING(membership_id, 9) AS UNSIGNED)), 0) + 1 
              FROM members 
              WHERE membership_id LIKE CONCAT('LIB-', YEAR(CURDATE()), '%')), 5, '0')
    );
END//
DELIMITER ;

-- =============================================
-- SAMPLE DATA (Optional - Uncomment to populate)
-- =============================================

/*
INSERT INTO authors (first_name, last_name, date_of_birth, nationality, email) VALUES
('George', 'Orwell', '1903-06-25', 'British', 'george.orwell@author.com'),
('Jane', 'Austen', '1775-12-16', 'British', 'jane.austen@author.com'),
('Isaac', 'Asimov', '1920-01-02', 'American', 'isaac.asimov@author.com');

INSERT INTO categories (name, description) VALUES
('Fiction', 'Fictional literature'),
('Science Fiction', 'Sci-fi and futuristic stories'),
('Classic Literature', 'Timeless literary works'),
('Romance', 'Love and relationships'),
('Mystery', 'Crime and detective stories');

INSERT INTO publishers (name, established_year, website) VALUES
('Penguin Books', 1935, 'https://www.penguin.com'),
('HarperCollins', 1989, 'https://www.harpercollins.com'),
('Secker & Warburg', 1910, 'https://www.penguinrandomhouse.com');

-- Add more sample data as needed...
*/

-- =============================================
-- END OF SCHEMA
-- This database supports:
-- • Book catalog with authors, publishers, categories
-- • Member management with auto-ID and status
-- • Borrowing with due dates and copy tracking
-- • Reservations with expiry
-- • Fine tracking and audit
-- • Full referential integrity
-- • Scalable and production-ready design
-- =============================================
