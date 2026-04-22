-- =====================================================
-- Update QueryExecutionLog Table Schema
-- Add ExecutionStartTime and ExecutionEndTime columns
-- =====================================================

-- Check if columns already exist before adding them
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.QueryExecutionLog') AND name = 'ExecutionStartTime')
BEGIN
    ALTER TABLE [dbo].[QueryExecutionLog]
    ADD [ExecutionStartTime] DATETIME2(7) NULL;
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.QueryExecutionLog') AND name = 'ExecutionEndTime')
BEGIN
    ALTER TABLE [dbo].[QueryExecutionLog]
    ADD [ExecutionEndTime] DATETIME2(7) NULL;
END

-- Update existing rows to set default values (optional)
-- You can set ExecutionStartTime = ExecutedAt and ExecutionEndTime = ExecutedAt for existing records
UPDATE [dbo].[QueryExecutionLog]
SET 
    [ExecutionStartTime] = ISNULL([ExecutionStartTime], [ExecutedAt]),
    [ExecutionEndTime] = ISNULL([ExecutionEndTime], [ExecutedAt])
WHERE [ExecutionStartTime] IS NULL OR [ExecutionEndTime] IS NULL;

-- Make columns NOT NULL after populating them (optional)
ALTER TABLE [dbo].[QueryExecutionLog]
ALTER COLUMN [ExecutionStartTime] DATETIME2(7) NOT NULL;

ALTER TABLE [dbo].[QueryExecutionLog]
ALTER COLUMN [ExecutionEndTime] DATETIME2(7) NOT NULL;

PRINT 'QueryExecutionLog table updated successfully with ExecutionStartTime and ExecutionEndTime columns.';
GO
