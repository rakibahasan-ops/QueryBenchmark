using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace QueryBenchmark.Models;

[Table("QueryExecutionLog")]
public class ExecutionLog
{
    [Key]
    [Column("LogId")]
    public int Id { get; set; }

    public string QueryName { get; set; } = string.Empty;
    public string QueryDescription { get; set; } = string.Empty;
    public long ExecutionTimeMs { get; set; }
    public int RowsReturned { get; set; }
    public bool IsSuccess { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime ExecutionStartTime { get; set; }
    public DateTime ExecutionEndTime { get; set; }
    public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;
    public string? ExecutedBy { get; set; }
}