USE master;
GO

-- Drop if exists
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'sManager')
BEGIN
    DROP LOGIN sManager;
END
GO

-- Create login with password
CREATE LOGIN sManager 
WITH PASSWORD = 'sManager@123',
     DEFAULT_DATABASE = CINEMA,
     CHECK_POLICY = OFF,
     CHECK_EXPIRATION = OFF;
GO

PRINT 'Login sManager created successfully';
GO

-- Switch to CINEMA database and create user
USE CINEMA;
GO

-- Drop user if exists
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'sManager')
BEGIN
    DROP USER sManager;
END
GO

-- Create user from login
CREATE USER sManager FOR LOGIN sManager;
GO

PRINT 'User sManager created in CINEMA database';
GO

-- Grant all permissions to sManager
-- Grant db_owner role (full access)
ALTER ROLE db_owner ADD MEMBER sManager;
GO

PRINT 'All permissions granted to sManager';
GO