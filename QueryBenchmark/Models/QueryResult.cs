namespace QueryBenchmark.Models;

public class QueryResult
{
    public bool Success { get; set; }
    public string QueryName { get; set; } = string.Empty;
    public long ExecutionTimeMs { get; set; }
    public int RowsReturned { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime ExecutedAt { get; set; }
    public Dictionary<string, object?> TimingBreakdown { get; set; } = new();
}

public class BenchmarkComparisonResult
{
    public int LogId { get; set; }
    public string QueryName { get; set; } = string.Empty;
    public string QueryDescription { get; set; } = string.Empty;
    public DateTime ExecutionStartTime { get; set; }
    public DateTime ExecutionEndTime { get; set; }
    public long ExecutionTimeMs { get; set; }
    public int RowsReturned { get; set; }
    public bool IsSuccess { get; set; }
    public string ErrorMessage { get; set; } = "-";
    public DateTime ExecutedAt { get; set; }
    public int SpeedRank { get; set; }
}