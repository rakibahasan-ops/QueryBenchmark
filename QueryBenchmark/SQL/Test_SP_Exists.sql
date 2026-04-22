-- =============================================
-- Quick Test: Check if Benchmark SPs exist
-- =============================================

-- Check if stored procedures exist
SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ProcedureName,
    create_date AS CreatedDate,
    modify_date AS ModifiedDate,
    'EXISTS' AS Status
FROM sys.procedures
WHERE name LIKE 'usp_Benchmark_%'
ORDER BY name;

-- If no results above, SPs don't exist - deploy SP_Benchmark_AllProcedures.sql first!

-- Check if table exists
IF OBJECT_ID('dbo.MembersForQueryBenchmarking', 'U') IS NOT NULL
BEGIN
    PRINT 'Table exists: dbo.MembersForQueryBenchmarking'
    
    -- Check row count
    SELECT COUNT(*) AS TotalRows FROM dbo.MembersForQueryBenchmarking;
    
    -- Check FirstName data
    SELECT COUNT(*) AS RowsWithFirstName 
    FROM dbo.MembersForQueryBenchmarking 
    WHERE FirstName IS NOT NULL;
    
    -- Show sample data
    SELECT TOP 5
        MemberDocID,
        FirstName,
        LastName,
        EmailAddress,
        MemberId
    FROM dbo.MembersForQueryBenchmarking
    ORDER BY MemberDocID;
END
ELSE
BEGIN
    PRINT 'ERROR: Table dbo.MembersForQueryBenchmarking does not exist!'
END

-- Test FirstName SP directly
PRINT ''
PRINT 'Testing usp_Benchmark_FirstName_ASC:'
PRINT '====================================='

IF OBJECT_ID('dbo.usp_Benchmark_FirstName_ASC', 'P') IS NOT NULL
BEGIN
    EXEC dbo.usp_Benchmark_FirstName_ASC
        @LastFirstName = NULL,
        @LastEntityId = 0,
        @PageSize = 5,
        @IsFirstPage = 1;
END
ELSE
BEGIN
    PRINT 'ERROR: usp_Benchmark_FirstName_ASC does not exist!'
    PRINT 'Deploy SP_Benchmark_AllProcedures.sql first!'
END
