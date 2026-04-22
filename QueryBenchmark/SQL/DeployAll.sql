-- =====================================================
-- Deploy All Stored Procedures and Update Schema
-- Run this script to set up the database
-- =====================================================

-- Step 1: Update table schema
PRINT 'Step 1: Updating table schema...';
:r UpdateTableSchema.sql

-- Step 2: Create/Update stored procedures
PRINT 'Step 2: Creating stored procedures...';
:r SP_QueryOne_OrBasedKeyset.sql
:r SP_QueryTwo_UnionAllKeyset.sql
:r SP_QueryThree_DirectSeek.sql
:r SP_GetLogs.sql

PRINT 'All stored procedures created successfully!';
GO
