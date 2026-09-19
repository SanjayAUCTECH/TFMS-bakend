Text                                                                                                                                                                                                                                                           
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[sp_GetUsers]
    @PageNumber    INT            = 1,
    @PageSize      INT            = 2147483647,
    @SearchText    NVARCHAR(MAX)  = NULL,
    @SortBy        NVARCHAR(MAX)  = NULL,
    @SortDirection NVARCHAR(MAX)  = 'ASC',
   
 @Role          NVARCHAR(MAX)  = NULL,
    @Source        NVARCHAR(MAX)  = NULL,
    @Status        NVARCHAR(MAX)  = NULL,
    @Designation   NVARCHAR(MAX)  = NULL,
    @ViewStatus    BIT            = NULL,
    @TotalRecords  INT OUTPUT
AS 
BEGIN
    SET 
NOCOUNT ON;

    -- Get total count
    SELECT @TotalRecords = COUNT(*)
    FROM AppUsers u
    LEFT JOIN Staff s ON s.Id = u.SourceId AND u.Source = 'Staff' AND s.IsDeleted = 0
    WHERE u.IsDeleted = 0
      AND (@Role        IS NULL OR u.Role        = 
@Role)
      AND (@ViewStatus  IS NULL OR u.ViewStatus  = @ViewStatus)
      AND (@Source      IS NULL OR u.Source      = @Source)
      AND (@Status      IS NULL OR u.Status      = @Status)
      AND (@Designation IS NULL OR s.Designation = @Designation)

      AND (@SearchText  IS NULL
           OR u.Name     LIKE '%' + @SearchText + '%'
           OR u.Username LIKE '%' + @SearchText + '%');

    -- Get paginated results
    SELECT
        u.Id, 
        u.UserId, 
        u.Name, 
        u.Username, 

        u.PasswordHash,
        u.Role, 
        u.Source, 
        u.SourceId, 
        u.Contact, 
        u.Email, 
        u.IsAdmin,
        u.ViewStatus,
        u.LoginAccess, 
        u.Status, 
        u.MenuAccess, 
        u.LastLogin,
       
 u.CreatedAt, 
        u.UpdatedAt, 
        u.AddedBy, 
        u.UpdatedBy,
        ISNULL(s.Designation, '') AS Designation
    FROM AppUsers u
    LEFT JOIN Staff s ON s.Id = u.SourceId AND u.Role = 'Staff' AND s.IsDeleted = 0
    WHERE u.IsDeleted = 
0
      AND (@Role        IS NULL OR u.Role        = @Role)
      AND (@ViewStatus  IS NULL OR u.ViewStatus  = @ViewStatus)
      AND (@Source      IS NULL OR u.Source      = @Source)
      AND (@Status      IS NULL OR u.Status      = @Status)
      AND (
@Designation IS NULL OR s.Designation = @Designation)
      AND (@SearchText  IS NULL
           OR u.Name     LIKE '%' + @SearchText + '%'
           OR u.Username LIKE '%' + @SearchText + '%')
    ORDER BY u.Name
    OFFSET (@PageNumber - 1) * @PageSize
 ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
                                                                                                                                                                                                                 
