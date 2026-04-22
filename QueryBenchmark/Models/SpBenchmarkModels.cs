using System.Data;

namespace QueryBenchmark.Models;

public class SpInfo
{
    public string Name { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string CursorLabel { get; set; } = string.Empty;
    public string CursorParameterName { get; set; } = string.Empty;
    public SqlDbType CursorDbType { get; set; }
    public bool IsSpecialMobile { get; set; } = false;
    public string? SqlQuery { get; set; }  // Direct SQL query text
    public bool UseDirectQuery { get; set; } = false;  // Use query instead of SP
}

public class SpExecutionRequest
{
    public string SpName { get; set; } = string.Empty;
    public string? CursorValue { get; set; }
    public int LastEntityId { get; set; } = 0;
    public int LastMemberDocId { get; set; } = 0;
    public int LastNullMemberDocId { get; set; } = 0;
    public int PageSize { get; set; } = 20;
    public bool IsFirstPage { get; set; } = true;
}

public class SpExecutionResult
{
    public bool Success { get; set; }
    public string SpName { get; set; } = string.Empty;
    public long ExecutionTimeMs { get; set; }
    public int RowsReturned { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime ExecutionStartTime { get; set; }
    public DateTime ExecutionEndTime { get; set; }
    public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;
    public List<Dictionary<string, object?>> ResultData { get; set; } = new();
}
