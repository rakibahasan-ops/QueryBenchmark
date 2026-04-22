-- =====================================================
-- Complete Deployment Script
-- Run this in SSMS or any SQL client
-- =====================================================

USE [Development_286]; -- Change this to your actual database name
GO

-- =====================================================
-- Step 0: Create QueryExecutionLog Table (if not exists)
-- =====================================================
PRINT '========== Step 0: Creating QueryExecutionLog Table ==========';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'QueryExecutionLog')
BEGIN
    CREATE TABLE [dbo].[QueryExecutionLog](
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [QueryName] [nvarchar](200) NOT NULL,
        [QueryDescription] [nvarchar](500) NOT NULL,
        [ExecutionTimeMs] [bigint] NOT NULL,
        [RowsReturned] [int] NOT NULL,
        [IsSuccess] [bit] NOT NULL,
        [ErrorMessage] [nvarchar](2000) NULL,
        [ExecutedAt] [datetime2](7) NOT NULL,
        [ExecutionStartTime] [datetime2](7) NOT NULL DEFAULT SYSUTCDATETIME(),
        [ExecutionEndTime] [datetime2](7) NOT NULL DEFAULT SYSUTCDATETIME(),
        [ExecutedBy] [nvarchar](100) NULL,
        CONSTRAINT [PK_QueryExecutionLog] PRIMARY KEY CLUSTERED ([Id] ASC)
    );

    CREATE NONCLUSTERED INDEX [IX_QueryExecutionLog_ExecutedAt] 
    ON [dbo].[QueryExecutionLog]([ExecutedAt] DESC);

    CREATE NONCLUSTERED INDEX [IX_QueryExecutionLog_QueryName] 
    ON [dbo].[QueryExecutionLog]([QueryName]);

    PRINT 'QueryExecutionLog table created successfully!';
END
ELSE
BEGIN
    PRINT 'QueryExecutionLog table already exists. Proceeding with schema updates...';
END
GO

-- =====================================================
-- Step 1: Update QueryExecutionLog Table Schema
-- =====================================================
PRINT '========== Step 1: Updating Table Schema ==========';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.QueryExecutionLog') AND name = 'ExecutionStartTime')
BEGIN
    ALTER TABLE [dbo].[QueryExecutionLog]
    ADD [ExecutionStartTime] DATETIME2(7) NULL;
    PRINT 'Added ExecutionStartTime column';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.QueryExecutionLog') AND name = 'ExecutionEndTime')
BEGIN
    ALTER TABLE [dbo].[QueryExecutionLog]
    ADD [ExecutionEndTime] DATETIME2(7) NULL;
    PRINT 'Added ExecutionEndTime column';
END

-- Make ExecutedBy column optional if it exists
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.QueryExecutionLog') AND name = 'ExecutedBy')
BEGIN
    ALTER TABLE [dbo].[QueryExecutionLog]
    ALTER COLUMN [ExecutedBy] NVARCHAR(100) NULL;
    PRINT 'Made ExecutedBy nullable';
END

-- Update existing rows to set start/end times from ExecutedAt if they're NULL
UPDATE [dbo].[QueryExecutionLog]
SET 
    [ExecutionStartTime] = ISNULL([ExecutionStartTime], [ExecutedAt]),
    [ExecutionEndTime] = ISNULL([ExecutionEndTime], [ExecutedAt])
WHERE [ExecutionStartTime] IS NULL OR [ExecutionEndTime] IS NULL;

-- Make columns NOT NULL after population
ALTER TABLE [dbo].[QueryExecutionLog]
ALTER COLUMN [ExecutionStartTime] DATETIME2(7) NOT NULL;

ALTER TABLE [dbo].[QueryExecutionLog]
ALTER COLUMN [ExecutionEndTime] DATETIME2(7) NOT NULL;

PRINT 'Table schema updated successfully!';
GO

-- =====================================================
-- Step 2: Create usp_Benchmark_QueryOne_OrBasedKeyset
-- =====================================================
PRINT '========== Step 2: Creating QueryOne SP ==========';
GO

CREATE OR ALTER PROCEDURE usp_Benchmark_QueryOne_OrBasedKeyset
    @LastCreationDate   DATETIME2   = '9999-12-31 23:59:59',
    @LastEntityId       INT         = 0,
    @PageSize           INT         = 20,
    @IsFirstPage        BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime          DATETIME2   = SYSUTCDATETIME();
    DECLARE @EndTime            DATETIME2;
    DECLARE @TotalRows          INT         = 0;
    DECLARE @RowsReturned       INT         = 0;
    DECLARE @ErrorMessage       NVARCHAR(2000) = NULL;

    BEGIN TRY
        IF OBJECT_ID('tempdb..#BaseMembers_A1') IS NOT NULL
            DROP TABLE #BaseMembers_A1;

        CREATE TABLE #BaseMembers_A1
        (
            EntityId        INT         NOT NULL,
            CurrentStateId  INT         NOT NULL,
            CreationDate    DATETIME2   NOT NULL
        );

        CREATE CLUSTERED INDEX IX_BaseMembers_A1_CreationDate_EntityId
        ON #BaseMembers_A1(CreationDate DESC, EntityId ASC);

        INSERT INTO #BaseMembers_A1 (EntityId, CurrentStateId, CreationDate)
        SELECT HL.EntityId, 2, U.CreationDate
        FROM HierarchyLinks_Test HL
        INNER JOIN User_Test U ON U.MemberDocId = HL.EntityId
        WHERE HL.HierarchyId = 2;

        IF @IsFirstPage = 1
            SELECT @TotalRows = COUNT_BIG(1) FROM #BaseMembers_A1;
        ELSE
            SET @TotalRows = -1;

        ;WITH TopMembers AS
        (
            SELECT TOP (@PageSize) BM.EntityId, BM.CurrentStateId, BM.CreationDate
            FROM #BaseMembers_A1 BM
            WHERE BM.CreationDate < @LastCreationDate
               OR (BM.CreationDate = @LastCreationDate AND BM.EntityId > @LastEntityId)
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

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES ('QueryOne', 'OR-based Keyset Pagination', DATEDIFF(MILLISECOND, @StartTime, @EndTime), @RowsReturned, 1, NULL, @StartTime, @EndTime, SYSUTCDATETIME());

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, @RowsReturned AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END TRY
    BEGIN CATCH
        SET @EndTime = SYSUTCDATETIME();
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES ('QueryOne', 'OR-based Keyset Pagination', DATEDIFF(MILLISECOND, @StartTime, @EndTime), 0, 0, @ErrorMessage, @StartTime, @EndTime, SYSUTCDATETIME());

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, 0 AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END CATCH
END
GO

PRINT 'QueryOne SP created successfully!';
GO

-- =====================================================
-- Step 3: Create usp_Benchmark_QueryTwo_UnionAllKeyset
-- =====================================================
PRINT '========== Step 3: Creating QueryTwo SP ==========';
GO

CREATE OR ALTER PROCEDURE usp_Benchmark_QueryTwo_UnionAllKeyset
    @LastCreationDate   DATETIME2   = '9999-12-31 23:59:59.9999999',
    @LastEntityId       INT         = 0,
    @PageSize           INT         = 20,
    @IsFirstPage        BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime          DATETIME2   = SYSUTCDATETIME();
    DECLARE @EndTime            DATETIME2;
    DECLARE @TotalRows          BIGINT      = -1;
    DECLARE @RowsReturned       INT         = 0;
    DECLARE @ErrorMessage       NVARCHAR(2000) = NULL;

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

        ;WITH TopMembers AS
        (
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

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES ('QueryTwo', 'UNION ALL Keyset + Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), @RowsReturned, 1, NULL, @StartTime, @EndTime, SYSUTCDATETIME());

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, @RowsReturned AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END TRY
    BEGIN CATCH
        SET @EndTime = SYSUTCDATETIME();
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES ('QueryTwo', 'UNION ALL Keyset + Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), 0, 0, @ErrorMessage, @StartTime, @EndTime, SYSUTCDATETIME());

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, 0 AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END CATCH
END
GO

PRINT 'QueryTwo SP created successfully!';
GO

-- =====================================================
-- Step 4: Create usp_Benchmark_QueryThree_DirectSeek
-- =====================================================
PRINT '========== Step 4: Creating QueryThree SP ==========';
GO

CREATE OR ALTER PROCEDURE usp_Benchmark_QueryThree_DirectSeek
    @LastCreationDate   DATETIME2   = '9999-12-31 23:59:59.9999999',
    @LastEntityId       INT         = 0,
    @PageSize           INT         = 20,
    @IsFirstPage        BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime          DATETIME2   = SYSUTCDATETIME();
    DECLARE @EndTime            DATETIME2;
    DECLARE @TotalRows          BIGINT      = -1;
    DECLARE @RowsReturned       INT         = 0;
    DECLARE @ErrorMessage       NVARCHAR(2000) = NULL;

    BEGIN TRY
        IF @IsFirstPage = 1
            SELECT @TotalRows = COUNT_BIG(1) FROM HierarchyLinks_Test WHERE HierarchyId = 2;

        ;WITH TopMembers AS
        (
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

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES ('QueryThree', 'Direct Seek, No Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), @RowsReturned, 1, NULL, @StartTime, @EndTime, SYSUTCDATETIME());

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, @RowsReturned AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END TRY
    BEGIN CATCH
        SET @EndTime = SYSUTCDATETIME();
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES ('QueryThree', 'Direct Seek, No Temp Table', DATEDIFF(MILLISECOND, @StartTime, @EndTime), 0, 0, @ErrorMessage, @StartTime, @EndTime, SYSUTCDATETIME());

        SELECT DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS ExecutionTimeMs, 0 AS RowsReturned,
               @StartTime AS ExecutionStartTime, @EndTime AS ExecutionEndTime, SYSUTCDATETIME() AS ExecutedAt, @ErrorMessage AS ErrorMessage;
    END CATCH
END
GO

PRINT 'QueryThree SP created successfully!';
GO

-- =====================================================
-- Step 5: Create/Update usp_Benchmark_GetLogs
-- =====================================================
PRINT '========== Step 5: Creating GetLogs SP ==========';
GO

CREATE OR ALTER PROCEDURE usp_Benchmark_GetLogs
    @TopN INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        Id, QueryName, QueryDescription, ExecutionTimeMs, RowsReturned,
        IsSuccess, ErrorMessage, ExecutedAt, ExecutionStartTime, ExecutionEndTime
    FROM QueryExecutionLog
    ORDER BY ExecutedAt DESC;
END
GO

PRINT 'GetLogs SP created successfully!';
GO

PRINT '========================================';
PRINT 'All stored procedures deployed successfully!';
PRINT 'You can now run QueryOne, QueryTwo, and QueryThree from your application.';
PRINT '========================================';
