-- =============================================
-- Benchmark Stored Procedures for Keyset Pagination
-- These procedures demonstrate different cursor-based pagination patterns
-- =============================================

USE [YourDatabaseName]
GO

-- =============================================
-- 1. CreationDate DESC - Pagination by CreationDate (descending)
-- =============================================
IF OBJECT_ID('dbo.usp_Benchmark_CreationDate_DESC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Benchmark_CreationDate_DESC;
GO

CREATE PROCEDURE dbo.usp_Benchmark_CreationDate_DESC
    @LastCreationDate DATETIME = NULL,
    @LastEntityId INT = 0,
    @PageSize INT = 20,
    @IsFirstPage BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsFirstPage = 1
    BEGIN
        -- First page - start from the beginning
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            CreationDate AS NextCursor_CreationDate,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        ORDER BY CreationDate DESC, MemberDocID DESC;
    END
    ELSE
    BEGIN
        -- Subsequent pages - use cursor
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            CreationDate AS NextCursor_CreationDate,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE (CreationDate < @LastCreationDate)
           OR (CreationDate = @LastCreationDate AND MemberDocID < @LastEntityId)
        ORDER BY CreationDate DESC, MemberDocID DESC;
    END
END
GO

-- =============================================
-- 2. FirstName ASC - Pagination by FirstName (ascending)
-- =============================================
IF OBJECT_ID('dbo.usp_Benchmark_FirstName_ASC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Benchmark_FirstName_ASC;
GO

CREATE PROCEDURE dbo.usp_Benchmark_FirstName_ASC
    @LastFirstName NVARCHAR(255) = NULL,
    @LastEntityId INT = 0,
    @PageSize INT = 20,
    @IsFirstPage BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsFirstPage = 1
    BEGIN
        -- First page - start from the beginning
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            FirstName AS NextCursor_FirstName,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE FirstName IS NOT NULL
        ORDER BY FirstName ASC, MemberDocID ASC;
    END
    ELSE
    BEGIN
        -- Subsequent pages - use cursor
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            FirstName AS NextCursor_FirstName,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE FirstName IS NOT NULL
          AND (
              (FirstName > @LastFirstName)
              OR (FirstName = @LastFirstName AND MemberDocID > @LastEntityId)
          )
        ORDER BY FirstName ASC, MemberDocID ASC;
    END
END
GO

-- =============================================
-- 3. LastName ASC - Pagination by LastName (ascending)
-- =============================================
IF OBJECT_ID('dbo.usp_Benchmark_LastName_ASC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Benchmark_LastName_ASC;
GO

CREATE PROCEDURE dbo.usp_Benchmark_LastName_ASC
    @LastLastName NVARCHAR(255) = NULL,
    @LastEntityId INT = 0,
    @PageSize INT = 20,
    @IsFirstPage BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsFirstPage = 1
    BEGIN
        -- First page - start from the beginning
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            LastName AS NextCursor_LastName,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE LastName IS NOT NULL
        ORDER BY LastName ASC, MemberDocID ASC;
    END
    ELSE
    BEGIN
        -- Subsequent pages - use cursor
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            LastName AS NextCursor_LastName,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE LastName IS NOT NULL
          AND (
              (LastName > @LastLastName)
              OR (LastName = @LastLastName AND MemberDocID > @LastEntityId)
          )
        ORDER BY LastName ASC, MemberDocID ASC;
    END
END
GO

-- =============================================
-- 4. Email ASC - Pagination by EmailAddress (ascending)
-- =============================================
IF OBJECT_ID('dbo.usp_Benchmark_Email_ASC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Benchmark_Email_ASC;
GO

CREATE PROCEDURE dbo.usp_Benchmark_Email_ASC
    @LastEmailAddress NVARCHAR(255) = NULL,
    @LastEntityId INT = 0,
    @PageSize INT = 20,
    @IsFirstPage BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsFirstPage = 1
    BEGIN
        -- First page - start from the beginning
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            EmailAddress AS NextCursor_EmailAddress,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE EmailAddress IS NOT NULL
        ORDER BY EmailAddress ASC, MemberDocID ASC;
    END
    ELSE
    BEGIN
        -- Subsequent pages - use cursor
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            EmailAddress AS NextCursor_EmailAddress,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE EmailAddress IS NOT NULL
          AND (
              (EmailAddress > @LastEmailAddress)
              OR (EmailAddress = @LastEmailAddress AND MemberDocID > @LastEntityId)
          )
        ORDER BY EmailAddress ASC, MemberDocID ASC;
    END
END
GO

-- =============================================
-- 5. MID ASC - Pagination by MemberId (ascending)
-- =============================================
IF OBJECT_ID('dbo.usp_Benchmark_MID_ASC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Benchmark_MID_ASC;
GO

CREATE PROCEDURE dbo.usp_Benchmark_MID_ASC
    @LastMemberId NVARCHAR(50) = NULL,
    @LastEntityId INT = 0,
    @PageSize INT = 20,
    @IsFirstPage BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsFirstPage = 1
    BEGIN
        -- First page - start from the beginning
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            MemberId AS NextCursor_MemberId,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE MemberId IS NOT NULL
        ORDER BY MemberId ASC, MemberDocID ASC;
    END
    ELSE
    BEGIN
        -- Subsequent pages - use cursor
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            MemberId AS NextCursor_MemberId,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE MemberId IS NOT NULL
          AND (
              (MemberId > @LastMemberId)
              OR (MemberId = @LastMemberId AND MemberDocID > @LastEntityId)
          )
        ORDER BY MemberId ASC, MemberDocID ASC;
    END
END
GO

-- =============================================
-- 6. Mobile ASC - Pagination by Mobile (ascending, with NULL handling)
-- This SP has special handling for NULL mobile numbers
-- =============================================
IF OBJECT_ID('dbo.usp_Benchmark_Mobile_ASC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Benchmark_Mobile_ASC;
GO

CREATE PROCEDURE dbo.usp_Benchmark_Mobile_ASC
    @LastMobile NVARCHAR(50) = NULL,
    @LastMemberDocId INT = 0,
    @LastNullMemberDocId INT = 0,
    @PageSize INT = 20,
    @IsFirstPage BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsFirstPage = 1
    BEGIN
        -- First page - start from the beginning
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            Mobile AS NextCursor_Mobile,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        ORDER BY 
            CASE WHEN Mobile IS NULL THEN 1 ELSE 0 END,
            Mobile ASC,
            MemberDocID ASC;
    END
    ELSE
    BEGIN
        -- Subsequent pages with NULL handling
        IF @LastMobile IS NULL
        BEGIN
            -- We're in the NULL section
            SELECT TOP (@PageSize)
                MemberDocID,
                CreationDate,
                FirstName,
                LastName,
                EmailAddress,
                MemberId,
                Mobile,
                FullName,
                Mobile AS NextCursor_Mobile,
                MemberDocID AS NextCursor_Id
            FROM dbo.MembersForQueryBenchmarking
            WHERE Mobile IS NULL
              AND MemberDocID > @LastNullMemberDocId
            ORDER BY 
                CASE WHEN Mobile IS NULL THEN 1 ELSE 0 END,
                Mobile ASC,
                MemberDocID ASC;
        END
        ELSE
        BEGIN
            -- We're in the non-NULL section
            SELECT TOP (@PageSize)
                MemberDocID,
                CreationDate,
                FirstName,
                LastName,
                EmailAddress,
                MemberId,
                Mobile,
                FullName,
                Mobile AS NextCursor_Mobile,
                MemberDocID AS NextCursor_Id
            FROM dbo.MembersForQueryBenchmarking
            WHERE Mobile IS NOT NULL
              AND (
                  (Mobile > @LastMobile)
                  OR (Mobile = @LastMobile AND MemberDocID > @LastMemberDocId)
              )
            ORDER BY 
                CASE WHEN Mobile IS NULL THEN 1 ELSE 0 END,
                Mobile ASC,
                MemberDocID ASC;
        END
    END
END
GO

-- =============================================
-- 7. FullName ASC - Pagination by FullName (ascending)
-- =============================================
IF OBJECT_ID('dbo.usp_Benchmark_FullName_ASC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Benchmark_FullName_ASC;
GO

CREATE PROCEDURE dbo.usp_Benchmark_FullName_ASC
    @LastFullName NVARCHAR(500) = NULL,
    @LastEntityId INT = 0,
    @PageSize INT = 20,
    @IsFirstPage BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsFirstPage = 1
    BEGIN
        -- First page - start from the beginning
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            FullName AS NextCursor_FullName,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE FullName IS NOT NULL
        ORDER BY FullName ASC, MemberDocID ASC;
    END
    ELSE
    BEGIN
        -- Subsequent pages - use cursor
        SELECT TOP (@PageSize)
            MemberDocID,
            CreationDate,
            FirstName,
            LastName,
            EmailAddress,
            MemberId,
            Mobile,
            FullName,
            -- Return cursor values for next page
            FullName AS NextCursor_FullName,
            MemberDocID AS NextCursor_Id
        FROM dbo.MembersForQueryBenchmarking
        WHERE FullName IS NOT NULL
          AND (
              (FullName > @LastFullName)
              OR (FullName = @LastFullName AND MemberDocID > @LastEntityId)
          )
        ORDER BY FullName ASC, MemberDocID ASC;
    END
END
GO

-- =============================================
-- Verification Query
-- =============================================
PRINT 'All 7 benchmark stored procedures created successfully!'
PRINT ''
PRINT 'Verify installation:'

SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ProcedureName,
    create_date AS CreatedDate,
    modify_date AS ModifiedDate
FROM sys.procedures
WHERE name LIKE 'usp_Benchmark_%'
ORDER BY name;

PRINT ''
PRINT 'Test with: EXEC dbo.usp_Benchmark_CreationDate_DESC @IsFirstPage=1, @PageSize=10'
