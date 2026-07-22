-- ============================================================
-- 060: sp_GetRoomTransactions + sp_DeleteTxnRecord (update)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. sp_GetRoomTransactions ─────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetRoomTransactions
    @ContractId   NVARCHAR(MAX),
    @TxnRecordId  INT           = NULL,
    @TxnDate      NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        crt.Id,
        crt.ContractId,
        crt.RoomId,
        crt.CampId,
        ISNULL(r.RoomNo, '')   RoomNo,
        ISNULL(ca.Name,  '')   CampName,
        crt.Amount,
        CONVERT(NVARCHAR(10), crt.TxnDate, 23) TxnDate,
        crt.TxnType,
        ISNULL(crt.Description, '') Description,
        CASE MONTH(crt.TxnDate)
            WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
            WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
            WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
            WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
        END + RIGHT(CAST(YEAR(crt.TxnDate) AS NVARCHAR), 2) Month
    FROM ContractRoomsTrns crt
    JOIN  Rooms r  ON r.Id  = crt.RoomId
    LEFT JOIN Camps ca ON ca.Id = crt.CampId
    WHERE crt.ContractId = @ContractId
      AND crt.TxnType    = 'CR'
      AND (
            @TxnRecordId IS NOT NULL AND (
                crt.TxnRecordId = @TxnRecordId
                OR (
                    crt.TxnRecordId IS NULL
                    AND @TxnDate IS NOT NULL
                    AND CONVERT(NVARCHAR(10), crt.TxnDate, 23) = @TxnDate
                )
            )
          OR (
                @TxnRecordId IS NULL
                AND @TxnDate IS NOT NULL
                AND CONVERT(NVARCHAR(10), crt.TxnDate, 23) = @TxnDate
          )
          OR (@TxnRecordId IS NULL AND @TxnDate IS NULL)
      )
    ORDER BY crt.Id DESC;
END
GO

PRINT '060 - sp_GetRoomTransactions created';
GO
