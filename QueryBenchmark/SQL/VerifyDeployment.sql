-- =====================================================
-- Quick Test & Verification Script
-- Run this AFTER CompleteDeployment.sql
-- =====================================================

USE [Development_286]; -- Change to match your database
GO

PRINT '========================================';
PRINT 'Starting Verification Tests...';
PRINT '========================================';
PRINT '';

-- =====================================================
-- 1. Verify Table Exists with All Columns
-- =====================================================
PRINT '1. Checking QueryExecutionLog table schema...';
PRINT '------------------------------------------------';

SELECT 
    COLUMN_NAME AS ColumnName,
    DATA_TYPE AS DataType,
    CHARACTER_MAXIMUM_LENGTH AS MaxLength,
    IS_NULLABLE AS IsNullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'QueryExecutionLog'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '✓ Expected 11 columns: Id, QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutedAt, ExecutionStartTime, ExecutionEndTime, ExecutedBy';
PRINT '';

-- =====================================================
-- 2. Verify Stored Procedures Exist
-- =====================================================
PRINT '2. Checking stored procedures...';
PRINT '------------------------------------------------';

SELECT 
    ROUTINE_NAME AS ProcedureName,
    CREATED AS CreatedDate,
    LAST_ALTERED AS LastModifiedDate
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND ROUTINE_NAME LIKE 'usp_Benchmark%'
ORDER BY ROUTINE_NAME;

PRINT '';
PRINT '✓ Expected procedures: QueryOne, QueryTwo, QueryThree, GetLogs, ClearLogs';
PRINT '';

-- =====================================================
-- 3. Test QueryOne Execution
-- =====================================================
PRINT '3. Testing QueryOne (OR-based Keyset)...';
PRINT '------------------------------------------------';

BEGIN TRY
    EXEC usp_Benchmark_QueryOne_OrBasedKeyset
        @LastCreationDate = '9999-12-31 23:59:59',
        @LastEntityId = 0,
        @PageSize = 5,
        @IsFirstPage = 1;
    PRINT '✓ QueryOne executed successfully!';
END TRY
BEGIN CATCH
    PRINT '✗ QueryOne failed: ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- =====================================================
-- 4. Test QueryTwo Execution
-- =====================================================
PRINT '4. Testing QueryTwo (UNION ALL Keyset)...';
PRINT '------------------------------------------------';

BEGIN TRY
    EXEC usp_Benchmark_QueryTwo_UnionAllKeyset
        @LastCreationDate = '9999-12-31 23:59:59.9999999',
        @LastEntityId = 0,
        @PageSize = 5,
        @IsFirstPage = 1;
    PRINT '✓ QueryTwo executed successfully!';
END TRY
BEGIN CATCH
    PRINT '✗ QueryTwo failed: ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- =====================================================
-- 5. Test QueryThree Execution
-- =====================================================
PRINT '5. Testing QueryThree (Direct Seek)...';
PRINT '------------------------------------------------';

BEGIN TRY
    EXEC usp_Benchmark_QueryThree_DirectSeek
        @LastCreationDate = '9999-12-31 23:59:59.9999999',
        @LastEntityId = 0,
        @PageSize = 5,
        @IsFirstPage = 1;
    PRINT '✓ QueryThree executed successfully!';
END TRY
BEGIN CATCH
    PRINT '✗ QueryThree failed: ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- =====================================================
-- 6. View Execution Logs
-- =====================================================
PRINT '6. Viewing recent execution logs...';
PRINT '------------------------------------------------';

EXEC usp_Benchmark_GetLogs @TopN = 10;

PRINT '';

-- =====================================================
-- 7. Execution Summary
-- =====================================================
PRINT '7. Execution summary from logs...';
PRINT '------------------------------------------------';

SELECT 
    QueryName,
    COUNT(*) AS TotalExecutions,
    AVG(ExecutionTimeMs) AS AvgTimeMs,
    MIN(ExecutionTimeMs) AS MinTimeMs,
    MAX(ExecutionTimeMs) AS MaxTimeMs,
    SUM(CASE WHEN IsSuccess = 1 THEN 1 ELSE 0 END) AS SuccessCount,
    SUM(CASE WHEN IsSuccess = 0 THEN 1 ELSE 0 END) AS FailureCount
FROM QueryExecutionLog
WHERE QueryName IN ('QueryOne', 'QueryTwo', 'QueryThree')
GROUP BY QueryName
ORDER BY QueryName;

PRINT '';
PRINT '========================================';
PRINT 'Verification Complete!';
PRINT '========================================';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Review the output above for any errors';
PRINT '2. Check that all 3 queries executed successfully';
PRINT '3. Run your .NET application and test the UI';
PRINT '4. Click Q One, Q Two, Q Three buttons to benchmark';
PRINT '';
