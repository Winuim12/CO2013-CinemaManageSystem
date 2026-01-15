CREATE FUNCTION fn_GetTotalSpending(@CustomerID INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Result DECIMAL(12,2);

    -- Validate input
    IF @CustomerID IS NULL OR @CustomerID <= 0
        RETURN NULL;

    -- Ensure customer exists
    IF NOT EXISTS (SELECT 1 FROM customer WHERE CustomerID = @CustomerID)
        RETURN NULL;

    /* 
       Compute spending per ticket:
       FinalPrice = MAX(PriceTotal - TotalDiscountApplied, 0)
    */
    SELECT @Result = SUM(
            CASE 
                WHEN t.PriceTotal - ISNULL(d.TotalDiscount, 0) < 0 THEN 0
                ELSE t.PriceTotal - ISNULL(d.TotalDiscount, 0)
            END
        )
    FROM ticket t
    LEFT JOIN (
        SELECT ad.TicketID, SUM(d.DiscountValue) AS TotalDiscount
        FROM apply_discount ad
        INNER JOIN discount d ON ad.DiscountID = d.DiscountID
        GROUP BY ad.TicketID
    ) d ON t.TicketID = d.TicketID
    WHERE t.CustomerID = @CustomerID;

    RETURN ISNULL(@Result, 0);
END;
GO

SELECT dbo.fn_GetTotalSpending(3) AS TotalSpent;
GO

CREATE FUNCTION fn_CountScreeningsByCity
(
    @MovieID INT,
    @City NVARCHAR(50)
)
RETURNS INT
AS
BEGIN
    IF @MovieID IS NULL OR @MovieID <= 0 OR @City IS NULL
        RETURN -1;   -- indicates invalid input

    DECLARE @Count INT;

    SELECT @Count = COUNT(*)
    FROM showtime s
    INNER JOIN cinema c ON s.CinemaID = c.CinemaID
    WHERE s.MovieID = @MovieID
      AND c.City = @City;

    RETURN @Count;
END;
GO

SELECT dbo.fn_CountScreeningsByCity(1, 'Hanoi') AS Screenings;

--DROP FUNCTION fn_CountScreeningsByCity
--DROP FUNCTION fn_GetTotalSpending
