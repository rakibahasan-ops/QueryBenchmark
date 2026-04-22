-- =====================================================
-- Update usp_Benchmark_GetLogs to include new columns
-- =====================================================

CREATE OR ALTER PROCEDURE usp_Benchmark_GetLogs
    @TopN INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        LogId,
        QueryName,
        QueryDescription,
        ExecutionTimeMs,
        RowsReturned,
        IsSuccess,
        ErrorMessage,
        ExecutedAt,
        ExecutionStartTime,
        ExecutionEndTime
    FROM QueryExecutionLog
    ORDER BY ExecutedAt DESC;
END
GO
