using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using QueryBenchmark.Models;
using System.Data;
using System.Diagnostics;

namespace QueryBenchmark.Controllers;

public class SpBenchmarkController : Controller
{
    private readonly IConfiguration _config;

    private static readonly Dictionary<string, SpInfo> StoredProcedures = new()
    {
        ["usp_Benchmark_CreationDate_DESC"] = new SpInfo
        {
            Name = "usp_Benchmark_CreationDate_DESC",
            DisplayName = "CreationDate ↓",
            CursorLabel = "@LastCreationDate",
            CursorParameterName = "@LastCreationDate",
            CursorDbType = SqlDbType.DateTime,
            UseDirectQuery = true,
            SqlQuery = @"
                SET NOCOUNT ON;
                DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
                DECLARE @TotalRows BIGINT = -1;
                DECLARE @ActualLastCreationDate DATETIME2 = ISNULL(@LastCreationDate, GETDATE());

                IF @IsFirstPage = 1
                BEGIN
                    SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks WHERE HierarchyId = 2;
                END

                ;WITH SelectedMembers AS
                (
                    SELECT TOP (@PageSize) HL.EntityId
                    FROM [User] U
                    INNER JOIN HierarchyLinks HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                    WHERE U.CreationDate <= @ActualLastCreationDate
                    AND NOT (U.CreationDate = @ActualLastCreationDate AND HL.EntityId <= @LastEntityId)
                    ORDER BY U.CreationDate DESC, HL.EntityId ASC
                )
                SELECT
                    U.CreationDate AS NextCursor_CreationDate,
                    M.EntityId AS NextCursor_Id,
                    M.EntityId AS MemberDocId,
                    U.MemberId AS MID,
                    U.UserId,
                    U.FirstName,
                    U.LastName,
                    U.ProfilePicURL,
                    U.EmailAddress,
                    CONCAT(UP.CountryCode, UP.Number) AS Mobile,
                    U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
                    CMS.EntitySummary AS OrganisationSummary,
                    MS.Entity1Memberships AS MembershipSummary,
                    s.[Name] AS [Status],
                    s.StateId AS StatusId,
                    U.DOB,
                    DATEDIFF(YEAR, U.DOB, GETDATE()) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, U.DOB, GETDATE()), U.DOB) > GETDATE() THEN 1 ELSE 0 END AS Age,
                    U.UserSyncId,
                    ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
                    ISNULL(F.FamilyCount, 0) AS NumberOfFamily,
                    @TotalRows AS TotalRows
                FROM SelectedMembers M
                INNER JOIN [User] U ON U.MemberDocId = M.EntityId
                INNER JOIN ClubMemberSummary CMS ON CMS.EntityId = M.EntityId
                INNER JOIN MembershipSummary MS ON MS.EntityId = M.EntityId
                INNER JOIN ProcessInfo p ON p.PrimaryDocId = M.EntityId
                INNER JOIN [State] s ON s.StateId = p.CurrentStateId
                OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links FL WHERE FL.EntityId = M.EntityId) F
                OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
                ORDER BY U.CreationDate DESC, M.EntityId ASC
                OPTION (RECOMPILE);

                SELECT CAST(DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME()) AS BIGINT) AS ExecutionTimeMs,
                       @@ROWCOUNT AS RowsReturned,
                       @StartTime AS ExecutionStartTime,
                       SYSUTCDATETIME() AS ExecutionEndTime,
                       SYSUTCDATETIME() AS ExecutedAt,
                       NULL AS ErrorMessage;
            "
        },
        ["usp_Benchmark_FirstName_ASC"] = new SpInfo
        {
            Name = "usp_Benchmark_FirstName_ASC",
            DisplayName = "FirstName ↑",
            CursorLabel = "@LastFirstName",
            CursorParameterName = "@LastFirstName",
            CursorDbType = SqlDbType.NVarChar,
            UseDirectQuery = true,
            SqlQuery = @"
                SET NOCOUNT ON;
                DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
                DECLARE @TotalRows BIGINT = -1;

                IF @IsFirstPage = 1
                BEGIN
                    SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks WHERE HierarchyId = 2;
                END

                ;WITH SelectedMembers AS
                (
                    SELECT TOP (@PageSize) HL.EntityId
                    FROM [User] U WITH (INDEX(IX_User_FirstName_MemberDocId))
                    INNER JOIN HierarchyLinks HL WITH (INDEX(IX_HierarchyLinks_HierarchyId_EntityId))
                        ON  HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                    WHERE U.FirstName >= @LastFirstName
                    AND NOT (U.FirstName = @LastFirstName AND HL.EntityId <= @LastEntityId)
                    ORDER BY U.FirstName ASC, HL.EntityId ASC
                )
                SELECT
                    U.FirstName AS NextCursor_FirstName,
                    M.EntityId AS NextCursor_Id,
                    M.EntityId AS MemberDocId,
                    U.MemberId AS MID,
                    U.UserId,
                    U.FirstName,
                    U.LastName,
                    U.ProfilePicURL,
                    U.EmailAddress,
                    ISNULL(UP.CountryCode, '') + ISNULL(UP.Number, '') AS Mobile,
                    U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
                    CMS.EntitySummary AS OrganisationSummary,
                    MS.Entity1Memberships AS MembershipSummary,
                    s.[Name] AS [Status],
                    s.StateId AS StatusId,
                    U.DOB,
                    CASE 
                        WHEN U.DOB IS NULL THEN NULL
                        ELSE (CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112)) - CONVERT(INT, CONVERT(CHAR(8), U.DOB, 112))) / 10000
                    END AS Age,
                    U.UserSyncId,
                    ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
                    ISNULL(F.FamilyCount, 0) AS NumberOfFamily,
                    U.CreationDate,
                    @TotalRows AS TotalRows
                FROM SelectedMembers M
                INNER JOIN [User] U ON U.MemberDocId = M.EntityId
                INNER JOIN ClubMemberSummary CMS ON CMS.EntityId = M.EntityId
                INNER JOIN MembershipSummary MS ON MS.EntityId = M.EntityId
                INNER JOIN ProcessInfo p ON p.PrimaryDocId = M.EntityId
                INNER JOIN [State] s ON s.StateId = p.CurrentStateId
                OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links FL WHERE FL.EntityId = M.EntityId) F
                OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
                ORDER BY U.FirstName ASC, M.EntityId ASC
                OPTION (RECOMPILE);
            "
        },
        ["usp_Benchmark_LastName_ASC"] = new SpInfo
        {
            Name = "usp_Benchmark_LastName_ASC",
            DisplayName = "LastName ↑",
            CursorLabel = "@LastLastName",
            CursorParameterName = "@LastLastName",
            CursorDbType = SqlDbType.NVarChar,
            UseDirectQuery = true,
            SqlQuery = @"
                SET NOCOUNT ON;
                DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
                DECLARE @TotalRows BIGINT = -1;

                IF @IsFirstPage = 1
                BEGIN
                    SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks WHERE HierarchyId = 2;
                END

                ;WITH SelectedMembers AS
                (
                    SELECT TOP (@PageSize) HL.EntityId
                    FROM [User] U
                    INNER JOIN HierarchyLinks HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                    WHERE U.LastName >= @LastLastName
                    AND NOT (U.LastName = @LastLastName AND HL.EntityId <= @LastEntityId)
                    ORDER BY U.LastName ASC, HL.EntityId ASC
                )
                SELECT
                    U.LastName AS NextCursor_LastName,
                    M.EntityId AS NextCursor_Id,
                    M.EntityId AS MemberDocId,
                    U.MemberId AS MID,
                    U.UserId,
                    U.FirstName,
                    U.LastName,
                    U.ProfilePicURL,
                    U.EmailAddress,
                    CONCAT(UP.CountryCode, UP.Number) AS Mobile,
                    U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
                    CMS.EntitySummary AS OrganisationSummary,
                    MS.Entity1Memberships AS MembershipSummary,
                    s.[Name] AS [Status],
                    s.StateId AS StatusId,
                    U.DOB,
                    DATEDIFF(YEAR, U.DOB, GETDATE()) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, U.DOB, GETDATE()), U.DOB) > GETDATE() THEN 1 ELSE 0 END AS Age,
                    U.UserSyncId,
                    ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
                    ISNULL(F.FamilyCount, 0) AS NumberOfFamily,
                    U.CreationDate,
                    @TotalRows AS TotalRows
                FROM SelectedMembers M
                INNER JOIN [User] U ON U.MemberDocId = M.EntityId
                INNER JOIN ClubMemberSummary CMS ON CMS.EntityId = M.EntityId
                INNER JOIN MembershipSummary MS ON MS.EntityId = M.EntityId
                INNER JOIN ProcessInfo p ON p.PrimaryDocId = M.EntityId
                INNER JOIN [State] s ON s.StateId = p.CurrentStateId
                OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links FL WHERE FL.EntityId = M.EntityId) F
                OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
                ORDER BY U.LastName ASC, M.EntityId ASC
                OPTION (RECOMPILE);
            "
        },
        ["usp_Benchmark_Email_ASC"] = new SpInfo
        {
            Name = "usp_Benchmark_Email_ASC",
            DisplayName = "Email ↑",
            CursorLabel = "@LastEmailAddress",
            CursorParameterName = "@LastEmailAddress",
            CursorDbType = SqlDbType.NVarChar,
            UseDirectQuery = true,
            SqlQuery = @"
                SET NOCOUNT ON;
                DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
                DECLARE @TotalRows BIGINT = -1;

                IF @IsFirstPage = 1
                BEGIN
                    SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks WHERE HierarchyId = 2;
                END

                ;WITH SelectedMembers AS
                (
                    SELECT TOP (@PageSize) HL.EntityId
                    FROM [User] U
                    INNER JOIN HierarchyLinks HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                    WHERE U.EmailAddress >= @LastEmailAddress
                    AND NOT (U.EmailAddress = @LastEmailAddress AND HL.EntityId <= @LastEntityId)
                    ORDER BY U.EmailAddress ASC, HL.EntityId ASC
                )
                SELECT
                    U.EmailAddress AS NextCursor_EmailAddress,
                    M.EntityId AS NextCursor_Id,
                    M.EntityId AS MemberDocId,
                    U.MemberId AS MID,
                    U.UserId,
                    U.FirstName,
                    U.LastName,
                    U.ProfilePicURL,
                    U.EmailAddress,
                    CONCAT(UP.CountryCode, UP.Number) AS Mobile,
                    U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
                    CMS.EntitySummary AS OrganisationSummary,
                    MS.Entity1Memberships AS MembershipSummary,
                    s.[Name] AS [Status],
                    s.StateId AS StatusId,
                    U.DOB,
                    DATEDIFF(YEAR, U.DOB, GETDATE()) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, U.DOB, GETDATE()), U.DOB) > GETDATE() THEN 1 ELSE 0 END AS Age,
                    U.UserSyncId,
                    ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
                    ISNULL(F.FamilyCount, 0) AS NumberOfFamily,
                    U.CreationDate,
                    @TotalRows AS TotalRows
                FROM SelectedMembers M
                INNER JOIN [User] U ON U.MemberDocId = M.EntityId
                INNER JOIN ClubMemberSummary CMS ON CMS.EntityId = M.EntityId
                INNER JOIN MembershipSummary MS ON MS.EntityId = M.EntityId
                INNER JOIN ProcessInfo p ON p.PrimaryDocId = M.EntityId
                INNER JOIN [State] s ON s.StateId = p.CurrentStateId
                OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links FL WHERE FL.EntityId = M.EntityId) F
                OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
                ORDER BY U.EmailAddress ASC, M.EntityId ASC
                OPTION (RECOMPILE);
            "
        },
        ["usp_Benchmark_MID_ASC"] = new SpInfo
        {
            Name = "usp_Benchmark_MID_ASC",
            DisplayName = "MID ↑",
            CursorLabel = "@LastMemberId",
            CursorParameterName = "@LastMemberId",
            CursorDbType = SqlDbType.NVarChar,
            UseDirectQuery = true,
            SqlQuery = @"
                SET NOCOUNT ON;
                DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
                DECLARE @TotalRows BIGINT = -1;

                IF @IsFirstPage = 1
                BEGIN
                    SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks WHERE HierarchyId = 2;
                END

                ;WITH SelectedMembers AS
                (
                    SELECT TOP (@PageSize) HL.EntityId
                    FROM [User] U
                    INNER JOIN HierarchyLinks HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                    WHERE U.MemberId >= @LastMemberId
                    AND NOT (U.MemberId = @LastMemberId AND HL.EntityId <= @LastEntityId)
                    ORDER BY U.MemberId ASC, HL.EntityId ASC
                )
                SELECT
                    U.MemberId AS NextCursor_MemberId,
                    M.EntityId AS NextCursor_Id,
                    M.EntityId AS MemberDocId,
                    U.MemberId AS MID,
                    U.UserId,
                    U.FirstName,
                    U.LastName,
                    U.ProfilePicURL,
                    U.EmailAddress,
                    CONCAT(UP.CountryCode, UP.Number) AS Mobile,
                    U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
                    CMS.EntitySummary AS OrganisationSummary,
                    MS.Entity1Memberships AS MembershipSummary,
                    s.[Name] AS [Status],
                    s.StateId AS StatusId,
                    U.DOB,
                    DATEDIFF(YEAR, U.DOB, GETDATE()) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, U.DOB, GETDATE()), U.DOB) > GETDATE() THEN 1 ELSE 0 END AS Age,
                    U.UserSyncId,
                    ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
                    ISNULL(F.FamilyCount, 0) AS NumberOfFamily,
                    U.CreationDate,
                    @TotalRows AS TotalRows
                FROM SelectedMembers M
                INNER JOIN [User] U ON U.MemberDocId = M.EntityId
                INNER JOIN ClubMemberSummary CMS ON CMS.EntityId = M.EntityId
                INNER JOIN MembershipSummary MS ON MS.EntityId = M.EntityId
                INNER JOIN ProcessInfo p ON p.PrimaryDocId = M.EntityId
                INNER JOIN [State] s ON s.StateId = p.CurrentStateId
                OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links FL WHERE FL.EntityId = M.EntityId) F
                OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
                ORDER BY U.MemberId ASC, M.EntityId ASC
                OPTION (RECOMPILE);
            "
        },
        ["usp_Benchmark_Mobile_ASC"] = new SpInfo
        {
            Name = "usp_Benchmark_Mobile_ASC",
            DisplayName = "Mobile ↑",
            CursorLabel = "@LastMobile",
            CursorParameterName = "@LastMobile",
            CursorDbType = SqlDbType.NVarChar,
            IsSpecialMobile = true,
            UseDirectQuery = true,
            SqlQuery = @"
                SET NOCOUNT ON;
                DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
                DECLARE @TotalRows BIGINT = -1;

                IF @IsFirstPage = 1
                BEGIN
                    SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks WHERE HierarchyId = 2;
                END

                ;WITH SelectedMembers AS
                (
                    SELECT TOP (@PageSize) EntityId FROM
                    (
                        -- Part 1: Non-NULL mobile
                        SELECT TOP (@PageSize)
                            HL.EntityId,
                            CONCAT(UP.CountryCode, UP.Number) AS SortMobile,
                            U.MemberDocId AS SortId
                        FROM UserPhoneNumber UP
                        INNER JOIN [User] U ON U.UserId = UP.UserId
                        INNER JOIN HierarchyLinks HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                        WHERE UP.[Type] = 'Mobile'
                        AND CONCAT(UP.CountryCode, UP.Number) >= @LastMobile
                        AND NOT (CONCAT(UP.CountryCode, UP.Number) = @LastMobile AND U.MemberDocId <= @LastMemberDocId)
                        ORDER BY CONCAT(UP.CountryCode, UP.Number) ASC, U.MemberDocId ASC

                        UNION ALL

                        -- Part 2: NULL mobile
                        SELECT TOP (@PageSize)
                            HL.EntityId,
                            NULL AS SortMobile,
                            U.MemberDocId AS SortId
                        FROM [User] U
                        INNER JOIN HierarchyLinks HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                        LEFT JOIN UserPhoneNumber UP2 ON UP2.UserId = U.UserId AND UP2.[Type] = 'Mobile'
                        WHERE UP2.UserId IS NULL
                        AND U.MemberDocId > @LastNullMemberDocId
                        ORDER BY U.MemberDocId ASC
                    ) X
                    ORDER BY CASE WHEN SortMobile IS NULL THEN 1 ELSE 0 END ASC, SortMobile ASC, SortId ASC
                )
                SELECT
                    CONCAT(UP.CountryCode, UP.Number) AS NextCursor_Mobile,
                    M.EntityId AS NextCursor_Id,
                    M.EntityId AS MemberDocId,
                    U.MemberId AS MID,
                    U.UserId,
                    U.FirstName,
                    U.LastName,
                    U.ProfilePicURL,
                    U.EmailAddress,
                    CONCAT(UP.CountryCode, UP.Number) AS Mobile,
                    U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
                    CMS.EntitySummary AS OrganisationSummary,
                    MS.Entity1Memberships AS MembershipSummary,
                    s.[Name] AS [Status],
                    s.StateId AS StatusId,
                    U.DOB,
                    DATEDIFF(YEAR, U.DOB, GETDATE()) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, U.DOB, GETDATE()), U.DOB) > GETDATE() THEN 1 ELSE 0 END AS Age,
                    U.UserSyncId,
                    ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
                    ISNULL(F.FamilyCount, 0) AS NumberOfFamily,
                    U.CreationDate,
                    @TotalRows AS TotalRows
                FROM SelectedMembers M
                INNER JOIN [User] U ON U.MemberDocId = M.EntityId
                LEFT JOIN ClubMemberSummary CMS ON CMS.EntityId = M.EntityId
                LEFT JOIN MembershipSummary MS ON MS.EntityId = M.EntityId
                INNER JOIN ProcessInfo p ON p.PrimaryDocId = M.EntityId
                INNER JOIN [State] s ON s.StateId = p.CurrentStateId
                OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links FL WHERE FL.EntityId = M.EntityId) F
                OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
                ORDER BY CASE WHEN CONCAT(UP.CountryCode, UP.Number) IS NULL THEN 1 ELSE 0 END ASC,
                         CONCAT(UP.CountryCode, UP.Number) ASC,
                         M.EntityId ASC
                OPTION (RECOMPILE);
            "
        },
        ["usp_Benchmark_FullName_ASC"] = new SpInfo
        {
            Name = "usp_Benchmark_FullName_ASC",
            DisplayName = "FullName ↑",
            CursorLabel = "@LastFirstName",
            CursorParameterName = "@LastFirstName",
            CursorDbType = SqlDbType.NVarChar,
            UseDirectQuery = true,
            SqlQuery = @"
                SET NOCOUNT ON;
                DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
                DECLARE @TotalRows BIGINT = -1;

                IF @IsFirstPage = 1
                BEGIN
                    SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks WHERE HierarchyId = 2;
                END

                ;WITH SelectedMembers AS
                (
                    SELECT TOP (@PageSize) HL.EntityId
                    FROM [User] U
                    INNER JOIN HierarchyLinks HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                    WHERE U.FirstName >= @LastFirstName
                    AND NOT (U.FirstName = @LastFirstName AND HL.EntityId <= @LastEntityId)
                    ORDER BY U.FirstName ASC, HL.EntityId ASC
                )
                SELECT
                    U.FirstName AS NextCursor_FirstName,
                    M.EntityId AS NextCursor_Id,
                    M.EntityId AS MemberDocId,
                    U.MemberId AS MID,
                    U.UserId,
                    U.FirstName,
                    U.LastName,
                    CONCAT(U.FirstName, ' ', U.LastName) AS FullName,
                    U.ProfilePicURL,
                    U.EmailAddress,
                    CONCAT(UP.CountryCode, UP.Number) AS Mobile,
                    U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
                    CMS.EntitySummary AS OrganisationSummary,
                    MS.Entity1Memberships AS MembershipSummary,
                    s.[Name] AS [Status],
                    s.StateId AS StatusId,
                    U.DOB,
                    DATEDIFF(YEAR, U.DOB, GETDATE()) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, U.DOB, GETDATE()), U.DOB) > GETDATE() THEN 1 ELSE 0 END AS Age,
                    U.UserSyncId,
                    ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
                    ISNULL(F.FamilyCount, 0) AS NumberOfFamily,
                    U.CreationDate,
                    @TotalRows AS TotalRows
                FROM SelectedMembers M
                INNER JOIN [User] U ON U.MemberDocId = M.EntityId
                INNER JOIN ClubMemberSummary CMS ON CMS.EntityId = M.EntityId
                INNER JOIN MembershipSummary MS ON MS.EntityId = M.EntityId
                INNER JOIN ProcessInfo p ON p.PrimaryDocId = M.EntityId
                INNER JOIN [State] s ON s.StateId = p.CurrentStateId
                OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links FL WHERE FL.EntityId = M.EntityId) F
                OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
                ORDER BY U.FirstName ASC, M.EntityId ASC
                OPTION (RECOMPILE);
            "
        }
    };

    public SpBenchmarkController(IConfiguration config)
    {
        _config = config;
    }

    public IActionResult Index()
    {
        return View();
    }

    [HttpPost]
    public async Task<IActionResult> ExecuteSp([FromBody] SpExecutionRequest request)
    {
        if (!StoredProcedures.TryGetValue(request.SpName, out var spInfo))
        {
            return BadRequest(new { error = $"Unknown stored procedure: {request.SpName}" });
        }

        var result = new SpExecutionResult
        {
            SpName = request.SpName,
            ExecutionStartTime = DateTime.Now
        };

        var stopwatch = Stopwatch.StartNew();

        try
        {
            await using var conn = new SqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            SqlCommand cmd;

            // Check if we should use direct query or stored procedure
            if (spInfo.UseDirectQuery && !string.IsNullOrEmpty(spInfo.SqlQuery))
            {
                // Use direct SQL query
                cmd = new SqlCommand(spInfo.SqlQuery, conn)
                {
                    CommandType = CommandType.Text,
                    CommandTimeout = 120
                };
            }
            else
            {
                // Use stored procedure
                cmd = new SqlCommand(spInfo.Name, conn)
                {
                    CommandType = CommandType.StoredProcedure,
                    CommandTimeout = 120
                };
            }

            await using (cmd)
            {
                // Add cursor parameter
                if (!string.IsNullOrWhiteSpace(request.CursorValue))
                {
                    if (spInfo.CursorDbType == SqlDbType.DateTime)
                    {
                        if (DateTime.TryParse(request.CursorValue, out var dateValue))
                        {
                            cmd.Parameters.Add(spInfo.CursorParameterName, SqlDbType.DateTime2).Value = dateValue;
                        }
                        else
                        {
                            result.ErrorMessage = "Invalid DateTime format";
                            result.ExecutionTimeMs = stopwatch.ElapsedMilliseconds;
                            result.ExecutionEndTime = DateTime.Now;
                            return Ok(result);
                        }
                    }
                    else
                    {
                        cmd.Parameters.Add(spInfo.CursorParameterName, SqlDbType.NVarChar, 500).Value = request.CursorValue;
                    }
                }
                else
                {
                    // For string parameters, use empty string instead of NULL to match SP defaults
                    if (spInfo.CursorDbType == SqlDbType.NVarChar)
                    {
                        cmd.Parameters.Add(spInfo.CursorParameterName, SqlDbType.NVarChar, 500).Value = string.Empty;
                    }
                    else
                    {
                        // For DateTime, pass NULL (query will use GETDATE() as default)
                        cmd.Parameters.Add(spInfo.CursorParameterName, SqlDbType.DateTime2).Value = DBNull.Value;
                    }
                }

                // Add entity ID parameter(s) - Mobile SP has special handling
                if (spInfo.IsSpecialMobile)
                {
                    cmd.Parameters.Add("@LastMemberDocId", SqlDbType.Int).Value = request.LastMemberDocId;
                    cmd.Parameters.Add("@LastNullMemberDocId", SqlDbType.Int).Value = request.LastNullMemberDocId;
                }
                else
                {
                    cmd.Parameters.Add("@LastEntityId", SqlDbType.Int).Value = request.LastEntityId;
                }

                // Add PageSize parameter
                cmd.Parameters.Add("@PageSize", SqlDbType.Int).Value = request.PageSize;

                // Add IsFirstPage parameter
                cmd.Parameters.Add("@IsFirstPage", SqlDbType.Bit).Value = request.IsFirstPage;

                // Log parameters for debugging
                Console.WriteLine($"Executing {spInfo.Name} ({(spInfo.UseDirectQuery ? "Direct Query" : "Stored Procedure")}):");
                foreach (SqlParameter param in cmd.Parameters)
                {
                    Console.WriteLine($"  {param.ParameterName} = {param.Value ?? "NULL"} ({param.SqlDbType})");
                }

                await using var reader = await cmd.ExecuteReaderAsync();

                // Read first result set (the actual data)
                var dataTable = new DataTable();
                dataTable.Load(reader);

                Console.WriteLine($"Returned {dataTable.Rows.Count} rows from first result set");

                // Check if there's a second result set (execution metadata)
                // If your SP returns execution stats in a second result set, we can read it here
                // but for now we'll just use the first result set

                result.RowsReturned = dataTable.Rows.Count;
                result.ResultData = ConvertDataTableToList(dataTable);
                result.Success = true;

                stopwatch.Stop();
                result.ExecutionTimeMs = stopwatch.ElapsedMilliseconds;
                result.ExecutionEndTime = DateTime.Now;
            }
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            result.Success = false;
            result.ErrorMessage = ex.Message;
            result.ExecutionTimeMs = stopwatch.ElapsedMilliseconds;
            result.ExecutionEndTime = DateTime.Now;
            result.RowsReturned = 0;
        }

        return Ok(result);
    }

    [HttpGet]
    public IActionResult GetStoredProcedures()
    {
        return Ok(StoredProcedures.Values.Select(sp => new
        {
            sp.Name,
            sp.DisplayName,
            sp.CursorLabel,
            sp.CursorParameterName,
            sp.IsSpecialMobile
        }));
    }

    private List<Dictionary<string, object?>> ConvertDataTableToList(DataTable dt)
    {
        var rows = new List<Dictionary<string, object?>>();

        foreach (DataRow row in dt.Rows)
        {
            var dict = new Dictionary<string, object?>();
            foreach (DataColumn col in dt.Columns)
            {
                dict[col.ColumnName] = row[col] == DBNull.Value ? null : row[col];
            }
            rows.Add(dict);
        }

        return rows;
    }
}
