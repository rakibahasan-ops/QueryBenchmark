# 📋 Deployment Instructions - Query Benchmark System

## Overview
This deployment will update your `QueryExecutionLog` table to include execution start and end times, and create three stored procedures for benchmarking different keyset pagination approaches.

## Prerequisites
- SQL Server Management Studio (SSMS) or Azure Data Studio
- Access to your database with DDL permissions (ALTER, CREATE)
- Existing tables: `User_Test`, `HierarchyLinks_Test`, `ClubMemberSummary_Test`, `MembershipSummary_Test`, `State_Test`, `Family_Links_Test`, `UserPhoneNumber_Test`

## Deployment Steps

### Step 1: Update Database Name
Open `QueryBenchmark/SQL/CompleteDeployment.sql` and update line 6:
```sql
USE [YourDatabaseName]; -- Change this to your actual database name
```

### Step 2: Execute Deployment Script
1. Open `CompleteDeployment.sql` in SSMS or Azure Data Studio
2. Execute the entire script (F5 or Execute button)
3. Review the output messages for any errors

### Step 3: Verify Deployment

#### Check Table Schema
```sql
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'QueryExecutionLog'
ORDER BY ORDINAL_POSITION;
```

Expected columns:
- `Id` (int, NOT NULL)
- `QueryName` (nvarchar(200), NOT NULL)
- `QueryDescription` (nvarchar(500), NOT NULL)
- `ExecutionTimeMs` (bigint, NOT NULL)
- `RowsReturned` (int, NOT NULL)
- `IsSuccess` (bit, NOT NULL)
- `ErrorMessage` (nvarchar(2000), NULL)
- `ExecutedAt` (datetime2, NOT NULL)
- `ExecutionStartTime` (datetime2, NOT NULL) ← **NEW**
- `ExecutionEndTime` (datetime2, NOT NULL) ← **NEW**
- `ExecutedBy` (nvarchar(100), NULL)

#### Check Stored Procedures
```sql
SELECT 
    ROUTINE_NAME,
    CREATED,
    LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND ROUTINE_NAME LIKE 'usp_Benchmark%'
ORDER BY ROUTINE_NAME;
```

Expected stored procedures:
- `usp_Benchmark_QueryOne_OrBasedKeyset`
- `usp_Benchmark_QueryTwo_UnionAllKeyset`
- `usp_Benchmark_QueryThree_DirectSeek`
- `usp_Benchmark_GetLogs`
- `usp_Benchmark_ClearLogs` (if it exists)

### Step 4: Test Stored Procedures

#### Test QueryOne
```sql
EXEC usp_Benchmark_QueryOne_OrBasedKeyset
    @LastCreationDate = '9999-12-31 23:59:59',
    @LastEntityId = 0,
    @PageSize = 20,
    @IsFirstPage = 1;
```

#### Test QueryTwo
```sql
EXEC usp_Benchmark_QueryTwo_UnionAllKeyset
    @LastCreationDate = '9999-12-31 23:59:59.9999999',
    @LastEntityId = 0,
    @PageSize = 20,
    @IsFirstPage = 1;
```

#### Test QueryThree
```sql
EXEC usp_Benchmark_QueryThree_DirectSeek
    @LastCreationDate = '9999-12-31 23:59:59.9999999',
    @LastEntityId = 0,
    @PageSize = 20,
    @IsFirstPage = 1;
```

#### Check Logs
```sql
EXEC usp_Benchmark_GetLogs @TopN = 10;
```

### Step 5: Start the Application
1. Open the solution in Visual Studio
2. Press F5 to run the application
3. Navigate to the home page
4. Click on "Q One", "Q Two", or "Q Three" buttons under **Keyset Pagination Benchmarks**
5. Verify that the execution log shows:
   - Execution Time (ms)
   - Start Time
   - End Time
   - Executed At

## What Changed

### Database Schema
- Added `ExecutionStartTime` column (DATETIME2, NOT NULL)
- Added `ExecutionEndTime` column (DATETIME2, NOT NULL)
- Made `ExecutedBy` column nullable (was NOT NULL)

### Three New Stored Procedures

#### 1. QueryOne - OR-based Keyset
- Uses a temp table (`#BaseMembers_A1`)
- Filters with `WHERE date < @Last OR (date = @Last AND id > @LastId)`
- Suitable for: Simple pagination, medium-sized datasets

#### 2. QueryTwo - UNION ALL Keyset
- Uses a temp table (`#BaseMembers_A2`)
- Separates conditions using UNION ALL
- Better for: Query optimizer to use separate execution plans

#### 3. QueryThree - Direct Seek
- No temp table
- Direct index seeks on base tables
- Best for: Large datasets, when indexes are well-optimized

### Application Updates
- `ExecutionLog.cs` model updated with new time columns
- `QueryController.cs` reads new columns from stored procedure results
- `Index.cshtml` displays Start Time, End Time in the log grid
- JavaScript updated to format and display times

## Troubleshooting

### Error: "Invalid column name 'ExecutedBy'"
**Solution**: Re-run Step 1 of `CompleteDeployment.sql` to ensure the column is made nullable.

### Error: "Invalid object name 'HierarchyLinks_Test'"
**Solution**: Ensure all test tables exist. Update table names in the stored procedures if yours are named differently.

### No data returned from stored procedures
**Solution**: 
1. Check that `HierarchyLinks_Test` has rows where `HierarchyId = 2`
2. Verify `User_Test` has matching `MemberDocId` values
3. Try with `@IsFirstPage = 1` to get total row count

### Log grid not showing Start/End times
**Solution**: 
1. Make sure you're running QueryOne, QueryTwo, or QueryThree (not Q1-Q4)
2. Check browser console for JavaScript errors
3. Verify `usp_Benchmark_GetLogs` returns the new columns

## Performance Comparison

After deployment, you can compare the three approaches:

| Approach | Temp Table | Best For | Typical Use Case |
|----------|-----------|----------|------------------|
| QueryOne (OR) | Yes | Medium datasets | General pagination |
| QueryTwo (UNION ALL) | Yes | Complex queries | When optimizer struggles with OR |
| QueryThree (Direct Seek) | No | Large datasets | Production systems with proper indexes |

## Rollback

If you need to rollback the changes:

```sql
-- Remove new columns
ALTER TABLE QueryExecutionLog DROP COLUMN ExecutionStartTime;
ALTER TABLE QueryExecutionLog DROP COLUMN ExecutionEndTime;

-- Make ExecutedBy NOT NULL again (if needed)
UPDATE QueryExecutionLog SET ExecutedBy = 'System' WHERE ExecutedBy IS NULL;
ALTER TABLE QueryExecutionLog ALTER COLUMN ExecutedBy NVARCHAR(100) NOT NULL;

-- Drop stored procedures
DROP PROCEDURE IF EXISTS usp_Benchmark_QueryOne_OrBasedKeyset;
DROP PROCEDURE IF EXISTS usp_Benchmark_QueryTwo_UnionAllKeyset;
DROP PROCEDURE IF EXISTS usp_Benchmark_QueryThree_DirectSeek;
```

## Support

For issues or questions, check:
1. SQL Server error log
2. Application Output window in Visual Studio
3. Browser console for JavaScript errors
4. QueryExecutionLog table for error messages
