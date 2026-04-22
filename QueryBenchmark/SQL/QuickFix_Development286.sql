-- =====================================================
-- 🚀 QUICK FIX DEPLOYMENT SCRIPT
-- Run this IMMEDIATELY in SSMS to fix the issue
-- Database: Development_286
-- =====================================================

USE [Development_286];
GO

PRINT '🔧 Deploying stored procedures to Development_286...';
PRINT '';

-- =====================================================
-- Create QueryExecutionLog Table if not exists
-- =====================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'QueryExecutionLog')
BEGIN
    PRINT '📋 Creating QueryExecutionLog table...';
    
    CREATE TABLE [dbo].[QueryExecutionLog](
        [LogId] [int] IDENTITY(1,1) NOT NULL,
        [QueryName] [nvarchar](200) NOT NULL,
        [QueryDescription] [nvarchar](500) NOT NULL,
        [ExecutionTimeMs] [bigint] NOT NULL,
        [RowsReturned] [int] NOT NULL,
        [IsSuccess] [bit] NOT NULL,
        [ErrorMessage] [nvarchar](2000) NULL,
        [ExecutedAt] [datetime2](7) NOT NULL DEFAULT SYSUTCDATETIME(),
        [ExecutionStartTime] [datetime2](7) NOT NULL DEFAULT SYSUTCDATETIME(),
        [ExecutionEndTime] [datetime2](7) NOT NULL DEFAULT SYSUTCDATETIME(),
        [ExecutedBy] [nvarchar](100) NULL,
        CONSTRAINT [PK_QueryExecutionLog] PRIMARY KEY CLUSTERED ([LogId] ASC)
    );
    
    CREATE NONCLUSTERED INDEX [IX_QueryExecutionLog_ExecutedAt] 
    ON [dbo].[QueryExecutionLog]([ExecutedAt] DESC);
    
    CREATE NONCLUSTERED INDEX [IX_QueryExecutionLog_QueryName] 
    ON [dbo].[QueryExecutionLog]([QueryName]);
    
    PRINT '✅ Table created successfully!';
END
ELSE
BEGIN
    PRINT '✅ QueryExecutionLog table already exists.';
    
    -- Add missing columns if needed
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.QueryExecutionLog') AND name = 'ExecutionStartTime')
    BEGIN
        ALTER TABLE [dbo].[QueryExecutionLog] ADD [ExecutionStartTime] DATETIME2(7) NULL;
        UPDATE [dbo].[QueryExecutionLog] SET [ExecutionStartTime] = [ExecutedAt] WHERE [ExecutionStartTime] IS NULL;
        ALTER TABLE [dbo].[QueryExecutionLog] ALTER COLUMN [ExecutionStartTime] DATETIME2(7) NOT NULL;
        PRINT '✅ Added ExecutionStartTime column';
    END
    
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.QueryExecutionLog') AND name = 'ExecutionEndTime')
    BEGIN
        ALTER TABLE [dbo].[QueryExecutionLog] ADD [ExecutionEndTime] DATETIME2(7) NULL;
        UPDATE [dbo].[QueryExecutionLog] SET [ExecutionEndTime] = [ExecutedAt] WHERE [ExecutionEndTime] IS NULL;
        ALTER TABLE [dbo].[QueryExecutionLog] ALTER COLUMN [ExecutionEndTime] DATETIME2(7) NOT NULL;
        PRINT '✅ Added ExecutionEndTime column';
    END
END
GO

PRINT '';
PRINT '📝 Creating QueryOne stored procedure...';
GO

-- =====================================================
-- QueryOne - OR-based Keyset
-- =====================================================
CREATE OR ALTER PROCEDURE usp_Benchmark_QueryOne_OrBasedKeyset
    @LastCreationDate   DATETIME2   = '9999-12-31 23:59:59',
    @LastEntityId       INT         = 0,
    @PageSize           INT         = 20,
    @IsFirstPage        BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime      DATETIME2       = SYSUTCDATETIME();
    DECLARE @EndTime        DATETIME2;
    DECLARE @TotalRows      INT             = 0;
    DECLARE @RowsReturned   INT             = 0;
    DECLARE @ErrorMessage   NVARCHAR(2000)  = NULL;

    BEGIN TRY
        IF OBJECT_ID('tempdb..#BaseMembers_A1') IS NOT NULL
            DROP TABLE #BaseMembers_A1;

        CREATE TABLE #BaseMembers_A1 (EntityId INT NOT NULL, CurrentStateId INT NOT NULL, CreationDate DATETIME2 NOT NULL);
        CREATE CLUSTERED INDEX IX_BaseMembers_A1_CreationDate_EntityId ON #BaseMembers_A1(CreationDate DESC, EntityId ASC);

        INSERT INTO #BaseMembers_A1 (EntityId, CurrentStateId, CreationDate)
        SELECT HL.EntityId, 2, U.CreationDate
        FROM HierarchyLinks_Test HL
        INNER JOIN User_Test U ON U.MemberDocId = HL.EntityId
        WHERE HL.HierarchyId = 2;

        IF @IsFirstPage = 1
            SELECT @TotalRows = COUNT_BIG(1) FROM #BaseMembers_A1;
        ELSE
            SET @TotalRows = -1;

        ;WITH TopMembers AS (
            SELECT TOP (@PageSize) BM.EntityId, BM.CurrentStateId, BM.CreationDate
            FROM #BaseMembers_A1 BM
            WHERE BM.CreationDate < @LastCreationDate OR (BM.CreationDate = @LastCreationDate AND BM.EntityId > @LastEntityId)
            ORDER BY BM.CreationDate DESC, BM.EntityId ASC
        )
        SELECT
            PM.CreationDate AS NextCursor_Date, PM.EntityId AS NextCursor_Id, PM.EntityId AS MemberDocId,
            U.MemberId AS MID, U.UserId, U.FirstName, U.LastName, U.ProfilePicURL, U.EmailAddress,
            ISNULL(UP.CountryCode, '') + ISNULL(UP.Number, '') AS Mobile,
            U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
            CMS.EntitySummary AS OrganisationSummary, MS.Entity1Memberships AS MembershipSummary,
            S.Name AS Status, S.StateId AS StatusId, U.DOB,
            CASE WHEN U.DOB IS NULL THEN NULL ELSE (CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112)) - CONVERT(INT, CONVERT(CHAR(8), U.DOB, 112))) / 10000 END AS Age,
            U.UserSyncId, ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
            ISNULL(F.NumberOfFamily, 0) AS NumberOfFamily, @TotalRows AS TotalRows
        FROM TopMembers PM
        INNER JOIN User_Test U ON U.MemberDocId = PM.EntityId
        INNER JOIN ClubMemberSummary_Test CMS ON CMS.EntityId = PM.EntityId
        INNER JOIN MembershipSummary_Test MS ON MS.EntityId = PM.EntityId
        INNER JOIN State_Test S ON S.StateId = PM.CurrentStateId
        OUTER APPLY (SELECT COUNT_BIG(1) AS NumberOfFamily FROM Family_Links_Test FL WHERE FL.EntityId = PM.EntityId) F
        OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber_Test WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
        ORDER BY PM.CreationDate DESC, PM.EntityId ASC;

        SET @RowsReturned = @@ROWCOUNT;
        SET @EndTime = SYSUTCDATETIME();
        DROP TABLE #BaseMembers_A1;

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime)
        VALUES ('QueryOne', 'OR-based Keyset Pagination', DATEDIFF(MILLISECOND, @StartTime, @EndTime), @RowsReturned, 1, NULL, @StartTime, @EndTime);

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, @RowsReturned AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END TRY
    BEGIN CATCH
        SET @EndTime = SYSUTCDATETIME();
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime)
        VALUES ('QueryOne', 'OR-based Keyset Pagination', DATEDIFF(MILLISECOND, @StartTime, @EndTime), 0, 0, @ErrorMessage, @StartTime, @EndTime);

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, 0 AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END CATCH
END
GO

PRINT '✅ QueryOne created!';
PRINT '';
PRINT '📝 Creating QueryTwo stored procedure...';
GO

-- =====================================================
-- QueryTwo - UNION ALL Keyset
-- =====================================================
CREATE OR ALTER PROCEDURE usp_Benchmark_QueryTwo_UnionAllKeyset
    @LastCreationDate   DATETIME2   = '9999-12-31 23:59:59.9999999',
    @LastEntityId       INT         = 0,
    @PageSize           INT         = 20,
    @IsFirstPage        BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime      DATETIME2       = SYSUTCDATETIME();
    DECLARE @EndTime        DATETIME2;
    DECLARE @TotalRows      BIGINT          = -1;
    DECLARE @RowsReturned   INT             = 0;
    DECLARE @ErrorMessage   NVARCHAR(2000)  = NULL;

    BEGIN TRY
        IF OBJECT_ID('tempdb..#BaseMembers_A2') IS NOT NULL
            DROP TABLE #BaseMembers_A2;

        CREATE TABLE #BaseMembers_A2 (EntityId INT NOT NULL, CurrentStateId INT NOT NULL, CreationDate DATETIME2 NOT NULL);
        CREATE CLUSTERED INDEX IX_BaseMembers_A2_CreationDate_EntityId ON #BaseMembers_A2(CreationDate DESC, EntityId ASC);

        INSERT INTO #BaseMembers_A2 (EntityId, CurrentStateId, CreationDate)
        SELECT HL.EntityId, 2, U.CreationDate
        FROM HierarchyLinks_Test HL
        INNER JOIN User_Test U ON U.MemberDocId = HL.EntityId
        WHERE HL.HierarchyId = 2;

        IF @IsFirstPage = 1
            SELECT @TotalRows = COUNT_BIG(1) FROM #BaseMembers_A2;

        ;WITH TopMembers AS (
            SELECT TOP (@PageSize) BM.EntityId, BM.CurrentStateId, BM.CreationDate
            FROM (
                SELECT TOP (@PageSize) BM.EntityId, BM.CurrentStateId, BM.CreationDate
                FROM #BaseMembers_A2 BM WHERE BM.CreationDate < @LastCreationDate
                ORDER BY BM.CreationDate DESC, BM.EntityId ASC
                UNION ALL
                SELECT TOP (@PageSize) BM.EntityId, BM.CurrentStateId, BM.CreationDate
                FROM #BaseMembers_A2 BM WHERE BM.CreationDate = @LastCreationDate AND BM.EntityId > @LastEntityId
                ORDER BY BM.CreationDate DESC, BM.EntityId ASC
            ) BM
            ORDER BY BM.CreationDate DESC, BM.EntityId ASC
        )
        SELECT
            PM.CreationDate AS NextCursor_Date, PM.EntityId AS NextCursor_Id, PM.EntityId AS MemberDocId,
            U.MemberId AS MID, U.UserId, U.FirstName, U.LastName, U.ProfilePicURL, U.EmailAddress,
            ISNULL(UP.CountryCode, '') + ISNULL(UP.Number, '') AS Mobile,
            U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
            CMS.EntitySummary AS OrganisationSummary, MS.Entity1Memberships AS MembershipSummary,
            S.Name AS Status, S.StateId AS StatusId, U.DOB,
            CASE WHEN U.DOB IS NULL THEN NULL ELSE (CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112)) - CONVERT(INT, CONVERT(CHAR(8), U.DOB, 112))) / 10000 END AS Age,
            U.UserSyncId, ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
            ISNULL(F.NumberOfFamily, 0) AS NumberOfFamily, @TotalRows AS TotalRows
        FROM TopMembers PM
        INNER JOIN User_Test U ON U.MemberDocId = PM.EntityId
        INNER JOIN ClubMemberSummary_Test CMS ON CMS.EntityId = PM.EntityId
        INNER JOIN MembershipSummary_Test MS ON MS.EntityId = PM.EntityId
        INNER JOIN State_Test S ON S.StateId = PM.CurrentStateId
        OUTER APPLY (SELECT COUNT_BIG(1) AS NumberOfFamily FROM Family_Links_Test FL WHERE FL.EntityId = PM.EntityId) F
        OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber_Test WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
        ORDER BY PM.CreationDate DESC, PM.EntityId ASC;

        SET @RowsReturned = @@ROWCOUNT;
        SET @EndTime = SYSUTCDATETIME();
        DROP TABLE #BaseMembers_A2;

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime)
        VALUES ('QueryTwo', 'UNION ALL Keyset + Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), @RowsReturned, 1, NULL, @StartTime, @EndTime);

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, @RowsReturned AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END TRY
    BEGIN CATCH
        SET @EndTime = SYSUTCDATETIME();
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime)
        VALUES ('QueryTwo', 'UNION ALL Keyset + Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), 0, 0, @ErrorMessage, @StartTime, @EndTime);

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, 0 AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END CATCH
END
GO

PRINT '✅ QueryTwo created!';
PRINT '';
PRINT '📝 Creating QueryThree stored procedure...';
GO

-- =====================================================
-- QueryThree - Direct Seek
-- =====================================================
CREATE OR ALTER PROCEDURE usp_Benchmark_QueryThree_DirectSeek
    @LastCreationDate   DATETIME2   = '9999-12-31 23:59:59.9999999',
    @LastEntityId       INT         = 0,
    @PageSize           INT         = 20,
    @IsFirstPage        BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime      DATETIME2       = SYSUTCDATETIME();
    DECLARE @EndTime        DATETIME2;
    DECLARE @TotalRows      BIGINT          = -1;
    DECLARE @RowsReturned   INT             = 0;
    DECLARE @ErrorMessage   NVARCHAR(2000)  = NULL;

    BEGIN TRY
        IF @IsFirstPage = 1
            SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks_Test WHERE HierarchyId = 2;

        ;WITH TopMembers AS (
            SELECT TOP (@PageSize) src.EntityId, src.CreationDate
            FROM (
                SELECT TOP (@PageSize) HL.EntityId, U.CreationDate
                FROM User_Test U
                INNER JOIN HierarchyLinks_Test HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                WHERE U.CreationDate < @LastCreationDate
                ORDER BY U.CreationDate DESC, HL.EntityId ASC
                UNION ALL
                SELECT TOP (@PageSize) HL.EntityId, U.CreationDate
                FROM User_Test U
                INNER JOIN HierarchyLinks_Test HL ON HL.EntityId = U.MemberDocId AND HL.HierarchyId = 2
                WHERE U.CreationDate = @LastCreationDate AND HL.EntityId > @LastEntityId
                ORDER BY U.CreationDate DESC, HL.EntityId ASC
            ) src
            ORDER BY src.CreationDate DESC, src.EntityId ASC
        )
        SELECT
            TM.CreationDate AS NextCursor_Date, TM.EntityId AS NextCursor_Id, TM.EntityId AS MemberDocId,
            U.MemberId AS MID, U.UserId, U.FirstName, U.LastName, U.ProfilePicURL, U.EmailAddress,
            ISNULL(UP.CountryCode, '') + ISNULL(UP.Number, '') AS Mobile,
            U.Address1, U.Address2, U.Address3, U.Town, U.Postcode, U.County, U.Country,
            CMS.EntitySummary AS OrganisationSummary, MS.Entity1Memberships AS MembershipSummary,
            S.Name AS Status, S.StateId AS StatusId, U.DOB,
            CASE WHEN U.DOB IS NULL THEN NULL ELSE (CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112)) - CONVERT(INT, CONVERT(CHAR(8), U.DOB, 112))) / 10000 END AS Age,
            U.UserSyncId, ISNULL(U.SuspensionLevel, 0) AS SuspensionLevel,
            ISNULL(F.FamilyCount, 0) AS NumberOfFamily, @TotalRows AS TotalRows
        FROM TopMembers TM
        INNER JOIN User_Test U ON U.MemberDocId = TM.EntityId
        INNER JOIN ClubMemberSummary_Test CMS ON CMS.EntityId = TM.EntityId
        INNER JOIN MembershipSummary_Test MS ON MS.EntityId = TM.EntityId
        INNER JOIN State_Test S ON S.StateId = 2
        OUTER APPLY (SELECT COUNT_BIG(1) AS FamilyCount FROM Family_Links_Test FL WHERE FL.EntityId = TM.EntityId) F
        OUTER APPLY (SELECT TOP 1 CountryCode, Number FROM UserPhoneNumber_Test WHERE UserId = U.UserId AND [Type] = 'Mobile') UP
        ORDER BY TM.CreationDate DESC, TM.EntityId ASC
        OPTION (RECOMPILE);

        SET @RowsReturned = @@ROWCOUNT;
        SET @EndTime = SYSUTCDATETIME();

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime)
        VALUES ('QueryThree', 'Direct Seek, No Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), @RowsReturned, 1, NULL, @StartTime, @EndTime);

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, @RowsReturned AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END TRY
    BEGIN CATCH
        SET @EndTime = SYSUTCDATETIME();
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime)
        VALUES ('QueryThree', 'Direct Seek, No Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), 0, 0, @ErrorMessage, @StartTime, @EndTime);

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, 0 AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END CATCH
END
GO

PRINT '✅ QueryThree created!';
PRINT '';
PRINT '📝 Creating GetLogs stored procedure...';
GO

-- =====================================================
-- GetLogs
-- =====================================================
CREATE OR ALTER PROCEDURE usp_Benchmark_GetLogs
    @TopN INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        LogId, QueryName, QueryDescription, ExecutionTimeMs, RowsReturned,
        IsSuccess, ErrorMessage, ExecutedAt, ExecutionStartTime, ExecutionEndTime
    FROM dbo.QueryExecutionLog
    ORDER BY ExecutedAt DESC;
END
GO

PRINT '✅ GetLogs created!';
GO

PRINT '';
PRINT '========================================';
PRINT '✅ ALL DONE! Deployment Successful!';
PRINT '========================================';
PRINT '';
PRINT '📊 Verifying installation...';
PRINT '';

-- Verify procedures
SELECT 
    '✅ ' + ROUTINE_NAME AS [Stored Procedure Created],
    CREATED AS [Created Date]
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND ROUTINE_NAME LIKE 'usp_Benchmark%'
ORDER BY ROUTINE_NAME;

PRINT '';
PRINT '🎉 Ready to test! Go to your application and click QueryOne, QueryTwo, or QueryThree buttons.';
PRINT '';
