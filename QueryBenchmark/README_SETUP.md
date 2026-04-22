# Query Benchmark - Setup Guide

This guide will help you set up the three new query benchmark stored procedures (QueryOne, QueryTwo, QueryThree) for keyset pagination performance testing.

## What's New

### 1. Updated Database Schema
- Added `ExecutionStartTime` and `ExecutionEndTime` columns to the `QueryExecutionLog` table
- These columns capture the exact start and end timestamps of query execution

### 2. Three New Stored Procedures
1. **usp_Benchmark_QueryOne_OrBasedKeyset** - OR-based keyset pagination with temp table
2. **usp_Benchmark_QueryTwo_UnionAllKeyset** - UNION ALL keyset pagination with temp table  
3. **usp_Benchmark_QueryThree_DirectSeek** - Direct seek without temp table

### 3. Updated UI
- Added three new query buttons (QueryOne, QueryTwo, QueryThree) with gradient badges
- Updated log table to show Start Time and End Time columns
- Enhanced visual styling for benchmark queries

## Installation Steps

### Option 1: Quick Deploy (Recommended)
1. Open SQL Server Management Studio (SSMS)
2. Connect to your database server
3. Open the file: `QueryBenchmark\SQL\CompleteDeployment.sql`
4. **IMPORTANT**: Change the database name on line 6:
   ```sql
   USE [YourDatabaseName]; -- Change this to your actual database name
   ```
5. Execute the entire script (F5)

### Option 2: Step-by-Step Deploy
1. Run `QueryBenchmark\SQL\UpdateTableSchema.sql` - Updates the table schema
2. Run `QueryBenchmark\SQL\SP_QueryOne_OrBasedKeyset.sql` - Creates QueryOne SP
3. Run `QueryBenchmark\SQL\SP_QueryTwo_UnionAllKeyset.sql` - Creates QueryTwo SP
4. Run `QueryBenchmark\SQL\SP_QueryThree_DirectSeek.sql` - Creates QueryThree SP
5. Run `QueryBenchmark\SQL\SP_GetLogs.sql` - Updates the GetLogs SP

## Verify Installation

After running the deployment script, verify the installation:

```sql
-- Check if columns exist
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'QueryExecutionLog';

-- Check if stored procedures exist
SELECT name 
FROM sys.procedures 
WHERE name LIKE 'usp_Benchmark_Query%';
```

You should see:
- ✅ `ExecutionStartTime` column (datetime2)
- ✅ `ExecutionEndTime` column (datetime2)
- ✅ `usp_Benchmark_QueryOne_OrBasedKeyset`
- ✅ `usp_Benchmark_QueryTwo_UnionAllKeyset`
- ✅ `usp_Benchmark_QueryThree_DirectSeek`

## Usage

1. **Run the Application**
   ```bash
   dotnet run
   ```

2. **Open Browser**
   Navigate to: `https://localhost:5001` (or your configured port)

3. **Execute Benchmark Queries**
   - Click **QueryOne** button to test OR-based keyset approach
   - Click **QueryTwo** button to test UNION ALL keyset approach
   - Click **QueryThree** button to test Direct Seek approach

4. **View Results**
   - Execution logs will display in the table below
   - You'll see Start Time, End Time, and Total Execution Time
   - Compare performance across all three approaches

## Log Table Columns

| Column | Description |
|--------|-------------|
| # | Sequential execution number |
| Query | Query name (QueryOne, QueryTwo, QueryThree) |
| Time (ms) | Total execution time in milliseconds |
| Rows | Number of rows returned |
| Status | Success/Failed indicator |
| Start Time | Query execution start timestamp |
| End Time | Query execution end timestamp |
| Executed At | Overall execution timestamp |

## Color Coding

The log table uses color coding for execution times:
- 🟢 **Green** (< 500ms) - Fast
- 🟡 **Yellow** (500ms - 2000ms) - Medium
- 🔴 **Red** (> 2000ms) - Slow

## Query Descriptions

### QueryOne: OR-based Keyset
- Creates a temp table with clustered index
- Uses OR condition for keyset pagination
- Best for: Consistent performance across pages

### QueryTwo: UNION ALL Keyset
- Creates a temp table with clustered index
- Uses UNION ALL to combine two seeks
- Best for: Eliminating OR performance issues

### QueryThree: Direct Seek
- No temp table creation
- Direct seeks on base tables
- Best for: Reducing tempdb overhead

## Troubleshooting

### Error: "Invalid object name 'QueryExecutionLog'"
**Solution**: Ensure the table exists in your database. Run the schema update script first.

### Error: "Could not find stored procedure 'usp_Benchmark_QueryOne_OrBasedKeyset'"
**Solution**: Run the CompleteDeployment.sql script to create all stored procedures.

### Error: "Invalid column name 'ExecutionStartTime'"
**Solution**: The table schema hasn't been updated. Run UpdateTableSchema.sql.

### No data showing in the UI
**Solution**: 
1. Check your connection string in `appsettings.json`
2. Verify the stored procedures exist
3. Check browser console for JavaScript errors

## Files Created

### SQL Files
- `SQL/UpdateTableSchema.sql` - Table schema update
- `SQL/SP_QueryOne_OrBasedKeyset.sql` - QueryOne stored procedure
- `SQL/SP_QueryTwo_UnionAllKeyset.sql` - QueryTwo stored procedure
- `SQL/SP_QueryThree_DirectSeek.sql` - QueryThree stored procedure
- `SQL/SP_GetLogs.sql` - Updated GetLogs stored procedure
- `SQL/CompleteDeployment.sql` - Complete deployment script (use this!)
- `SQL/DeployAll.sql` - SQLCMD mode deployment script

### Updated C# Files
- `Models/ExecutionLog.cs` - Added ExecutionStartTime and ExecutionEndTime properties
- `Controllers/QueryController.cs` - Added support for three new queries
- `Views/Home/Index.cshtml` - Added UI for new queries and updated log table

## Next Steps

1. ✅ Deploy the database changes
2. ✅ Run the application
3. ✅ Execute all three queries multiple times
4. ✅ Compare execution times
5. ✅ Analyze which approach performs best for your data

## Support

If you encounter issues:
1. Check the browser console (F12) for JavaScript errors
2. Check the application logs
3. Verify SQL Server connection
4. Ensure all stored procedures are created correctly

---

**Happy Benchmarking!** 🚀
