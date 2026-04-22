-- =============================================
-- Find Member-related tables in Sandbox_Db
-- =============================================

USE Sandbox_Db;
GO

PRINT 'Searching for Member-related tables...';
PRINT '';

-- Find all tables with "Member" in the name
SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS TableName,
    create_date AS CreatedDate
FROM sys.tables
WHERE name LIKE '%Member%'
ORDER BY name;

PRINT '';
PRINT 'If no tables found, list ALL tables:';
PRINT '';

-- List all tables in the database
SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS TableName,
    create_date AS CreatedDate
FROM sys.tables
ORDER BY name;
