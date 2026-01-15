IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'CINEMA')
    CREATE DATABASE CINEMA;
GO

USE CINEMA;
GO

-- Cleanup (optional)
--EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";
--EXEC sp_MSforeachtable "DROP TABLE ?";

CREATE TABLE user_account (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    Phone NVARCHAR(15) NOT NULL UNIQUE,
    Gender CHAR(1) NOT NULL CHECK (Gender IN ('M','F','O')),
    DateOfBirth DATE NULL,
    City NVARCHAR(50) NULL,
    District NVARCHAR(50) NULL
);

CREATE TABLE customer (
    CustomerID INT PRIMARY KEY,
    CONSTRAINT fk_customer_user FOREIGN KEY (CustomerID)
        REFERENCES user_account(UserID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE membership (
    CustomerID INT NOT NULL,
    CardNo NVARCHAR(20) NOT NULL,
    RegisterDate DATE NOT NULL,
    Status NVARCHAR(10) NOT NULL CHECK (Status IN ('Normal', 'VIP', 'VVIP')) DEFAULT 'Normal',
    CONSTRAINT pk_membership PRIMARY KEY (CustomerID, CardNo),
    CONSTRAINT fk_membership_customer FOREIGN KEY (CustomerID)
        REFERENCES customer(CustomerID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE cinema (
    CinemaID INT IDENTITY(1,1) PRIMARY KEY,
    CinemaName NVARCHAR(100) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    District NVARCHAR(50) NOT NULL,
    Address NVARCHAR(200) NOT NULL
);

CREATE TABLE auditorium (
    AuditoriumID INT NOT NULL,
    CinemaID INT NOT NULL,
    AuditoriumName NVARCHAR(50) NOT NULL,
    Type NVARCHAR(20) NOT NULL CHECK (Type IN ('Standard', 'IMAX', 'VIP', '4DX')) DEFAULT 'Standard',
    Capacity INT NOT NULL CHECK (Capacity > 0),
    CONSTRAINT pk_auditorium PRIMARY KEY (CinemaID, AuditoriumID),
    CONSTRAINT fk_auditorium_cinema FOREIGN KEY (CinemaID)
        REFERENCES cinema(CinemaID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE staff (
    StaffID INT PRIMARY KEY,
    CinemaID INT NOT NULL,
    CONSTRAINT fk_staff_user FOREIGN KEY (StaffID)
        REFERENCES user_account(UserID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_staff_cinema FOREIGN KEY (CinemaID)
        REFERENCES cinema(CinemaID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE movie (
    MovieID INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(100) NOT NULL,
    Classification NVARCHAR(5) NOT NULL CHECK (Classification IN ('P', '13+', '16+', '18+')) DEFAULT 'P',
    DurationMin INT NOT NULL CHECK (DurationMin > 0),
    Rating DECIMAL(3,1) NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Now Showing',
    ReleaseDate DATE NOT NULL,
    Language NVARCHAR(30) NOT NULL,
    ImageFile NVARCHAR(255) NOT NULL,
    CONSTRAINT uq_movie_title UNIQUE (Title)
);

CREATE TABLE movie_genre (
    MovieID INT NOT NULL,
    Genre NVARCHAR(20) NOT NULL,
    CONSTRAINT pk_movie_genre PRIMARY KEY (MovieID, Genre),
    CONSTRAINT fk_mg_movie FOREIGN KEY (MovieID)
        REFERENCES movie(MovieID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE showtime (
    ScreeningID INT IDENTITY(1,1) PRIMARY KEY,
    MovieID INT NOT NULL,
    CinemaID INT NOT NULL,
    AuditoriumID INT NOT NULL,
    ShowDate DATE NOT NULL,
    StartTime TIME NOT NULL,
    
    CONSTRAINT fk_screen_movie FOREIGN KEY (MovieID)
        REFERENCES movie(MovieID)
        ON UPDATE CASCADE,

    CONSTRAINT fk_screen_aud FOREIGN KEY (CinemaID, AuditoriumID)
        REFERENCES auditorium(CinemaID, AuditoriumID)
        ON UPDATE CASCADE
);

CREATE TABLE seat (
    SeatNumber INT NOT NULL,
    AuditoriumID INT NOT NULL,
    CinemaID INT NOT NULL,
    SeatType NVARCHAR(10) NOT NULL CHECK (SeatType IN ('Regular','VIP')) DEFAULT 'Regular',
    CONSTRAINT pk_seat PRIMARY KEY (CinemaID, AuditoriumID, SeatNumber),
    CONSTRAINT fk_seat_aud FOREIGN KEY (CinemaID, AuditoriumID)
        REFERENCES auditorium(CinemaID, AuditoriumID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

/* Ticket (one ticket per purchase — can include multiple seats) */
CREATE TABLE ticket (
    TicketID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    ScreeningID INT NOT NULL,
    PriceTotal DECIMAL(12,2) NOT NULL,
    PurchaseDatetime DATETIME NOT NULL DEFAULT GETDATE(),
    SeatCount INT NOT NULL CHECK (SeatCount > 0),
    CONSTRAINT fk_ticket_customer FOREIGN KEY (CustomerID)
        REFERENCES customer(CustomerID)
        ON UPDATE CASCADE,
    CONSTRAINT fk_ticket_showtime FOREIGN KEY (ScreeningID)
        REFERENCES showtime(ScreeningID),
    CONSTRAINT chk_ticket_price CHECK (PriceTotal >= 0)
);

CREATE TABLE seat_booking (
    TicketID INT NOT NULL,
    SeatNumber INT NOT NULL,
    CinemaID INT NOT NULL,
    AuditoriumID INT NOT NULL,
    CONSTRAINT pk_seat_booking PRIMARY KEY (TicketID, SeatNumber, AuditoriumID, CinemaID),
    CONSTRAINT fk_aud_seat FOREIGN KEY (CinemaID, AuditoriumID, SeatNumber)
        REFERENCES seat(CinemaID, AuditoriumID, SeatNumber)
        ON UPDATE CASCADE,
    CONSTRAINT fk_sb_ticket FOREIGN KEY (TicketID)
        REFERENCES ticket(TicketID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE discount (
    DiscountID INT IDENTITY(1,1) PRIMARY KEY,
    DiscountCode AS ('DISC' + RIGHT('000' + CAST(DiscountID AS VARCHAR(3)), 3)) PERSISTED,
    DiscountType NVARCHAR(20) NOT NULL CHECK (DiscountType IN ('GiftCard','Coupon','Voucher')),
    DiscountValue DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    RedeemDate DATE NULL,
    ExpiryDate DATE NOT NULL,
    CONSTRAINT chk_redeem_expiry CHECK (RedeemDate IS NULL OR RedeemDate <= ExpiryDate),
    CONSTRAINT chk_discount_value CHECK (DiscountValue >= 0),
);

CREATE TABLE own_discount (
    DiscountID INT NOT NULL,
    CustomerID INT NOT NULL,
    Quantity INT NOT NULL DEFAULT 1,
    CONSTRAINT pk_own_discount PRIMARY KEY (CustomerID, DiscountID),
    CONSTRAINT chk_quantity CHECK (Quantity >= 0),
    CONSTRAINT fk_own_disc FOREIGN KEY (DiscountID)
        REFERENCES discount(DiscountID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_own_cust FOREIGN KEY (CustomerID)
        REFERENCES customer(CustomerID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE apply_discount (
    DiscountID INT NOT NULL,
    TicketID INT NOT NULL,
    AppliedDateTime DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT pk_apply_discount PRIMARY KEY (DiscountID, TicketID),
    CONSTRAINT fk_apply_disc FOREIGN KEY (DiscountID)
        REFERENCES discount(DiscountID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_apply_ticket FOREIGN KEY (TicketID)
        REFERENCES ticket(TicketID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE manage (
    ManagerID INT NOT NULL,
    EmployeeID INT NOT NULL,
    CONSTRAINT pk_manage PRIMARY KEY (ManagerID, EmployeeID),
    CONSTRAINT fk_manage_mgr FOREIGN KEY (ManagerID)
        REFERENCES staff(StaffID),
    CONSTRAINT fk_manage_emp FOREIGN KEY (EmployeeID)
        REFERENCES staff(StaffID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_manager_self CHECK (ManagerID <> EmployeeID)
);

GO

-- Trigger: Validate date of birth (must be 18+ years old)
CREATE TRIGGER trg_user_account_dob
ON user_account
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.DateOfBirth IS NULL
           OR i.DateOfBirth > DATEADD(YEAR, -18, CAST(GETDATE() AS DATE))
           OR i.DateOfBirth < '1900-01-01'
    )
    BEGIN
        RAISERROR('Invalid DateOfBirth: user must be at least 18 years old.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- Trigger: Validate Vietnamese phone number format
CREATE TRIGGER trg_user_account_phone
ON user_account
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.Phone IS NOT NULL
          AND NOT (
                (i.Phone LIKE '0[1-9]%' AND LEN(i.Phone) BETWEEN 10 AND 11)
                OR (i.Phone LIKE '+84[1-9]%' AND LEN(i.Phone) BETWEEN 12 AND 13)
          )
    )
    BEGIN
        RAISERROR('Invalid Phone format. Expect Vietnamese number: 0xxxxxxxxx(x) or +84xxxxxxxxx(x).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- Trigger: Auto-update movie status based on release date
CREATE TRIGGER trg_MovieStatusUpdate
ON movie
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Only update if the Status actually needs to change (prevents infinite recursion)
    UPDATE m
    SET Status = CASE 
                    WHEN i.ReleaseDate > CAST(GETDATE() AS DATE) THEN 'Coming Soon'
                    ELSE 'Now Showing'
                 END
    FROM movie m
    INNER JOIN inserted i ON m.MovieID = i.MovieID
    WHERE m.Status <> CASE 
                        WHEN i.ReleaseDate > CAST(GETDATE() AS DATE) THEN 'Coming Soon'
                        ELSE 'Now Showing'
                      END;
END;
GO

-- Trigger: Prevent overlapping screenings in same auditorium (with 30min buffer)
CREATE TRIGGER trg_showtime_overlap
ON showtime
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN movie m_new ON i.MovieID = m_new.MovieID
        INNER JOIN showtime s ON i.CinemaID = s.CinemaID 
                              AND i.AuditoriumID = s.AuditoriumID
                              AND i.ShowDate = s.ShowDate
        INNER JOIN movie m_old ON s.MovieID = m_old.MovieID
        WHERE i.ScreeningID <> s.ScreeningID
          AND m_new.Status = 'Now Showing'  -- only new movie if now showing
          AND m_old.Status = 'Now Showing'  -- only check overlap with now showing movies
          AND (
                (CAST(i.ShowDate AS DATETIME) + CAST(i.StartTime AS DATETIME)) 
                < DATEADD(MINUTE, m_old.DurationMin + 30, CAST(s.ShowDate AS DATETIME) + CAST(s.StartTime AS DATETIME))
                AND
                DATEADD(MINUTE, m_new.DurationMin + 30, CAST(i.ShowDate AS DATETIME) + CAST(i.StartTime AS DATETIME)) 
                > (CAST(s.ShowDate AS DATETIME) + CAST(s.StartTime AS DATETIME))
          )
    )
    BEGIN
        RAISERROR('Screening time overlaps with another screening in the same auditorium (including 30min buffer).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- Trigger: Validate purchase datetime is before show datetime
CREATE TRIGGER trg_ValidatePurchaseDateTime
ON ticket
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if any ticket was purchased on or after the show time
    IF EXISTS (
        SELECT 1
        FROM inserted i
        -- Join to the showtime table to get the actual show date and time
        INNER JOIN showtime st ON i.ScreeningID = st.ScreeningID
        
        WHERE 
            -- Combine ShowDate (DATE) and StartTime (TIME) to get the ShowDateTime
            CAST(i.PurchaseDatetime AS DATETIME) 
            >= 
            (CAST(st.ShowDate AS DATETIME) + CAST(st.StartTime AS DATETIME))
    )
    BEGIN
        RAISERROR('Ticket cannot be purchased on or after the show datetime.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

CREATE TRIGGER trg_apply_discount_validate
ON apply_discount
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check 1: Validate AppliedDateTime <= ExpiryDate (A discount cannot be used after it expires)
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN discount d ON i.DiscountID = d.DiscountID
        WHERE i.AppliedDateTime > CAST(d.ExpiryDate AS DATETIME) -- Compares applied time against the date part (00:00:00)
    )
    BEGIN
        RAISERROR('Cannot apply discount: AppliedDateTime exceeds ExpiryDate.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    -- Check 2: Validate customer owns the discount AND has quantity available
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN ticket t ON i.TicketID = t.TicketID
        -- Left Join to see if a matching record exists in own_discount
        LEFT JOIN own_discount od ON i.DiscountID = od.DiscountID 
                                  AND t.CustomerID = od.CustomerID
        
        -- If od.DiscountID IS NULL (no record exists) OR Quantity is zero or less
        WHERE od.DiscountID IS NULL OR od.Quantity <= 0
    )
    BEGIN
        RAISERROR('Cannot apply discount: Customer does not own this discount or quantity is zero.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    -- --- TRANSACTIONAL INVENTORY MANAGEMENT ---
    
    -- Step 3: Decrement quantity in own_discount (Uses the same logic as Check 2 for safety)
    UPDATE od
    SET Quantity = od.Quantity - 1
    FROM own_discount od
    INNER JOIN inserted i ON od.DiscountID = i.DiscountID
    INNER JOIN ticket t ON i.TicketID = t.TicketID
    WHERE od.CustomerID = t.CustomerID
      AND od.DiscountID IN (SELECT DiscountID FROM inserted); -- Only target the rows involved
    
    -- Step 4: Delete rows where Quantity = 0 (Cleanup)
    DELETE FROM od
    FROM own_discount od
    INNER JOIN inserted i ON od.DiscountID = i.DiscountID
    INNER JOIN ticket t ON i.TicketID = t.TicketID
    WHERE od.CustomerID = t.CustomerID
      AND od.DiscountID IN (SELECT DiscountID FROM inserted) -- Only target the rows involved
      AND od.Quantity <= 0; -- Use <= 0 to be safe against accidental negative numbers
    
    -- PRINT statement is generally removed in production for performance, but kept for debug.
    -- PRINT 'Discount quantity decremented and zero-quantity rows deleted';
END;
GO

-- Trigger: ShowDate >= ReleaseDate 
CREATE TRIGGER trg_showtime_release_date
ON showtime
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN movie m ON i.MovieID = m.MovieID
        WHERE i.ShowDate < m.ReleaseDate
    )
    BEGIN
        DECLARE @MovieTitle NVARCHAR(100);
        DECLARE @ShowDate NVARCHAR(20);
        DECLARE @ReleaseDate NVARCHAR(20);
        
        SELECT TOP 1
            @MovieTitle = m.Title,
            @ShowDate = CONVERT(NVARCHAR(20), i.ShowDate, 23),  -- Format: YYYY-MM-DD
            @ReleaseDate = CONVERT(NVARCHAR(20), m.ReleaseDate, 23)
        FROM inserted i
        INNER JOIN movie m ON i.MovieID = m.MovieID
        WHERE i.ShowDate < m.ReleaseDate;
        
        ROLLBACK TRANSACTION;
        
        RAISERROR('Cannot create showtime: Movie "%s" has show date (%s) before its release date (%s).', 
                  16, 1, @MovieTitle, @ShowDate, @ReleaseDate);
    END
END;
GO

-- Trigger: check capacity
CREATE TRIGGER trg_seat_capacity_check
ON seat
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT 
                s.CinemaID,
                s.AuditoriumID,
                COUNT(*) AS CurrentSeatCount,
                a.Capacity
            FROM seat s
            INNER JOIN auditorium a 
                ON s.CinemaID = a.CinemaID 
                AND s.AuditoriumID = a.AuditoriumID
            WHERE EXISTS (
                SELECT 1 
                FROM inserted i 
                WHERE i.CinemaID = s.CinemaID 
                AND i.AuditoriumID = s.AuditoriumID
            )
            GROUP BY s.CinemaID, s.AuditoriumID, a.Capacity
        ) AS SeatCheck
        WHERE CurrentSeatCount > Capacity
    )
    BEGIN
        DECLARE @AuditoriumName NVARCHAR(50);
        DECLARE @CurrentCount INT;
        DECLARE @Capacity INT;
        
        SELECT TOP 1
            @AuditoriumName = a.AuditoriumName,
            @CurrentCount = COUNT(*),
            @Capacity = a.Capacity
        FROM seat s
        INNER JOIN auditorium a 
            ON s.CinemaID = a.CinemaID 
            AND s.AuditoriumID = a.AuditoriumID
        WHERE EXISTS (
            SELECT 1 
            FROM inserted i 
            WHERE i.CinemaID = s.CinemaID 
            AND i.AuditoriumID = s.AuditoriumID
        )
        GROUP BY a.AuditoriumName, a.Capacity
        HAVING COUNT(*) > a.Capacity;
        
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMsg NVARCHAR(500);
        SET @ErrorMsg = 'Cannot add seat: Auditorium "' + @AuditoriumName + 
                        '" has reached maximum capacity. Current seats: ' + 
                        CAST(@CurrentCount AS NVARCHAR(10)) + 
                        ', Capacity: ' + CAST(@Capacity AS NVARCHAR(10));
        
        RAISERROR(@ErrorMsg, 16, 1);
    END
END;
GO


INSERT INTO user_account (Username, Email, Phone, Gender, DateOfBirth, City, District)
VALUES
('kimcuong', 'kimcuong@example.com', '0123456789', 'M', '2005-06-15', 'Hanoi', 'Ba Dinh'),
('tanloc', 'tanloc@example.com', '0987654321', 'O', '1998-03-22', 'Hanoi', 'Dong Da'),
('manhthang', 'manhthang@example.com', '0911223344', 'M', '2000-11-05', 'HCMC', 'District 1'),
('minhtriet', 'minhtriet@example.com', '0933445566', 'M', '1997-08-30', 'Danang', 'Hai Chau'),
('diennguyen', 'diennguyen@example.com', '0999998888', 'M', '1996-12-10', 'HCMC', 'District 3'),
('thikim', 'thikim@example.com', '0909988776', 'F', '1999-01-18', 'Hue', 'Phu Hoi'),
('quanle', 'quanle@example.com', '0912333444', 'M', '2001-07-25', 'Can Tho', 'Ninh Kieu'),
('anhdao', 'anhdao@example.com', '0922113344', 'F', '1995-04-12', 'Hanoi', 'Tay Ho'),
('ducnguyen', 'ducnguyen@example.com', '0933221144', 'M', '1998-09-09', 'HCMC', 'Binh Thanh'),
('hoangyen', 'hoangyen@example.com', '0999977777', 'F', '2000-05-05', 'Danang', 'Lien Chieu'),
('ngocanh', 'ngocanh@example.com', '0901234567', 'F', '1999-02-14', 'Hanoi', 'Cau Giay'),
('trungkien', 'trungkien@example.com', '0911456789', 'M', '1994-07-11', 'HCMC', 'Go Vap'),
('phuonglinh', 'phuonglinh@example.com', '0922567890', 'F', '2001-10-23', 'Haiphong', 'Ngo Quyen'),
('vietanh', 'vietanh@example.com', '0933678901', 'M', '1997-06-01', 'HCMC', 'Tan Binh'),
('thuyduong', 'thuyduong@example.com', '0944789012', 'F', '1996-12-27', 'Danang', 'Cam Le'),
('giabao', 'giabao@example.com', '0764969871', 'M', '1999-09-09', 'HCMC', 'District 7'),
('thuyvy', 'thuyvy@example.com', '0559917108', 'F', '2000-08-09', 'Hanoi', 'Dong Da');

SELECT * FROM user_account

INSERT INTO cinema (CinemaName, City, District, Address)
VALUES
('CGV Vincom Ba Trieu', 'Hanoi', 'Hai Ba Trung', '191 Ba Trieu, Hai Ba Trung District, Hanoi'),
('CGV Aeon Mall Tan Phu', 'HCMC', 'Tan Phu', '30 Bo Bao Tan Thang, Son Ky Ward, Tan Phu District, HCMC'),
('CGV Vincom Nguyen Chi Thanh', 'Hanoi', 'Dong Da', '54 Nguyen Chi Thanh, Dong Da District, Hanoi'),
('CGV Aeon Mall Binh Duong Canary', 'Binh Duong', 'Thuan An', '01 Binh Duong Boulevard, Thuan Giao Ward, Thuan An City, Binh Duong'),
('CGV Vincom Da Nang', 'Danang', 'Hai Chau', '910A Ngo Quyen, Son Tra District, Danang');

SELECT * FROM cinema

INSERT INTO auditorium (AuditoriumID, CinemaID, AuditoriumName, Type, Capacity)
VALUES
-- CGV Vincom Ba Trieu (CinemaID = 1)
(1, 1, 'Hall 1', 'Standard', 50),
(2, 1, 'Hall 2', 'IMAX', 50),

-- CGV Aeon Mall Tan Phu (CinemaID = 2)
(3, 2, 'Deluxe Room', 'VIP', 50),
(4, 2, 'Main Screen', 'Standard', 50),

-- CGV Vincom Nguyen Chi Thanh (CinemaID = 3)
(5, 3, 'Screen A', '4DX', 50),
(6, 3, 'Screen B', 'Standard', 50),

-- CGV Aeon Mall Binh Duong Canary (CinemaID = 4)
(7, 4, 'Room 1', 'Standard', 50),
(8, 4, 'Room 2', 'VIP', 50),

-- CGV Vincom Da Nang (CinemaID = 5)
(9, 5, 'Theater 1', 'IMAX', 50),
(10, 5, 'Theater 2', 'Standard', 50);

SELECT * FROM auditorium

-- Thêm dữ liệu vào bảng movie
INSERT INTO movie (Title, Classification, DurationMin, Rating, ReleaseDate, Language, ImageFile)
VALUES
('The Cursed', '18+', 97, 8.7, '2025-11-28', 'Korean', 'the_cursed.jpg'),
('Betting with Ghost 2: The Diamond War', '16+', 125, 7.9, '2025-11-28', 'Vietnamese', 'betting_with_ghost_diamond_war.jpg'),
(N'Mưa Đỏ', '16+', 124, 8.0, '2025-09-02', 'Vietnamese', 'muado.jpg'),
('Spider-Man: Brand New Day', '13+', 150, NULL, '2026-07-31', 'English', 'spider_man_brand_new_day.jpg'),
('Scarlet', 'P', 110, NULL, '2025-12-12', 'Japanese', 'scarlet.jpg'),
('Avatar 3: Fire and Ash', '13+', 195, NULL, '2025-12-19', 'English', 'avatar3.jpg'); 


SELECT * FROM movie

-- Movie genres
INSERT INTO movie_genre (MovieID, Genre)
VALUES

-- The Cursed
(1, 'Horror'),


-- Betting with Ghost 2: The Diamond War
(2, 'Comedy'),
(2, 'Horror'),
(2, 'Supernatural'),

-- Mưa Đỏ
(3, 'Drama'),
(3, 'Thriller'),

-- Spider-Man: Brand New Day
(4, 'Action'),
(4, 'Sci-Fi'),
(4, 'Adventure'),

-- Scarlet
(5, 'Animation'),
(5, 'Fantasy'),

-- Avatar 3
(6, 'Action'),
(6, 'Adventure'),
(6, 'Fantasy'),
(6, 'Science Fiction');

SELECT * FROM movie_genre

INSERT INTO staff (StaffID, CinemaID)
VALUES
(6, 1),  -- thikim - CGV Vincom Ba Trieu
(7, 2),  -- quanle - CGV Aeon Mall Tan Phu
(8, 3),  -- anhdao - CGV Vincom Nguyen Chi Thanh
(9, 4),  -- ducnguyen - CGV Aeon Mall Binh Duong Canary
(10, 5), -- hoangyen - CGV Vincom Da Nang
(11, 1), -- ngocanh - CGV Vincom Ba Trieu
(12, 2), -- trungkien - CGV Aeon Mall Tan Phu
(13, 3), -- phuonglinh - CGV Vincom Nguyen Chi Thanh
(14, 4), -- vietanh - CGV Aeon Mall Binh Duong Canary
(15, 5), -- thuyduong - CGV Vincom Da Nang
(16, 2), -- giabao - CGV Aeon Mall Tan Phu
(17, 1); -- thuyvy - CGV Vincom Ba Trieu


SELECT * FROM staff

INSERT INTO manage (ManagerID, EmployeeID)
VALUES

(6, 11),  -- Cinema 1: thikim manages ngocanh 
(6, 17),  -- Cinema 1: thikim manages thuyvy
(7, 12),  -- Cinema 2: quanle manages trungkien
(7, 16),  -- Cinema 2: quanle manages giabao
(8, 13),  -- Cinema 3: anhdao manages phuonglinh
(9, 14),  -- Cinema 4: ducnguyen manages vietanh
(10, 15); -- Cinema 5: hoangyen manages thuyduong

SELECT * FROM manage

INSERT INTO customer (CustomerID)
VALUES
(1),
(2),
(3),
(4),
(5);

SELECT * FROM customer

INSERT INTO membership (CustomerID, CardNo, RegisterDate, Status)
VALUES
(1, 'CGV1001', '2023-02-15', 'Normal'),
(2, 'CGV1002', '2023-05-20', 'VIP'),
(3, 'CGV1003', '2024-01-10', 'Normal'),
(4, 'CGV1004', '2024-06-30', 'VVIP');

SELECT * FROM membership

INSERT INTO discount (DiscountType, DiscountValue, RedeemDate, ExpiryDate)
VALUES
('GiftCard', 100000, NULL, '2025-12-31'),
('Coupon', 50000, '2025-01-15', '2025-12-31'),
('Voucher', 75000, NULL, '2025-12-30'),
('GiftCard', 120000, '2025-02-10', '2026-01-31'),
('Coupon', 60000, NULL, '2025-12-31');

SELECT * FROM discount

INSERT INTO showtime (MovieID, CinemaID, AuditoriumID, ShowDate, StartTime)
VALUES
-- The Cursed (MovieID = 1)
(1, 1, 1, '2025-12-05', '10:00:00'),
(1, 1, 1, '2025-12-05', '14:00:00'),
(1, 1, 2, '2025-12-05', '18:00:00'),
(1, 2, 3, '2025-12-06', '09:30:00'),
(1, 2, 4, '2025-12-06', '15:00:00'),
(1, 3, 5, '2025-12-07', '11:00:00'),
(1, 3, 6, '2025-12-07', '18:30:00'),

-- Betting with Ghost 2: The Diamond War (MovieID = 2)
(2, 1, 1, '2025-12-05', '17:30:00'),
(2, 2, 3, '2025-12-06', '13:00:00'),
(2, 2, 4, '2025-12-06', '20:00:00'),
(2, 4, 7, '2025-12-08', '10:30:00'),
(2, 4, 8, '2025-12-08', '17:00:00'),

-- Mưa Đỏ (MovieID = 3)
(3, 1, 2, '2025-12-05', '12:00:00'),
(3, 3, 5, '2025-12-07', '14:30:00'),
(3, 3, 6, '2025-12-07', '22:00:00'),
(3, 5, 9, '2025-12-09', '13:00:00'),
(3, 5, 10, '2025-12-09', '18:30:00'),

-- The Cursed (MovieID = 1) 
(1, 1, 1, '2025-12-10', '10:00:00'),
(1, 1, 1, '2025-12-10', '14:00:00'),
(1, 1, 2, '2025-12-10', '18:00:00'),
(1, 2, 3, '2025-12-11', '09:30:00'),
(1, 2, 4, '2025-12-11', '15:00:00'),

-- Betting with Ghost 2: The Diamond War (MovieID = 2)
(2, 1, 1, '2025-12-10', '17:30:00'),
(2, 2, 3, '2025-12-11', '13:00:00'),
(2, 2, 4, '2025-12-11', '20:00:00'),

-- Mưa Đỏ (MovieID = 3)
(3, 1, 2, '2025-12-10', '12:00:00'),
(3, 4, 7, '2025-12-11', '14:30:00'),
(3, 4, 8, '2025-12-11', '22:00:00');


SELECT * FROM showtime;

-- Cinema 1
INSERT INTO seat (SeatNumber, AuditoriumID, CinemaID, SeatType)
VALUES
-- Hall 1 (Auditorium 1, Cinema 1)
(1,1,1,'Regular'),(2,1,1,'Regular'),(3,1,1,'Regular'),(4,1,1,'Regular'),(5,1,1,'Regular'),
(6,1,1,'Regular'),(7,1,1,'Regular'),(8,1,1,'Regular'),(9,1,1,'Regular'),(10,1,1,'Regular'),
(11,1,1,'Regular'),(12,1,1,'Regular'),(13,1,1,'Regular'),(14,1,1,'Regular'),(15,1,1,'Regular'),
(16,1,1,'Regular'),(17,1,1,'Regular'),(18,1,1,'Regular'),(19,1,1,'Regular'),(20,1,1,'Regular'),
(21,1,1,'Regular'),(22,1,1,'Regular'),(23,1,1,'Regular'),(24,1,1,'Regular'),(25,1,1,'Regular'),
(26,1,1,'Regular'),(27,1,1,'Regular'),(28,1,1,'Regular'),(29,1,1,'Regular'),(30,1,1,'Regular'),
(31,1,1,'VIP'),(32,1,1,'VIP'),(33,1,1,'VIP'),(34,1,1,'VIP'),(35,1,1,'VIP'),
(36,1,1,'VIP'),(37,1,1,'VIP'),(38,1,1,'VIP'),(39,1,1,'VIP'),(40,1,1,'VIP'),
(41,1,1,'VIP'),(42,1,1,'VIP'),(43,1,1,'VIP'),(44,1,1,'VIP'),(45,1,1,'VIP'),
(46,1,1,'VIP'),(47,1,1,'VIP'),(48,1,1,'VIP'),(49,1,1,'VIP'),(50,1,1,'VIP'),

-- Hall 2 (Auditorium 2, Cinema 1)
(1,2,1,'Regular'),(2,2,1,'Regular'),(3,2,1,'Regular'),(4,2,1,'Regular'),(5,2,1,'Regular'),
(6,2,1,'Regular'),(7,2,1,'Regular'),(8,2,1,'Regular'),(9,2,1,'Regular'),(10,2,1,'Regular'),
(11,2,1,'Regular'),(12,2,1,'Regular'),(13,2,1,'Regular'),(14,2,1,'Regular'),(15,2,1,'Regular'),
(16,2,1,'Regular'),(17,2,1,'Regular'),(18,2,1,'Regular'),(19,2,1,'Regular'),(20,2,1,'Regular'),
(21,2,1,'Regular'),(22,2,1,'Regular'),(23,2,1,'Regular'),(24,2,1,'Regular'),(25,2,1,'Regular'),
(26,2,1,'Regular'),(27,2,1,'Regular'),(28,2,1,'Regular'),(29,2,1,'Regular'),(30,2,1,'Regular'),
(31,2,1,'VIP'),(32,2,1,'VIP'),(33,2,1,'VIP'),(34,2,1,'VIP'),(35,2,1,'VIP'),
(36,2,1,'VIP'),(37,2,1,'VIP'),(38,2,1,'VIP'),(39,2,1,'VIP'),(40,2,1,'VIP'),
(41,2,1,'VIP'),(42,2,1,'VIP'),(43,2,1,'VIP'),(44,2,1,'VIP'),(45,2,1,'VIP'),
(46,2,1,'VIP'),(47,2,1,'VIP'),(48,2,1,'VIP'),(49,2,1,'VIP'),(50,2,1,'VIP');

-- Cinema 2
INSERT INTO seat (SeatNumber, AuditoriumID, CinemaID, SeatType)
VALUES
-- Deluxe Room (Auditorium 3, Cinema 2)
(1,3,2,'Regular'),(2,3,2,'Regular'),(3,3,2,'Regular'),(4,3,2,'Regular'),(5,3,2,'Regular'),
(6,3,2,'Regular'),(7,3,2,'Regular'),(8,3,2,'Regular'),(9,3,2,'Regular'),(10,3,2,'Regular'),
(11,3,2,'Regular'),(12,3,2,'Regular'),(13,3,2,'Regular'),(14,3,2,'Regular'),(15,3,2,'Regular'),
(16,3,2,'Regular'),(17,3,2,'Regular'),(18,3,2,'Regular'),(19,3,2,'Regular'),(20,3,2,'Regular'),
(21,3,2,'Regular'),(22,3,2,'Regular'),(23,3,2,'Regular'),(24,3,2,'Regular'),(25,3,2,'Regular'),
(26,3,2,'Regular'),(27,3,2,'Regular'),(28,3,2,'Regular'),(29,3,2,'Regular'),(30,3,2,'Regular'),
(31,3,2,'VIP'),(32,3,2,'VIP'),(33,3,2,'VIP'),(34,3,2,'VIP'),(35,3,2,'VIP'),
(36,3,2,'VIP'),(37,3,2,'VIP'),(38,3,2,'VIP'),(39,3,2,'VIP'),(40,3,2,'VIP'),
(41,3,2,'VIP'),(42,3,2,'VIP'),(43,3,2,'VIP'),(44,3,2,'VIP'),(45,3,2,'VIP'),
(46,3,2,'VIP'),(47,3,2,'VIP'),(48,3,2,'VIP'),(49,3,2,'VIP'),(50,3,2,'VIP'),

-- Main Screen (Auditorium 4, Cinema 2)
(1,4,2,'Regular'),(2,4,2,'Regular'),(3,4,2,'Regular'),(4,4,2,'Regular'),(5,4,2,'Regular'),
(6,4,2,'Regular'),(7,4,2,'Regular'),(8,4,2,'Regular'),(9,4,2,'Regular'),(10,4,2,'Regular'),
(11,4,2,'Regular'),(12,4,2,'Regular'),(13,4,2,'Regular'),(14,4,2,'Regular'),(15,4,2,'Regular'),
(16,4,2,'Regular'),(17,4,2,'Regular'),(18,4,2,'Regular'),(19,4,2,'Regular'),(20,4,2,'Regular'),
(21,4,2,'Regular'),(22,4,2,'Regular'),(23,4,2,'Regular'),(24,4,2,'Regular'),(25,4,2,'Regular'),
(26,4,2,'Regular'),(27,4,2,'Regular'),(28,4,2,'Regular'),(29,4,2,'Regular'),(30,4,2,'Regular'),
(31,4,2,'VIP'),(32,4,2,'VIP'),(33,4,2,'VIP'),(34,4,2,'VIP'),(35,4,2,'VIP'),
(36,4,2,'VIP'),(37,4,2,'VIP'),(38,4,2,'VIP'),(39,4,2,'VIP'),(40,4,2,'VIP'),
(41,4,2,'VIP'),(42,4,2,'VIP'),(43,4,2,'VIP'),(44,4,2,'VIP'),(45,4,2,'VIP'),
(46,4,2,'VIP'),(47,4,2,'VIP'),(48,4,2,'VIP'),(49,4,2,'VIP'),(50,4,2,'VIP');

-- Cinema 3
INSERT INTO seat (SeatNumber, AuditoriumID, CinemaID, SeatType)
VALUES
-- Screen A (Auditorium 5, Cinema 3)
(1,5,3,'Regular'),(2,5,3,'Regular'),(3,5,3,'Regular'),(4,5,3,'Regular'),(5,5,3,'Regular'),
(6,5,3,'Regular'),(7,5,3,'Regular'),(8,5,3,'Regular'),(9,5,3,'Regular'),(10,5,3,'Regular'),
(11,5,3,'Regular'),(12,5,3,'Regular'),(13,5,3,'Regular'),(14,5,3,'Regular'),(15,5,3,'Regular'),
(16,5,3,'Regular'),(17,5,3,'Regular'),(18,5,3,'Regular'),(19,5,3,'Regular'),(20,5,3,'Regular'),
(21,5,3,'Regular'),(22,5,3,'Regular'),(23,5,3,'Regular'),(24,5,3,'Regular'),(25,5,3,'Regular'),
(26,5,3,'Regular'),(27,5,3,'Regular'),(28,5,3,'Regular'),(29,5,3,'Regular'),(30,5,3,'Regular'),
(31,5,3,'VIP'),(32,5,3,'VIP'),(33,5,3,'VIP'),(34,5,3,'VIP'),(35,5,3,'VIP'),
(36,5,3,'VIP'),(37,5,3,'VIP'),(38,5,3,'VIP'),(39,5,3,'VIP'),(40,5,3,'VIP'),
(41,5,3,'VIP'),(42,5,3,'VIP'),(43,5,3,'VIP'),(44,5,3,'VIP'),(45,5,3,'VIP'),
(46,5,3,'VIP'),(47,5,3,'VIP'),(48,5,3,'VIP'),(49,5,3,'VIP'),(50,5,3,'VIP'),

-- Screen B (Auditorium 6, Cinema 3)
(1,6,3,'Regular'),(2,6,3,'Regular'),(3,6,3,'Regular'),(4,6,3,'Regular'),(5,6,3,'Regular'),
(6,6,3,'Regular'),(7,6,3,'Regular'),(8,6,3,'Regular'),(9,6,3,'Regular'),(10,6,3,'Regular'),
(11,6,3,'Regular'),(12,6,3,'Regular'),(13,6,3,'Regular'),(14,6,3,'Regular'),(15,6,3,'Regular'),
(16,6,3,'Regular'),(17,6,3,'Regular'),(18,6,3,'Regular'),(19,6,3,'Regular'),(20,6,3,'Regular'),
(21,6,3,'Regular'),(22,6,3,'Regular'),(23,6,3,'Regular'),(24,6,3,'Regular'),(25,6,3,'Regular'),
(26,6,3,'Regular'),(27,6,3,'Regular'),(28,6,3,'Regular'),(29,6,3,'Regular'),(30,6,3,'Regular'),
(31,6,3,'VIP'),(32,6,3,'VIP'),(33,6,3,'VIP'),(34,6,3,'VIP'),(35,6,3,'VIP'),
(36,6,3,'VIP'),(37,6,3,'VIP'),(38,6,3,'VIP'),(39,6,3,'VIP'),(40,6,3,'VIP'),
(41,6,3,'VIP'),(42,6,3,'VIP'),(43,6,3,'VIP'),(44,6,3,'VIP'),(45,6,3,'VIP'),
(46,6,3,'VIP'),(47,6,3,'VIP'),(48,6,3,'VIP'),(49,6,3,'VIP'),(50,6,3,'VIP');

-- Cinema 4
INSERT INTO seat (SeatNumber, AuditoriumID, CinemaID, SeatType)
VALUES
-- Room 1 (Auditorium 7, Cinema 4)
(1,7,4,'Regular'),(2,7,4,'Regular'),(3,7,4,'Regular'),(4,7,4,'Regular'),(5,7,4,'Regular'),
(6,7,4,'Regular'),(7,7,4,'Regular'),(8,7,4,'Regular'),(9,7,4,'Regular'),(10,7,4,'Regular'),
(11,7,4,'Regular'),(12,7,4,'Regular'),(13,7,4,'Regular'),(14,7,4,'Regular'),(15,7,4,'Regular'),
(16,7,4,'Regular'),(17,7,4,'Regular'),(18,7,4,'Regular'),(19,7,4,'Regular'),(20,7,4,'Regular'),
(21,7,4,'Regular'),(22,7,4,'Regular'),(23,7,4,'Regular'),(24,7,4,'Regular'),(25,7,4,'Regular'),
(26,7,4,'Regular'),(27,7,4,'Regular'),(28,7,4,'Regular'),(29,7,4,'Regular'),(30,7,4,'Regular'),
(31,7,4,'VIP'),(32,7,4,'VIP'),(33,7,4,'VIP'),(34,7,4,'VIP'),(35,7,4,'VIP'),
(36,7,4,'VIP'),(37,7,4,'VIP'),(38,7,4,'VIP'),(39,7,4,'VIP'),(40,7,4,'VIP'),
(41,7,4,'VIP'),(42,7,4,'VIP'),(43,7,4,'VIP'),(44,7,4,'VIP'),(45,7,4,'VIP'),
(46,7,4,'VIP'),(47,7,4,'VIP'),(48,7,4,'VIP'),(49,7,4,'VIP'),(50,7,4,'VIP'),

-- Room 2 (Auditorium 8, Cinema 4)
(1,8,4,'Regular'),(2,8,4,'Regular'),(3,8,4,'Regular'),(4,8,4,'Regular'),(5,8,4,'Regular'),
(6,8,4,'Regular'),(7,8,4,'Regular'),(8,8,4,'Regular'),(9,8,4,'Regular'),(10,8,4,'Regular'),
(11,8,4,'Regular'),(12,8,4,'Regular'),(13,8,4,'Regular'),(14,8,4,'Regular'),(15,8,4,'Regular'),
(16,8,4,'Regular'),(17,8,4,'Regular'),(18,8,4,'Regular'),(19,8,4,'Regular'),(20,8,4,'Regular'),
(21,8,4,'Regular'),(22,8,4,'Regular'),(23,8,4,'Regular'),(24,8,4,'Regular'),(25,8,4,'Regular'),
(26,8,4,'Regular'),(27,8,4,'Regular'),(28,8,4,'Regular'),(29,8,4,'Regular'),(30,8,4,'Regular'),
(31,8,4,'VIP'),(32,8,4,'VIP'),(33,8,4,'VIP'),(34,8,4,'VIP'),(35,8,4,'VIP'),
(36,8,4,'VIP'),(37,8,4,'VIP'),(38,8,4,'VIP'),(39,8,4,'VIP'),(40,8,4,'VIP'),
(41,8,4,'VIP'),(42,8,4,'VIP'),(43,8,4,'VIP'),(44,8,4,'VIP'),(45,8,4,'VIP'),
(46,8,4,'VIP'),(47,8,4,'VIP'),(48,8,4,'VIP'),(49,8,4,'VIP'),(50,8,4,'VIP');

-- Cinema 5
INSERT INTO seat (SeatNumber, AuditoriumID, CinemaID, SeatType)
VALUES
-- Theater 1 (Auditorium 9, Cinema 5)
(1,9,5,'Regular'),(2,9,5,'Regular'),(3,9,5,'Regular'),(4,9,5,'Regular'),(5,9,5,'Regular'),
(6,9,5,'Regular'),(7,9,5,'Regular'),(8,9,5,'Regular'),(9,9,5,'Regular'),(10,9,5,'Regular'),
(11,9,5,'Regular'),(12,9,5,'Regular'),(13,9,5,'Regular'),(14,9,5,'Regular'),(15,9,5,'Regular'),
(16,9,5,'Regular'),(17,9,5,'Regular'),(18,9,5,'Regular'),(19,9,5,'Regular'),(20,9,5,'Regular'),
(21,9,5,'Regular'),(22,9,5,'Regular'),(23,9,5,'Regular'),(24,9,5,'Regular'),(25,9,5,'Regular'),
(26,9,5,'Regular'),(27,9,5,'Regular'),(28,9,5,'Regular'),(29,9,5,'Regular'),(30,9,5,'Regular'),
(31,9,5,'VIP'),(32,9,5,'VIP'),(33,9,5,'VIP'),(34,9,5,'VIP'),(35,9,5,'VIP'),
(36,9,5,'VIP'),(37,9,5,'VIP'),(38,9,5,'VIP'),(39,9,5,'VIP'),(40,9,5,'VIP'),
(41,9,5,'VIP'),(42,9,5,'VIP'),(43,9,5,'VIP'),(44,9,5,'VIP'),(45,9,5,'VIP'),
(46,9,5,'VIP'),(47,9,5,'VIP'),(48,9,5,'VIP'),(49,9,5,'VIP'),(50,9,5,'VIP'),

-- Theater 2 (Auditorium 10, Cinema 5)
(1,10,5,'Regular'),(2,10,5,'Regular'),(3,10,5,'Regular'),(4,10,5,'Regular'),(5,10,5,'Regular'),
(6,10,5,'Regular'),(7,10,5,'Regular'),(8,10,5,'Regular'),(9,10,5,'Regular'),(10,10,5,'Regular'),
(11,10,5,'Regular'),(12,10,5,'Regular'),(13,10,5,'Regular'),(14,10,5,'Regular'),(15,10,5,'Regular'),
(16,10,5,'Regular'),(17,10,5,'Regular'),(18,10,5,'Regular'),(19,10,5,'Regular'),(20,10,5,'Regular'),
(21,10,5,'Regular'),(22,10,5,'Regular'),(23,10,5,'Regular'),(24,10,5,'Regular'),(25,10,5,'Regular'),
(26,10,5,'Regular'),(27,10,5,'Regular'),(28,10,5,'Regular'),(29,10,5,'Regular'),(30,10,5,'Regular'),
(31,10,5,'VIP'),(32,10,5,'VIP'),(33,10,5,'VIP'),(34,10,5,'VIP'),(35,10,5,'VIP'),
(36,10,5,'VIP'),(37,10,5,'VIP'),(38,10,5,'VIP'),(39,10,5,'VIP'),(40,10,5,'VIP'),
(41,10,5,'VIP'),(42,10,5,'VIP'),(43,10,5,'VIP'),(44,10,5,'VIP'),(45,10,5,'VIP'),
(46,10,5,'VIP'),(47,10,5,'VIP'),(48,10,5,'VIP'),(49,10,5,'VIP'),(50,10,5,'VIP');


SELECT * FROM seat;

INSERT INTO own_discount (DiscountID, CustomerID, Quantity)
VALUES
-- Customer 1 (kimcuong) owns multiple discounts
(1, 1, 3),  -- GiftCard - can use 3 times
(2, 1, 2),  -- Coupon - can use 2 times

-- Customer 2 (tanloc) 
(1, 2, 5),  -- GiftCard - can use 5 times, used 1
(3, 2, 2),  -- Voucher - can use 2 times

-- Customer 3 (manhthang)
(2, 3, 1),  -- Coupon - can use 1 time
(4, 3, 3),  -- GiftCard (VIP) - can use 3 times

-- Customer 4 (minhtriet)
(3, 4, 4),  -- Voucher - can use 4 times, used 1
(5, 4, 2),  -- Coupon (drink) - can use 2 times

-- Customer 5 (diennguyen)
(1, 5, 2),  -- GiftCard - can use 2 times
(5, 5, 3);  -- Coupon (drink) - can use 3 times, used 1

SELECT * FROM own_discount;

INSERT INTO ticket (CustomerID, ScreeningID, PriceTotal, PurchaseDatetime, SeatCount)
VALUES
-- Customer 1 (kimcuong) - 2 tickets
(1, 1, 150000, '2025-12-01 09:30:00', 2),  -- Ticket 1: 2 seats for The Cursed
(1, 2, 100000, '2025-12-02 14:20:00', 1),  -- Ticket 2: 1 seat for The Cursed

-- Customer 2 (tanloc) - 3 tickets
(2, 4, 450000, '2025-12-01 10:00:00', 3),  -- Ticket 3: 3 VIP seats for The Cursed
(2, 10, 200000, '2025-12-03 11:00:00', 2),  -- Ticket 4: 2 seats for Betting with Ghost 2
(2, 6, 250000, '2025-12-04 15:30:00', 1),  -- Ticket 5: 1 4DX seat for The Cursed

-- Customer 3 (manhthang) - 2 tickets
(3, 3, 300000, '2025-12-02 16:00:00', 2),  -- Ticket 6: 2 IMAX seats for The Cursed
(3, 11, 150000, '2025-12-05 09:00:00', 3),  -- Ticket 7: 3 seats for Betting with Ghost 2

-- Customer 4 (minhtriet) - 1 ticket
(4, 15, 200000, '2025-12-03 18:00:00', 2),  -- Ticket 8: 2 seats for Mưa Đỏ

-- Customer 5 (diennguyen) - 2 tickets
(5, 16, 350000, '2025-12-04 12:00:00', 2),  -- Ticket 9: 2 IMAX seats for Mưa Đỏ
(5, 17, 125000, '2025-12-05 14:00:00', 1); -- Ticket 10: 1 seat for Mưa Đỏ

SELECT * FROM ticket;

INSERT INTO seat_booking (TicketID, SeatNumber, CinemaID, AuditoriumID)
VALUES
-- Ticket 1: Customer 1, 2 seats
(1, 1, 1, 1),
(1, 2, 1, 1),

-- Ticket 2: Customer 1, 1 seat
(2, 3, 1, 1),

-- Ticket 3: Customer 2, 3 VIP seats
(3, 1, 2, 3),
(3, 2, 2, 3),
(3, 3, 2, 3),

-- Ticket 4: Customer 2, 2 seats
(4, 5, 2, 4),
(4, 6, 2, 4),

-- Ticket 5: Customer 2, 1 seat
(5, 6, 3, 5),

-- Ticket 6: Customer 3, 2 seats
(6, 4, 1, 2),
(6, 5, 1, 2),

-- Ticket 7: Customer 3, 3 seats
(7, 1, 4, 7),
(7, 2, 4, 7),
(7, 3, 4, 7),

-- Ticket 8: Customer 4, 2 seats
(8, 9, 3, 6),
(8, 10, 3, 6),

-- Ticket 9: Customer 5, 2 seats
(9, 7, 5, 9),
(9, 8, 5, 9),

-- Ticket 10: Customer 5, 1 seat
(10, 11, 5, 10);

SELECT * FROM seat_booking;

INSERT INTO apply_discount (DiscountID, TicketID, AppliedDateTime)
VALUES
-- Customer 1 applies discount to ticket 1
(1, 1, '2025-12-01 09:30:00'),  -- GiftCard applied

-- Customer 2 applies discount to ticket 3
(1, 3, '2025-12-01 10:00:00'),  -- GiftCard applied (this increments Used from 1 to 2)

-- Customer 3 applies discount to ticket 6
(2, 6, '2025-12-02 16:00:00'),  -- Coupon applied

-- Customer 4 applies discount to ticket 8
(3, 8, '2025-12-03 18:00:00'),  -- Voucher applied (this increments Used from 1 to 2)

-- Customer 5 applies discount to ticket 10
(5, 10, '2025-12-05 14:05:00'); -- Coupon applied (this increments Used from 1 to 2)

SELECT * FROM apply_discount;

SELECT * FROM own_discount;

