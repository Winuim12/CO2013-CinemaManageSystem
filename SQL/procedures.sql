CREATE PROCEDURE sp_GetCustomersByMembershipStatus
(
    @Status NVARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validation
    IF @Status NOT IN ('Normal', 'VIP', 'VVIP')
    BEGIN
        RAISERROR('Invalid membership status.', 16, 1);
        RETURN;
    END

    SELECT c.CustomerID, u.Username, m.CardNo, m.Status, m.RegisterDate
    FROM membership m
    INNER JOIN customer c ON m.CustomerID = c.CustomerID
    INNER JOIN user_account u ON c.CustomerID = u.UserID
    WHERE m.Status = @Status
    ORDER BY m.RegisterDate DESC;
END;
GO

EXEC sp_GetCustomersByMembershipStatus 'VIP';
GO
--DROP PROCEDURE sp_GetMonthlyCinemaRevenue 
--DROP PROCEDURE sp_GetCustomersByMembershipStatus

CREATE PROCEDURE dbo.sp_GetMonthlyCinemaRevenue
(
    @CinemaID INT = NULL,
    @Year INT,
    @Month INT,
    @MinRevenue DECIMAL(12,2) = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Standard Validation (Good)
    IF (@CinemaID IS NOT NULL AND @CinemaID <= 0)
    BEGIN
        RAISERROR('CinemaID must be a positive integer.', 16, 1);
        RETURN;
    END

    IF (@CinemaID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM cinema WHERE CinemaID = @CinemaID))
    BEGIN
        RAISERROR('Cinema does not exist.', 16, 1);
        RETURN;
    END

    -- Main query: Calculating revenue based on ticket purchases and linking back to the Cinema via Showtime
    SELECT
      st.CinemaID, ---------------------------------- Source changed to Showtime
      c.CinemaName,
      COUNT(DISTINCT t.CustomerID) AS TotalCustomers,
      SUM(t.SeatCount) AS TotalTickets,
      SUM(
        CASE 
          WHEN (t.PriceTotal - ISNULL(d.TotalDiscountApplied, 0)) < 0 THEN 0
          ELSE (t.PriceTotal - ISNULL(d.TotalDiscountApplied, 0))
        END
      ) AS MonthlyRevenue
    FROM ticket t
    -- NEW JOIN: Link Ticket to Showtime to get the CinemaID
    INNER JOIN showtime st ON t.ScreeningID = st.ScreeningID
    -- EXISTING JOIN: Link Showtime to Cinema details
    INNER JOIN cinema c ON st.CinemaID = c.CinemaID 
    
    LEFT JOIN (
      SELECT ad.TicketID,
             SUM(d.DiscountValue) AS TotalDiscountApplied
      FROM apply_discount ad
      INNER JOIN discount d ON ad.DiscountID = d.DiscountID
      GROUP BY ad.TicketID
    ) d ON t.TicketID = d.TicketID
    
    WHERE YEAR(t.PurchaseDatetime) = @Year
      AND MONTH(t.PurchaseDatetime) = @Month
      -- Condition now applies to Showtime's CinemaID
      AND ( @CinemaID IS NULL OR st.CinemaID = @CinemaID ) 
      
    GROUP BY st.CinemaID, c.CinemaName -- Grouping changed to use Showtime's CinemaID
    HAVING
      SUM(
        CASE 
          WHEN (t.PriceTotal - ISNULL(d.TotalDiscountApplied, 0)) < 0 THEN 0
          ELSE (t.PriceTotal - ISNULL(d.TotalDiscountApplied, 0))
        END
      ) >= @MinRevenue
    ORDER BY c.CinemaName;
END
GO

EXEC sp_GetMonthlyCinemaRevenue 
    @CinemaID = 1, 
    @Year = 2025, 
    @Month = 12,
    @MinRevenue = 0;