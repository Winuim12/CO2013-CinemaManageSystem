USE master;
GO

-- Check if 'sa' exists
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'sa')
BEGIN
    PRINT 'Creating sa login...';
    CREATE LOGIN sa 
    WITH PASSWORD = 'CreateYourPasswordHere',
         CHECK_POLICY = OFF;
END
ELSE
BEGIN
    PRINT 'sa already exists, enabling and resetting password...';
    ALTER LOGIN sa ENABLE;
    ALTER LOGIN sa WITH PASSWORD = 'Strong!Pass123';
END
GO

-- Ensure 'sa' has sysadmin rights
IF NOT EXISTS (
    SELECT * FROM sys.server_role_members rm
    JOIN sys.server_principals sp1 ON rm.role_principal_id = sp1.principal_id
    JOIN sys.server_principals sp2 ON rm.member_principal_id = sp2.principal_id
    WHERE sp1.name = 'sysadmin' AND sp2.name = 'sa'
)
BEGIN
    PRINT 'Granting sysadmin role to sa...';
    EXEC sp_addsrvrolemember 'sa', 'sysadmin';
END
ELSE
BEGIN
    PRINT 'sa already has sysadmin role.';
END
GO

-- Force Mixed Authentication Mode
-- This part requires restarting SQL Server manually afterwards.
EXEC xp_instance_regwrite 
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode',
    REG_DWORD,
    2;  -- 1 = Windows only, 2 = Mixed (Windows + SQL)
GO

PRINT 'sa account is ready with sysadmin privileges and mixed authentication enabled.';
