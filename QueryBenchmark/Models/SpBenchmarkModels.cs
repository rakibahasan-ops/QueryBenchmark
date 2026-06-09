using System.Data;

namespace QueryBenchmark.Models;

public class SpInfo
{
    public string Name { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;

    public string CursorLabel { get; set; } = string.Empty;
    public string CursorParameterName { get; set; } = string.Empty;

    public string? InputCursorLabel { get; set; }
    public string? InputCursorParameterName { get; set; }

    public SqlDbType CursorDbType { get; set; }

    public bool IsSpecialMobile { get; set; }

    public bool UseDirectQuery { get; set; }

    public string? SqlQuery { get; set; }
}

public class SpExecutionRequest
{
    public string SpName { get; set; } = string.Empty;

    public string? CursorValue { get; set; }

    public string? InputValue { get; set; }

    public string? InputCursorValue { get; set; }

    public int LastEntityId { get; set; }

    public int LastMemberDocId { get; set; }

    public int LastNullMemberDocId { get; set; }

    public int PageSize { get; set; }

    public bool IsFirstPage { get; set; }
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
