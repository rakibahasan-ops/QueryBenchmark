-- =====================================================
-- APPROACH 3  — No Temp Table, Direct Seek
-- =====================================================

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
        -- Get total count only on first page
        IF @IsFirstPage = 1
        BEGIN
            SELECT @TotalRows = COUNT_BIG(1)
            FROM HierarchyLinks_Test
            WHERE HierarchyId = 2;
        END

        -- Main query
        ;WITH TopMembers AS
        (
            SELECT TOP (@PageSize)
                src.EntityId,
                src.CreationDate
            FROM
            (
                SELECT TOP (@PageSize)
                    HL.EntityId,
                    U.CreationDate
                FROM User_Test U
                INNER JOIN HierarchyLinks_Test HL
                    ON  HL.EntityId     = U.MemberDocId
                    AND HL.HierarchyId  = 2
                WHERE U.CreationDate    < @LastCreationDate
                ORDER BY
                    U.CreationDate  DESC,
                    HL.EntityId     ASC

                UNION ALL

                SELECT TOP (@PageSize)
                    HL.EntityId,
                    U.CreationDate
                FROM User_Test U
                INNER JOIN HierarchyLinks_Test HL
                    ON  HL.EntityId     = U.MemberDocId
                    AND HL.HierarchyId  = 2
                WHERE U.CreationDate    = @LastCreationDate
                  AND HL.EntityId       > @LastEntityId
                ORDER BY
                    U.CreationDate  DESC,
                    HL.EntityId     ASC

            ) src
            ORDER BY
                src.CreationDate    DESC,
                src.EntityId        ASC
        )
        SELECT
            TM.CreationDate                                             AS NextCursor_Date,
            TM.EntityId                                                 AS NextCursor_Id,
            TM.EntityId                                                 AS MemberDocId,
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
            ISNULL(F.FamilyCount, 0)                                    AS NumberOfFamily,
            @TotalRows                                                  AS TotalRows
        FROM TopMembers TM
        INNER JOIN User_Test U
            ON  U.MemberDocId               = TM.EntityId
        INNER JOIN ClubMemberSummary_Test CMS
            ON  CMS.EntityId                = TM.EntityId
        INNER JOIN MembershipSummary_Test MS
            ON  MS.EntityId                 = TM.EntityId
        INNER JOIN State_Test S
            ON  S.StateId                   = 2
        OUTER APPLY
        (
            SELECT COUNT_BIG(1) AS FamilyCount
            FROM Family_Links_Test FL
            WHERE FL.EntityId   = TM.EntityId
        ) F
        OUTER APPLY
        (
            SELECT TOP 1 CountryCode, Number
            FROM UserPhoneNumber_Test
            WHERE UserId    = U.UserId
              AND [Type]    = 'Mobile'
        ) UP
        ORDER BY
            TM.CreationDate DESC,
            TM.EntityId     ASC
        OPTION (RECOMPILE);

        SET @RowsReturned = @@ROWCOUNT;
        SET @EndTime = SYSUTCDATETIME();

        -- Insert into log
        INSERT INTO QueryExecutionLog (QueryName, QueryDescription, ExecutionTimeMs, RowsReturned, IsSuccess, ErrorMessage, ExecutionStartTime, ExecutionEndTime, ExecutedAt)
        VALUES (
            'QueryThree',
            'Direct Seek, No Temp Table',
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
            'QueryThree',
            'Direct Seek, No Temp Table',
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
