-- =====================================================
-- APPROACH 1 — OR-based Keyset
-- WHERE CreationDate < @Last OR (same date AND EntityId >)
-- =====================================================

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
        -- Create temp table
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
        SELECT
            HL.EntityId,
            2,
            U.CreationDate
        FROM HierarchyLinks_Test HL
        INNER JOIN User_Test U
            ON U.MemberDocId    = HL.EntityId
        WHERE HL.HierarchyId    = 2;

        -- Get total count only on first page
        IF @IsFirstPage = 1
        BEGIN
            SELECT @TotalRows = COUNT_BIG(1) FROM #BaseMembers_A1;
        END
        ELSE
        BEGIN
            SET @TotalRows = -1;
        END

        -- Main query
        ;WITH TopMembers AS
        (
            SELECT TOP (@PageSize)
                BM.EntityId,
                BM.CurrentStateId,
                BM.CreationDate
            FROM #BaseMembers_A1 BM
            WHERE
                BM.CreationDate < @LastCreationDate
                OR
                (
                    BM.CreationDate = @LastCreationDate
                    AND BM.EntityId > @LastEntityId
                )
            ORDER BY
                BM.CreationDate DESC,
                BM.EntityId     ASC
        )
        SELECT
            PM.CreationDate                                             AS NextCursor_Date,
            PM.EntityId                                                 AS NextCursor_Id,
            PM.EntityId                                                 AS MemberDocId,
            U.MemberId                                                  AS MID,
            U.UserId,
            U.FirstName,
            U.LastName,
            U.ProfilePicURL,
            U.EmailAddress,
            ISNULL(UP.CountryCode, '') + ISNULL(UP.Number, '')          AS Mobile,
            U.Address1,
            U.Address2,
            U.Address3,
            U.Town,
            U.Postcode,
            U.County,
            U.Country,
            CMS.EntitySummary                                           AS OrganisationSummary,
            MS.Entity1Memberships                                       AS MembershipSummary,
            S.Name                                                      AS Status,
            S.StateId                                                   AS StatusId,
            U.DOB,
            CASE
                WHEN U.DOB IS NULL THEN NULL
                ELSE
                (
                    CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112))
                    - CONVERT(INT, CONVERT(CHAR(8), U.DOB, 112))
                ) / 10000
            END                                                         AS Age,
            U.UserSyncId,
            ISNULL(U.SuspensionLevel, 0)                                AS SuspensionLevel,
            ISNULL(F.NumberOfFamily, 0)                                 AS NumberOfFamily,
            @TotalRows                                                  AS TotalRows
        FROM TopMembers PM
        INNER JOIN User_Test U
            ON U.MemberDocId        = PM.EntityId
        INNER JOIN ClubMemberSummary_Test CMS
            ON CMS.EntityId         = PM.EntityId
        INNER JOIN MembershipSummary_Test MS
            ON MS.EntityId          = PM.EntityId
        INNER JOIN State_Test S
            ON S.StateId            = PM.CurrentStateId
        OUTER APPLY
        (
            SELECT COUNT_BIG(1) AS NumberOfFamily
            FROM Family_Links_Test FL
            WHERE FL.EntityId = PM.EntityId
        ) F
        OUTER APPLY
        (
            SELECT TOP 1 CountryCode, Number
            FROM UserPhoneNumber_Test
            WHERE UserId    = U.UserId
              AND [Type]    = 'Mobile'
        ) UP
        ORDER BY
            PM.CreationDate DESC,
            PM.EntityId     ASC;

        SET @RowsReturned = @@ROWCOUNT;
        SET @EndTime = SYSUTCDATETIME();

        -- Clean up
        DROP TABLE #BaseMembers_A1;

        -- Insert into log
        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES (
            'QueryOne',
            'OR-based Keyset Pagination',
            DATEDIFF(MILLISECOND, @StartTime, @EndTime),
            @RowsReturned,
            1,
            NULL,
            @StartTime,
            @EndTime,
            SYSUTCDATETIME()
        );

        -- Return timing metadata
        SELECT 
            CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS BIGINT) AS ExecutionTimeMs,
            @RowsReturned AS RowsReturned,
            @StartTime AS ExecutionStartTime,
            @EndTime AS ExecutionEndTime,
            SYSUTCDATETIME() AS ExecutedAt,
            @ErrorMessage AS ErrorMessage;

    END TRY
    BEGIN CATCH
        SET @EndTime = SYSUTCDATETIME();
        SET @ErrorMessage = ERROR_MESSAGE();

        -- Log error
        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES (
            'QueryOne',
            'OR-based Keyset Pagination',
            DATEDIFF(MILLISECOND, @StartTime, @EndTime),
            0,
            0,
            @ErrorMessage,
            @StartTime,
            @EndTime,
            SYSUTCDATETIME()
        );

        -- Return error metadata
        SELECT 
            CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS BIGINT) AS ExecutionTimeMs,
            0 AS RowsReturned,
            @StartTime AS ExecutionStartTime,
            @EndTime AS ExecutionEndTime,
            SYSUTCDATETIME() AS ExecutedAt,
            @ErrorMessage AS ErrorMessage;
    END CATCH
END
GO
