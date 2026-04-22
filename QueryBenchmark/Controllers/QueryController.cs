using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using QueryBenchmark.Models;
using System.Data;

namespace QueryBenchmark.Controllers;

[ApiController]
[Route("api/[controller]")]
public class QueryController : ControllerBase
{
    private readonly IConfiguration _config;

    // Map of query key → SP name
    private static readonly Dictionary<string, string> SpMap = new()
    {
        ["QueryOne"] = "usp_Benchmark_QueryOne_OrBasedKeyset",
        ["QueryTwo"] = "usp_Benchmark_QueryTwo_UnionAllKeyset",
        ["QueryThree"] = "usp_Benchmark_QueryThree_DirectSeek",
    };

    public QueryController(IConfiguration config)
    {
        _config = config;
    }

    // ── Execute ────────────────────────────────────────────────────────────────
    [HttpPost("execute/{queryKey}")]
    public async Task<IActionResult> Execute(string queryKey)
    {
        if (!SpMap.TryGetValue(queryKey, out var spName))
            return BadRequest(new { error = $"Unknown query key: {queryKey}" });

        var result = new QueryResult { QueryName = queryKey };

        await using var conn = new SqlConnection(
            _config.GetConnectionString("DefaultConnection"));

        await conn.OpenAsync();

        await using var cmd = new SqlCommand(spName, conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };

        // Add SP-specific parameters
        AddParameters(cmd, queryKey);

        try
        {
            await using var reader = await cmd.ExecuteReaderAsync();

            // Consume the first result set (actual query data) without storing it
            while (await reader.ReadAsync()) { }

            // Move to the second result set (timing metadata)
            if (await reader.NextResultAsync())
            {
                // Read the single timing row returned by every SP
                if (await reader.ReadAsync())
                {
                    result.ExecutionTimeMs = reader.GetInt64(reader.GetOrdinal("ExecutionTimeMs"));
                    result.RowsReturned = reader.GetInt32(reader.GetOrdinal("RowsReturned"));
                    result.ExecutedAt = reader.GetDateTime(reader.GetOrdinal("ExecutedAt"));
                    result.Success = true;

                    // Handle new columns for QueryOne, QueryTwo, QueryThree
                    if (queryKey.StartsWith("Query"))
                    {
                        var startOrd = reader.GetOrdinal("ExecutionStartTime");
                        var endOrd = reader.GetOrdinal("ExecutionEndTime");

                        result.TimingBreakdown["ExecutionStartTime"] = reader.GetDateTime(startOrd);
                        result.TimingBreakdown["ExecutionEndTime"] = reader.GetDateTime(endOrd);
                    }

                    var errOrd = reader.GetOrdinal("ErrorMessage");
                    if (!reader.IsDBNull(errOrd))
                    {
                        result.ErrorMessage = reader.GetString(errOrd);
                        result.Success = false;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.ErrorMessage = ex.Message;
            result.ExecutedAt = DateTime.UtcNow;
        }

        return Ok(result);
    }

    // ── Logs ───────────────────────────────────────────────────────────────────
    [HttpGet("logs")]
    public async Task<IActionResult> GetLogs()
    {
        var logs = new List<ExecutionLog>();

        await using var conn = new SqlConnection(
            _config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("usp_Benchmark_GetLogs", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@TopN", 50);

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            logs.Add(new ExecutionLog
            {
                Id = reader.GetInt32(0),
                QueryName = reader.GetString(1),
                QueryDescription = reader.GetString(2),
                ExecutionTimeMs = reader.GetInt64(3),
                RowsReturned = reader.GetInt32(4),
                IsSuccess = reader.GetBoolean(5),
                ErrorMessage = reader.IsDBNull(6) ? null : reader.GetString(6),
                ExecutedAt = reader.GetDateTime(7),
                ExecutionStartTime = reader.IsDBNull(8) ? DateTime.MinValue : reader.GetDateTime(8),
                ExecutionEndTime = reader.IsDBNull(9) ? DateTime.MinValue : reader.GetDateTime(9),
            });
        }

        return Ok(logs);
    }

    [HttpDelete("logs")]
    public async Task<IActionResult> ClearLogs()
    {
        // Only clear the grid on UI, don't delete from database
        return Ok(new { message = "Grid cleared." });
    }

    // ── Benchmark Executor ─────────────────────────────────────────────────────
    [HttpPost("benchmark")]
    public async Task<IActionResult> RunBenchmark(
        [FromQuery] string? lastCreationDate = null,
        [FromQuery] int lastEntityId = 0,
        [FromQuery] int pageSize = 20,
        [FromQuery] bool isFirstPage = true)
    {
        var lastDate = string.IsNullOrEmpty(lastCreationDate) 
            ? "9999-12-31 23:59:59.9999999" 
            : lastCreationDate;

        var results = new List<QueryResult>();
        var queries = new[] { "QueryOne", "QueryTwo", "QueryThree" };

        await using var conn = new SqlConnection(
            _config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        foreach (var queryKey in queries)
        {
            var result = new QueryResult { QueryName = queryKey };
            var spName = SpMap[queryKey];

            await using var cmd = new SqlCommand(spName, conn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 120
            };

            cmd.Parameters.AddWithValue("@LastCreationDate", lastDate);
            cmd.Parameters.AddWithValue("@LastEntityId", lastEntityId);
            cmd.Parameters.AddWithValue("@PageSize", pageSize);
            cmd.Parameters.AddWithValue("@IsFirstPage", isFirstPage);

            try
            {
                await using var reader = await cmd.ExecuteReaderAsync();

                while (await reader.ReadAsync()) { }

                if (await reader.NextResultAsync())
                {
                    if (await reader.ReadAsync())
                    {
                        result.ExecutionTimeMs = reader.GetInt64(reader.GetOrdinal("ExecutionTimeMs"));
                        result.RowsReturned = reader.GetInt32(reader.GetOrdinal("RowsReturned"));
                        result.ExecutedAt = reader.GetDateTime(reader.GetOrdinal("ExecutedAt"));
                        result.Success = true;

                        var startOrd = reader.GetOrdinal("ExecutionStartTime");
                        var endOrd = reader.GetOrdinal("ExecutionEndTime");
                        result.TimingBreakdown["ExecutionStartTime"] = reader.GetDateTime(startOrd);
                        result.TimingBreakdown["ExecutionEndTime"] = reader.GetDateTime(endOrd);

                        var errOrd = reader.GetOrdinal("ErrorMessage");
                        if (!reader.IsDBNull(errOrd))
                        {
                            result.ErrorMessage = reader.GetString(errOrd);
                            result.Success = false;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.ErrorMessage = ex.Message;
                result.ExecutedAt = DateTime.UtcNow;
            }

            results.Add(result);
        }

        return Ok(results);
    }

    // ── Benchmark Comparison Report ────────────────────────────────────────────
    [HttpGet("benchmark/comparison")]
    public async Task<IActionResult> GetBenchmarkComparison()
    {
        var comparisons = new List<BenchmarkComparisonResult>();

        await using var conn = new SqlConnection(
            _config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var sql = @"
SELECT
    LogId,
    QueryName,
    QueryDescription,
    ExecutionStartTime,
    ExecutionEndTime,
    ExecutionTimeMs,
    RowsReturned,
    IsSuccess,
    ISNULL(ErrorMessage, '-') AS ErrorMessage,
    ExecutedAt,
    RANK() OVER (
        ORDER BY
            CASE WHEN IsSuccess = 1
                 THEN ExecutionTimeMs
                 ELSE 999999
            END ASC
    ) AS SpeedRank
FROM dbo.QueryExecutionLog
WHERE QueryName IN (
    'usp_Benchmark_QueryOne_OrBasedKeyset',
    'usp_Benchmark_QueryTwo_UnionAllKeyset',
    'usp_Benchmark_QueryThree_DirectSeek'
)
ORDER BY ExecutionTimeMs ASC;";

        await using var cmd = new SqlCommand(sql, conn);
        await using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            comparisons.Add(new BenchmarkComparisonResult
            {
                LogId = reader.GetInt32(0),
                QueryName = reader.GetString(1),
                QueryDescription = reader.GetString(2),
                ExecutionStartTime = reader.GetDateTime(3),
                ExecutionEndTime = reader.GetDateTime(4),
                ExecutionTimeMs = reader.GetInt64(5),
                RowsReturned = reader.GetInt32(6),
                IsSuccess = reader.GetBoolean(7),
                ErrorMessage = reader.GetString(8),
                ExecutedAt = reader.GetDateTime(9),
                SpeedRank = reader.GetInt32(10)
            });
        }

        return Ok(comparisons);
    }

    // ── Helper ─────────────────────────────────────────────────────────────────
    private static void AddParameters(SqlCommand cmd, string queryKey)
    {
        switch (queryKey)
        {
            case "QueryOne":
            case "QueryTwo":
            case "QueryThree":
                cmd.Parameters.AddWithValue("@LastCreationDate", "9999-12-31 23:59:59.9999999");
                cmd.Parameters.AddWithValue("@LastEntityId", 0);
                cmd.Parameters.AddWithValue("@PageSize", 20);
                cmd.Parameters.AddWithValue("@IsFirstPage", 1);
                break;
        }
    }
}