USE [PKRetail_GIBO_VAN_New_20151227]
GO
/****** Object:  StoredProcedure [dbo].[Getsolistforcompletegridview]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Getsolistforcompletegridview] @LocationID    VARCHAR(50), 
                                                     @SONO          VARCHAR(50), 
                                                     @SOID          VARCHAR(50), 
                                                     @TimeFrom      VARCHAR(50), 
                                                     @TimeTo        VARCHAR(50), 
                                                     @DateType      VARCHAR(50), 
                                                     @Status        VARCHAR(50), 
                                                     @ProductName   NVARCHAR(50), 
                                                     @PLU           VARCHAR(50), 
                                                     @Barcode       VARCHAR(50), 
                                                     @CustomerID    VARCHAR(50), 
                                                     @CustomerPhone VARCHAR(50), 
                                                     @Sales         VARCHAR(50), 
                                                     @OrderedBy         VARCHAR(50), 
                                                     @BrandName     VARCHAR(50), 
                                                     @ReturnNo      VARCHAR(50), 
                                                     @Remarks       VARCHAR(200) 
AS 
  BEGIN 
      DECLARE @ReturnAmount DECIMAL(18, 2); 

	  if len(@TimeFrom)<11 
	  begin
		set @TimeFrom = @TimeFrom + ' 00:00:00';
	  end

	  if len(@TimeTo)<11 
	  begin
		set @TimeTo = @TimeTo + ' 23:59:59';
	  end


      SELECT TOP 1 soid, 
                   orderid, 
                   Replace(pkso.orderid, 'S', 'I') AS InvoceNo, 
                   soldtotitle, 
                   filestartdate, 
                   orderdate, 
                   shipdate, 
                   soenddate, 
                   orderby, 
                   fileendby, 
                   subtotal, 
                   totaltax, 
                   pkso.totalamount, 
                   locationid, 
                   shipfee, 
                   otherfees, 
                   @ReturnAmount                   AS ReturnAmount, 
                   Isnull(preorder, 'F')           AS PreOrder 
      INTO   #tblso 
      FROM   pkso; 

      DELETE FROM #tblso; 

      IF @ReturnNo = '' 
        BEGIN 
            INSERT INTO #tblso 
            SELECT DISTINCT pkso.soid, 
                            pkso.orderid, 
                            Replace(pkso.orderid, 'S', 'I') AS InvoceNo, 
                            soldtotitle, 
                            filestartdate, 
                            orderdate, 
                            shipdate, 
                            soenddate, 
                            orderby, 
                            fileendby, 
                            pkso.subtotal, 
                            pkso.totaltax, 
                            pkso.totalamount, 
                            pkso.locationid, 
                            pkso.shipfee, 
                            pkso.otherfees, 
                            Isnull(returnamount, 0)         AS ReturnAmount, 
                            CASE preorder 
                              WHEN 'true'THEN 'Y' 
                              ELSE 'N' 
                            END                             AS PreOrder 
            FROM   pkso 
                   LEFT OUTER JOIN (SELECT soid, 
                                           Sum(totalamount) AS ReturnAmount 
                                    FROM   pksoreturn 
                                    WHERE  status = 'POST' 
                                           AND (( ( @ReturnNo != '' 
                                                    AND soreturnid LIKE '%' + @ReturnNo + '%' )
                                                   OR ( @ReturnNo = '' ) )) 
                                           AND ( ( @DateType <> '1' ) 
                                                  OR ( @DateType = '1' 
                                                       --AND returndate >= @TimeFrom 
                                                       --AND returndate <= @TimeTo 
													   AND 
													   
													   ( @TimeFrom = '' OR ( @TimeFrom <> '' AND returndate >= @TimeFrom ) ) 
													   and
													   ( @TimeTo = '' OR ( @TimeTo <> '' AND returndate <= @TimeTo  ) ) 



													   
													   ) ) 
                                    GROUP  BY soid) AS SOReturn 
                                ON pkso.soid = SOReturn.soid 
                   LEFT OUTER JOIN pksoproduct PSP 
                                ON pkso.soid = PSP.soid 
                   LEFT OUTER JOIN pksoreturn PSR 
                                ON pkso.soid = PSR.soid 
            WHERE  pkso.type != 'Contract' 
                   AND ( @SONO = '' 
                          OR ( @SONO <> '' 
                               AND pkso.orderid LIKE '%' + @SONO + '%' ) ) 
                   AND ( @SOID = '' 
                          OR ( @SOID <> '' 
                               AND pkso.soid = @SOID ) ) 
                   AND ( @LocationID = '' 
                          OR ( @LocationID <> '' 
                               AND pkso.locationid = @LocationID ) ) 
                   AND ( @TimeFrom = '' 
                          OR ( @TimeFrom <> '' 
                               AND ( @DateType = '0' 
                                     AND pkso.orderdate >= @TimeFrom ) 
                                OR ( @DateType = '3' 
                                     --AND pkso.shipdate >= @TimeFrom ) 
                                     AND pkso.SOEndDate >= @TimeFrom ) 
                                OR ( @DateType = '1' 
                                     AND PSR.returndate >= @TimeFrom ) ) ) 
                   AND ( @TimeTo = '' 
                          OR ( @TimeTo <> '' 
                               AND ( @DateType = '0' 
                                     AND pkso.orderdate <= @TimeTo ) 
                                OR ( @DateType = '3' 
                                     --AND pkso.shipdate <= @TimeTo ) 
                                     AND pkso.SOEndDate <= @TimeTo ) 
                                OR ( @DateType = '1' 
                                     AND PSR.returndate <= @TimeTo ) ) ) 
                   AND ( @Status = '' 
                          OR ( @Status <> '' 
                               AND ( ( Lower(@Status) = 'preorder' 
                                       AND ( Lower(pkso.status) = 'back' 
                                              OR Lower(pkso.status) = 'pending' ) 
                                       AND Isnull(pkso.preorder, 'false') = 'true' ) 
                                      OR ( Lower(@Status) = 'back' 
                                           AND Lower(pkso.status) = 'back' 
                                           AND Isnull(pkso.preorder, 'false') = 'false' ) 
                                      OR ( Lower(@Status) = 'pending' 
                                           AND Lower(pkso.status) = 'pending' 
                                           AND Isnull(pkso.preorder, 'false') = 'false' ) 
                                      OR ( Lower(@Status) <> 'pending' 
                                           AND Lower(@Status) <> 'back' 
                                           AND Lower(@Status) <> 'preorder' 
                                           AND Lower(pkso.status) = Lower(@Status) ) 
                                    -- 
                                    ) ) ) 
                   AND ( @ProductName = '' 
                          OR ( @ProductName <> '' 
                               AND psp.productname1 + psp.productname2 LIKE N'%' + @ProductName + '%' ) )
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND psp.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Barcode = '' 
                          OR ( @Barcode <> '' 
                               AND psp.barcode LIKE '%' + @Barcode + '%' ) ) 
                   AND ( @CustomerID = '' 
                          OR ( @CustomerID <> '' 
                               AND pkso.customerid = @CustomerID ) ) 
                   AND ( @CustomerPhone = '' 
                          OR ( @CustomerPhone <> '' 
                               AND pkso.comtel + pkso.shipttel LIKE '%' + @CustomerPhone + '%' ) )
                   AND ( @OrderedBy = '' 
                          OR ( @OrderedBy <> '' 
                               AND pkso.OrderBy = @OrderedBy ) ) 
                   AND ( @Remarks = '' 
                          OR ( @Remarks <> '' 
                               AND pkso.soremarks LIKE N'%' + @Remarks + '%' ) ) 
            ORDER  BY pkso.soenddate DESC, 
                      pkso.orderid DESC 
        END 
      ELSE 
        BEGIN 
            INSERT INTO #tblso 
            SELECT DISTINCT pkso.soid, 
                            pkso.orderid, 
                            Replace(pkso.orderid, 'S', 'I') AS InvoceNo, 
                            soldtotitle, 
                            filestartdate, 
                            orderdate, 
                            shipdate, 
                            soenddate, 
                            orderby, 
                            fileendby, 
                            pkso.subtotal, 
                            pkso.totaltax, 
                            pkso.totalamount, 
                            pkso.locationid, 
                            pkso.shipfee, 
                            pkso.otherfees, 
                            Isnull(returnamount, 0)         AS ReturnAmount, 
                            CASE preorder 
                              WHEN 'true'THEN 'Y' 
                              ELSE 'N' 
                            END                             AS PreOrder 
            FROM   pkso 
                   inner JOIN (SELECT soid, 
                                           Sum(totalamount) AS ReturnAmount 
                                    FROM   pksoreturn 
                                    WHERE  status = 'POST' 
                                           AND (( ( @ReturnNo != '' 
                                                    AND soreturnid LIKE '%' + @ReturnNo + '%' )
                                                   OR ( @ReturnNo = '' ) )) 
                                           AND ( ( @DateType <> '1' ) 
                                                  OR ( @DateType = '1' 
                                                       AND 
													   
													   ( @TimeFrom = '' OR ( @TimeFrom <> '' AND returndate >= @TimeFrom ) ) 
													   and
													   ( @TimeTo = '' OR ( @TimeTo <> '' AND returndate <= @TimeTo  ) ) 

													   
													   ) ) 
                                    GROUP  BY soid) AS SOReturn 
                                ON pkso.soid = SOReturn.soid 
                   LEFT OUTER JOIN pksoproduct PSP 
                                ON pkso.soid = PSP.soid 
                   LEFT OUTER JOIN pksoreturn PSR 
                                ON pkso.soid = PSR.soid 
            WHERE  pkso.type != 'Contract' 
                   AND ( @SONO = '' 
                          OR ( @SONO <> '' 
                               AND pkso.orderid LIKE '%' + @SONO + '%' ) ) 
                   AND ( @SOID = '' 
                          OR ( @SOID <> '' 
                               AND pkso.soid = @SOID ) ) 
                   AND ( @LocationID = '' 
                          OR ( @LocationID <> '' 
                               AND pkso.locationid = @LocationID ) ) 
                   AND ( @TimeFrom = '' 
                          OR ( @TimeFrom <> '' 
                               AND ( @DateType = '0' 
                                     AND pkso.orderdate >= @TimeFrom ) 
                                OR ( @DateType = '3' 
                                     --AND pkso.shipdate >= @TimeFrom ) 
                                     AND pkso.SOEndDate >= @TimeFrom ) 
                                OR ( @DateType = '1' 
                                     AND PSR.returndate >= @TimeFrom ) ) ) 
                   AND ( @TimeTo = '' 
                          OR ( @TimeTo <> '' 
                               AND ( @DateType = '0' 
                                     AND pkso.orderdate <= @TimeTo ) 
                                OR ( @DateType = '3' 
                                     --AND pkso.shipdate <= @TimeTo ) 
                                     AND pkso.SOEndDate <= @TimeTo ) 
                                OR ( @DateType = '1' 
                                     AND PSR.returndate <= @TimeTo ) ) ) 
                   AND ( @Status = '' 
                          OR ( @Status <> '' 
                               AND ( ( Lower(@Status) = 'preorder' 
                                       AND ( Lower(pkso.status) = 'back' 
                                              OR Lower(pkso.status) = 'pending' ) 
                                       AND Isnull(pkso.preorder, 'false') = 'true' ) 
                                      OR ( Lower(@Status) = 'back' 
                                           AND Lower(pkso.status) = 'back' 
                                           AND Isnull(pkso.preorder, 'false') = 'false' ) 
                                      OR ( Lower(@Status) = 'pending' 
                                           AND Lower(pkso.status) = 'pending' 
                                           AND Isnull(pkso.preorder, 'false') = 'false' ) 
                                      OR ( Lower(@Status) <> 'pending' 
                                           AND Lower(@Status) <> 'back' 
                                           AND Lower(@Status) <> 'preorder' 
                                           AND Lower(pkso.status) = Lower(@Status) ) 
                                    -- 
                                    ) ) ) 
                   AND ( @ProductName = '' 
                          OR ( @ProductName <> '' 
                               AND psp.productname1 + psp.productname2 LIKE N'%' + @ProductName + '%' ) )
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND psp.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Barcode = '' 
                          OR ( @Barcode <> '' 
                               AND psp.barcode LIKE '%' + @Barcode + '%' ) ) 
                   AND ( @CustomerID = '' 
                          OR ( @CustomerID <> '' 
                               AND pkso.customerid = @CustomerID ) ) 
                   AND ( @CustomerPhone = '' 
                          OR ( @CustomerPhone <> '' 
                               AND pkso.comtel + pkso.shipttel LIKE '%' + @CustomerPhone + '%' ) )
                   AND ( @OrderedBy = '' 
                          OR ( @OrderedBy <> '' 
                               AND pkso.OrderBy = @OrderedBy ) ) 
                   AND ( @Remarks = '' 
                          OR ( @Remarks <> '' 
                               AND pkso.soremarks LIKE N'%' + @Remarks + '%' ) ) 
            ORDER  BY pkso.soenddate DESC, 
                      pkso.orderid DESC 
        END 

      --IF( Len(@ReturnNo) > 0 )  
      --  BEGIN  
      --      SELECT 1;  
      --  END  
      --ELSE  
      --  BEGIN  
      --      SELECT 1;  
      --  END  
      --IF @DateType = '1'  
      --    OR @RadioButtonSelect = '7'  
      --  BEGIN  
      --      INSERT INTO #tblso  
      --      SELECT PKSO.SOID,  
      --             PKSO.ORDERID,  
      --             Replace(PKSO.ORDERID, 'S', 'I') AS InvoceNo,  
      --             SOLDTOTITLE,  
      --             FILESTARTDATE,  
      --             ORDERDATE,  
      --             SHIPDATE,  
      --             SOENDDATE,  
      --             ORDERBY,  
      --             FILEENDBY,  
      --             SUBTOTAL,  
      --             TOTALTAX,  
      --             PKSO.TOTALAMOUNT,  
      --             LOCATIONID,  
      --             SHIPFEE,  
      --             OTHERFEES,  
      --             Isnull(RETURNAMOUNT, 0)         AS ReturnAmount,  
      --             CASE PREORDER  
      --               WHEN 'true'THEN 'Y'  
      --               ELSE 'N'  
      --             END                             AS PreOrder  
      --      FROM   PKSO  
      --             INNER JOIN (SELECT SOID,  
      --                                Sum(TOTALAMOUNT) AS ReturnAmount  
      --                         FROM   PKSORETURN  
      --                         WHERE  STATUS = 'POST'  
      --                                AND (( ( @RadioButtonSelect = '7'  
      --                                         AND @TxtSearch != ''  
      --                                         AND SORETURNID LIKE '%' + @TxtSearch + '%' )  
      --                                        OR ( @RadioButtonSelect <> '7'  
      --                                              OR @TxtSearch = '' ) ))  
      --                                AND RETURNDATE >= @FromDateTime  
      --                                AND RETURNDATE <= @ToDateTime  
      --                         GROUP  BY SOID) AS SOReturn  
      --                     ON PKSO.SOID = SOReturn.SOID  
      --      WHERE  TYPE != 'Contract'  
      --             AND ( PKSO.STATUS = 'Shipped'  
      --                    OR ( PKSO.STATUS = 'Pending'  
      --                         AND PKSO.PREORDER = 'true' ) )  
      --             AND LOCATIONID = CASE @LocationID  
      --                                WHEN '' THEN LOCATIONID  
      --                                ELSE @LocationID  
      --                              END  
      --             AND CUSTOMERID = CASE @CustomerID  
      --                                WHEN '' THEN CUSTOMERID  
      --                                ELSE @CustomerID  
      --                              END  
      --             AND ORDERBY = CASE @Sales  
      --                             WHEN '' THEN ORDERBY  
      --                             ELSE @Sales  
      --                           END  
      --             AND SOREMARKS LIKE '%' + CASE WHEN @RadioButtonSelect = '8' AND @TxtSearch!='' THEN @TxtSearch ELSE SOREMARKS END + '%'
      --             AND SOLDTOTEL LIKE '%' + CASE WHEN @RadioButtonSelect = '6' AND @TxtSearch!='' THEN @TxtSearch ELSE SOLDTOTEL END + '%'
      --             AND ORDERID LIKE '%' + CASE WHEN @RadioButtonSelect = '5' AND @TxtSearch !='' THEN @TxtSearch ELSE ORDERID END + '%'
      --      ORDER  BY PKSO.SOENDDATE DESC,  
      --                PKSO.ORDERID DESC  
      --  END  
      --ELSE IF @DateType = '3'  
      --  BEGIN  
      --      INSERT INTO #tblso  
      --      SELECT PKSO.SOID,  
      --             ORDERID,  
      --             Replace(PKSO.ORDERID, 'S', 'I') AS InvoceNo,  
      --             SOLDTOTITLE,  
      --             FILESTARTDATE,  
      --             ORDERDATE,  
      --             SHIPDATE,  
      --             SOENDDATE,  
      --             ORDERBY,  
      --             FILEENDBY,  
      --             SUBTOTAL,  
      --             TOTALTAX,  
      --             PKSO.TOTALAMOUNT,  
      --             LOCATIONID,  
      --             SHIPFEE,  
      --             OTHERFEES,  
      --             Isnull(RETURNAMOUNT, 0)         AS ReturnAmount,  
      --             CASE PREORDER  
      --               WHEN 'true'THEN 'Y'  
      --               ELSE 'N'  
      --             END                             AS PreOrder  
      --      FROM   PKSO  
      --             LEFT OUTER JOIN (SELECT SOID,  
      --                                     Sum(TOTALAMOUNT) AS ReturnAmount  
      --                              FROM   PKSORETURN  
      --                              WHERE  STATUS = 'Post'  
      --                              GROUP  BY SOID) AS SOReturn  
      --                          ON PKSO.SOID = SOReturn.SOID  
      --      WHERE  TYPE != 'Contract'  
      --             AND ( ( PKSO.STATUS = 'Shipped'  
      --                     AND SOENDDATE >= @FromDateTime  
      --                     AND SOENDDATE <= @ToDateTime )  
      --                    OR ( PKSO.STATUS = 'Pending'  
      --                         AND Isnull(PKSO.PREORDER, '') = 'true'  
      --                         AND ORDERDATE >= @FromDateTime  
      --                         AND ORDERDATE <= @ToDateTime ) )  
      --             AND LOCATIONID = CASE @LocationID  
      --                                WHEN '' THEN LOCATIONID  
      --                                ELSE @LocationID  
      --                              END  
      --             AND CUSTOMERID = CASE @CustomerID  
      --                                WHEN '' THEN CUSTOMERID  
      --                                ELSE @CustomerID  
      --                              END  
      --             AND ORDERBY = CASE @Sales  
      --                             WHEN '' THEN ORDERBY  
      --                             ELSE @Sales  
      --                           END  
      --             --             AND (   
      --             --( Isnull(preorder, '') = 'true'   
      --             --)   
      --             --                    OR  
      --             --( Isnull(preorder, '') <> 'true'   
      --             --                         AND soenddate >= @FromDateTime   
      --             --                         AND soenddate <= @ToDateTime   
      --             --)   
      --             --)   
      --             AND SOREMARKS LIKE '%' + CASE WHEN @RadioButtonSelect = '8' AND @TxtSearch!='' THEN @TxtSearch ELSE SOREMARKS END + '%'
      --             AND SOLDTOTEL LIKE '%' + CASE WHEN @RadioButtonSelect = '6' AND @TxtSearch!='' THEN @TxtSearch ELSE SOLDTOTEL END + '%'
      --             AND ORDERID LIKE '%' + CASE WHEN @RadioButtonSelect = '5' AND @TxtSearch !='' THEN @TxtSearch ELSE ORDERID END + '%'
      --  END  
      --ELSE  
      --  BEGIN  
      --      INSERT INTO #tblso  
      --      SELECT PKSO.SOID,  
      --             ORDERID,  
      --             Replace(PKSO.ORDERID, 'S', 'I') AS InvoceNo,  
      --             SOLDTOTITLE,  
      --             FILESTARTDATE,  
      --             ORDERDATE,  
      --             SHIPDATE,  
      --             SOENDDATE,  
      --             ORDERBY,  
      --             FILEENDBY,  
      --             SUBTOTAL,  
      --             TOTALTAX,  
      --             PKSO.TOTALAMOUNT,  
      --             LOCATIONID,  
      --             SHIPFEE,  
      --             OTHERFEES,  
      --             Isnull(RETURNAMOUNT, 0)         AS ReturnAmount,  
      --             CASE PREORDER  
      --               WHEN 'true'THEN 'Y'  
      --               ELSE 'N'  
      --             END                             AS PreOrder  
      --      FROM   PKSO  
      --             LEFT OUTER JOIN (SELECT SOID,  
      --                                     Sum(TOTALAMOUNT) AS ReturnAmount  
      --                              FROM   PKSORETURN  
      --                              WHERE  STATUS = 'Post'  
      --                              GROUP  BY SOID) AS SOReturn  
      --                          ON PKSO.SOID = SOReturn.SOID  
      --      WHERE  TYPE != 'Contract'  
      --             AND ( PKSO.STATUS = 'Shipped'  
      --                    OR ( PKSO.STATUS = 'Pending'  
      --                         AND Isnull(PKSO.PREORDER, '') = 'true' ) )  
      --             AND LOCATIONID = CASE @LocationID  
      --                                WHEN '' THEN LOCATIONID  
      --                                ELSE @LocationID  
      --                              END  
      --             AND CUSTOMERID = CASE @CustomerID  
      --                                WHEN '' THEN CUSTOMERID  
      --                                ELSE @CustomerID  
      --                              END  
      --             AND ORDERBY = CASE @Sales  
      --                             WHEN '' THEN ORDERBY  
      --                             ELSE @Sales  
      --                           END  
      --             AND CASE @DateType  
      --                   WHEN '0' THEN ORDERDATE  
      --                   WHEN '2' THEN SHIPDATE  
      --                 END >= @FromDateTime  
      --             AND CASE @DateType  
      --                   WHEN '0' THEN ORDERDATE  
      --                   WHEN '2' THEN SHIPDATE  
      --                 END <= @ToDateTime  
      --             AND SOREMARKS LIKE '%' + CASE WHEN @RadioButtonSelect = '8' AND @TxtSearch!='' THEN @TxtSearch ELSE SOREMARKS END + '%'
      --             AND SOLDTOTEL LIKE '%' + CASE WHEN @RadioButtonSelect = '6' AND @TxtSearch!='' THEN @TxtSearch ELSE SOLDTOTEL END + '%'
      --             AND ORDERID LIKE '%' + CASE WHEN @RadioButtonSelect = '5' AND @TxtSearch !='' THEN @TxtSearch ELSE ORDERID END + '%'
      --  --Order by PKSO.SOEndDate desc,PKSO.OrderID desc       
      --  END  
      SELECT #tblso.soid, 
             Sum(Isnull(paymentamount, 0)) AS PayAmount 
      INTO   #tblpayment 
      FROM   #tblso 
             LEFT JOIN pkpayment 
                    ON #tblso.soid = pkpayment.orderid 
      WHERE  paytype <> 'Credit' 
      GROUP  BY soid 

      SELECT #tblso.*, 
             Isnull(payamount, 0)               AS PayAmount, 
             totalamount - Isnull(payamount, 0) AS Balance 
      INTO   #tblsopayment 
      FROM   #tblso 
             LEFT JOIN #tblpayment 
                    ON #tblso.soid = #tblpayment.soid 

      SELECT DISTINCT #tblsopayment.*, 
                      Isnull(GSTTax.amount, 0) AS GST, 
                      Isnull(PSTTax.amount, 0) AS PST 
      FROM   #tblsopayment 
             LEFT OUTER JOIN (SELECT soid, 
                                     amount 
                              FROM   pksotax 
                              WHERE  taxname = 'GST:') AS GSTTax 
                          ON #tblsopayment.soid = GSTTax.soid 
             LEFT OUTER JOIN (SELECT soid, 
                                     amount 
                              FROM   pksotax 
                              WHERE  taxname = 'PST:') AS PSTTax 
                          ON #tblsopayment.soid = PSTTax.soid 
      --LEFT OUTER JOIN PKSOPRODUCT  
      --             ON #TBLSOPAYMENT.SOID = PKSOPRODUCT.SOID  
      --LEFT OUTER JOIN PKPRODUCT  
      --             ON PKSOPRODUCT.PRODUCTID = PKPRODUCT.ID  
      --WHERE  ( PKSOPRODUCT.PRODUCTNAME1 IS NULL  
      --          OR PKSOPRODUCT.PRODUCTNAME1 LIKE '%' + CASE WHEN @RadioButtonSelect = '1' AND @TxtSearch !='' THEN @TxtSearch ELSE PKSOPRODUCT.PRODUCTNAME1 END + '%' )
      --       AND ( PKSOPRODUCT.PLU IS NULL  
      --              OR PKSOPRODUCT.PLU LIKE '%' + CASE WHEN @RadioButtonSelect = '2' AND @TxtSearch != '' THEN @TxtSearch ELSE PKSOPRODUCT.PLU END + '%' )
      --       AND ( PKSOPRODUCT.BARCODE IS NULL  
      --              OR PKSOPRODUCT.BARCODE LIKE '%' + CASE WHEN @RadioButtonSelect ='3' AND @TxtSearch= '' THEN @TxtSearch ELSE PKSOPRODUCT.BARCODE END + '%' )
      --       AND ( PKPRODUCT.BRAND IS NULL  
      --              OR PKPRODUCT.BRAND LIKE '%' + CASE WHEN @RadioButtonSelect= '4' AND @TxtSearch ='' THEN @TxtSearch ELSE PKPRODUCT.BRAND END + '%' )
      ORDER  BY orderdate DESC 

      DROP TABLE #tblso; 

      DROP TABLE #tblpayment; 

      DROP TABLE #tblsopayment; 
  END 

GO
/****** Object:  StoredProcedure [dbo].[PK_AddLocationPrice]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[PK_AddLocationPrice]
(
       @LocationID NVARCHAR(50),
       @ProductID NVARCHAR(50),
       @UpdateTime NVARCHAR(50),
       @Price DECIMAL(18,2),
       @Updater NVARCHAR(50)
)
AS
BEGIN 
       INSERT INTO PkBookProductLocationPrice (LocationID, ProductID, UpdateTime, Price, Updater)
       VALUES (@LocationID, @ProductID, @UpdateTime, @Price, @Updater)
END

GO
/****** Object:  StoredProcedure [dbo].[PK_BackupInventoryInHistory]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_BackupInventoryInHistory] 
	@InventoryId nvarchar(50),
	@LocationId nvarchar(50),
	@OldQty decimal(18,2),
	@NewQty decimal(18,2),
	@UpdatedBy nvarchar(50),
	@Remark nvarchar(200),
	@LatestCost decimal(18,2),
	@averageCost decimal(18,2),
	@unit nvarchar(50)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
	INSERT INTO [dbo].[PKInventoryHistory]
           ([InventoryId]
		   ,[LocationId]
           ,[updateTime]
           ,[OldQty]
           ,[NewQty]
           ,[updatedBy]
           ,[remark]
		   ,LatestCostOld
		   ,averageCostOld
		   ,unit
		   )
     VALUES(
		   @InventoryId,
		   @LocationId,
		   getdate(),
		   @OldQty,
		   @NewQty,
		   @UpdatedBy,
		   @Remark,
		   @LatestCost,
		   @averageCost,
		   @unit
		   );
END


GO
/****** Object:  StoredProcedure [dbo].[PK_CreateSOFromContract]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_CreateSOFromContract] 
	
AS
BEGIN
	SET NOCOUNT ON;
    declare @ID varchar(50);
	declare @SOID nvarchar(50);
	declare @ContractID varchar(50);
	declare @InvoiceType varchar(50);
	declare @StartDate smalldatetime;
	declare @EndDate smalldatetime;
	declare @Period varchar(50);
	declare @Status nvarchar(50);
	declare @UpdateDate datetime;
	declare @CreateSO varchar(1);

SELECT *  INTO #tblSOContract FROM PKSOContract WHERE StartDate <= GETDATE() AND  GETDATE()<=EndDate AND Status != 'Complete' AND CONVERT(date, UpdateDate) <= CONVERT(date, GETDATE())

--SELECT * FROM #tblSOContract
   
declare @tbl1SOContractID nvarchar(50)
declare tblSOContractCursor CURSOR FOR SELECT ID FROM #tblSOContract 
OPEN tblSOContractCursor
FETCH NEXT FROM tblSOContractCursor
INTO @tbl1SOContractID
WHILE @@FETCH_Status = 0
BEGIN

    SELECT @ID=ID, @SOID = SOID, @ContractID = ContractID, @InvoiceType=InvoiceType, @StartDate = StartDate, @EndDate = EndDate, @Period = Period, @UpdateDate = UpdateDate 
	FROM PKSOContract 
	WHERE ID= @tbl1SOContractID

	--print @UpdateDate
	--print GETDATE()

	    declare @NewSOID nvarchar(50);
		SET @NewSOID = NEWID();
        	 
	    SELECT * 
		INTO #tbl1
		FROM PKSO WHERE SOID = @SOID
		UPDATE #tbl1 SET SOID = @NewSOID, ORDERID = '', Status = 'Draft', FileStartDate = GETDATE(), OrderDate = GETDATE(), ShipDate = DateADD(day, 3, ShipDate), ContractNo= @ContractID, Type = 'Local'

		SELECT * 
		INTO #tbl2
		FROM PKSOProduct WHERE SOID = @SOID ORDER BY seq
		
		declare @tbl2SOProductID nvarchar(50)
		declare @HasReference int

		declare tbl2Cursor CURSOR FOR SELECT SOProductID FROM #tbl2
		OPEN tbl2Cursor
		FETCH NEXT FROM tbl2Cursor
		INTO @tbl2SOProductID
		WHILE @@FETCH_Status = 0
		BEGIN
			declare @SOProductID nvarchar(50)
  			SET @SOProductID = NEWID()

--			print @tbl2SOProductID
--			print @SOProductID

			SELECT @HasReference = COUNT(*) FROM #tbl2 WHERE ReferenceID=@tbl2SOProductID
			if (@HasReference > 1)
				Begin
				  UPDATE #tbl2 SET ReferenceID= @SOProductID , SOID = @NewSOID WHERE ReferenceID=@tbl2SOProductID
				end

			if (@InvoiceType = 'Split order in quality per invoice')
			BEGIN
				declare @Qty decimal(18,2)
				declare @ContractQty decimal(18,2)
				declare @TotalSOQty decimal(18,2)
				declare @ProductID varchar(50)
				SELECT @Qty = Qty, @ProductID=ProductID FROM PKSOContractProduct WHERE SOContractID=@ID AND SOProductID = @tbl2SOProductID
				SELECT @ContractQty=OrderQty FROM #tbl2 WHERE SOProductID = @tbl2SOProductID
				SELECT @TotalSOQty = ISNULL(SUM(ISNULL(OrderQty,0)),0) FROM PKSO INNER JOIN PKSOProduct ON PKSO.SOID = PKSOProduct.SOID 
				WHERE ContractNo = @ContractID AND Status = 'Shipped' AND ProductID = @ProductID

				IF ((@ContractQty - @TotalSOQty) > @Qty) 
 				     UPDATE #tbl2 SET OrderQty = @Qty, ShippingQty = @Qty WHERE SOProductID = @tbl2SOProductID
				ELSE IF (@ContractQty <= @TotalSOQty)
				     DELETE FROM #tbl2 WHERE SOProductID = @tbl2SOProductID
				ELSE IF (@ContractQty > @TotalSOQty)
				    UPDATE #tbl2 SET OrderQty = @ContractQty-@TotalSOQty, ShippingQty = @ContractQty-@TotalSOQty WHERE SOProductID = @tbl2SOProductID 
					  
			END
			UPDATE #tbl2 SET SOProductID= @SOProductID, SOID = @NewSOID WHERE SOProductID = @tbl2SOProductID
--			SELECT * FROM #tbl2

			FETCH NEXT FROM tbl2Cursor
			INTO @tbl2SOProductID
		END
		CLOSE tbl2Cursor
		DEAlLOCATE tbl2Cursor

	--	SELECT * FROM #tbl2

		ALTER TABLE #tbl2
		DROP COLUMN seq
		declare @RowCount int
		SELECT @RowCount = Count(*) FROM #tbl2
        IF (@RowCount >0)
		BEGIN
            INSERT INTO PKSOProduct (SOProductID, LocationID, SOID, ProductID, PLU, Barcode, ProductName1, ProductName2, Pack, Size, OrderQty, Weigh, Unit, UnitCost,
	  	Discount, Markup, TaxMarkup, TotalCost, SOProductRemarks, ShippingQty, BackQty, SerialNumbers, ReferenceID, Type, AverageCost) SELECT * FROM #tbl2
		    INSERT INTO PKSO SELECT * FROM #tbl1
		END
		ELSE
		BEGIN
		   UPDATE PKSOContract SET Status = 'Complete' WHERE ID= @ID
		   UPDATE PKSO SET Status = 'Complete' WHERE SOID = @SOID
	   END


		SELECT * 
		INTO #tbl3
		FROM PKSOProductTax WHERE SOID = @SOID

		declare @tbl3SOProductTaxID nvarchar(50)
		declare tbl3Cursor CURSOR FOR SELECT ID FROM #tbl3
		OPEN tbl3Cursor
		FETCH NEXT FROM tbl3Cursor
		INTO @tbl3SOProductTaxID
		WHILE @@FETCH_Status = 0
		BEGIN
		UPDATE #tbl3 SET ID=NEWID(), SOID = @NewSOID WHERE ID=@tbl3SOProductTaxID
		FETCH NEXT FROM tbl3Cursor
		INTO @tbl3SOProductTaxID
		END
		CLOSE tbl3Cursor
		DEAlLOCATE tbl3Cursor

--		SELECT * FROM #tbl3
		INSERT INTO PKSOProductTax SELECT * FROM #tbl3 

print @Period
	SELECT @UpdateDate = CASE  WHEN @Period='1D' THEN  DATEADD(dd, 1, @UpdateDate) WHEN @Period='1W' THEN DATEADD(dd, 7, @UpdateDate) 
	WHEN @Period='2W' THEN DATEADD(dd, 14, @UpdateDate)
	WHEN @Period='1M' THEN DATEADD(mm, 1, @UpdateDate)
	WHEN @Period='1Y' THEN DATEADD(yy, 1, @UpdateDate)
	WHEN @Period='SM' AND day(@UpdateDate) <15 THEN CONVERT(date,CONVERT(varchar(4),year(@UpdateDate))+'-'+CONVERT(varchar(2),MONTH(@Updatedate))+'-'+'15')
	WHEN @Period='SM' AND day(@UpdateDate) >=15 THEN CONVERT(date,CONVERT(varchar(4),year(@UpdateDate))+'-'+CONVERT(varchar(2),MONTH(@Updatedate)+1)+'-'+'01')
	WHEN @Period='SY' THEN DateAdd(MONTH,6, @UpdateDate)
	WHEN @Period='QY' THEN DateAdd(MONTH,3, @UpdateDate)
--	WHEN @Period='SY' AND (day(@StartDate) = day(GETDATE()) AND MONTH(@StartDate) = Month(GETDATE()) OR (day(@StartDate) = day(GETDATE()) AND MONTH(@StartDate)+6 = Month(GETDATE()))) THEN 'Y'
	ELSE @UpdateDate END  

--	print @Updatedate

	IF (@UpdateDate > @EndDate)
	   Update PKSOContract SET Status = 'Complete' WHERE ID=@ID 
	ELSE
	   Update PKSOContract SET UpdateDate = @UpdateDate WHERE ID=@ID 

	   declare @OrderBy nvarchar(50)
	   SELECT @OrderBy = OrderBY FROM #tbl1
	   declare @Email nvarchar(50)
	   SELECT @Email=EMail FROM PKUsers INNER JOIN PKEmployee ON PKUsers.EmployeeID = PKEmployee.ID WHERE UserName = @OrderBy
    
	EXEC msdb.dbo.sp_send_dbmail @profile_name='Posking',  
    @recipients=@Email,  
    @subject='Create new SO.',  
    @body='SO created successfully.'   

	drop table #tbl1;
	drop table #tbl2;
	drop table #tbl3;
	
 	FETCH NEXT FROM tblSOContractCursor
	INTO @tbl1SOContractID

	END
	CLOSE tblSOContractCursor
	DEAlLOCATE tblSOContractCursor

	drop table #tblSOContract;
End

GO
/****** Object:  StoredProcedure [dbo].[PK_CreateSOProductTableFromContract]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_CreateSOProductTableFromContract] 
   @SOID nvarchar(50)
	
AS
BEGIN
	SET NOCOUNT ON;
    declare @ID varchar(50);
	declare @ContractID varchar(50);
	declare @InvoiceType varchar(50);
	declare @StartDate smalldatetime;
	declare @EndDate smalldatetime;
	declare @Period varchar(50);
	declare @Status nvarchar(50);
	declare @UpdateDate datetime;
	declare @CreateSO varchar(1);


    SELECT @ID=ID, @ContractID = ContractID, @InvoiceType=InvoiceType, @StartDate = StartDate, @EndDate = EndDate, @Period = Period, @UpdateDate = UpdateDate 
	FROM PKSOContract 
	WHERE SOID=@SOID
	
		SELECT * 
		INTO #tbl2
		FROM PKSOProduct WHERE SOID = @SOID ORDER BY seq
		
		declare @tbl2SOProductID nvarchar(50)
		declare @HasReference int

		declare tbl2Cursor CURSOR FOR SELECT SOProductID FROM #tbl2
		OPEN tbl2Cursor
		FETCH NEXT FROM tbl2Cursor
		INTO @tbl2SOProductID
		WHILE @@FETCH_Status = 0
		BEGIN
			declare @SOProductID nvarchar(50)
  			SET @SOProductID = NEWID()

--			print @tbl2SOProductID
--			print @SOProductID

			SELECT @HasReference = COUNT(*) FROM #tbl2 WHERE ReferenceID=@tbl2SOProductID
			if (@HasReference > 1)
				Begin
				  UPDATE #tbl2 SET ReferenceID= @SOProductID , SOID = '' WHERE ReferenceID=@tbl2SOProductID
				end

			if (@InvoiceType = 'Split order in quality per invoice')
			BEGIN
				declare @Qty decimal(18,2)
				declare @ContractQty decimal(18,2)
				declare @TotalSOQty decimal(18,2)
				declare @ProductID varchar(50)
				SELECT @Qty = Qty, @ProductID=ProductID FROM PKSOContractProduct WHERE SOContractID=@ID AND SOProductID = @tbl2SOProductID
				SELECT @ContractQty=OrderQty FROM #tbl2 WHERE SOProductID = @tbl2SOProductID
				SELECT @TotalSOQty = ISNULL(SUM(ISNULL(OrderQty,0)),0) FROM PKSO INNER JOIN PKSOProduct ON PKSO.SOID = PKSOProduct.SOID 
				WHERE ContractNo = @ContractID AND Status = 'Shipped' AND ProductID = @ProductID

				IF ((@ContractQty - @TotalSOQty) > @Qty) 
 				     UPDATE #tbl2 SET OrderQty = @Qty, ShippingQty = @Qty WHERE SOProductID = @tbl2SOProductID
				ELSE IF (@ContractQty <= @TotalSOQty)
				     DELETE FROM #tbl2 WHERE SOProductID = @tbl2SOProductID
				ELSE IF (@ContractQty > @TotalSOQty)
				    UPDATE #tbl2 SET OrderQty = @ContractQty-@TotalSOQty, ShippingQty = @ContractQty-@TotalSOQty WHERE SOProductID = @tbl2SOProductID 
					  
			END
			UPDATE #tbl2 SET SOProductID= @SOProductID, SOID = '' WHERE SOProductID = @tbl2SOProductID

			FETCH NEXT FROM tbl2Cursor
			INTO @tbl2SOProductID
		END
		CLOSE tbl2Cursor
		DEAlLOCATE tbl2Cursor
		ALTER TABLE #tbl2
		DROP COLUMN seq
		SELECT * FROM #tbl2    		

	drop table #tbl2;
End

GO
/****** Object:  StoredProcedure [dbo].[PK_DelPaymentMethod]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_DelPaymentMethod]
	@Method varchar(50)
AS
BEGIN
	DECLARE @Seq int;

	SELECT @Seq = Seq FROM PaymentMethod WHERE Method=@Method
	IF @Seq IS NOT NULL
	BEGIN
		DELETE PaymentMethod WHERE Method=@Method
		UPDATE PaymentMethod set Seq = Seq - 1 WHERE Seq > @Seq
	END
END


GO
/****** Object:  StoredProcedure [dbo].[PK_DoCleanUseless_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_DoCleanUseless_SN]
	@ProductId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--delete from PKProductSNExpire 
	--	where not exists(select b.* from PKReceiveProduct b where b.receiveproductId = PKProductSNExpire.receiveproductId) 
	--	and  not exists(select b.* from PKInboundProduct b where b.ID = PKProductSNExpire.receiveproductId) 
	--	and PKProductSNExpire.productId = @ProductId
	--	and DATEDIFF(n, PKProductSNExpire.createTime,getdate())>5

	----For Inbound cancel status.
	--delete from PKProductSNExpire where exists (select Id from PKInboundProduct where PKInboundProduct.ID = PKProductSNExpire.ReceiveProductId and PKInboundProduct.Status = 'Cancel')

end

GO
/****** Object:  StoredProcedure [dbo].[PK_DoCleanUseless_SN_PoCancel]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_DoCleanUseless_SN_PoCancel]
	@ReceiveId varchar(50),
	@ProductId varchar(50),
	@receiveProductId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--Remove all the SN in the table, which are not received but were set in the database.
	--delete from PKProductSNExpire 
	--    where 
	--	ReceiveProductId = @receiveProductId
	--	and not exists(select * from PKPOReturnProduct where PKPOReturnProduct.receiveProductId = PKProductSNExpire.ReceiveProductId)


end


GO
/****** Object:  StoredProcedure [dbo].[PK_DoDeleteStockTakeById]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_DoDeleteStockTakeById]
	@StockTakeId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @StockTakeStatus varchar(50);
	select @StockTakeStatus = StockTakeStatus from PKStockTake where ID = @StockTakeId;
    If @StockTakeStatus<> 'Completed'
	begin
		delete from PKStockTakeProductInput 
		where exists(
			Select Id from PKStockTakeProduct b where  PKStockTakeProductInput.StockTakeProductID = b.ID
			and b.StockTakeID = @StockTakeId
		);
		delete from PKStockTakeProduct 
		where StockTakeID = @StockTakeId;
		delete from PKStockTake where ID = @StockTakeId;
	End
END

GO
/****** Object:  StoredProcedure [dbo].[PK_DoOutbound_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_DoOutbound_SN]
	@OutboundID varchar(50),
	@OutboundProductID varchar(50),
	@ProductId varchar(50),
	@serialNumbers varchar(4000)
AS
BEGIN
   --************************************--------------
   --*****OUT Bound SN processing,Saving before post the whole outbound action.-------------
   --************************************--------------


	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--****Put the SN number string into a temp table.====================================
	declare @str varchar(2000);
	declare @tablename table(value varchar(200));
	set @str = @serialNumbers + ',';
	set @str = replace(@str,' ','');
	set @str = replace(@str,',,',',');
	Declare @insertStr varchar(50) --
	Declare @newstr varchar(1000) --
	set @insertStr = left(@str,charindex(',',@str)-1)
	set @newstr = stuff(@str,1,charindex(',',@str),'')
	Insert @tableName Values(@insertStr)
	while(len(@newstr)>0)
	begin
		set @insertStr = left(@newstr,charindex(',',@newstr)-1)
		Insert @tableName Values(@insertStr)
		set @newstr = stuff(@newstr,1,charindex(',',@newstr),'')
	end
    --****===============================================================================

	set @serialNumbers = replace(@serialNumbers,',,',',');
	set @serialNumbers = replace(@serialNumbers,',,',',');
	
	--delete from PKProductSNExpire where SOProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set outBoundProductId=@OutboundProductID, Remark2='outbound' where  ProductId = @ProductId and exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set outBoundProductId='' where outBoundProductId =@OutboundProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKSOProduct set SerialNumbers = @serialNumbers where SOID =@SOID and ProductId = @ProductId


	--delete from PKProductSNExpire where SOProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKProductSNExpire set Status='deleting'  where ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKProductSNExpire set Status=''  where ProductId = @ProductId and exists(select value from @tablename where value = PKProductSNExpire.sn)
	
	--update PKProductSNExpire set Status='deleting'  where ProductId = @ProductId and receiveProductId = @OutboundProductID and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKProductSNExpire set Status=''  where ProductId = @ProductId and receiveProductId = @ReceiveProductID and exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKReceiveProduct set ProductRemarks = @serialNumbers where ReceiveProductID =@ReceiveProductID and ProductId = @ProductId

END


GO
/****** Object:  StoredProcedure [dbo].[PK_DoOutboundPost_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_DoOutboundPost_SN]
	--@OutboundID varchar(50),
	@OutboundProductID varchar(50),
	@ProductId varchar(50)
	--@serialNumbers varchar(4000)
AS
BEGIN
   --************************************--------------
   --*****OUT Bound SN Finishing -------------
   --************************************--------------


	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	update PKProductSNExpire set SOProductID=outBoundProductId where  ProductId = @ProductId and outBoundProductId=@OutboundProductID;
	
	Declare @sn varchar(50)
	Declare @snCount varchar(2000)
	set @snCount = '';
	Declare Cur Cursor For Select sn From PKProductSNExpire  where  ProductId = @ProductId and outBoundProductId=@OutboundProductID;  
	Open Cur
	Fetch next From Cur Into @sn
	While @@fetch_status=0     
	Begin
		set @snCount = @snCount + @sn + ','
		Fetch Next From Cur Into @sn
	End   
	Close Cur   
	Deallocate Cur
	update PKOutboundProduct set SerialNumber = @snCount where id = @OutboundProductID;

END


GO
/****** Object:  StoredProcedure [dbo].[PK_DoPoReturn_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_DoPoReturn_SN]
	@ReceiveID varchar(50),
	@ReceiveProductID varchar(50),
	@ProductId varchar(50),
	@serialNumbers varchar(4000),
	@snCount varchar(4000) out
AS
BEGIN
   --************************************--------------
   --*****PO PO PO PO PO PO PO PO PO PO PO-------------
   --************************************--------------
   --*****PO PO PO PO PO PO PO PO PO PO PO-------------
   --************************************--------------
   --*****PO PO PO PO PO PO PO PO PO PO PO-------------
   --************************************--------------

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--****Put the SN number string into a temp table.====================================
	declare @str varchar(2000);
	declare @tablename table(value varchar(200));
	set @str = @serialNumbers + ',';
	set @str = replace(@str,' ','');
	set @str = replace(@str,',,',',');
	Declare @insertStr varchar(50) --
	Declare @newstr varchar(1000) --
	set @insertStr = left(@str,charindex(',',@str)-1)
	set @newstr = stuff(@str,1,charindex(',',@str),'')
	Insert @tableName Values(@insertStr)
	while(len(@newstr)>0)
	begin
		set @insertStr = left(@newstr,charindex(',',@newstr)-1)
		Insert @tableName Values(@insertStr)
		set @newstr = stuff(@newstr,1,charindex(',',@newstr),'')
	end
    --****===============================================================================

	set @serialNumbers = replace(@serialNumbers,',,',',');
	set @serialNumbers = replace(@serialNumbers,',,',',');
	--delete from PKProductSNExpire where SOProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)+
	-- forgot the reason for the first part.
	update PKProductSNExpire set Status='deleting'  
		where ProductId = @ProductId 
		and exists(select receiveId from PKReceiveProduct where PKReceiveProduct.ReceiveProductID = PKProductSNExpire.ReceiveProductId and ReceiveID = @ReceiveID ) 
		and exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set Status=''          
		where ProductId = @ProductId 
		and exists(select receiveId from PKReceiveProduct where PKReceiveProduct.ReceiveProductID = PKProductSNExpire.ReceiveProductId and ReceiveID = @ReceiveID ) 
		and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKReceiveProduct set ProductRemarks = @serialNumbers where ReceiveID =@ReceiveID and ProductId = @ProductId
	

	update PKProductSNExpire set Status='deleting'  
		where ProductId = @ProductId and receiveProductId = @ReceiveProductID 
		and exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set Status=''  
		where ProductId = @ProductId and receiveProductId = @ReceiveProductID 
		and not exists(select value from @tablename where value = PKProductSNExpire.sn)

	--update PKReceiveProduct set ProductRemarks = @serialNumbers where ReceiveProductID =@ReceiveProductID and ProductId = @ProductId
	Declare @sn varchar(50)
	--Declare @snCount varchar(2000)
	set @snCount = '';
	Declare Cur Cursor For Select sn From PKProductSNExpire where ProductId = @ProductId and receiveProductId = @ReceiveProductID  and Status ='deleting' and isnull(SOProductID,'')=''
	Open Cur
		Fetch next From Cur Into @sn
		While @@fetch_status=0     
			Begin
				set @snCount = @snCount + @sn + ','
				Fetch Next From Cur Into @sn
			End   
	Close Cur   
	Deallocate Cur

	--update PKReceiveProduct set ProductRemarks = @snCount where ReceiveProductID =@ReceiveProductID and ProductId = @ProductId

END


GO
/****** Object:  StoredProcedure [dbo].[PK_DoSO_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_DoSO_SN]
	@SOID varchar(50),
	@SOProductID varchar(50),
	@ProductId varchar(50),
	@serialNumbers varchar(4000)
AS
BEGIN
   --************************************--------------
   --*****SO processing. -------------
   --************************************--------------


	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--****Put the SN number string into a temp table.====================================
	declare @str varchar(2000);
	declare @tablename table(value varchar(200));
	set @str = @serialNumbers + ',';
	set @str = replace(@str,' ','');
	set @str = replace(@str,',,',',');
	Declare @insertStr varchar(50) --
	Declare @newstr varchar(1000) --
	set @insertStr = left(@str,charindex(',',@str)-1)
	set @newstr = stuff(@str,1,charindex(',',@str),'')
	Insert @tableName Values(@insertStr)
	while(len(@newstr)>0)
	begin
		set @insertStr = left(@newstr,charindex(',',@newstr)-1)
		Insert @tableName Values(@insertStr)
		set @newstr = stuff(@newstr,1,charindex(',',@newstr),'')
	end
    --****===============================================================================

	set @serialNumbers = replace(@serialNumbers,',,',',');
	set @serialNumbers = replace(@serialNumbers,',,',',');
	--delete from PKProductSNExpire where SOProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKProductSNExpire set SOProductId=@SOProductID, Remark2='SO' where  ProductId = @ProductId and exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKProductSNExpire set SOProductId='' where SOProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set outBoundProductId=@SOProductID, Remark2='SO' where  ProductId = @ProductId and exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set outBoundProductId='',SOProductID=''		  where outBoundProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set outBoundProductId='',SOProductID=''		  where SOProductID =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	
	update PKSOProduct set SerialNumbers = @serialNumbers where SOProductID = @SOProductID

END


GO
/****** Object:  StoredProcedure [dbo].[PK_DoSOPost_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_DoSOPost_SN]
	--@OutboundID varchar(50),
	@SOProductID varchar(50),
	@ProductId varchar(50)
	--@serialNumbers varchar(4000)
AS
BEGIN
   --************************************--------------
   --*****OUT Bound SN Finishing -------------
   --************************************--------------


	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	update PKProductSNExpire set SOProductID=outBoundProductId where  ProductId = @ProductId and outBoundProductId=@SOProductID;
	update PKProductSNExpire set outBoundProductId=''		   where  ProductId = @ProductId and outBoundProductId=@SOProductID;

END


GO
/****** Object:  StoredProcedure [dbo].[PK_DoSoReturn_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_DoSoReturn_SN]
	@SOID varchar(50),
	@SOProductID varchar(50),
	@ProductId varchar(50),
	@serialNumbers varchar(2000)
AS
BEGIN

   --************************************--------------
   --*****This is SO!!!!!!!!!------------
   --*****SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS------------
   --*****OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO------------
   --************************************--------------


	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--****Put the SN number string into a temp table.====================================
	declare @str varchar(2000);
	declare @tablename table(value varchar(200));
	set @str = @serialNumbers + ',';
	set @str = replace(@str,' ','');
	set @str = replace(@str,',,',',');
	Declare @insertStr varchar(50) --
	Declare @newstr varchar(1000) --
	set @insertStr = left(@str,charindex(',',@str)-1)
	set @newstr = stuff(@str,1,charindex(',',@str),'')
	Insert @tableName Values(@insertStr)
	while(len(@newstr)>0)
	begin
		set @insertStr = left(@newstr,charindex(',',@newstr)-1)
		Insert @tableName Values(@insertStr)
		set @newstr = stuff(@newstr,1,charindex(',',@newstr),'')
	end
    --****===============================================================================

	set @serialNumbers = replace(@serialNumbers,',,',',');
	set @serialNumbers = replace(@serialNumbers,',,',',');
	--delete from PKProductSNExpire where SOProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKProductSNExpire set SOProductId=@SOProductID, Remark2='SO' where  ProductId = @ProductId and exists(select value from @tablename where value = PKProductSNExpire.sn)
	--update PKProductSNExpire set SOProductId='' where SOProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set outBoundProductId=''                         where outBoundProductId =@SOProductID and ProductId = @ProductId and not exists(select value from @tablename where value = PKProductSNExpire.sn)
	update PKProductSNExpire set outBoundProductId=@SOProductID, Remark2='SO' where										ProductId = @ProductId and exists(select value from @tablename where value = PKProductSNExpire.sn)
	

	Declare @sn varchar(50)
	Declare @snCount varchar(2000)
	set @snCount = '';
	Declare Cur Cursor For Select sn From PKProductSNExpire where SOProductID = @SOProductID and outBoundProductId = @SOProductID   
	Open Cur
	Fetch next From Cur Into @sn
	While @@fetch_status=0     
	Begin
		set @snCount = @snCount + @sn + ','
		Fetch Next From Cur Into @sn
	End   
	Close Cur   
	Deallocate Cur

	update PKSOreturnProduct set remarks = @snCount where SOProductID = @SOProductID

END


GO
/****** Object:  StoredProcedure [dbo].[PK_DoSoReturnPost_SN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_DoSoReturnPost_SN]
	@SOProductID varchar(50),
	@SOReturnID varchar(50),
	@ProductId varchar(50)
AS
BEGIN

   --************************************--------------
   --*****This is SO!!!!!!!!!------------
   --*****SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS------------
   --*****OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO------------
   --************************************--------------


	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	
	Declare @sn varchar(50)
	Declare @snCount varchar(2000)
	set @snCount = '';
	Declare Cur Cursor For Select sn From PKProductSNExpire  where  ProductId = @ProductId and outBoundProductId=@SOProductID;  
	Open Cur
	Fetch next From Cur Into @sn
	While @@fetch_status=0     
	Begin
		set @snCount = @snCount + @sn + ','
		Fetch Next From Cur Into @sn
	End   
	Close Cur   
	Deallocate Cur
	update PKProductSNExpire set SOProductID='',outBoundProductId='' where  ProductId = @ProductId and outBoundProductId=@SOProductID;
	update PKSOReturnProduct set sn = @snCount where SOProductID = @SOProductID and SOReturnID=@SOReturnID;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_Get_Outbound_BySOID_ForPrepaid]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_Get_Outbound_BySOID_ForPrepaid]
	@SOID varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT ID
      ,LocationID
      ,SOID
      ,OrderID
      ,SoldTTitle
      ,SoldTContact
      ,SoldTAddress
      ,SoldTTEL
      ,SoldTFAX
      ,Terms
      ,InvoiceNo
      ,OutboundDate
      ,OutboundBy
      ,SubTotal
      ,TotalTAX
      ,TotalAmount
      ,Status
      ,Remarks
      ,TotalCost
      ,seq
  FROM PKOutbound
  where SOID = @SOID
  order by seq desc


END


GO
/****** Object:  StoredProcedure [dbo].[PK_Get_SOProduct_BySOID_ForPrepaid]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_Get_SOProduct_BySOID_ForPrepaid]
	@SOID varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	select POBP.* 
	into #tbl1
	from PKOutboundProduct POBP 
		inner join PKOutbound POB on POBP.OutboundID = POB.ID 
		where POB.SOID = @SOID;
	
	select productId, sum(orderQTy) as orderQty 
	into #tbl2
	from #tbl1
	group by productId
	;


	select isnull(t2.OrderQty,0) as outedQty, psp.* 
	from PKSOProduct psp
		left outer join #tbl2 t2 on psp.ProductID = t2.productId
	where psp.SOID = @SOID
	order by psp.seqOrder 


	drop table #tbl1;
	drop table #tbl2;

END


GO
/****** Object:  StoredProcedure [dbo].[Pk_GetAllBaseProductByCategoryId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetAllBaseProductByCategoryId]
	@CategoryId varchar(50),
	@ExceptProductId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	select distinct
		p.plu,
		p.Barcode,
		p.ID,
		p.name1 as productName
	from PKProduct P
	inner join PKMapping PM on pm.BaseProductID = p.ID
	where p.CategoryID = @CategoryId
	and p.id <> @ExceptProductId
	union

	select distinct
		p.plu,
		p.Barcode,
		p.ID,
		p.name1 as productName
	from PKProduct P
	
	where p.CategoryID = @CategoryId
		and p.id <> @ExceptProductId
		and not exists(select * from PKMapping pm where pm.BaseProductID = p.id)
		and not exists(select * from PKMapping pm where pm.ProductID = p.id)


END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetAveAndLatestCostByLastInboundProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetAveAndLatestCostByLastInboundProduct]
	@ProductId varchar(50),
	@LastQty decimal(18,2),
	@LastCost decimal(18,2)
AS
BEGIN 
    DECLARE @BaseProductId VARCHAR(50); 
    DECLARE @count INT; 
    DECLARE @Capacity DECIMAL(18, 4); 
    DECLARE @BaseAveCost DECIMAL(18, 4); 
    DECLARE @ProductAveCost DECIMAL(18, 4); 
	DECLARE @ProductQty DECIMAL(18, 4); 
          DECLARE @ProductNewValue DECIMAL(18, 4); 
          DECLARE @ProductNewQty DECIMAL(18, 4); 

    SELECT @count = Count(*) 
    FROM   pkmapping 
    WHERE  productid = @productId; 

    IF @count = 0 
      BEGIN 
          SELECT @ProductQty = dbo.Pk_funcgetallfamilyqtyintooneprod(@ProductId, ''); 
		  
		  SELECT @BaseAveCost = averagecost FROM   pkinventory WHERE  productid = @productId; 


		  SET @ProductNewValue = @ProductQty * @BaseAveCost + @LastCost * @LastQty; 
          SET @ProductNewQty = @ProductQty + @LastQty; 

		  IF @ProductNewQty = 0 
            BEGIN 
                SET @ProductNewQty = 1; 
            END 

          SET @ProductAveCost = @ProductNewValue / @ProductNewQty; 

          SELECT @ProductAveCost AS newAveCost; 
      END 
    ELSE 
      BEGIN 
          SELECT @BaseProductId = baseproductid 
          FROM   pkmapping 
          WHERE  productid = @productId; 

          SELECT @BaseAveCost = averagecost 
          FROM   pkinventory 
          WHERE  productid = @BaseProductId; 

          SELECT @Capacity = dbo.Pk_funcgetcapacitybyprodid(@productId); 

          SET @ProductAveCost = @BaseAveCost * @Capacity; 
          SET @ProductAveCost=Isnull(@ProductAveCost, 0); 

          

          SELECT @ProductQty = dbo.Pk_funcgetallfamilyqtyintooneprod(@ProductId, ''); 



          SET @ProductNewValue = @ProductQty * @ProductAveCost + 
                                 @LastCost * @LastQty; 
          SET @ProductNewQty = @ProductQty + @LastQty; 

          IF @ProductNewQty = 0 
            BEGIN 
                SET @ProductNewQty = 1; 
            END 

          SET @ProductAveCost = @ProductNewValue / @ProductNewQty; 

          SELECT @ProductAveCost AS newAveCost; 
      END 
--declare @wholeCostInInventory decimal(18,2); 
--declare @wholeQtyInInventory decimal(18,2); 
--declare @newCostInInventory decimal(18,2); 
--declare @newQtyInInventory decimal(18,2); 
--declare @HeaderQuarterPrice decimal(18,2); 
--select @HeaderQuarterPrice = a.AverageCost from PKInventory a 
--    inner join PKLocation b on a.LocationID = b.LocationID 
--    where a.ProductID = @ProductId and b.IsHeadquarter = 1; 
----select @wholeQtyInInventory = sum(isnull(qty,0)) from PKInventory where ProductID = @ProductId;
--select @wholeQtyInInventory = dbo.PK_FuncGetAllFamilyQtyIntoOneProd(@ProductId,''); 
--set @wholeQtyInInventory = isnull(@wholeQtyInInventory,0); 
----select @wholeCostInInventory = sum(isnull(qty,0)*isnull(@HeaderQuarterPrice,isnull(AverageCost,0))) from PKInventory where ProductID = @ProductId;
--set @wholeCostInInventory = @wholeQtyInInventory * @HeaderQuarterPrice; 
--set @wholeCostInInventory = isnull(@wholeCostInInventory,0); 
--set @newQtyInInventory = @wholeQtyInInventory + @LastQty; 
--set @newQtyInInventory = isnull(@newQtyInInventory,1); 
--set @newCostInInventory = (@wholeCostInInventory + @LastCost*@LastQty)/@newQtyInInventory; 
--select @newCostInInventory as newAveCost; 
END 






GO
/****** Object:  StoredProcedure [dbo].[PK_GetAveAndLatestCostFromInventory]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetAveAndLatestCostFromInventory]
	@productId varchar(50)
AS
BEGIN
	declare @id varchar(50)
	declare @AverageCost decimal(8,2)
	declare @LatestCost decimal(8,2)

	set @id=''
	set @AverageCost = 0
	set @LatestCost = 0

	select ID
      ,LocationID
      ,ProductID
      ,Qty
      ,Unit
      ,LatestCost
      ,AverageCost
      ,CreateTime
      ,UpdateTime
      ,Creater
      ,Updater
	into #tbl1
	from PKInventory
	where ProductID = @productId

	select @id = isnull(id,'') from #tbl1 a 
	inner join PKLocation b 
		on a.LocationID = b.LocationID
	where b.IsHeadquarter = 1

	if @id = ''
		begin
			select @AverageCost = max(AverageCost) from #tbl1
			select @LatestCost = max(LatestCost) from #tbl1
		end
	else
		begin
			select @AverageCost = AverageCost,@LatestCost = LatestCost from #tbl1 where ID = @id
		end

	select isnull(@AverageCost,0) as averageCost, isnull(@LatestCost,0) as latestCost

	drop table #tbl1;
End


GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingContentByTransferId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookingContentByTransferId] 
	@transferId VARCHAR(50)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	--**************************************************************************
	-----This procedure comes from PK_GetOwnPackage with similiar Logic.---------
	--**************************************************************************

	DECLARE @tempString NVARCHAR(100); 
	DECLARE @PurchaseId uniqueidentifier 
	DECLARE @count int 

	SET @tempString = N'1234567891012345678910123456789101234567891012345678910'; 
	SET @tempString = @tempString + @tempString; 

	select ppp.*, @tempString as IfBookedAll, @tempString as IfBookedAny into #tbl1 from PKPurchasePackage ppp 
	where ppp.transferId = @transferId and ppp.itemType = 'B';

	update #tbl1 set IfBookedAll = '', IfBookedAny = '';

	DECLARE t_cursor CURSOR FOR SELECT PurchaseId FROM #tbl1

	OPEN t_cursor
	FETCH next FROM t_cursor INTO @PurchaseId
	WHILE @@fetch_status = 0
	BEGIN 
		select @count = Count(PurchaseItemId) from PKPurchaseItem where  PurchaseId = @PurchaseId and ISNULL(resourceTimeFrom, '') = '';
		if @count = 0
		begin
			update #tbl1 set IfBookedAll = 'true' where PurchaseId = @PurchaseId 
		end 
		select @count = Count(PurchaseItemId) from PKPurchaseItem where  PurchaseId = @PurchaseId and ISNULL(resourceTimeFrom, '') <> '';
		if @count > 0
		begin
			update #tbl1 set IfBookedAny = 'true' where PurchaseId = @PurchaseId
		end 
		FETCH next FROM t_cursor INTO @PurchaseId
	END 
	CLOSE t_cursor 
	DEALLOCATE t_cursor 

	select PPm.Name1 + ' ' + PPm.Name2 + '[' + CONVERT(varchar(12), ppp.createdate, 102 ) + ']' as Name, Substring(PPm.name1, 0, 20) as name1, CONVERT(varchar(12), ppp.createdate, 102) as createDate, 
	ppp.createdate as originalCreateDate, PPP.amount AS Price, ppp.purchaseId, ppp.IfBookedAll, ppp.IfBookedAny, 'package' as packageType, ppp.transferId 
	into #tbl2 from pkPromotion PPm 
	inner join #tbl1 PPP on PPP.BomOrProductId = PPM.Id 
	inner join PKPromotionPrice Pprice on Pprice.promotionid = PPM.Id 
	inner join PKPromotionProduct PMP on pmp.PromotionID = PPm.ID 
	INNER JOIN PKProduct ON PKProduct.ID = PMP.ProductID 

      --order by ppp.createdate desc 
	select pp.name1 + ' ' + pp.Name2 + '[' + CONVERT(varchar(12), PPI.createdate, 102 ) + ']' as Name, Substring(pp.name1, 0, 20) as name1, CONVERT(varchar(12), PPI.createdate, 102) as createDate,
	ppi.CreateDate as originalCreateDate, pkPP.amount as price, ppi.PurchaseItemId as PurchaseId, case ISNULL(resourceTimeFrom, '') when '' then 'false' else 'true' end as IfBookedAll, 
	case ISNULL(resourceTimeFrom, '') when '' then 'false' else 'true' end as IfBookedAny, 'product' as packageType, isnull(pkpp.transferId, '') as transferId 
	into #tbl3 from PKPurchaseItem PPI 
	inner join PKProduct PP on ppi.ProductId = pp.ID
	inner join PKPrice PPr on ppr.ProductID = pp.ID 
	inner join PKPurchasePackage pkPP on pkpp.PurchaseId = ppi.PurchaseItemId 
	where  pkpp.transferId = @transferId and packagetype = 'product'; 

	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl5 FROM PKPurchasePackagePayment 
	GROUP BY PaymentOrderID, Balance

	SELECT PKPurchasePackagePaymentItem.transferId 
	INTO #tbl6 FROM #tbl5 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)

	-----------------------------------------------------------------------
	SELECT PKPrepaidPackage.Name1 + ' ' + PKPrepaidPackage.Name2 +'[' + CONVERT(varchar(12), PKPrepaidPackageTransaction.CreateTime, 102 ) + ']' as Name, SUBSTRING(PKPrepaidPackage.Name1, 0, 20) as name1, 
	CONVERT(varchar(12), PKPrepaidPackageTransaction.CreateTime, 102 ) as createDate, PKPrepaidPackageTransaction.CreateTime AS originalCreateDate, PKPrepaidPackageTransaction.Price, 
	PKPrepaidPackageTransaction.ID, ISNULL(IfBookedAll, '') AS IfBookedAll, ISNULL(IfBookedAny, '') AS IfBookedAny, 'prepaidPackage' as packageType, 
	isnull(PKPrepaidPackageTransaction.transferId,'') as transferId 
	into #tbl4 FROM PKPrepaidPackageTransaction 
	INNER JOIN PKPrepaidPackage ON PKPrepaidPackage.ID = PKPrepaidPackageTransaction.PrepaidPackageID
	LEFT JOIN (SELECT transferId, 'true' AS IfBookedAll, '' AS IfBookedAny FROM #tbl6 GROUP BY transferId) AS payment ON payment.transferId = PKPrepaidPackageTransaction.transferId
	WHERE PKPrepaidPackageTransaction.transferId = @transferId and PKPrepaidPackageTransaction.Type = 'Purchase'

   select [name], transferId, count(*) as countName
   into #tbl4A
   from #tbl4
   group by name, transferid
   ;

   select [name], max(ID) as ID,transferId
   into #tbl4B
   from #tbl4
   group by name, transferid
   ;

   select tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    t4.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    t4.createDate,
    t4.originalCreateDate,
    t4.Price,
    t4.ID,
    t4.IfBookedAll,
    t4.IfBookedAny,
    t4.packageType,
    t4.transferId
   into #tbl4c
   from #tbl4b tb
   inner join #tbl4a ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tbl4 t4 on t4.id = tb.ID
   -------------------------------------------------------------------------------------
	SELECT PDP.Name1 + ' ' + PDP.Name2 +'[' + CONVERT(varchar(12), PDT.CreateTime, 102 ) + ']' as Name, 
		SUBSTRING(PDP.Name1, 0, 20) as name1, 
		CONVERT(varchar(12), PDT.CreateTime, 102 ) as createDate, 
		PDT.CreateTime AS originalCreateDate, 
		isnull(PDT.Price,0) as Price, 
		PDT.ID, ISNULL(IfBookedAll, '') AS IfBookedAll, 
		ISNULL(IfBookedAny, '') AS IfBookedAny, 
		'depositPackage' as packageType, 
		isnull(PDT.transferId,'') as transferId 
		into #tblDeposit 
	FROM PKDepositPackageTransaction PDT 
	INNER JOIN PKDepositPackage PDP ON PDP.ID = PDT.PrepaidPackageID
	LEFT JOIN (SELECT transferId, 'true' AS IfBookedAll, '' AS IfBookedAny FROM #tbl6 GROUP BY transferId) AS payment ON payment.transferId = PDT.transferId
	WHERE PDT.transferId = @transferId and PDT.Type = 'Purchase'

   select [name], transferId, count(*) as countName
   into #tblDepositA
   from #tblDeposit
   group by name, transferid
   ;

   select [name], max(ID) as ID,transferId
   into #tblDepositB
   from #tblDeposit
   group by name, transferid
   ;

   select tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    td.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    td.createDate,
    td.originalCreateDate,
    td.Price,
    td.ID,
    td.IfBookedAll,
    td.IfBookedAny,
    td.packageType,
    td.transferId
   into #tblDepositc
   from #tblDepositb tb
   inner join #tblDeposita ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tblDeposit tD on td.id = tb.ID
   -------------------------------------------------------------------------------------
	SELECT PDP.Name1 + ' ' + PDP.Name2 +'[' + CONVERT(varchar(12), PDT.CreateTime, 102 ) + ']' as Name, 
		SUBSTRING(PDP.Name1, 0, 20) as name1, 
		CONVERT(varchar(12), PDT.CreateTime, 102 ) as createDate, 
		PDT.CreateTime AS originalCreateDate, 
		isnull(PDT.Price,0) as Price, 
		PDT.ID, ISNULL(IfBookedAll, '') AS IfBookedAll, 
		ISNULL(IfBookedAny, '') AS IfBookedAny, 
		'depositPackage' as packageType, 
		isnull(PDT.transferId,'') as transferId 
		into #tblGiftCard
	FROM PKGiftCardTransaction PDT 
	INNER JOIN PKGiftCard PDP ON PDP.ID = PDT.GiftCardId
	LEFT JOIN (SELECT transferId, 'true' AS IfBookedAll, '' AS IfBookedAny FROM #tbl6 GROUP BY transferId) AS payment ON payment.transferId = PDT.transferId
	WHERE PDT.transferId = @transferId and PDT.Type = 'Purchase'

   select [name], transferId, count(*) as countName
   into #tblGiftCardA
   from #tblGiftCard
   group by name, transferid
   ;

   select [name], max(ID) as ID,transferId
   into #tblGiftCardB
   from #tblGiftCard
   group by name, transferid
   ;

   select tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    td.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    td.createDate,
    td.originalCreateDate,
    td.Price,
    td.ID,
    td.IfBookedAll,
    td.IfBookedAny,
    td.packageType,
    td.transferId
   into #tblGiftCardc
   from #tblGiftCardb tb
   inner join #tblGiftCarda ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tblGiftCard tD on td.id = tb.ID
   -------------------------------------------------------------------------------------

	select * from 
		(
			select * from #tbl2 
			union 
            select * from #tbl3 
            union 
            select * from #tbl4c
            union 
            select * from #tblDepositc
            union 
            select * from #tblGiftCardc
		) a order  by originalCreateDate desc 

	drop table #tbl1; 
    drop table #tbl2; 
    drop table #tbl3; 
    drop table #tbl4;
	drop table #tbl5;
	drop table #tbl6;
	drop table #tbl4A;
	drop table #tbl4B;
	drop table #tbl4c;
	drop table #tblDeposit;
	drop table #tblDepositA;
	drop table #tblDepositB;
	drop table #tblDepositc;
	drop table #tblGiftCard;
	drop table #tblGiftCardA;
	drop table #tblGiftCardB;
	drop table #tblGiftCardc;

END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingCustomerList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookingCustomerList] 
	@ResourceId VARCHAR(50), 
	@ResourceDate VARCHAR(50)
AS 
BEGIN 
    -- SET NOCOUNT ON added to prevent extra result sets from  
    -- interfering with SELECT statements.  
    SET nocount ON; 

	DECLARE @isMultiCard varchar(50);
	SELECT @isMultiCard = ISNULL(Value, 'false') FROM PKSetting WHERE FieldName = 'isBookingMultiCard';

	SELECT PKPurchaseItemModifier.PurchaseItemId, PKModifierItem.Name1 INTO #tbl1 FROM PKPurchaseItemModifier 
	LEFT JOIN PKModifierItem ON PKModifierItem.ID = PKPurchaseItemModifier.ModifierItemId 
	ORDER BY PKModifierItem.ModifierGroupID

	SELECT PurchaseItemId, [Value]=stuff((  
	SELECT ', '+[Name1] FROM #tbl1 as Temp2 WHERE Temp2.PurchaseItemId = Temp1.PurchaseItemId FOR XML PATH('')),1,2,'') INTO #tbl2 FROM #tbl1 AS Temp1  
	GROUP BY PurchaseItemId 

	IF LOWER(@isMultiCard) = 'true'
	BEGIN
		SELECT PKPurchaseItem.PurchaseId AS ID, PKPurchaseItem.CardHolder AS Name, ISNULL(Customer.Phone, '') AS Cell, ISNULL(PurchaseModifiers.Value, '') AS Modifiers FROM PKPurchaseItem
			INNER JOIN CustomerCard ON (CustomerCard.CardNo = PKPurchaseItem.CardNumber)
			INNER JOIN Customer ON (Customer.ID = CustomerCard.CustomerID)
			LEFT JOIN #tbl2 AS PurchaseModifiers on PurchaseModifiers.PurchaseItemId = PKPurchaseItem.PurchaseItemId
			WHERE ((PKPurchaseItem.Status = 'Active') AND (PKPurchaseItem.ResourceDate IS NOT NULL) AND (PKPurchaseItem.ResourceId = @ResourceId) AND (PKPurchaseItem.ResourceDate = @ResourceDate))
	END
	ELSE
	BEGIN
		SELECT PKPurchaseItem.PurchaseId AS ID, PKPurchaseItem.CardHolder AS Name, ISNULL(Customer.Phone, '') AS Cell, ISNULL(PurchaseModifiers.Value, '') AS Modifiers FROM PKPurchaseItem
			INNER JOIN Customer ON (Customer.CustomerNo = PKPurchaseItem.CardNumber)
			LEFT JOIN #tbl2 AS PurchaseModifiers on PurchaseModifiers.PurchaseItemId = PKPurchaseItem.PurchaseItemId
			WHERE ((PKPurchaseItem.Status = 'Active') AND (PKPurchaseItem.ResourceDate IS NOT NULL) AND (PKPurchaseItem.ResourceId = @ResourceId) AND (PKPurchaseItem.ResourceDate = @ResourceDate))
	END

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingListAll]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetBookingListAll]
	@locationId varchar(50),
	@dateStart varchar(50),
	@dateEnd varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	declare 	@timeStart datetime
	declare @timeEnd datetime

	set @timeStart = cast(@dateStart + ' 00:01' as datetime)
	set @timeEnd =  cast(@dateEnd + ' 23:59' as datetime) 

	DECLARE @isMultiCard varchar(50);
	SELECT @isMultiCard = ISNULL(Value, 'false') FROM PKSetting WHERE FieldName = 'isBookingMultiCard';
	----------------------------------------------------
	DECLARE @SuperCustomerId varchar(50);
	SELECT @SuperCustomerId = ISNULL(Value, '') FROM PKSetting WHERE FieldName = 'SuperVIPIdForWalkIn';
	----------------------------------------------------

	SELECT PKPurchasePackageOrder.transferId, PKLocation.LocationName AS Location INTO #tbl1 FROM PKPurchasePackageOrder
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId

	------------------
	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl2 
	FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance
	------------------
	SELECT PKPurchasePackagePaymentItem.transferId 
	INTO #tbl3 
	FROM #tbl2 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)
	--------------------
	 select 
	 c.ID,
	 c.FirstName,
	 c.LastName,
	 c.phone,
	 c.IDCardNo,
	 c.Gender,
	 cc.CardNo
	 into #tblCustomer
	 
	 from Customer C
	 inner join CustomerCard CC on CC.CustomerID = c.ID
	--------------------
	SELECT PKPurchaseItemModifier.PurchaseItemId, PKModifierItem.Name1 
	INTO #tbl4 
	FROM PKPurchaseItemModifier 
	LEFT JOIN PKModifierItem ON PKModifierItem.ID = PKPurchaseItemModifier.ModifierItemId 
	ORDER BY PKModifierItem.ModifierGroupID
	----------------------------------------------------
	SELECT PurchaseItemId, [Value]=stuff((  
	SELECT distinct ', '+[Name1] FROM #tbl4 as Temp2 WHERE Temp2.PurchaseItemId = Temp1.PurchaseItemId FOR XML PATH('')),1,2,'') 
	INTO #tbl5 
	FROM #tbl4 AS Temp1  
	GROUP BY PurchaseItemId 
	----------------------------------------------------
	SELECT PKPurchasePackage.PurchaseId, PKLocation.LocationName 
	INTO #tbl6 
	FROM PKPurchasePackage 
	LEFT JOIN PKPurchasePackageOrder ON PKPurchasePackageOrder.transferId = PKPurchasePackage.transferId
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId
	----------------------------------------------------
	select * from (

		SELECT 
			PKPrepaidPackageTransaction.ID AS ID, 
			PKPrepaidPackageTransaction.CreateTime AS TimeDate, 
			CONVERT(VARCHAR(100), PKPrepaidPackageTransaction.CreateTime, 23) as thisDate,
			CONVERT(VARCHAR(100), PKPrepaidPackageTransaction.CreateTime, 24) as thisTime,
			PKPrepaidPackageTransaction.CardNumber AS Card, 
			PKPrepaidPackageTransaction.CardHolders AS Customer, 
			tc.Gender,
			PKPrepaidPackageTransaction.Price, 
			PKPrepaidPackageTransaction.Deposit, 
			PKPrepaidPackage.Name1 + ' ' + PKPrepaidPackage.Name2 AS Product,
			PKPrepaidPackageTransaction.CreateBy, 
			Location.Location,
			PU.UserName as Sales, 
			'' as SalesCommission,
			'' as CreateByCommission,
			'purchase' as dataType,
			'prepaid' as dataType2,
			'' as [Type]
		FROM PKPrepaidPackageTransaction
		INNER JOIN PKPrepaidPackage ON PKPrepaidPackage.ID = PKPrepaidPackageTransaction.PrepaidPackageID
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKPrepaidPackageTransaction.transferId
		INNER JOIN #tbl3 AS Payment ON payment.transferId = PKPrepaidPackageTransaction.transferId
		inner join #tblCustomer Tc on tc.CardNo = PKPrepaidPackageTransaction.CardNumber
		left outer join PKUsers PU on pu.EmployeeID = PKPrepaidPackageTransaction.Sales
		UNION
		(
			SELECT 
				PKGiftCardTransaction.ID AS ID, 
				PKGiftCardTransaction.CreateTime AS TimeDate, 
				CONVERT(VARCHAR(100), PKGiftCardTransaction.CreateTime, 23) as thisDate,
				CONVERT(VARCHAR(100), PKGiftCardTransaction.CreateTime, 24) as thisTime,			
				PKGiftCardTransaction.CardNumber AS Card, 
				PKGiftCardTransaction.CardHolders AS Customer, 
				tc.Gender,
				PKGiftCardTransaction.Price, 
				PKGiftCardTransaction.Deposit, 
				PKGiftCard.Name1 + ' ' + PKGiftCard.Name2 AS Product,
				PKGiftCardTransaction.CreateBy, 
				Location.Location ,
				PU.UserName as Sales, 
				'' as SalesCommission,
				'' as CreateByCommission,
			'purchase' as dataType,
			'giftcard' as dataType2,
			'' as [Type]
			FROM PKGiftCardTransaction
			INNER JOIN PKGiftCard ON PKGiftCard.ID = PKGiftCardTransaction.GiftCardId
			INNER JOIN #tbl1 AS Location ON Location.transferId = PKGiftCardTransaction.transferId
			INNER JOIN #tbl3 AS Payment ON payment.transferId = PKGiftCardTransaction.transferId
			inner join #tblCustomer Tc on tc.CardNo = PKGiftCardTransaction.CardNumber
			left outer join PKUsers PU on pu.EmployeeID = PKGiftCardTransaction.Sales
		)
		UNION
		(
			SELECT 
				PKDepositPackageTransaction.ID AS ID, 
				PKDepositPackageTransaction.CreateTime AS TimeDate, 
				CONVERT(VARCHAR(100), PKDepositPackageTransaction.CreateTime, 23) as thisDate,
				CONVERT(VARCHAR(100), PKDepositPackageTransaction.CreateTime, 24) as thisTime,			
				PKDepositPackageTransaction.CardNumber AS Card, 
				PKDepositPackageTransaction.CardHolders AS Customer, 
				tc.Gender,
				PKDepositPackageTransaction.Price,
				 PKDepositPackageTransaction.Deposit, 
				 PKDepositPackage.Name1 + ' ' + PKDepositPackage.Name2 AS Product,
				 PKDepositPackageTransaction.CreateBy, 
				 Location.Location ,
				 PU.UserName as Sales, 
				 '' as SalesCommission,
				 '' as CreateByCommission,
			'purchase' as dataType,
			'deposit' as dataType2,
			'' as [Type]
			FROM PKDepositPackageTransaction
			INNER JOIN PKDepositPackage ON PKDepositPackage.ID = PKDepositPackageTransaction.PrepaidPackageID
			INNER JOIN #tbl1 AS Location ON Location.transferId = PKDepositPackageTransaction.transferId
			INNER JOIN #tbl3 AS Payment ON payment.transferId = PKDepositPackageTransaction.transferId
			inner join #tblCustomer Tc on tc.CardNo = PKDepositPackageTransaction.CardNumber
			left outer join PKUsers PU on pu.EmployeeID = PKDepositPackageTransaction.Sales
			where PKDepositPackageTransaction.Status = 'Active'
		) 
		---------------------------------------------------------------------------
		UNION
		(
			SELECT distinct 
				PKPurchasePackage.PurchaseId AS ID, 
				CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, 
				CONVERT(VARCHAR(100), PKPurchasePackage.CreateDate, 23) as thisDate,
				CONVERT(VARCHAR(100), PKPurchasePackage.CreateDate, 24) as thisTime,			
				PKPurchasePackage.CardNumber AS Card,  
				PKPurchasePackage.CardHolders AS Customer, 
				tc.Gender,
				PKPurchasePackage.amount AS Price, 
				null as deposit,
				(CASE WHEN ISNULL(PKPromotion.Name2, '') = '' THEN PKPromotion.Name1 ELSE (PKPromotion.Name1 + ' / ' + PKPromotion.Name2 ) END) AS Product,
				createdBy ,
				Location.Location,
				PU.UserName as Sales, 
				'' as SalesCommission,
				'' as CreateByCommission,
			'Expense' as dataType,
			'package' as dataType2,
			'' as [Type]
			FROM PKPurchasePackage
			INNER JOIN PKPromotion ON PKPromotion.ID = PKPurchasePackage.BomOrProductID
			INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
			INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
			inner join #tblCustomer Tc on tc.CardNo = PKPurchasePackage.CardNumber
			left outer join PKUsers PU on pu.EmployeeID = PKPurchasePackage.booker
			WHERE itemType = 'B' and PKPurchasePackage.Status = 'Active'
		)
		UNION
		(
			SELECT 
				PKPurchasePackage.PurchaseId AS ID, 
				CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, 
				CONVERT(VARCHAR(100), PKPurchasePackage.CreateDate, 23) as thisDate,
				CONVERT(VARCHAR(100), PKPurchasePackage.CreateDate, 24) as thisTime,			
				PKPurchasePackage.CardNumber AS Card,  
				PKPurchasePackage.CardHolders AS Customer, 
				tc.Gender,
				PKPurchasePackage.amount AS Price, 
				null as deposit,
				(CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2 ) END) AS Product,
				createdBy , 
				Location.Location,
				PU.UserName as Sales, 
				'' as SalesCommission,
				'' as CreateByCommission,
			'Expense' as dataType,
			'product' as dataType2,
			'' as [Type]
			FROM PKPurchasePackage
			INNER JOIN PKProduct ON PKProduct.ID = PKPurchasePackage.BomOrProductID
			INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
			INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
			inner join #tblCustomer Tc on tc.CardNo = PKPurchasePackage.CardNumber
			left outer join PKUsers PU on pu.EmployeeID = PKPurchasePackage.booker
			WHERE itemType = 'P' and PKPurchasePackage.Status = 'Active'

		) 
		--------------------------------------------------------------
		Union
		(
			SELECT 
				PKPurchaseItem.PurchaseItemId AS ID, 
				CAST(PKPurchaseItem.ResourceDate + ' 02:00' AS datetime) AS TimeDate, 
				CONVERT(VARCHAR(100), PKPurchaseItem.ResourceDate, 23) as thisDate,
				CONVERT(VARCHAR(100), PKPurchaseItem.ResourceDate + ' ' + PKPurchaseItem.ResourceTimeFrom, 24) as thisTime,	
				PKPurchaseItem.CardNumber AS Card,  
				PKPurchaseItem.CardHolder AS Customer, 
				tc.Gender,
				null as price,
				null as deposit,			
				(CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2) END) AS Product, 
				PKPurchaseItem.createdBy , 
				Location.LocationName AS Location,
				pu.UserName as Sales,
				'' as SalesCommission,
				'' as CreateByCommission,
				--case lower(TC.Gender) when 'male' then 'M' when 'female' then 'F' else '' end as CustomerGender,
				-----
				'Book' as dataType,
				'' as dataType2,
				case cast(TC.id as varchar(50)) when @SuperCustomerId then 'Walk-In' else
					case lower(PKPurchaseItem.forceSales) when 'true' then 'Appointment' else 'Random' end
				end as [Type]
			FROM PKPurchaseItem
			INNER JOIN PKProduct ON PKProduct.ID = PKPurchaseItem.ProductId INNER JOIN PKCategory ON PKCategory.ID = PKProduct.CategoryID
			LEFT JOIN #tbl5 AS PurchaseModifiers on PurchaseModifiers.PurchaseItemId = PKPurchaseItem.PurchaseItemId
			INNER JOIN #tbl6 AS Location ON Location.PurchaseId = PKPurchaseItem.PurchaseId
			INNER JOIN #tblCustomer TC on tc.CardNo = PKPurchaseItem.CardNumber
			left outer join PKUsers PU on pu.EmployeeID = PKPurchaseItem.sales
			WHERE ((PKPurchaseItem.Status = 'Active') AND ( ISNULL(PKPurchaseItem.ResourceDate, '') != '')) 
		)
	) a
	where TimeDate between @timeStart and @timeEnd


	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
	DROP TABLE #tblCustomer;
	DROP TABLE #tbl4;
	DROP TABLE #tbl5;
	DROP TABLE #tbl6;


END


GO
/****** Object:  StoredProcedure [dbo].[Pk_GetBookingModifierByTimesAndResourceID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[Pk_GetBookingModifierByTimesAndResourceID]
	@purchaseItemId varchar(50),
	@StrDate  varchar(50),
	@strTimeFrom varchar(50),
	@strTimeTo varchar(50),
	@inputResourceId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;

    -- Insert statements for procedure here
	declare @productId varchar(50);
	declare @categoryId varchar(50);
	declare @ResourceId uniqueidentifier;
	declare @inputDate smalldatetime;

	select @productId = ProductId from PKPurchaseItem where PurchaseItemId = @purchaseItemId;
	select @categoryId = categoryid from PKProduct where id = @productId;
	set @inputDate  = cast(@StrDate as smalldatetime);

	--Get the common template by the timeFrom and the timeTo.
	--Conveniently, get out the resourceId.
	select @ResourceId = cast(@inputResourceId as uniqueidentifier);

	select prm.SpecialOrResourceId as ResourceId,
	Prm.ModifierID
	into #tbl1
	from PKResourceModifier PRM where prm.SpecialOrResourceId = @ResourceId
	
	-----------------------------------------------------------
	--Get out the modifier Item IDs from the special template.
	-----------------------------------------------------------
	select 
	Prm.ModifierID
	into #tbl2
	from PKResourceSpecial PRS
	inner join PKResourceModifier PRM on prm.SpecialOrResourceId = prs.SpecialResourceId
	where prs.ResourceId = @ResourceId and Datetime = @inputDate



	------------------------------------------------------------
	--To know if there is recode in special template. If true, put them into #tbl3.
	--If false , put the modifier from common template into #tbl3----
	-------------------------------------------------------------
	select newid() as ModifierID into #tbl3;
	delete from #tbl3;

	declare @count int;
	select @count = count(*) from #tbl2;
	
	if @count >0 
	begin
		insert into #tbl3 select ModifierID from #tbl2;
	end
	else
	begin
		insert into #tbl3 select ModifierID from #tbl1;
	end

	--------------------------------------------------------------
	--Get All modifier items which are included in the resource.
	--------------------------------------------------------------
	select
	pmi.ID as modifierItemId,
	PMI.Name1 as ModifierName,
	PMG.Name1 as ModifierGroupName,
	t3.ModifierID as modifierGroupId
	into #tblAllMItemOfProduct
	from #tbl3 t3
	inner join PKModifierItem PMI on pmi.ModifierGroupID = t3.ModifierID 
	inner join PKModifierGroup PMG on t3.ModifierID = pmg.ID


	select distinct 
		modifierGroupId, 
		ModifierGroupName ,
		pmg.MaxSelectedItems,
		pmg.MinSelectedItems
	into #tblModifGroupInfo
	from #tblAllMItemOfProduct TMP
	inner join PKModifierGroup PMg on pmg.ID = tmp.modifierGroupId 

	--select modifierItemId ,
	--	ModifierName
	--into #tblAllMItemOfProduct
	--from 
	--	(
	--	select PMI.ID as modifierItemId,
	--	PMI.Name1 as ModifierName
	--	from PKModifierConnection PMC 
	--	inner join PKModifierItem PMI on pmi.ModifierGroupID = pmc.ModifierGroupID
	--	where PMC.FoodID = @productId

	--	union
	
	--	select PMI.ID as modifierItemId ,
	--	PMI.Name1 as ModifierName	 
	--	from pkModifierConnection PMC
	--	inner join pkProduct pP on pp.CategoryID = PMC.FoodID 
	--	inner join PKModifierItem PMI on pmi.ModifierGroupID = pmc.ModifierGroupID
	--	where PP.id = @productId

	--	) a




	--------------------------------------------------------------------
	--Get all the modifier items which are booked already in the past schedule,by other,by this time
	--pay attention to <>
	--------------------------------------------------------------------
	select distinct PPm.ModifierItemId ,
		PMI.Name1 as ModifierName,
	PMG.Name1 as ModifierGroupName,
	PMg.ID as modifierGroupId

	into #tblOtherMItemSelected
	from PKPurchaseItem PPI
	inner join PKPurchaseItemModifier PPM on ppm.PurchaseItemId  = PPI.PurchaseItemId
	inner join PKModifierItem PMI on pmi.ID = PPm.ModifierItemId
	inner join PKModifierGroup PMG on PMI.ModifierGroupID = pmg.ID

	where PPI.ResourceDate = @StrDate
	and (
		((ppi.ResourceTimeFrom <= @strTimeFrom and ppi.ResourceTimeTo>=@strTimeFrom) or (ppi.ResourceTimeFrom <= @strTimeTo and ppi.ResourceTimeTo>=@strTimeTo))
		or
		(ppi.ResourceTimeFrom >= @strTimeFrom and ppi.ResourceTimeTo<=@strTimeTo)
		)
	and ppi.PurchaseItemId <> @purchaseItemId

	--------------------------------------------------------------------
	--Get all the modifier items which are booked already in the past schedule,by this one,by this time
	--Pay attention to ppi.PurchaseItemId = @purchaseItemId
	--------------------------------------------------------------------
	select distinct PPm.ModifierItemId,
		PMI.Name1 as ModifierName ,
		PMG.Name1 as ModifierGroupName,
		PMg.ID as modifierGroupId

	into #tblMItemSelected
	from PKPurchaseItem PPI
	inner join PKPurchaseItemModifier PPM on ppm.PurchaseItemId  = PPI.PurchaseItemId
	inner join PKModifierItem PMI on pmi.ID = PPm.ModifierItemId
	inner join PKModifierGroup PMG on PMI.ModifierGroupID = pmg.ID
	where PPI.ResourceDate = @StrDate
	and (
		((ppi.ResourceTimeFrom <= @strTimeFrom and ppi.ResourceTimeTo>=@strTimeFrom) or (ppi.ResourceTimeFrom <= @strTimeTo and ppi.ResourceTimeTo>=@strTimeTo))
		or
		(ppi.ResourceTimeFrom >= @strTimeFrom and ppi.ResourceTimeTo<=@strTimeTo)
		)
	and ppi.PurchaseItemId = @purchaseItemId



	select * from #tblAllMItemOfProduct;
	select * from #tblOtherMItemSelected;
	select * from #tblMItemSelected;
	select * from #tblModifGroupInfo



	drop table #tblModifGroupInfo;
	drop table #tblAllMItemOfProduct;
	drop table #tblOtherMItemSelected;
	drop table #tblMItemSelected;
	drop table #tbl1;
	drop table #tbl2;
	drop table #tbl3;



END



GO
/****** Object:  StoredProcedure [dbo].[Pk_GetBookingModifierByTimesAndResourceItem]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetBookingModifierByTimesAndResourceItem]
	@purchaseItemId varchar(50),
	@StrDate  varchar(50),
	@strTimeFrom varchar(50),
	@strTimeTo varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SET NOCOUNT ON;

    -- Insert statements for procedure here
	declare @productId varchar(50);
	declare @categoryId varchar(50);
	declare @ResourceId uniqueidentifier;
	declare @inputDate smalldatetime;

	select @productId = ProductId from PKPurchaseItem where PurchaseItemId = @purchaseItemId;
	select @categoryId = categoryid from PKProduct where id = @productId;
	set @inputDate  = cast(@StrDate as smalldatetime);

	--Get the common template by the timeFrom and the timeTo.
	--Conveniently, get out the resourceId.
	select prt.ResourceId,
	Prm.ModifierID
	into #tbl1
	from PKResourceTemplate PRT
	inner join PKResourceModifier PRM on prm.SpecialOrResourceId = prt.ResourceId
	where prt.ProductID = @productId and TimeFrom = @strTimeFrom and TimeTo  = @strTimeTo

	

	select @ResourceId = isnull(ResourceId, newid()) from #tbl1;

	-----------------------------------------------------------
	--Get out the modifier Item IDs from the special template.
	-----------------------------------------------------------
	select 
	Prm.ModifierID
	into #tbl2
	from PKResourceSpecial PRS
	inner join PKResourceModifier PRM on prm.SpecialOrResourceId = prs.SpecialResourceId
	where prs.ResourceId = @ResourceId and Datetime = @inputDate


	------------------------------------------------------------
	--To know if there is recode in special template. If true, put them into #tbl3.
	--If false , put the modifier from common template into #tbl3----
	-------------------------------------------------------------
	select newid() as ModifierID into #tbl3;
	delete from #tbl3;

	declare @count int;
	select @count = count(*) from #tbl2;
	
	if @count >0 
	begin
		insert into #tbl3 select ModifierID from #tbl2;
	end
	else
	begin
		insert into #tbl3 select ModifierID from #tbl1;
	end

	--------------------------------------------------------------
	--Get All modifier items which are included in the resource.
	--------------------------------------------------------------
	select
	pmi.ID as modifierItemId,
	PMI.Name1 as ModifierName,
	PMG.Name1 as ModifierGroupName,
	t3.ModifierID as modifierGroupId
	into #tblAllMItemOfProduct
	from #tbl3 t3
	inner join PKModifierItem PMI on pmi.ModifierGroupID = t3.ModifierID 
	inner join PKModifierGroup PMG on t3.ModifierID = pmg.ID


	--select modifierItemId ,
	--	ModifierName
	--into #tblAllMItemOfProduct
	--from 
	--	(
	--	select PMI.ID as modifierItemId,
	--	PMI.Name1 as ModifierName
	--	from PKModifierConnection PMC 
	--	inner join PKModifierItem PMI on pmi.ModifierGroupID = pmc.ModifierGroupID
	--	where PMC.FoodID = @productId

	--	union
	
	--	select PMI.ID as modifierItemId ,
	--	PMI.Name1 as ModifierName	 
	--	from pkModifierConnection PMC
	--	inner join pkProduct pP on pp.CategoryID = PMC.FoodID 
	--	inner join PKModifierItem PMI on pmi.ModifierGroupID = pmc.ModifierGroupID
	--	where PP.id = @productId

	--	) a




	--------------------------------------------------------------------
	--Get all the modifier items which are booked already in the past schedule,by other,by this time
	--pay attention to <>
	--------------------------------------------------------------------
	select distinct PPm.ModifierItemId ,
		PMI.Name1 as ModifierName,
	PMG.Name1 as ModifierGroupName,
	PMg.ID as modifierGroupId

	into #tblOtherMItemSelected
	from PKPurchaseItem PPI
	inner join PKPurchaseItemModifier PPM on ppm.PurchaseItemId  = PPI.PurchaseItemId
	inner join PKModifierItem PMI on pmi.ID = PPm.ModifierItemId
	inner join PKModifierGroup PMG on PMI.ModifierGroupID = pmg.ID

	where PPI.ResourceDate = @StrDate
	and ppi.ResourceTimeFrom = @strTimeFrom
	and ppi.ResourceTimeTo  = @strTimeTo
	and ppi.PurchaseItemId <> @purchaseItemId

	--------------------------------------------------------------------
	--Get all the modifier items which are booked already in the past schedule,by this one,by this time
	--Pay attention to ppi.PurchaseItemId = @purchaseItemId
	--------------------------------------------------------------------
	select distinct PPm.ModifierItemId,
		PMI.Name1 as ModifierName ,
		PMG.Name1 as ModifierGroupName,
		PMg.ID as modifierGroupId

	into #tblMItemSelected
	from PKPurchaseItem PPI
	inner join PKPurchaseItemModifier PPM on ppm.PurchaseItemId  = PPI.PurchaseItemId
	inner join PKModifierItem PMI on pmi.ID = PPm.ModifierItemId
	inner join PKModifierGroup PMG on PMI.ModifierGroupID = pmg.ID
	where PPI.ResourceDate = @StrDate
	and ppi.ResourceTimeFrom = @strTimeFrom
	and ppi.ResourceTimeTo  = @strTimeTo
	and ppi.PurchaseItemId = @purchaseItemId



	select * from #tblAllMItemOfProduct;
	select * from #tblOtherMItemSelected;
	select * from #tblMItemSelected;

	drop table #tblAllMItemOfProduct;
	drop table #tblOtherMItemSelected;
	drop table #tblMItemSelected;
	drop table #tbl1;
	drop table #tbl2;
	drop table #tbl3;


END

GO
/****** Object:  StoredProcedure [dbo].[Pk_GetBookingModifierByTimesAndResourceItem2]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetBookingModifierByTimesAndResourceItem2]
	@purchaseItemId varchar(50),
	@StrDate  varchar(50),
	@strTimeFrom varchar(50),
	@strTimeTo varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SET NOCOUNT ON;

    -- Insert statements for procedure here
	declare @productId varchar(50);
	declare @categoryId varchar(50);
	declare @ResourceId uniqueidentifier;
	declare @inputDate smalldatetime;

	select @productId = ProductId from PKPurchaseItem where PurchaseItemId = @purchaseItemId;
	select @categoryId = categoryid from PKProduct where id = @productId;
	set @inputDate  = cast(@StrDate as smalldatetime);

	--Get the common template by the timeFrom and the timeTo.
	--Conveniently, get out the resourceId.
	select prt.ResourceId,
	Prm.ModifierID
	into #tbl1
	from PKResourceTemplate PRT
	inner join PKResourceModifier PRM on prm.SpecialOrResourceId = prt.ResourceId
	where prt.ProductID = @productId and TimeFrom <= @strTimeFrom and TimeTo >= @strTimeTo

	

	select @ResourceId = isnull(ResourceId, newid()) from #tbl1;

	-----------------------------------------------------------
	--Get out the modifier Item IDs from the special template.
	-----------------------------------------------------------
	select 
	Prm.ModifierID
	into #tbl2
	from PKResourceSpecial PRS
	inner join PKResourceModifier PRM on prm.SpecialOrResourceId = prs.SpecialResourceId
	where prs.ResourceId = @ResourceId and Datetime = @inputDate


	------------------------------------------------------------
	--To know if there is recode in special template. If true, put them into #tbl3.
	--If false , put the modifier from common template into #tbl3----
	-------------------------------------------------------------
	select newid() as ModifierID into #tbl3;
	delete from #tbl3;

	declare @count int;
	select @count = count(*) from #tbl2;
	
	if @count >0 
	begin
		insert into #tbl3 select ModifierID from #tbl2;
	end
	else
	begin
		insert into #tbl3 select ModifierID from #tbl1;
	end

	--------------------------------------------------------------
	--Get All modifier items which are included in the resource.
	--------------------------------------------------------------
	select
	pmi.ID as modifierItemId,
	PMI.Name1 as ModifierName,
	PMG.Name1 as ModifierGroupName,
	t3.ModifierID as modifierGroupId
	into #tblAllMItemOfProduct
	from #tbl3 t3
	inner join PKModifierItem PMI on pmi.ModifierGroupID = t3.ModifierID 
	inner join PKModifierGroup PMG on t3.ModifierID = pmg.ID

	select distinct 
		modifierGroupId, 
		ModifierGroupName ,
		pmg.MaxSelectedItems,
		pmg.MinSelectedItems
	into #tblModifGroupInfo
	from #tblAllMItemOfProduct TMP
	inner join PKModifierGroup PMg on pmg.ID = tmp.modifierGroupId 

	--select modifierItemId ,
	--	ModifierName
	--into #tblAllMItemOfProduct
	--from 
	--	(
	--	select PMI.ID as modifierItemId,
	--	PMI.Name1 as ModifierName
	--	from PKModifierConnection PMC 
	--	inner join PKModifierItem PMI on pmi.ModifierGroupID = pmc.ModifierGroupID
	--	where PMC.FoodID = @productId

	--	union
	
	--	select PMI.ID as modifierItemId ,
	--	PMI.Name1 as ModifierName	 
	--	from pkModifierConnection PMC
	--	inner join pkProduct pP on pp.CategoryID = PMC.FoodID 
	--	inner join PKModifierItem PMI on pmi.ModifierGroupID = pmc.ModifierGroupID
	--	where PP.id = @productId

	--	) a




	--------------------------------------------------------------------
	--Get all the modifier items which are booked already in the past schedule,by other,by this time
	--pay attention to <>
	--------------------------------------------------------------------
	select distinct PPm.ModifierItemId ,
		PMI.Name1 as ModifierName,
	PMG.Name1 as ModifierGroupName,
	PMg.ID as modifierGroupId

	into #tblOtherMItemSelected
	from PKPurchaseItem PPI
	inner join PKPurchaseItemModifier PPM on ppm.PurchaseItemId  = PPI.PurchaseItemId
	inner join PKModifierItem PMI on pmi.ID = PPm.ModifierItemId
	inner join PKModifierGroup PMG on PMI.ModifierGroupID = pmg.ID

	where PPI.ResourceDate = @StrDate
	and ppi.ResourceTimeFrom = @strTimeFrom
	and ppi.ResourceTimeTo  = @strTimeTo
	and ppi.PurchaseItemId <> @purchaseItemId

	--------------------------------------------------------------------
	--Get all the modifier items which are booked already in the past schedule,by this one,by this time
	--Pay attention to ppi.PurchaseItemId = @purchaseItemId
	--------------------------------------------------------------------
	select distinct PPm.ModifierItemId,
		PMI.Name1 as ModifierName ,
		PMG.Name1 as ModifierGroupName,
		PMg.ID as modifierGroupId

	into #tblMItemSelected
	from PKPurchaseItem PPI
	inner join PKPurchaseItemModifier PPM on ppm.PurchaseItemId  = PPI.PurchaseItemId
	inner join PKModifierItem PMI on pmi.ID = PPm.ModifierItemId
	inner join PKModifierGroup PMG on PMI.ModifierGroupID = pmg.ID
	where PPI.ResourceDate = @StrDate
	and ppi.ResourceTimeFrom = @strTimeFrom
	and ppi.ResourceTimeTo  = @strTimeTo
	and ppi.PurchaseItemId = @purchaseItemId



	select * from #tblAllMItemOfProduct;
	select * from #tblOtherMItemSelected;
	select * from #tblMItemSelected;
	select * from #tblModifGroupInfo

	drop table #tblModifGroupInfo;
	drop table #tblAllMItemOfProduct;
	drop table #tblOtherMItemSelected;
	drop table #tblMItemSelected;
	drop table #tbl1;
	drop table #tbl2;
	drop table #tbl3;


END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingNonpaymentGiftCardSN]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookingNonpaymentGiftCardSN]
	@OrderList [dbo].[PKOrderTableType] READONLY
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	SELECT PKGiftCardTransaction.ID, (CASE WHEN ISNULL(PKGiftCard.Name2, '') = '' THEN PKGiftCard.Name1 ELSE (PKGiftCard.Name1 + ' / ' + PKGiftCard.Name2) END) AS Name,
	PKGiftCard.ID AS CardId, PKGiftCardTransaction.GiftCardNo FROM PKGiftCardTransaction
	INNER JOIN PKGiftCard ON PKGiftCard.ID = PKGiftCardTransaction.GiftCardId
	WHERE (transferId in (SELECT OrderID FROM @OrderList)) ORDER BY PKGiftCard.Name1, PKGiftCard.Name2
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingNonpaymentOrder]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookingNonpaymentOrder] 
	@CardNo VARCHAR(50),
	@LocationId NVarchar(50)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	SELECT transferId AS ID, CreateDate, 1 as Qty, ISNULL(amount, 0.00) AS Amount INTO #tbl1 
	FROM PKPurchasePackage WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL)
	UNION ALL
	(
		SELECT transferId AS ID, CreateTime AS CreateDate, 1 as Qty, ISNULL(Price, 0.00) AS Amount 
		FROM PKPrepaidPackageTransaction WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL)
	)
	UNION ALL
	(
		SELECT transferId AS ID, CreateTime AS CreateDate, 1 as Qty, ISNULL(Price, 0.00) AS Amount 
		FROM PKDepositPackageTransaction WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL)
	)	
	UNION ALL
	(
		SELECT transferId AS ID, CreateTime AS CreateDate, 1 as Qty, ISNULL(Price, 0.00) AS Amount 
		FROM PKGiftCardTransaction WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL)
	)

	SELECT ID, MIN(CreateDate) AS CreateDate, SUM(Qty) AS Qty, SUM(Amount) AS Amount INTO #tbl2 FROM #tbl1 GROUP BY ID

	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount INTO #tbl3 FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance
	SELECT PKPurchasePackagePaymentItem.transferId AS ID, 1 AS AllPaid INTO #tbl4 FROM #tbl3 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)

	SELECT orderlist.ID, orderlist.CreateDate, orderlist.Qty, orderlist.Amount, PKPurchasePackageOrder.Type FROM #tbl2 AS orderlist 
	LEFT JOIN #tbl4 AS payment ON payment.ID = orderlist.ID
	INNER JOIN PKPurchasePackageOrder ON PKPurchasePackageOrder.transferId = orderlist.ID
	WHERE (ISNULL(AllPaid, 0) != 1) AND ((@LocationId='') or (@LocationId<>'' and PKPurchasePackageOrder.Locationid = @LocationId)) AND (ISNULL(PKPurchasePackageOrder.Type, '') != '') ORDER BY orderlist.ID DESC

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
	DROP TABLE #tbl4;
END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingNonpaymentOrderALL]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookingNonpaymentOrderALL] 

AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
	
	SELECT transferId AS ID, CreateDate, 1 as Qty, ISNULL(amount, 0.00) AS Amount,CardNumber INTO #tbl1 
	FROM PKPurchasePackage WHERE  (transferId IS NOT NULL)
	UNION ALL
	(
		SELECT transferId AS ID, CreateTime AS CreateDate, 1 as Qty, ISNULL(Price, 0.00) AS Amount,CardNumber
		FROM PKPrepaidPackageTransaction WHERE   (transferId IS NOT NULL)
	)
	UNION ALL
	(
		SELECT transferId AS ID, CreateTime AS CreateDate, 1 as Qty, ISNULL(Price, 0.00) AS Amount ,CardNumber
		FROM PKDepositPackageTransaction WHERE   (transferId IS NOT NULL)
	)	
	UNION ALL
	(
		SELECT transferId AS ID, CreateTime AS CreateDate, 1 as Qty, ISNULL(Price, 0.00) AS Amount ,CardNumber
		FROM PKGiftCardTransaction WHERE  (transferId IS NOT NULL)
	)

	--select * from #tbl1;


	SELECT ID, CardNumber, MIN(CreateDate) AS CreateDate, SUM(Qty) AS Qty, SUM(Amount) AS Amount 
	INTO #tbl2 FROM #tbl1 GROUP BY ID,CardNumber
	--select * from #tbl2 order by id desc
	--select * from #tbl2b


	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl3 FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance;

	SELECT PKPurchasePackagePaymentItem.transferId AS ID, 1 AS AllPaid 
	INTO #tbl4 FROM #tbl3 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount);

	SELECT orderlist.ID,orderlist.CardNumber, orderlist.CreateDate as TimeDate, orderlist.Qty, orderlist.Amount, PKPurchasePackageOrder.Type, PKPurchasePackageOrder.Locationid, isnull(payment.Allpaid,0) as Allpaid
	FROM #tbl2 AS orderlist 
	LEFT JOIN #tbl4 AS payment ON payment.ID = orderlist.ID
	INNER JOIN PKPurchasePackageOrder ON PKPurchasePackageOrder.transferId = orderlist.ID
	WHERE  (ISNULL(PKPurchasePackageOrder.Type, '') != '') ORDER BY orderlist.ID desc
	

	DROP TABLE #tbl1;
	--DROP TABLE #tbl2;
	DROP TABLE #tbl3;
	DROP TABLE #tbl4;	
	DROP TABLE #tbl2;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingNonpaymentPackage]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookingNonpaymentPackage] 
	@CardNo VARCHAR(50),
	@OrderList [dbo].[PKOrderTableType] READONLY
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	SELECT PKPromotionProduct.ID, PKPromotionProduct.PromotionID, PKPromotionProduct.ProductID, PKProduct.PLU, PKProduct.Name1 AS Name, PKPromotionProduct.PromotionUnitPrice AS RPrice, 
	PKPromotionProduct.Qty INTO #tbl1 FROM PKPromotionProduct 
	INNER JOIN PKProduct ON PKProduct.ID = PKPromotionProduct.ProductID

	SELECT PromotionID, [Value]=stuff((  
	SELECT ',' + [Name] + '  x' + CONVERT(varchar(10), Qty) FROM #tbl1 as Temp2 WHERE Temp2.PromotionID = Temp1.PromotionID FOR XML PATH('')),1,1,'') INTO #tbl2 FROM #tbl1 AS Temp1  
	GROUP BY PromotionID 

	SELECT ID, GiftCardId, GiftCardNo, transferId INTO #tbl5 FROM PKGiftCardTransaction WHERE ISNULL(GiftCardNo, '') != ''
	SELECT transferId, GiftCardId, [Value]=stuff((  
	SELECT ',CardNo: ' + [GiftCardNo] FROM #tbl5 as Temp2 WHERE Temp2.GiftCardId = Temp1.GiftCardId AND Temp2.transferId = Temp1.transferId FOR XML PATH('')),1,1,'') INTO #tbl6 FROM #tbl5 AS Temp1  
	GROUP BY transferId, GiftCardId 

	SELECT transferId, CardNumber, BomOrProductID, itemType, CreateDate, amount, 1 AS Qty INTO #tbl3 FROM PKPurchasePackage
	WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL) AND (transferId in (SELECT OrderID FROM @OrderList))
	UNION ALL
	(
		SELECT transferId, CardNumber, PrepaidPackageID AS BomOrProductID, 'Prepaid' AS itemType, CreateTime AS CreateDate, Price AS amount, 1 AS Qty FROM PKPrepaidPackageTransaction
		WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL) AND (transferId in (SELECT OrderID FROM @OrderList))
	)
	UNION ALL
	(
		SELECT transferId, CardNumber, PrepaidPackageID AS BomOrProductID, 'Deposit' AS itemType, CreateTime AS CreateDate, Price AS amount, 1 AS Qty FROM PKDepositPackageTransaction
		WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL) AND (transferId in (SELECT OrderID FROM @OrderList))
	)	
	UNION ALL
	(
		SELECT transferId, CardNumber, GiftCardId AS BomOrProductID, 'GiftCard' AS itemType, CreateTime AS CreateDate, Price AS amount, 1 AS Qty FROM PKGiftCardTransaction
		WHERE (CardNumber = @CardNo) AND (transferId IS NOT NULL) AND (transferId in (SELECT OrderID FROM @OrderList))
	)
	SELECT NEWID() AS ID, Package.transferId, Package.CardNumber, Package.BomOrProductID, Package.itemType, MAX(Package.CreateDate) AS CreateDate, Package.amount, 
	SUM(Package.Qty) AS Qty, PKPurchasePackageOrder.Type AS OrderType INTO #tbl4 FROM #tbl3 AS Package
	INNER JOIN PKPurchasePackageOrder ON PKPurchasePackageOrder.transferId = Package.transferId
	GROUP BY Package.transferId, Package.CardNumber, Package.BomOrProductID, Package.itemType, Package.amount, PKPurchasePackageOrder.Type

	SELECT Packages.ID AS ID, (CASE WHEN ISNULL(PKPromotion.Name2, '') = '' THEN PKPromotion.Name1 + ',' + PromotionProducts.Value ELSE (PKPromotion.Name1 + ' / ' + PKPromotion.Name2 + ',' + PromotionProducts.Value) END) AS Name, 
	PKPromotion.Name1 AS PName, Packages.transferId AS TransferID, CardNumber, Packages.CreateDate, Packages.amount as Amount, Packages.Qty, Packages.amount * Packages.Qty AS TotalAmount, Packages.OrderType,
	Packages.BomOrProductID AS PackageID, 'Package' AS PackageType FROM #tbl4 AS Packages
	INNER JOIN PKPromotion ON PKPromotion.ID = Packages.BomOrProductID
	INNER JOIN #tbl2 AS PromotionProducts ON PromotionProducts.PromotionID = Packages.BomOrProductID
	WHERE itemType = 'B'
	UNION
	(
		SELECT Packages.ID AS ID, (CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2) END) AS Name, PKProduct.Name1 AS PName,
		Packages.transferId AS TransferID, CardNumber, Packages.CreateDate, Packages.amount as Amount, Packages.Qty, Packages.amount * Packages.Qty AS TotalAmount, Packages.OrderType,
		Packages.BomOrProductID AS PackageID, 'Product' AS PackageType FROM #tbl4 AS Packages
		INNER JOIN PKProduct ON PKProduct.ID = Packages.BomOrProductID
		WHERE itemType = 'P'
	) 
	UNION
	(
		SELECT Packages.ID AS ID, (CASE WHEN ISNULL(PKPrepaidPackage.Name2, '') = '' THEN PKPrepaidPackage.Name1 ELSE (PKPrepaidPackage.Name1 + ' / ' + PKPrepaidPackage.Name2) END) AS Name, 
		PKPrepaidPackage.Name1 AS PName, Packages.transferId AS TransferID, CardNumber, Packages.CreateDate, Packages.amount as Amount, Packages.Qty, Packages.amount * Packages.Qty AS TotalAmount, 
		Packages.OrderType, Packages.BomOrProductID AS PackageID, 'Prepaid' AS PackageType FROM #tbl4 AS Packages
		INNER JOIN PKPrepaidPackage ON PKPrepaidPackage.ID = Packages.BomOrProductID
		WHERE itemType = 'Prepaid'
	)
	UNION
	(
		SELECT Packages.ID AS ID, (CASE WHEN ISNULL(PKDepositPackage.Name2, '') = '' THEN PKDepositPackage.Name1 ELSE (PKDepositPackage.Name1 + ' / ' + PKDepositPackage.Name2) END) AS Name, 
		PKDepositPackage.Name1 AS PName, Packages.transferId AS TransferID, CardNumber, Packages.CreateDate, Packages.amount as Amount, Packages.Qty, Packages.amount * Packages.Qty AS TotalAmount, 
		Packages.OrderType, Packages.BomOrProductID AS PackageID, 'Deposit' AS PackageType FROM #tbl4 AS Packages
		INNER JOIN PKDepositPackage ON PKDepositPackage.ID = Packages.BomOrProductID
		WHERE itemType = 'Deposit'
	)	
	UNION
	(
		SELECT Packages.ID AS ID, (CASE WHEN ISNULL(PKGiftCard.Name2, '') = '' THEN PKGiftCard.Name1 + ',' + ISNULL(GiftCardNo.Value, '') ELSE (PKGiftCard.Name1 + ' / ' + PKGiftCard.Name2 + ',' + ISNULL(GiftCardNo.Value, '')) END) AS Name, 
		PKGiftCard.Name1 AS PName, Packages.transferId AS TransferID, CardNumber, Packages.CreateDate, Packages.amount as Amount, Packages.Qty, Packages.amount * Packages.Qty AS TotalAmount, Packages.OrderType,
		Packages.BomOrProductID AS PackageID, 'GiftCard' AS PackageType FROM #tbl4 AS Packages
		INNER JOIN PKGiftCard ON PKGiftCard.ID = Packages.BomOrProductID
		LEFT JOIN #tbl6 AS GiftCardNo ON Packages.transferId = GiftCardNo.transferId AND Packages.BomOrProductID = GiftCardNo.GiftCardId
		WHERE itemType = 'GiftCard'
	)ORDER BY CreateDate, Name

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
	DROP TABLE #tbl4;
	DROP TABLE #tbl5;
	DROP TABLE #tbl6;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingNonpaymentPackageTax]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_GetBookingNonpaymentPackageTax] 
	@OrderList [dbo].[PKOrderTableType] READONLY
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	SELECT TaxID, TaxName + ':' AS TaxName, SUM(Amount) AS Amount FROM PKPurchasePackageOrderTax WHERE (transferId in (SELECT OrderID FROM @OrderList)) GROUP BY TaxID, TaxName

END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingPackageOrderTax]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetBookingPackageOrderTax] 
	@transferId VARCHAR(50)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	SELECT PurchaseId, transferId, CardNumber, BomOrProductID, itemType, CreateDate, amount INTO #tbl1 FROM PKPurchasePackage WHERE (transferId = @transferId)
	SELECT NEWID() AS ID, PKPromotionProduct.ProductID AS productId, 
	CAST(ROUND(ISNULL(PKPromotionProduct.Qty, 0.00) * ISNULL(PKPromotionProduct.PromotionUnitPrice, 0.00) * dbo.PK_FuncGetPackagePriceFactor(Packages.BomOrProductID, Packages.amount), 2) AS decimal(18, 2)) AS amount 
	INTO #tbl2 FROM #tbl1 AS Packages 
	INNER JOIN PKPromotionProduct ON PKPromotionProduct.PromotionID = Packages.BomOrProductID
	WHERE itemType = 'B'
	UNION
	(
		SELECT NEWID() AS ID, BomOrProductID AS productId, amount FROM #tbl1 AS Packages WHERE itemType = 'P'
	) ORDER BY ID

	SELECT productTax.TaxID, productTax.TaxName, CAST(ROUND(Products.amount * ISNULL(productTax.TaxValue, 0.00) / 100, 2) AS decimal(18, 2)) AS TaxAmount INTO #tbl3 FROM #tbl2 AS Products
	INNER JOIN (
		SELECT PKProductTax.ProductID, PKProductTax.TaxID, PKTax.TaxName, PKTax.TaxValue FROM PKProductTax 
		join PKTax on PKProductTax.TaxID = PKTax.ID WHERE Lower(Flag) = 'yes' AND ValueType='%'
	) AS productTax ON productTax.ProductID = Products.productId ORDER BY TaxName

	SELECT TaxID, TaxName, SUM(TaxAmount) AS Amount FROM #tbl3 GROUP BY TaxID, TaxName

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookingPaymentItem]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookingPaymentItem]
	@OrderList [dbo].[PKOrderTableType] READONLY
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	SELECT * FROM PKPurchasePackagePaymentItem WHERE (transferId in (SELECT OrderID FROM @OrderList))
END

GO
/****** Object:  StoredProcedure [dbo].[Pk_GetBookingTimesByResourceItem]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetBookingTimesByResourceItem]
	@purchaseItemId varchar(50),
	@StrDate  varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @tempString NVARCHAR(100); 
	  SET @tempString =  N'1234567891012345678910123456789101234567891012345678910'       ; 
      SET @tempString = @tempString + @tempString; 
  
	
	declare @productId varchar(50);
	declare @ResourceId uniqueidentifier;
	declare @inputDate smalldatetime;

	declare @Qty int;
	declare @TimeFrom varchar(50);
	declare @TimeTo varchar(50);
	declare @ResouceId uniqueIdentifier

	select @productId = ProductId from PKPurchaseItem where PurchaseItemId = @purchaseItemId;
	set @inputDate  = cast(@StrDate as smalldatetime);

	select 
	PRT.ProductId,
	Prt.TimeFrom,
	prt.TimeTo,
	isnull(PRS.Qty,PRT.Qty) as QTY,
	isnull(PrS.status,prt.status) as [STatus],
	PRt.TimeFrom + ' - ' + prt.TimeTo as timePeriod,
	Prt.ResourceId,
	@tempString as isFullFilled
	into #tblTimePeriods
	from PKResourceTemplate PRT
	left outer join PKResourceSpecial PRS on prs.ResourceId = prt.ResourceId and prs.[Datetime] = @inputDate
	where Prt.ProductID = @productId




	DECLARE t_cursor CURSOR FOR 
        SELECT QTY,TimeFrom,TimeTo,ResourceId from #tblTimePeriods

      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @qty,@TimeFrom,@timeTo,@ResouceId
      WHILE @@fetch_status = 0 
        BEGIN 
		    declare @count int;
			select @count = count(*) 
			from PKPurchaseItem 
			where isnull(ResourceDate,'') = @StrDate
			and isnull(resourceTimefrom,'') = @TimeFrom
			and isnull(resourceTimeTo,'') = @TimeTo
			and PurchaseItemId <> @purchaseItemId

			if @count >= @Qty
			begin
				update #tblTimePeriods set isFullFilled = 'true'
			end

            FETCH next FROM t_cursor INTO @qty,@TimeFrom,@timeTo,@ResouceId
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 

	  select * from #tblTimePeriods

	drop table #tblTimePeriods;
END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetBookList]
	@locationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	DECLARE @isMultiCard varchar(50);
	SELECT @isMultiCard = ISNULL(Value, 'false') FROM PKSetting WHERE FieldName = 'isBookingMultiCard';
	----------------------------------------------------
	DECLARE @SuperCustomerId varchar(50);
	SELECT @SuperCustomerId = ISNULL(Value, '') FROM PKSetting WHERE FieldName = 'SuperVIPIdForWalkIn';
	----------------------------------------------------
	SELECT PKPurchaseItemModifier.PurchaseItemId, PKModifierItem.Name1 
	INTO #tbl1 
	FROM PKPurchaseItemModifier 
	LEFT JOIN PKModifierItem ON PKModifierItem.ID = PKPurchaseItemModifier.ModifierItemId 
	ORDER BY PKModifierItem.ModifierGroupID
	----------------------------------------------------
	SELECT PurchaseItemId, [Value]=stuff((  
	SELECT distinct ', '+[Name1] FROM #tbl1 as Temp2 WHERE Temp2.PurchaseItemId = Temp1.PurchaseItemId FOR XML PATH('')),1,2,'') 
	INTO #tbl2 
	FROM #tbl1 AS Temp1  
	GROUP BY PurchaseItemId 
	----------------------------------------------------
	SELECT PKPurchasePackage.PurchaseId, PKLocation.LocationName 
	INTO #tbl3 
	FROM PKPurchasePackage 
	LEFT JOIN PKPurchasePackageOrder ON PKPurchasePackageOrder.transferId = PKPurchasePackage.transferId
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId
	----------------------------------------------------
	IF LOWER(@isMultiCard) = 'true'
	BEGIN
		SELECT PKPurchaseItem.PurchaseItemId AS ID, PKPurchaseItem.CardNumber AS Card,  PKPurchaseItem.CardHolder AS Customer, Customer.Phone, PKPurchaseItem.ResourceTimeFrom AS TimeStart, PKPurchaseItem.ResourceTimeTo AS TimeEnd, 
		CAST(PKPurchaseItem.ResourceDate AS datetime) AS TimeDate, PKCategory.Name AS Category, 
		(CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2) END) AS ProductName, 
		PurchaseModifiers.Value AS Modifiers, PKPurchaseItem.Remark, Location.LocationName AS Location,
		pu.UserName as Sales,'' as SalesCommission,
		case lower(Customer.Gender) when 'male' then 'M' when 'female' then 'F' else '' end as CustomerGender,
		-----
		case cast(CustomerCard.CustomerID as varchar(50)) when @SuperCustomerId then 'Walk-In' else
			case lower(PKPurchaseItem.forceSales) when 'true' then 'Appointment' else 'Random' end
		end as [Type]
		-----
		FROM PKPurchaseItem
		INNER JOIN PKProduct ON PKProduct.ID = PKPurchaseItem.ProductId INNER JOIN PKCategory ON PKCategory.ID = PKProduct.CategoryID
		LEFT JOIN #tbl2 AS PurchaseModifiers on PurchaseModifiers.PurchaseItemId = PKPurchaseItem.PurchaseItemId
		INNER JOIN #tbl3 AS Location ON Location.PurchaseId = PKPurchaseItem.PurchaseId
		INNER JOIN CustomerCard ON CustomerCard.CardNo = PKPurchaseItem.CardNumber
		INNER JOIN Customer ON Customer.ID = CustomerCard.CustomerID
		left outer join PKUsers PU on pu.EmployeeID = PKPurchaseItem.sales
		WHERE ((PKPurchaseItem.Status = 'Active') AND ( ISNULL(PKPurchaseItem.ResourceDate, '') != '')) ORDER BY TimeDate desc, TimeStart desc
	END
	ELSE
	BEGIN
		SELECT PKPurchaseItem.PurchaseItemId AS ID, PKPurchaseItem.CardNumber AS Card,  PKPurchaseItem.CardHolder AS Customer, Customer.Phone, PKPurchaseItem.ResourceTimeFrom AS TimeStart, PKPurchaseItem.ResourceTimeTo AS TimeEnd, 
		CAST(PKPurchaseItem.ResourceDate AS datetime) AS TimeDate, PKCategory.Name AS Category, 
		(CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2) END) AS ProductName, 
		PurchaseModifiers.Value AS Modifiers, PKPurchaseItem.Remark, Location.LocationName AS Location,
		pu.UserName as Sales,'' as SalesCommission,
		case lower(Customer.Gender) when 'male' then 'CustomerMale' when 'female' then 'CustomerFemale' else 'CustomerGender' end as CustomerGender,
		-----
		case cast(CustomerCard.CustomerID as varchar(50)) when @SuperCustomerId then 'Walk-In' else
			case lower(PKPurchaseItem.forceSales) when 'true' then 'Appointment' else 'Random' end
		end as [Type]
		-----
		FROM PKPurchaseItem
		INNER JOIN PKProduct ON PKProduct.ID = PKPurchaseItem.ProductId INNER JOIN PKCategory ON PKCategory.ID = PKProduct.CategoryID
		LEFT JOIN #tbl2 AS PurchaseModifiers on PurchaseModifiers.PurchaseItemId = PKPurchaseItem.PurchaseItemId
		INNER JOIN #tbl3 AS Location ON Location.PurchaseId = PKPurchaseItem.PurchaseId
		INNER JOIN Customer ON Customer.CustomerNo = PKPurchaseItem.CardNumber
		left outer join PKUsers PU on pu.EmployeeID = PKPurchaseItem.sales
		WHERE ((PKPurchaseItem.Status = 'Active') AND ( ISNULL(PKPurchaseItem.ResourceDate, '') != '')) ORDER BY TimeDate desc, TimeStart desc
	END

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookListByHour]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_GetBookListByHour]
	@locationId varchar(50),
	@CurrentDate varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	DECLARE @isMultiCard varchar(50);
	SELECT @isMultiCard = ISNULL(Value, 'false') FROM PKSetting WHERE FieldName = 'isBookingMultiCard';

	DECLARE @isGroupByEmployeeOrModifierEmployee varchar(50);
	SELECT @isGroupByEmployeeOrModifierEmployee = ISNULL(Value, 'true') FROM PKSetting WHERE FieldName = 'isGroupByEmployeeOrModifierEmployee';

	DECLARE @cols NVARCHAR(MAX)= N''
	DECLARE @colsUpdate NVARCHAR(MAX)= N''
	DECLARE @sql NVARCHAR(MAX)

	------------------------------------------------------------------------
	--purchase and locations.-------------------------------
	------------------------------------------------------------------------
	SELECT pkpurchasepackage.purchaseid, 
		   pklocation.locationname ,
		   pklocation.LocationID
	INTO   #tbl3 
	FROM   pkpurchasepackage 
		   LEFT JOIN pkpurchasepackageorder 
				  ON pkpurchasepackageorder.transferid = 
					 pkpurchasepackage.transferid 
		   LEFT JOIN pklocation 
				  ON pklocation.locationid = pkpurchasepackageorder.locationid 
	WHERE  pklocation.locationid LIKE @locationId 
	------------------------------------------------------------------------


		SELECT pkpurchaseitem.purchaseitemid                 AS ID, 
			   pkpurchaseitem.cardnumber                     AS Card, 
			   pkpurchaseitem.cardholder                     AS Customer, 
			   customer.phone, 
			   pkpurchaseitem.resourcetimefrom               AS TimeStart, 
			   pkpurchaseitem.resourcetimeto                 AS TimeEnd, 
			   pkpurchaseitem.sales,
			   pkpurchaseitem.forceSales,
			   Cast(pkpurchaseitem.resourcedate AS DATETIME) AS TimeDate, 
			   pkcategory.NAME                               AS Category, 
			   ( CASE 
				   WHEN Isnull(pkproduct.name2, '') = '' THEN pkproduct.name1 
				   ELSE ( pkproduct.name1 + ' / ' + pkproduct.name2 ) 
				 END )                                       AS ProductName, 
			   pkpurchaseitem.remark, 
			   Location.locationname                         AS Location,
			   pkpurchaseitem.updatedBy,
			   dbo.pk_FuncGetLocationPrice(pkpurchaseitem.ProductId,location.LocationID) as Price,
			   case lower(Customer.Gender) when 'male' then 'CustomerMale' when 'female' then 'CustomerFemale' else 'CustomerGender' end as customerGender
		into #tblAllItems
		FROM   pkpurchaseitem 
			   INNER JOIN pkproduct 
					   ON pkproduct.id = pkpurchaseitem.productid 
			   INNER JOIN pkcategory 
					   ON pkcategory.id = pkproduct.categoryid 
			   INNER JOIN #tbl3 AS Location 
					   ON Location.purchaseid = pkpurchaseitem.purchaseid 
			   INNER JOIN customercard 
					   ON customercard.cardno = pkpurchaseitem.cardnumber 
			   INNER JOIN customer 
					   ON customer.id = customercard.customerid 
		WHERE  ( ( pkpurchaseitem.status = 'Active' ) 
				 AND ( Isnull(pkpurchaseitem.resourcedate, '') != '' ) ) 
				 and cast( PKPurchaseItem.ResourceDate as smalldatetime) = cast(@CurrentDate as smalldatetime) 
		ORDER  BY timedate DESC, 
				  timestart DESC ;

		--select * from #tblAllItems;


END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookListCashOutReport]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetBookListCashOutReport]
	@locationId varchar(50),
	@dateStart varchar(50),
	@dateEnd varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 
	 
	declare 	@timeStart datetime
	declare @timeEnd datetime
	if len(@dateStart) <=12
	begin
		set @timeStart = cast(@dateStart + ' 00:01' as datetime)
		set @timeEnd =  cast(@dateEnd + ' 23:59' as datetime) 
	end
	else
	begin
		set @timeStart = cast(@dateStart  as datetime)
		set @timeEnd =  cast(@dateEnd  as datetime) 
	end

	select PPPP.paymentAmount,PPPP.paymentType --* --paymentAmount,paymentType
	into #tblPayType
	from PKPurchasePackagePayment PPPP
	inner  join PKPurchasePackagePaymentOrder PPPO on PPPo.id = PPPP.PaymentOrderId
	where paymentType <> 'Deposit'
	and PPPP.createTime between @timestart and @timeEnd
	and PPPO.Locationid = @locationId
	order by pppo.createTime desc;
	
	--select * from #tblPayType;

	select '' as flag,count(paymentAmount) as [count], paymentType as items, sum(paymentAmount) as amount, 'service1' as OrderA,'Operating Income' as OrderName,row_number() over (partition by '''' order by paymentType) as orderB
	into #tblA 
	from #tblPayType
	group by paymentType

	-------------------------------------------------------------------------------------
		SELECT PKPurchasePackageOrder.transferId, PKLocation.LocationName AS Location 
	INTO #tbl1 
	FROM PKPurchasePackageOrder
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId
	------------
	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl2 
	FROM PKPurchasePackagePayment 
	GROUP BY PaymentOrderID, Balance
	--------------------
	SELECT PKPurchasePackagePaymentItem.transferId 
	INTO #tbl3 
	FROM #tbl2 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID

	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)
	--------------------------
	select '' as flag, 	count(product) as [count], product as items, sum(price) as amount, 'service3' as OrderA,'Items Sold' as OrderName,row_number() over (partition by '''' order by product) as orderB
	into #tblB
	 from 
	(
		SELECT 
		distinct PKPurchasePackage.PurchaseId AS ID, 
		CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, 
		PKPurchasePackage.CardNumber AS Card,  
		PKPurchasePackage.CardHolders AS Customer, 
		(CASE WHEN ISNULL(PKPromotion.Name2, '') = '' THEN PKPromotion.Name1 ELSE (PKPromotion.Name1 + ' / ' + PKPromotion.Name2 ) END) AS Product,
		PKPurchasePackage.amount AS Price, 
		Location.Location,
		createdBy ,
		PU.UserName as Sales,
		 '' as SalesCommission,'' as CreateByCommission

		FROM PKPurchasePackage
		INNER JOIN PKPromotion ON PKPromotion.ID = PKPurchasePackage.BomOrProductID
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
		INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
		left outer join PKUsers PU on pu.EmployeeID = PKPurchasePackage.booker
		WHERE itemType = 'B' and PKPurchasePackage.Status = 'Active' 
			and PKPurchasePackage.CreateDate between @timestart and @timeEnd
		UNION
		(
			SELECT PKPurchasePackage.PurchaseId AS ID, 
			CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, 
			PKPurchasePackage.CardNumber AS Card,  
			PKPurchasePackage.CardHolders AS Customer, 
			(CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2 ) END) AS Product,
			PKPurchasePackage.amount AS Price, 
			Location.Location,createdBy , 
			PU.UserName as Sales, 
			'' as SalesCommission,
			'' as CreateByCommission
			FROM PKPurchasePackage
			INNER JOIN PKProduct ON PKProduct.ID = PKPurchasePackage.BomOrProductID
			INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
			INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
			left outer join PKUsers PU on pu.EmployeeID = PKPurchasePackage.booker
			WHERE itemType = 'P' and PKPurchasePackage.Status = 'Active' and PKPurchasePackage.CreateDate between @timestart and @timeEnd

		) 
	) as a

	group by product 
	-------------------------------------------------------------------------------------

	select  '' as flag,
	count(ppot.TaxName) as [count], ppot.TaxName as items, sum(ppot.Amount) as amount, 'service2' as OrderA,'Taxes' as OrderName,row_number() over (partition by '''' order by ppot.TaxName) as orderB
	into #tblC
	from PKPurchasePackageOrderTax PPOT
	inner join PKPurchasePackageOrder ppo on ppo.transferId = ppot.transferId
	inner join PKPurchasePackagePaymentItem pppI on pppi.transferId = ppo.transferId
	where ppot.createTime between @timestart and @timeEnd
	group by ppot.TaxName
	-------------------------------------------------------------------------------------

	select * from #tblA
	union
	select * from #tblB
	union
	select * from #tblC
	order by OrderA, items



	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
	drop table #tblPayType

	DROP TABLE #tblA;
	DROP TABLE #tblB;
	DROP TABLE #tblC;

END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookListSummary]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_GetBookListSummary]
	@locationId varchar(50),
	@startTime varchar(50),
	@endTime varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	
	DECLARE @isMultiCard varchar(50);
	SELECT @isMultiCard = ISNULL(Value, 'false') FROM PKSetting WHERE FieldName = 'isBookingMultiCard';

	DECLARE @isGroupByEmployeeOrModifierEmployee varchar(50);
	SELECT @isGroupByEmployeeOrModifierEmployee = ISNULL(Value, 'true') FROM PKSetting WHERE FieldName = 'isGroupByEmployeeOrModifierEmployee';

	DECLARE @cols NVARCHAR(MAX)= N''
	DECLARE @colsUpdate NVARCHAR(MAX)= N''
	DECLARE @sql NVARCHAR(MAX)
	------------------------------------------------------------------------
	--purchase item and single modifier Name.-------------------------------
	------------------------------------------------------------------------
	SELECT distinct pkpurchaseitemmodifier.purchaseitemid, 
		   pkmodifieritem.name1 + ' ' 
		   + pkmodifieritem.name2 AS name1, 
		   pkpurchaseitem.resourcedate, 
		   pkpurchaseitem.resourcetimefrom ,
		   pkmodifieritem.modifiergroupid,
		   PKModifierGroup.name1 + ' ' 
		   + PKModifierGroup.name2 AS modifierGroupName,
		   pkpurchaseitemmodifier.modifieritemid,
		   PKModifierGroup.Type as mgType,
		   PKEmployee.FirstName,
		   case lower(PKEmployee.Gender) when 'male' then 'Worker Male' when 'female' then 'Worker Female' else PKEmployee.Gender end as Gender
	INTO   #tbl1 
	FROM   pkpurchaseitemmodifier 
		   INNER JOIN pkpurchaseitem 
				   ON pkpurchaseitem.purchaseitemid = 
					  pkpurchaseitemmodifier.purchaseitemid 
		   
		   LEFT JOIN pkmodifieritem 
				  ON pkmodifieritem.id = pkpurchaseitemmodifier.modifieritemid 
		   inner join PKModifierGroup on PKModifierGroup.id = pkmodifieritem.ModifierGroupID
		   left outer join PKEmployee on PKEmployee.id = pkpurchaseitemmodifier.modifieritemid

	--where cast( PKPurchaseItem.ResourceDate + ' ' +  PKPurchaseItem.ResourceTimeFrom as smalldatetime) between cast(@starttime as smalldatetime) and cast(@endtime as smalldatetime)
	ORDER  BY pkmodifieritem.modifiergroupid ;

	--select * from #tbl1;

	------------------------------------------------------------------------
	--purchase item and related all modifiers Names.-------------------------------
	------------------------------------------------------------------------
	SELECT purchaseitemid, 
		   [Value]=Stuff((SELECT DISTINCT ', ' + [name1] 
						  FROM   #tbl1 AS Temp2 
						  WHERE  Temp2.purchaseitemid = Temp1.purchaseitemid 
						  FOR xml path('')), 1, 2, '') 
	INTO   #tbl2 
	FROM   #tbl1 AS Temp1 
	GROUP  BY purchaseitemid 
	------------------------------------------------------------------------
	--purchase and locations.-------------------------------
	------------------------------------------------------------------------
	SELECT pkpurchasepackage.purchaseid, 
		   pklocation.locationname ,
		   pklocation.LocationID
	INTO   #tbl3 
	FROM   pkpurchasepackage 
		   LEFT JOIN pkpurchasepackageorder 
				  ON pkpurchasepackageorder.transferid = 
					 pkpurchasepackage.transferid 
		   LEFT JOIN pklocation 
				  ON pklocation.locationid = pkpurchasepackageorder.locationid 
	WHERE  pklocation.locationid LIKE @locationId 
	
	--select * from #tbl1 order by cast(ResourceDate  as datetime) desc;
	--select * from #tbl2 order by PurchaseItemId;
	--select * from #tbl3 where purchaseid = '3D31EAD3-1AED-4445-B7A5-F7874344FAEF'
	-- order by purchaseid;

	------------------------------------------------------------------------
	--Related product id and product names.-------------------------------
	------------------------------------------------------------------------
	
	select distinct ppi.ProductId, 
		( CASE WHEN Isnull(pp.name2, '') = '' THEN pp.name1 
		   ELSE ( pp.name1 + ' / ' + pp.name2 ) 
		END ) AS ProductName
	into #tblAllProductsBooked
	from PKPurchaseItem ppI
	inner join PKProduct pp on ppi.ProductId = pp.ID
	WHERE  ( ( ppI.status = 'Active' ) 
				 AND ( Isnull(ppI.resourcedate, '') != '' ) ) ;

	--select * from #tblAllProductsBooked;
	--------------------------------------------------------------------------
	-- Different settings. multi Card or single vip card.---------------------
	--------------------------------------------------------------------------
	IF LOWER(@isMultiCard) = 'true'
	BEGIN
		----------------------------------------------------------------------
		---select all the related data together.------------------------------
		----------------------------------------------------------------------
		SELECT pkpurchaseitem.purchaseitemid                 AS ID, 
			   pkpurchaseitem.cardnumber                     AS Card, 
			   pkpurchaseitem.cardholder                     AS Customer, 
			   customer.phone, 
			   pkpurchaseitem.resourcetimefrom               AS TimeStart, 
			   pkpurchaseitem.resourcetimeto                 AS TimeEnd, 
			   Cast(pkpurchaseitem.resourcedate AS DATETIME) AS TimeDate, 
			   pkcategory.NAME                               AS Category, 
			   ( CASE 
				   WHEN Isnull(pkproduct.name2, '') = '' THEN pkproduct.name1 
				   ELSE ( pkproduct.name1 + ' / ' + pkproduct.name2 ) 
				 END )                                       AS ProductName, 
			   PurchaseModifiers.value                       AS Modifiers, 
			   pkpurchaseitem.remark, 
			   Location.locationname                         AS Location,
			   pkpurchaseitem.updatedBy,
			   dbo.pk_FuncGetLocationPrice(pkpurchaseitem.ProductId,location.LocationID) as Price,
			   case lower(Customer.Gender) when 'male' then 'CustomerMale' when 'female' then 'CustomerFemale' else 'CustomerGender' end as customerGender
			   into #tblAllMultiCard
		FROM   pkpurchaseitem 
			   INNER JOIN pkproduct 
					   ON pkproduct.id = pkpurchaseitem.productid 
			   INNER JOIN pkcategory 
					   ON pkcategory.id = pkproduct.categoryid 
			   LEFT JOIN #tbl2 AS PurchaseModifiers 
					  ON PurchaseModifiers.purchaseitemid = 
						 pkpurchaseitem.purchaseitemid 
			   INNER JOIN #tbl3 AS Location 
					   ON Location.purchaseid = pkpurchaseitem.purchaseid 
			   INNER JOIN customercard 
					   ON customercard.cardno = pkpurchaseitem.cardnumber 
			   INNER JOIN customer 
					   ON customer.id = customercard.customerid 
		WHERE  ( ( pkpurchaseitem.status = 'Active' ) 
				 AND ( Isnull(pkpurchaseitem.resourcedate, '') != '' ) ) 
				 and cast( PKPurchaseItem.ResourceDate + ' ' +  PKPurchaseItem.ResourceTimeFrom as smalldatetime) between cast(@starttime as smalldatetime) and cast(@endtime as smalldatetime)
		ORDER  BY timedate DESC, 
				  timestart DESC ;
		
		--select * from #tblAllMultiCard ;--where id = '2083E23B-1279-4524-A199-F6E7FE84A9EF';

		--if @isGroupByEmployeeOrModifierEmployee = 'true'
		--begin
		---------------------------------------------------------------------
		--the relationship of the last updator and the productName.
		---------------------------------------------------------------------	
			select ProductName, isnull(updatedBy,'VOID') as updatedBy, count(isnull(updatedBy,'VOID'))  as itemCount--,sum(price) as Price
			into #tblService1
			from #tblAllMultiCard 
			group by updatedBy,ProductName

		--end

		---------------------------------------------------------------------
		--the relationship of the last updator and the modifiers.
		--Cannot distict here
		---------------------------------------------------------------------	

		select isnull(updatedby,'VOID') as updatedBy, isnull(modifierName,'VOID') as ProductName, count(isnull(modifierName,'VOID'))  as itemCount, isnull(gName,'VOID') as gName--,sum(price) as Price,'2service' as orderA, row_number() over (partition by '' order by modifierName) as orderB
			into #tblservice2a
		from (
			select tam.* ,t1.name1 as modifierName,t1.modifierGroupName as gName
			from #tblAllMultiCard tam 
			left outer join #tbl1 t1 on t1.PurchaseItemId = tam.ID
			) as tbla
		group by updatedby,modifierName,gName

		---------------------------------------------------------------------
		--the relationship of the last updator and the modifiers.
		--Cannot distict here
		---------------------------------------------------------------------	
			select customerGender as productName, isnull(updatedBy,'VOID') as updatedBy, count(isnull(updatedBy,'VOID'))  as itemCount--,sum(price) as Price
			into #tblService3
			from #tblAllMultiCard 
			group by updatedBy,customerGender

		---------------------------------------------------------------------
		--the relationship of the last updator and the modifierGender.
		--
		---------------------------------------------------------------------	
		---------------------------------------------------------------------	
		---------------------------------------------------------------------	
		--BEGIN TRY
			select isnull(updatedby,'VOID') as updatedBy, isnull(Gender,'VOID') as ProductName, count(isnull(Gender,'VOID'))  as itemCount--,sum(price) as Price,'2service' as orderA, row_number() over (partition by '' order by modifierName) as orderB
				into #tblservice4
			from (
				select tam.* ,t1.Gender
				from #tblAllMultiCard tam 
				inner join #tbl1 t1 on t1.PurchaseItemId = tam.ID
				where t1.Gender is not null
				) as tbla
			group by updatedby,Gender

			---------------------------------------------------------------------		---------------------------------------------------------------------	
			--select * from #tblService1;
			--select * from #tblservice4;
			

		--end try
		--begin catch
			
		--end catch
		---------------------------------------------------------------------
		---------------------------------------------------------------------
		---------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the product name , and the income.
		--Begin Pivot------------------------------------------------------------------
		---------------------------------------------------------------------	
		SELECT @cols = @cols + iif(@cols = N'',N'['+updatedby+N']',N',[' + updatedby+N']')
		FROM 
		(
			--select pu.UserName  as updatedby 
			--from PKUsers PU 
			--inner join PKEmployee pE on pe.ID = PU.EmployeeID
			SELECT DISTINCT(isnull(updatedby,'VOID'))  as updatedby 
			FROM pkpurchaseitem 
		) t order by updatedby

		--print @cols;

		SELECT @colsUpdate = @colsUpdate + iif(@colsUpdate = N'',N' isnull(['+updatedby+N'],0)',N'+ isnull([' + updatedby+N'],0)')
		FROM 
		(
			--select pu.UserName  as updatedby 
			--from PKUsers PU 
			--inner join PKEmployee pE on pe.ID = PU.EmployeeID
			SELECT DISTINCT(isnull(updatedby,'VOID'))  as updatedby 
			FROM pkpurchaseitem 
			
		) t order by updatedby
		------------------------------------------------------------------------

		SET @sql = N'
		select '''' as flag,''service1'' as orderA, dbo.inttohex(row_number() over (partition by '''' order by ProductName)) as orderB, * ,0 as total
		into ##tblPart1
		from #tblService1
		PIVOT
		(
		  SUM(itemCount) 
		  FOR updatedby
		  IN ('
		  + @cols
		  + ')

		) AS t ;
		
		'
		EXEC sp_executesql @sql
		---------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the modifiers , and the income.
		--Begin Pivot--------------------------------------------------------
		--The total count here is meaningless. becuase the modifier might overlap the records.
		---------------------------------------------------------------------	
		SET @sql = N'
		select '''' as flag,''service2'' as orderA, dbo.inttohex(row_number() over (partition by '''' order by ProductName)) as orderB, 
		*,
		
		0 as total
		into ##tblpart2a
		from #tblservice2a
		PIVOT
		(
		  SUM(itemCount) 
		  FOR updatedby
		  IN ('
		  + @cols
		  + ')
		) AS t  order by gname desc'
		EXEC sp_executesql @sql
		

		
		SET @sql = N'
		select '''' as flag,''service2'' as orderA, row_number() over (partition by '''' order by gname desc) as orderB, productName,
		'
		  + @cols
		  + ',
		
		0 as total
		into ##tblpart2
		from ##tblpart2a
		 '

		EXEC sp_executesql @sql

	
		---------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the customer Gender , and the income.
		--Begin Pivot--------------------------------------------------------
		--
		---------------------------------------------------------------------	
		SET @sql = N'
		select '''' as flag,''service3'' as orderA, row_number() over (partition by '''' order by productName) as orderB, * ,0 as total
		into ##tblpart3
		from #tblservice3
		PIVOT
		(
		  SUM(itemCount) 
		  FOR updatedby
		  IN ('
		  + @cols
		  + ')
		) AS t'
		EXEC sp_executesql @sql

		--------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the worker's gender.
		--Begin Pivot--------------------------------------------------------
		---------------------------------------------------------------------	
		SET @sql = N'
		select '''' as flag,''service4'' as orderA, row_number() over (partition by '''' order by productName) as orderB, * ,0 as total
		into ##tblpart4
		from #tblservice4
		PIVOT
		(
			SUM(itemCount) 
			FOR updatedby
			IN ('
			+ @cols
			+ ')
		) AS t'
		EXEC sp_executesql @sql	

			

		---------------------------------------------------------------------------------

		if len(@colsUpdate)>0
		begin
			set @sql = N'
				update ##tblPart1 set total = total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql

			set @sql = N'
				update ##tblpart2 set total = total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql

			set @sql = N'
				update ##tblpart3 set total = total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql

			set @sql = N'
				update ##tblpart4 set total = total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql
		end
		---------------------------------------------------------------------------------
		--select * from ##tblpart3
		--select * from ##tblpart4


		---------------------------------------------------------------------------------
		select * 
		into #tblPartTotal 
		from (
			select * from ##tblpart1
			union
			select * from ##tblpart2
			union
			select * from ##tblpart3
			union
			select * from ##tblpart4
		) a
		
		
		--select * from ##tblpart1;

		select * from #tblPartTotal order by orderA asc, orderb;

		drop table ##tblpart1;
		drop table ##tblpart2;
		drop table ##tblpart2a;
		drop table ##tblpart3;
		drop table ##tblpart4;
		drop table #tblPartTotal;
		-------------------------------------------------------------------------
		--select * from #tblAllMultiCard;
		drop table #tblAllMultiCard;
		drop table #tblService1;
		drop table #tblservice2a;
		drop table #tblservice3;
		drop table #tblservice4;
	END
	ELSE
	BEGIN


		SELECT pkpurchaseitem.purchaseitemid                 AS ID, 
			   pkpurchaseitem.cardnumber                     AS Card, 
			   pkpurchaseitem.cardholder                     AS Customer, 
			   customer.phone, 
			   pkpurchaseitem.resourcetimefrom               AS TimeStart, 
			   pkpurchaseitem.resourcetimeto                 AS TimeEnd, 
			   Cast(pkpurchaseitem.resourcedate AS DATETIME) AS TimeDate, 
			   pkcategory.NAME                               AS Category, 
			   ( CASE 
				   WHEN Isnull(pkproduct.name2, '') = '' THEN pkproduct.name1 
				   ELSE ( pkproduct.name1 + ' / ' + pkproduct.name2 ) 
				 END )                                       AS ProductName, 
			   PurchaseModifiers.value                       AS Modifiers, 
			   pkpurchaseitem.remark, 
			   Location.locationname                         AS Location,
			   pkpurchaseitem.updatedBy
			   into #tblAllNoMultiCard
		FROM   pkpurchaseitem 
			   INNER JOIN pkproduct 
					   ON pkproduct.id = pkpurchaseitem.productid 
			   INNER JOIN pkcategory 
					   ON pkcategory.id = pkproduct.categoryid 
			   LEFT JOIN #tbl2 AS PurchaseModifiers 
					  ON PurchaseModifiers.purchaseitemid = 
						 pkpurchaseitem.purchaseitemid 
			   INNER JOIN #tbl3 AS Location 
					   ON Location.purchaseid = pkpurchaseitem.purchaseid 
			   INNER JOIN customer 
					   ON customer.customerno = pkpurchaseitem.cardnumber 
		WHERE  ( ( pkpurchaseitem.status = 'Active' ) 
				 AND ( Isnull(pkpurchaseitem.resourcedate, '') != '' ) ) 
		ORDER  BY timedate DESC, 
				  timestart DESC ;
		

		drop table #tblAllNoMultiCard;

	END

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
	drop table #tblAllProductsBooked;



END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookListSummary2]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetBookListSummary2]
	@locationId varchar(50),
	@startTime varchar(50),
	@endTime varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 
	-----------------
	DECLARE @isMultiCard varchar(50);
	SELECT @isMultiCard = ISNULL(Value, 'false') FROM PKSetting WHERE FieldName = 'isBookingMultiCard';
	-----------------
	DECLARE @isGroupByEmployeeOrModifierEmployee varchar(50);
	SELECT @isGroupByEmployeeOrModifierEmployee = ISNULL(Value, 'true') FROM PKSetting WHERE FieldName = 'isGroupByEmployeeOrModifierEmployee';
	-----------------
	DECLARE @SuperCustomerId varchar(50);
	SELECT @SuperCustomerId = ISNULL(Value, '') FROM PKSetting WHERE FieldName = 'SuperVIPIdForWalkIn';
	-----------------
	DECLARE @cols NVARCHAR(MAX)= N''
	DECLARE @colsUpdate NVARCHAR(MAX)= N''
	DECLARE @sql NVARCHAR(MAX)

	declare @decTotal decimal(18,2);
	set @decTotal = 0;
	------------------------------------------------------------------------
	--purchase and locations.-------------------------------
	------------------------------------------------------------------------
	SELECT pkpurchasepackage.purchaseid, 
		   pklocation.locationname ,
		   pklocation.LocationID
	INTO   #tbl3 
	FROM   pkpurchasepackage 
		   LEFT JOIN pkpurchasepackageorder 
				  ON pkpurchasepackageorder.transferid = 
					 pkpurchasepackage.transferid 
		   LEFT JOIN pklocation 
				  ON pklocation.locationid = pkpurchasepackageorder.locationid 
	WHERE  pklocation.locationid LIKE @locationId 
	------------------------------------------------------------------------
		SELECT pkpurchaseitem.purchaseitemid                 AS ID, 
			   pkpurchaseitem.cardnumber                     AS Card, 
			   pkpurchaseitem.cardholder                     AS Customer, 
			   customer.phone, 
			   pkpurchaseitem.resourcetimefrom               AS TimeStart, 
			   pkpurchaseitem.resourcetimeto                 AS TimeEnd, 
			   pkpurchaseitem.sales,
			   pkpurchaseitem.forceSales,
			   PKPurchaseItem.booker,
			   Cast(pkpurchaseitem.resourcedate AS DATETIME) AS TimeDate, 
			   pkcategory.NAME                               AS Category, 
			   ( CASE 
				   WHEN Isnull(pkproduct.name2, '') = '' THEN pkproduct.name1 
				   ELSE ( pkproduct.name1 + ' / ' + pkproduct.name2 ) 
				 END )                                       AS ProductName, 
			   pkpurchaseitem.remark, 
			   Location.locationname                         AS Location,
			   pkpurchaseitem.updatedBy,
			   dbo.pk_FuncGetLocationPrice(pkpurchaseitem.ProductId,location.LocationID) as Price,
			   case lower(Customer.Gender) when 'male' then 'Male Customer' when 'female' then 'Female Customer' else 'CustomerGender' end as customerGender,
			   Customer.id as customerId,
			   PKPurchaseItem.packsize
		into #tblAllItems
		FROM   pkpurchaseitem 
			   INNER JOIN pkproduct 
					   ON pkproduct.id = pkpurchaseitem.productid 
			   INNER JOIN pkcategory 
					   ON pkcategory.id = pkproduct.categoryid 
			   INNER JOIN #tbl3 AS Location 
					   ON Location.purchaseid = pkpurchaseitem.purchaseid 
			   INNER JOIN customercard 
					   ON customercard.cardno = pkpurchaseitem.cardnumber 
			   INNER JOIN customer 
					   ON customer.id = customercard.customerid 
		WHERE  ( ( pkpurchaseitem.status = 'Active' ) 
				 AND ( Isnull(pkpurchaseitem.resourcedate, '') != '' ) ) 
				 and cast( PKPurchaseItem.ResourceDate + ' ' +  PKPurchaseItem.ResourceTimeFrom as smalldatetime) between cast(@starttime as smalldatetime) and cast(@endtime as smalldatetime)
				 
		ORDER  BY timedate DESC, 
				  timestart DESC ;
		--select * from #tblAllItems;
		---------------------------------------------------------------------
		------------------------------------------------------------------------
		SELECT pkpurchaseitem.purchaseitemid                 AS ID, 
			   pkpurchaseitem.cardnumber                     AS Card, 
			   pkpurchaseitem.cardholder                     AS Customer, 
			   customer.phone, 
			   pkpurchaseitem.resourcetimefrom               AS TimeStart, 
			   pkpurchaseitem.resourcetimeto                 AS TimeEnd, 
			   pkpurchaseitem.sales,
			   pkpurchaseitem.forceSales,
			   PKPurchaseItem.booker,
			   Cast(pkpurchaseitem.resourcedate AS DATETIME) AS TimeDate, 
			   pkcategory.NAME                               AS Category, 
			   ( CASE 
				   WHEN Isnull(pkproduct.name2, '') = '' THEN pkproduct.name1 
				   ELSE ( pkproduct.name1 + ' / ' + pkproduct.name2 ) 
				 END )                                       AS ProductName, 
			   pkpurchaseitem.remark, 
			   Location.locationname                         AS Location,
			   pkpurchaseitem.updatedBy,
			   dbo.pk_FuncGetLocationPrice(pkpurchaseitem.ProductId,location.LocationID) as Price,
			   case lower(Customer.Gender) when 'male' then 'Male Customer' when 'female' then 'Female Customer' else 'CustomerGender' end as customerGender,
			   PKPurchaseItem.packsize
		into #tblAllItemsBooker
		FROM   pkpurchaseitem 
			   INNER JOIN pkproduct 
					   ON pkproduct.id = pkpurchaseitem.productid 
			   INNER JOIN pkcategory 
					   ON pkcategory.id = pkproduct.categoryid 
			   INNER JOIN #tbl3 AS Location 
					   ON Location.purchaseid = pkpurchaseitem.purchaseid 
			   INNER JOIN customercard 
					   ON customercard.cardno = pkpurchaseitem.cardnumber 
			   INNER JOIN customer 
					   ON customer.id = customercard.customerid 
		WHERE  ( pkpurchaseitem.status = 'Active' ) 
				 
				 and PKPurchaseItem.CreateDate between cast(@starttime as smalldatetime) and cast(@endtime as smalldatetime)
		ORDER  BY timedate DESC, 
				  timestart DESC ;
		--select * from #tblAllItems;
		---------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the product name , and the income.
		--Begin Pivot------------------------------------------------------------------
		---------------------------------------------------------------------	
		SELECT @cols = @cols + iif(@cols = N'',N'['+sales+N']',N',[' + sales+N']')
		FROM 
		(
			select pu.EmployeeID as sales 
			from PKUsers PU 
			inner join PKEmployee pE on pe.ID = PU.EmployeeID

			union

			select 'NO ONE' as salse
			--SELECT DISTINCT(case isnull(sales,'NO ONE') when '' then 'NO ONE' else isnull(sales,'NO ONE') end)  as sales 
			--FROM pkpurchaseitem 
		) t order by sales
		--print @cols;
		SELECT @colsUpdate = @colsUpdate + iif(@colsUpdate = N'',N' cast(isnull(['+sales+N'],0) as decimal(18,2))',N'+ cast(isnull([' + sales+N'],0)as decimal(18,2))')
		FROM 
		(
			select pu.EmployeeID as sales 
			from PKUsers PU 
			inner join PKEmployee pE on pe.ID = PU.EmployeeID
			
			union

			select 'NO ONE' as salse

			--SELECT DISTINCT(case isnull(sales,'NO ONE') when '' then 'NO ONE' else isnull(sales,'NO ONE') end)  as sales 
			--FROM pkpurchaseitem 
			
		) t order by sales
		--print @cols
		--print @colsUpdate
		---------------------------------------------------------------------
		--the sales and the count
		--
		---------------------------------------------------------------------	
		select ProductName as Items,case isnull(sales,'NO ONE') when '' then 'NO ONE' else isnull(sales,'NO ONE') end as sales, sum(cast(packsize as decimal(18,2))) as itemCount --count(isnull(sales,'NO ONE')) as itemCount
		INTO #tblService1
		from #tblAllItems 
		group by productname, sales
		---------------------------------------------------------------------	
		select ProductName as Items,case isnull(booker,'NO ONE') when '' then 'NO ONE' else isnull(booker,'NO ONE') end as sales, sum(price) as itemCount --count(isnull(booker,'NO ONE')) as itemCount --count(cast(packsize as decimal(18,2))) as itemCount
		INTO #tblService2
		from #tblAllItemsBooker 
		group by productname, booker
		---------------------------------------------------------------------
		--select * ,cast(packsize as decimal(18,2)) as a
		--from #tblAllItems
		--select * from #tblService1;
		--select * from #tblService2;

		--the relationship of the last updator and the modifiers.
		--Cannot distict here
		---------------------------------------------------------------------	
		select customerGender  as Items, case isnull(sales,'NO ONE') when '' then 'NO ONE' else isnull(sales,'NO ONE') end as sales, count(isnull(sales,'NO ONE'))  as itemCount--,sum(price) as Price
		INTO #tblService5	
		from #tblAllItems 
		group by sales,customerGender
		---------------------------------------------------------------------	
		--the random and ByAppointment.
		--
		---------------------------------------------------------------------	
		select 
		case customerId when @SuperCustomerId then 'Walk-In' else 
			case forceSales when 'true' then 'Force' else 'Random' end 
		end
		as Items, 

		case isnull(sales,'NO ONE') when '' then 'NO ONE' else isnull(sales,'NO ONE') end as sales, 
		count(isnull(sales,'NO ONE'))  as itemCount--,sum(price) as Price
		INTO #tblService4
		from #tblAllItems 
		group by sales,forceSales,customerId
		---------------------------------------------------------------------	
		--the paid card and the sales.
		--
		---------------------------------------------------------------------	
		SELECT PKPurchasePackageOrder.transferId, PKLocation.LocationName AS Location 
		INTO #tblA1 
		FROM PKPurchasePackageOrder
		LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
		WHERE PKLocation.LocationID like @locationId
		------------
		SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
		INTO #tblA2 
		FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance
		--------------
		SELECT PKPurchasePackagePaymentItem.transferId 
		INTO #tblA3 
		FROM #tblA2 as PaymentOrder 
		INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
		WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)
		--------------
		select [TYPE] as Items, case isnull(sales,'NO ONE') when '' then 'NO ONE' else isnull(sales,'NO ONE') end as sales, SUM(price)  as itemCount--,sum(price) as Price
		INTO #tblService3
		from(
				SELECT PKPrepaidPackageTransaction.ID AS ID, PKPrepaidPackageTransaction.CreateTime AS TimeDate, PKPrepaidPackageTransaction.CardNumber AS Card, 
				PKPrepaidPackageTransaction.CardHolders AS Customer, PKPrepaidPackageTransaction.Price, PKPrepaidPackageTransaction.Deposit, PKPrepaidPackage.Name1 + ' ' + PKPrepaidPackage.Name2  AS Type,
				PKPrepaidPackageTransaction.CreateBy, Location.Location ,PKPrepaidPackageTransaction.sales
				FROM PKPrepaidPackageTransaction
				INNER JOIN PKPrepaidPackage ON PKPrepaidPackage.ID = PKPrepaidPackageTransaction.PrepaidPackageID
				INNER JOIN #tblA1 AS Location ON Location.transferId = PKPrepaidPackageTransaction.transferId
				INNER JOIN #tblA3 AS Payment ON payment.transferId = PKPrepaidPackageTransaction.transferId
				UNION
				(
					SELECT PKGiftCardTransaction.ID AS ID, PKGiftCardTransaction.CreateTime AS TimeDate, PKGiftCardTransaction.CardNumber AS Card, 
					PKGiftCardTransaction.CardHolders AS Customer, PKGiftCardTransaction.Price, PKGiftCardTransaction.Deposit, PKGiftCard.Name1 + ' ' + PKGiftCard.Name2  AS Type,
					PKGiftCardTransaction.CreateBy, Location.Location,PKGiftCardTransaction.sales
					FROM PKGiftCardTransaction
					INNER JOIN PKGiftCard ON PKGiftCard.ID = PKGiftCardTransaction.GiftCardId
					INNER JOIN #tblA1 AS Location ON Location.transferId = PKGiftCardTransaction.transferId
					INNER JOIN #tblA3 AS Payment ON payment.transferId = PKGiftCardTransaction.transferId
				)
				UNION
				(
					SELECT PKDepositPackageTransaction.ID AS ID, PKDepositPackageTransaction.CreateTime AS TimeDate, PKDepositPackageTransaction.CardNumber AS Card, 
					PKDepositPackageTransaction.CardHolders AS Customer, PKDepositPackageTransaction.Price, PKDepositPackageTransaction.Deposit, PKDepositPackage.Name1 + ' ' + PKDepositPackage.Name2  AS Type,
					PKDepositPackageTransaction.CreateBy, Location.Location ,PKDepositPackageTransaction.sales
					FROM PKDepositPackageTransaction
					INNER JOIN PKDepositPackage ON PKDepositPackage.ID = PKDepositPackageTransaction.PrepaidPackageID
					INNER JOIN #tblA1 AS Location ON Location.transferId = PKDepositPackageTransaction.transferId
					INNER JOIN #tblA3 AS Payment ON payment.transferId = PKDepositPackageTransaction.transferId
					where PKDepositPackageTransaction.Status = 'Active'
				) 
		) AS A
		group by sales,[Type]
	--select * from #tblService1
	--select * from #tblService2
	--select * from #tblService3

	
	--select * from #tblService4
		SET @sql = N'
		select '''' as flag,''service1'' as orderA, row_number() over (partition by '''' order by Items) as orderB, * ,099999999.01 as Total
		into ##tblPart1
		from #tblService1
		PIVOT
		(
		  SUM(itemCount) 
		  FOR sales
		  IN ('
		  + @cols
		  + ')
		) AS t ;
		
		'
		EXEC sp_executesql @sql
		
		---------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the modifiers , and the income.
		--Begin Pivot--------------------------------------------------------
		--The total count here is meaningless. becuase the modifier might overlap the records.
		---------------------------------------------------------------------	
		SET @sql = N'
		select '''' as flag,''service2'' as orderA, row_number() over (partition by '''' order by Items) as orderB, * ,0 as Total
		into ##tblPart2
		from #tblService2
		PIVOT
		(
		  SUM(itemCount) 
		  FOR sales
		  IN ('
		  + @cols
		  + ')
		) AS t ;
		
		'
		--print @sql
		EXEC sp_executesql @sql
	
	    --select * from ##tblpart2;
		---------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the customer Gender , and the income.
		--Begin Pivot--------------------------------------------------------
		--
		---------------------------------------------------------------------	
		SET @sql = N'
		select '''' as flag,''service3'' as orderA, row_number() over (partition by '''' order by Items) as orderB, * ,0 as Total
		into ##tblpart3
		from #tblservice3
		PIVOT
		(
		  SUM(itemCount) 
		  FOR sales
		  IN ('
		  + @cols
		  + ')
		) AS t'
		EXEC sp_executesql @sql
		--------------------------------------------------------------------
		--ROW TO COLUMNS. the last updator , the worker's gender.
		--Begin Pivot--------------------------------------------------------
		---------------------------------------------------------------------	
		SET @sql = N'
		select '''' as flag,''service4'' as orderA, row_number() over (partition by '''' order by Items) as orderB, * ,0 as Total
		into ##tblpart4
		from #tblservice4
		PIVOT
		(
			SUM(itemCount) 
			FOR sales
			IN ('
			+ @cols
			+ ')
		) AS t'
		EXEC sp_executesql @sql	
		-----------------------------------------------------------------------------------
		SET @sql = N'
		select '''' as flag,''service5'' as orderA, row_number() over (partition by '''' order by Items) as orderB, * ,0 as Total
		into ##tblpart5
		from #tblservice5
		PIVOT
		(
			SUM(itemCount) 
			FOR sales
			IN ('
			+ @cols
			+ ')
		) AS t'
		EXEC sp_executesql @sql	
		-----------------------------------------------------------------------------------		if len(@colsUpdate)>0
		begin
			--select * from ##tblPart1
			set @sql = N'
				update ##tblPart1 set Total = Total + '+ @colsUpdate +N'
			'
			update ##tblPart1 set Total = 0;

			EXEC sp_executesql @sql

			set @sql = N'
				update ##tblpart2 set Total = Total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql
			set @sql = N'
				update ##tblpart3 set Total = Total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql
			set @sql = N'
				update ##tblpart4 set Total = Total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql
			set @sql = N'
				update ##tblpart5 set Total = Total + '+ @colsUpdate +N'
			'
			EXEC sp_executesql @sql		end
		-----------------------------------------------------------------------------------
		--select * from ##tblPart1
		--select * from ##tblPart2
		--select * from ##tblPart3
		--select * from ##tblPart4
		-----------------------------------------------------------------------------------
		select * 
		into #tblPartTotal 
		from (
			select * from ##tblpart1
			union
			select * from ##tblpart2
			union
			select * from ##tblpart3
			union
			select * from ##tblpart4
			union
			select * from ##tblpart5
		) a
		
		
		select * from #tblPartTotal order by orderA asc, orderb;


		drop table ##tblpart1;
		drop table ##tblpart2;
		drop table ##tblpart3;
		drop table ##tblpart4;
		drop table ##tblpart5;
		drop table #tblPartTotal;
		---------------------------------------------------------------------------
		----select * from #tblAllMultiCard;
		--drop table #tblAllMultiCard;
		drop table #tblService1;
		drop table #tblservice2;
		drop table #tblservice3;
		drop table #tblservice4;
		drop table #tblservice5;
	
		DROP TABLE #tbl3;
		--drop table #tblAllProductsBooked;
		drop table #tblAllItems;
		drop table #tblAllItemsBooker;
		drop table #tblA1;
		drop table #tblA2;
		drop table #tblA3;

END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookPackageList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetBookPackageList]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	SELECT PKPromotionProduct.ID, PKPromotionProduct.PromotionID, PKPromotionProduct.ProductID, PKProduct.PLU, PKProduct.Name1 AS Name, PKPromotionProduct.PromotionUnitPrice AS RPrice, 
	PKPromotionProduct.Qty INTO #tbl1 FROM PKPromotionProduct 

	INNER JOIN PKProduct ON PKProduct.ID = PKPromotionProduct.ProductID
	inner join PKCategory Pc on pc.ID = PKProduct.CategoryID
	inner join PKDepartmentPMS PDP on pdp.id = pc.DepartmentID

	SELECT PromotionID, [Value]=stuff((  
	SELECT ',' + [Name] + '  x' + CONVERT(varchar(10), Qty) FROM #tbl1 as Temp2 WHERE Temp2.PromotionID = Temp1.PromotionID FOR XML PATH('')),1,1,'') INTO #tbl2 FROM #tbl1 AS Temp1  
	GROUP BY PromotionID 

	SELECT distinct PKPromotion.ID, PKPromotion.Name1, PKPromotion.Name2, PKPromotion.Barcode, PKPromotion.Type, PKPromotion.Remarks, PKPromotion.StartDate, PKPromotion.ExpireDate, PKPromotion.Status, PKPromotion.CreateTime,
			(CASE WHEN ISNULL(PKPromotion.Name2, '') = '' THEN PKPromotion.Name1 + ',' + PromotionProducts.Value ELSE (PKPromotion.Name1 + ' / ' + PKPromotion.Name2 + ',' + PromotionProducts.Value) END) AS Name, 
			 PKPromotion.CreateBy, PKPromotion.UpdateTime, PKPromotion.UpdateBy, PKPromotion.PLU, PKPromotion.locationexclude, PKPromotionPrice.Price FROM PKPromotion
			 inner join PKPromotionProduct PMP on pmp.PromotionID = PKPromotion.ID
			 INNER JOIN PKProduct ON PKProduct.ID = PMP.ProductID
			inner join PKCategory Pc on pc.ID = PKProduct.CategoryID
			inner join PKDepartmentPMS PDP on pdp.id = pc.DepartmentID

			INNER JOIN PKPromotionPrice ON PKPromotion.ID= PKPromotionPrice.PromotionID 
			LEFT JOIN #tbl2 AS PromotionProducts ON PromotionProducts.PromotionID = PKPromotion.ID
			WHERE Type='3' ORDER BY Name

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetBookPackageListPMS]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_GetBookPackageListPMS]
	@deptId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	SELECT PKPromotionProduct.ID, PKPromotionProduct.PromotionID, PKPromotionProduct.ProductID, PKProduct.PLU, PKProduct.Name1 AS Name, PKPromotionProduct.PromotionUnitPrice AS RPrice, 
	PKPromotionProduct.Qty INTO #tbl1 FROM PKPromotionProduct 

	INNER JOIN PKProduct ON PKProduct.ID = PKPromotionProduct.ProductID
	inner join PKCategory Pc on pc.ID = PKProduct.CategoryID and pc.DepartmentID = @deptId
	

	SELECT PromotionID, [Value]=stuff((  
	SELECT ',' + [Name] + '  x' + CONVERT(varchar(10), Qty) FROM #tbl1 as Temp2 WHERE Temp2.PromotionID = Temp1.PromotionID FOR XML PATH('')),1,1,'') INTO #tbl2 FROM #tbl1 AS Temp1  
	GROUP BY PromotionID 

	SELECT distinct PKPromotion.ID, PKPromotion.Name1, PKPromotion.Name2, PKPromotion.Barcode, PKPromotion.Type, PKPromotion.Remarks, PKPromotion.StartDate, PKPromotion.ExpireDate, PKPromotion.Status, PKPromotion.CreateTime,
			(CASE WHEN ISNULL(PKPromotion.Name2, '') = '' THEN PKPromotion.Name1 + ',' + PromotionProducts.Value ELSE (PKPromotion.Name1 + ' / ' + PKPromotion.Name2 + ',' + PromotionProducts.Value) END) AS Name, 
			 PKPromotion.CreateBy, PKPromotion.UpdateTime, PKPromotion.UpdateBy, PKPromotion.PLU, PKPromotion.locationexclude, PKPromotionPrice.Price FROM PKPromotion
			 inner join PKPromotionProduct PMP on pmp.PromotionID = PKPromotion.ID
			 INNER JOIN PKProduct ON PKProduct.ID = PMP.ProductID
			inner join PKCategory Pc on pc.ID = PKProduct.CategoryID and pc.DepartmentID = @deptId
			

			INNER JOIN PKPromotionPrice ON PKPromotion.ID= PKPromotionPrice.PromotionID 
			LEFT JOIN #tbl2 AS PromotionProducts ON PromotionProducts.PromotionID = PKPromotion.ID
			WHERE Type='3' ORDER BY Name

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
END
GO
/****** Object:  StoredProcedure [dbo].[Pk_getCalcoulatetourcommission]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[Pk_getCalcoulatetourcommission] @TourCode            NVARCHAR(50), 
                                      @CommissionBeforeTax NVARCHAR(50), 
                                      @timestamp           SMALLDATETIME 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from  
      -- interfering with SELECT statements.  
      -- @CommissionBeforeTax, true, means calculation before tax.false, means to calculate the commission after tax.
      -- in the old rules of LULU, they calculate the rules after tax. now then want to calculate it before tax.
      -- @timestamp, the time before it and the time after that will be opposite calculate way.   
      SET nocount ON; 

      SELECT pkcategory.NAME, 
             Cast(Sum(itemsubtotal) AS DECIMAL(10, 2))     AS Net, 
             Cast(Sum(TX.itemtaxamount) AS DECIMAL(10, 2)) AS Tax, 
             CASE 
               WHEN Sum(TX.itemtaxamount) IS NULL THEN Cast(Sum(itemsubtotal) AS DECIMAL(10, 2))
               ELSE Cast(Sum(itemsubtotal) AS DECIMAL(10, 2)) 
                    + Cast(Sum(TX.itemtaxamount) AS DECIMAL(10, 2)) 
             END                                           AS Gross, 
             TCR.oa, 
             TCR.la, 
             TCR.tl, 
             TCR.tg 
      --POSTransaction.StatusDateTime as transTime  
      --Cast(Sum(itemsubtotal) * TCR.oa * 0.01 AS DECIMAL(10, 2)) AS OA,   
      --Cast(Sum(itemsubtotal) * TCR.la * 0.01 AS DECIMAL(10, 2)) AS LA,   
      --Cast(Sum(itemsubtotal) * TCR.tl * 0.01 AS DECIMAL(10, 2)) AS TL,   
      -- Cast(Sum(itemsubtotal) * TCR.tg * 0.01 AS DECIMAL(10, 2)) AS TG   
      INTO   #tbl1 
      FROM   tourtransaction 
             JOIN postransaction 
               ON tourtransaction.transactionid = postransaction.id 
             JOIN transactionitem 
               ON postransaction.id = transactionitem.transactionid 
             LEFT OUTER JOIN (SELECT transactionitemid, 
                                     Sum(itemtaxamount) AS ItemTaxAmount 
                              FROM   transactionitemtax 
                              GROUP  BY transactionitemid) AS TX 
                          ON TX.transactionitemid = transactionitem.id 
             JOIN pkproduct 
               ON transactionitem.productid = pkproduct.id 
             JOIN pkcategory 
               ON pkproduct.categoryid = pkcategory.id 
             JOIN (SELECT * 
                   FROM   tourcommitionrate 
                   WHERE  tourcode = @TourCode) AS TCR 
               ON pkcategory.id = TCR.categoryid 
      WHERE  tourtransaction.tourid = @TourCode 
             AND postransaction.status = 'Confirmed' 
             AND transactionitem.status = 'Confirmed' 
             AND postransaction.statusdatetime < @timestamp 
      GROUP  BY pkcategory.id, 
                pkcategory.NAME, 
                TCR.oa, 
                TCR.la, 
                TCR.tl, 
                TCR.tg 
      ORDER  BY pkcategory.NAME; 
	  ------------------------------------------------------------------------------------------------
      SELECT pkcategory.NAME, 
             Cast(Sum(itemsubtotal) AS DECIMAL(10, 2))     AS Net, 
             Cast(Sum(TX.itemtaxamount) AS DECIMAL(10, 2)) AS Tax, 
             CASE 
               WHEN Sum(TX.itemtaxamount) IS NULL THEN Cast(Sum(itemsubtotal) AS DECIMAL(10, 2))
               ELSE Cast(Sum(itemsubtotal) AS DECIMAL(10, 2)) 
                    + Cast(Sum(TX.itemtaxamount) AS DECIMAL(10, 2)) 
             END                                           AS Gross, 
             TCR.oa, 
             TCR.la, 
             TCR.tl, 
             TCR.tg 
      INTO   #tbl2 
      FROM   tourtransaction 
             JOIN postransaction 
               ON tourtransaction.transactionid = postransaction.id 
             JOIN transactionitem 
               ON postransaction.id = transactionitem.transactionid 
             LEFT OUTER JOIN (SELECT transactionitemid, 
                                     Sum(itemtaxamount) AS ItemTaxAmount 
                              FROM   transactionitemtax 
                              GROUP  BY transactionitemid) AS TX 
                          ON TX.transactionitemid = transactionitem.id 
             JOIN pkproduct 
               ON transactionitem.productid = pkproduct.id 
             JOIN pkcategory 
               ON pkproduct.categoryid = pkcategory.id 
             JOIN (SELECT * 
                   FROM   tourcommitionrate 
                   WHERE  tourcode = @TourCode) AS TCR 
               ON pkcategory.id = TCR.categoryid 
      WHERE  tourtransaction.tourid = @TourCode 
             AND postransaction.status = 'Confirmed' 
             AND transactionitem.status = 'Confirmed' 
             AND postransaction.statusdatetime >= @timestamp 
      GROUP  BY pkcategory.id, 
                pkcategory.NAME, 
                TCR.oa, 
                TCR.la, 
                TCR.tl, 
                TCR.tg 
      ORDER  BY pkcategory.NAME; 
	  ------------------------------------------------------------------------------------------------

      SELECT NAME, 
             net, 
             tax, 
             gross, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN gross 
                    ELSE net 
                  END * oa * 0.01 AS DECIMAL(10, 2)) AS OA, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN gross 
                    ELSE   net
                  END * la * 0.01 AS DECIMAL(10, 2)) AS LA, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN gross 
                    ELSE net 
                  END * tl * 0.01 AS DECIMAL(10, 2)) AS TL, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN gross 
                    ELSE net 
                  END * tg * 0.01 AS DECIMAL(10, 2)) AS TG 
      FROM   #tbl1 
	  ------------------------------------------------------------------------------------------------
      UNION 
	  ------------------------------------------------------------------------------------------------
      SELECT NAME, 
             net, 
             tax, 
             gross, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN net 
                    ELSE gross 
                  END * oa * 0.01 AS DECIMAL(10, 2)) AS OA, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN net 
                    ELSE gross 
                  END * la * 0.01 AS DECIMAL(10, 2)) AS LA, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN net 
                    ELSE gross 
                  END * tl * 0.01 AS DECIMAL(10, 2)) AS TL, 
             Cast(CASE @CommissionBeforeTax 
                    WHEN 'true' THEN net 
                    ELSE gross 
                  END * tg * 0.01 AS DECIMAL(10, 2)) AS TG 
      FROM   #tbl2 
	  ------------------------------------------------------------------------------------------------

      DROP TABLE #tbl1; 

      DROP TABLE #tbl2; 
  END 


GO
/****** Object:  StoredProcedure [dbo].[PK_GetCalculateABCDEPrice]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetCalculateABCDEPrice]
	@productId varchar(50)

AS
BEGIN
	
	declare @productPriceFix bit

	declare @averageCost decimal(8,2)
	declare @latestCost decimal(8,2)

	declare @baseCost decimal(8,2)
	declare @baseCostOriginal decimal(8,2)

	declare @APrice decimal(8,2)
	declare @BPrice decimal(8,2)
	declare @CPrice decimal(8,2)
	declare @DPrice decimal(8,2)
	declare @EPrice decimal(8,2)

	declare @APriceRate decimal(8,2)
	declare @BPriceRate decimal(8,2)
	declare @CPriceRate decimal(8,2)
	declare @DPriceRate decimal(8,2)
	declare @EPriceRate decimal(8,2)

	declare @APriceRate2 decimal(8,2)
	declare @BPriceRate2 decimal(8,2)
	declare @CPriceRate2 decimal(8,2)
	declare @DPriceRate2 decimal(8,2)
	declare @EPriceRate2 decimal(8,2)

	declare @ABaseOn varchar(1)
	declare @BBaseOn varchar(1)
	declare @CBaseOn varchar(1)
	declare @DBaseOn varchar(1)
	declare @EBaseOn varchar(1)

	declare @AOperator1 varchar(1)
	declare @BOperator1 varchar(1)
	declare @COperator1 varchar(1)
	declare @DOperator1 varchar(1)
	declare @EOperator1 varchar(1)

	declare @AOperator2 varchar(1)
	declare @BOperator2 varchar(1)
	declare @COperator2 varchar(1)
	declare @DOperator2 varchar(1)
	declare @EOperator2 varchar(1)

	declare @AIsFixed bit
	declare @BIsFixed bit
	declare @CIsFixed bit
	declare @DIsFixed bit
	declare @EIsFixed bit





	declare @IsPriceExisted varchar(50)

	set @baseCost = 0
	set @baseCostOriginal = 0
	set @averageCost = 0
	set @latestCost = 0

	--select @globalAutoChangePrice = value from PKSetting where FieldName='InboundUpdatePrice' --switchForAutoPriceChange
	--select @globalAveOrLatest = value from PKSetting where FieldName='basePricebyAveOrlastPrice'
	select @productPriceFix = isnull(FixPrice,1)  from PKPrice where ProductID = @productId
	SELECT @latestCost = isnull(a.LatestCost,0),
		   @averageCost = isnull(a.AverageCost,0) 
		   FROM PKInventory a 
		   inner join PKLocation b on a.LocationID = b.LocationID  where a.ProductID = @productId and b.IsHeadquarter = 1;
	


		SELECT TOP 1 @APriceRate=isnull(RateA,0),
		@BPriceRate=isnull(RateB,0),
		@CPriceRate=isnull(RateC,0),
		@DPriceRate=isnull(RateD,0),
		@EPriceRate=isnull(RateE,0),

		@APriceRate2 = isnull(RateA2,0),
        @BPriceRate2 = isnull(RateB2,0),
        @CPriceRate2 = isnull(RateC2,0),
        @DPriceRate2 = isnull(RateD2,0),
        @EPriceRate2 = isnull(RateE2,0),

        @ABaseOn = isnull(ABaseOn,'a'),
        @BBaseOn = isnull(BBaseOn,'a'),
        @CBaseOn = isnull(CBaseOn,'a'),
        @DBaseOn = isnull(DBaseOn,'a'),
        @EBaseOn = isnull(EBaseOn,'a'),

        @AOperator1 = isnull(AOperator,'*'),
        @BOperator1 = isnull(BOperator,'*'),
        @COperator1 = isnull(COperator,'*'),
        @DOperator1 = isnull(DOperator,'*'),
        @EOperator1 = isnull(EOperator,'*'),

        --isnull(AUnit,'%') as AUnit,
        --isnull(BUnit,'%') as BUnit,
        --isnull(CUnit,'%') as CUnit,
        --isnull(DUnit,'%') as DUnit,
        --isnull(EUnit,'%') as EUnit,

        @AOperator2 = isnull(AOperator2,'+'),
        @BOperator2 = isnull(BOperator2,'+'),
        @COperator2 = isnull(COperator2,'+'),
        @DOperator2 = isnull(DOperator2,'+'),
        @EOperator2 = isnull(EOperator2,'+'),
        --isnull(AUnit2,'$') as AUnit2,
        --isnull(BUnit2,'$') as BUnit2,
        --isnull(CUnit2,'$') as CUnit2,
        --isnull(DUnit2,'$') as DUnit2,
        --isnull(EUnit2,'$') as EUnit2,
        @AIsFixed = isnull(AIsfixed,'0'),
        @BIsFixed = isnull(BIsfixed,'0'),
        @CIsFixed = isnull(CIsfixed,'0'),
        @DIsFixed = isnull(DIsfixed,'0'),
        @EIsFixed = isnull(EIsfixed,'0')

		FROM PKPriceRate
		

		/*
		if lower(@globalAveOrLatest)='l'
			begin
				set @baseCost = @latestCost
			end
		else if lower(@globalAveOrLatest)='a'
			begin
				set @baseCost = @averageCost
			end 
		

		set @APrice = @baseCost + @baseCost * @APriceRate/100;
		set @BPrice = @baseCost + @baseCost * @BPriceRate/100;
		set @CPrice = @baseCost + @baseCost * @CPriceRate/100;
		set @DPrice = @baseCost + @baseCost * @DPriceRate/100;
		set @EPrice = @baseCost + @baseCost * @EPriceRate/100;
		*/

		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@ABaseOn)='l' then @latestCost else @averageCost end;

		SET @APrice = @baseCost +
		case 
		 when @AOperator1='+' then @APriceRate
		 when @AOperator1='-' then (@APriceRate * -1)
		 when @AOperator1='*' then case when @APriceRate=0 then 0 else (@APriceRate/100-1) * @baseCost end 
		 when @AOperator1='/' then case when @APriceRate=0 then 0 else @baseCost*100/@APriceRate - @baseCost end 
		 end
		 
		 SET @APrice = @APrice +
		 case 
		 when @AOperator2='+' then @APriceRate2
		 when @AOperator2='-' then (@APriceRate2 * -1)
		 when @AOperator2='*' then case when @APriceRate2=0 then 0 else (@APriceRate2/100 -1) * @APrice end 
		 when @AOperator2='/' then case when @APriceRate2=0 then 0 else @APrice*100/@APriceRate2 -@APrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@BBaseOn)='l' then @latestCost else @averageCost end;

		SET @BPrice = @baseCost +
		case 
		 when @BOperator1='+' then @BPriceRate
		 when @BOperator1='-' then (@BPriceRate * -1)
		 when @BOperator1='*' then case when @BPriceRate=0 then 0 else (@BPriceRate/100-1) * @baseCost end
		 when @BOperator1='/' then case when @BPriceRate=0 then 0 else  @baseCost/@BPriceRate - @baseCost end 
		 end

		SET @BPrice = @BPrice +
		 case 
		 when @BOperator2='+' then @BPriceRate2
		 when @BOperator2='-' then (@BPriceRate2 * -1)
		 when @BOperator2='*' then case when @BPriceRate2=0 then 0 else  (@BPriceRate2/100-1) * @BPrice end 
		 when @BOperator2='/' then case when @BPriceRate2=0 then 0 else  @BPrice*100/@BPriceRate2 -@BPrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@CBaseOn)='l' then @latestCost else @averageCost end;

		SET @CPrice = @baseCost +
		case 
		 when @COperator1='+' then @CPriceRate
		 when @COperator1='-' then (@CPriceRate * -1)
		 when @COperator1='*' then case when @CPriceRate=0 then 0 else (@CPriceRate/100-1) * @baseCost end 
		 when @COperator1='/' then case when @CPriceRate=0 then 0 else @baseCost*100/@CPriceRate - @baseCost end 
		 end

		SET @CPrice = @CPrice +
		 case 
		 when @COperator2='+' then @CPriceRate2
		 when @COperator2='-' then (@CPriceRate2 * -1)
		 when @COperator2='*' then case when @CPriceRate2=0 then 0 else   (@CPriceRate2/100 -1) * @CPrice end 
		 when @COperator2='/' then case when @CPriceRate2=0 then 0 else   @CPrice*100/@CPriceRate2 -@CPrice end 
		 end

		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@DBaseOn)='l' then @latestCost else @averageCost end;

		SET @DPrice = @baseCost +
		case 
		 when @DOperator1='+' then @DPriceRate
		 when @DOperator1='-' then (@DPriceRate * -1)
		 when @DOperator1='*' then case when @DPriceRate=0 then 0 else   (@DPriceRate/100-1) * @baseCost END 
		 when @DOperator1='/' then case when @DPriceRate=0 then 0 else   @baseCost*100/@DPriceRate - @baseCost end 
		 end
		SET @DPrice = @DPrice +
		 case 
		 when @DOperator2='+' then @DPriceRate2
		 when @DOperator2='-' then (@DPriceRate2 * -1)
		 when @DOperator2='*' then case when @dPriceRate2=0 then 0 else   (@DPriceRate2/100-1) * @DPrice end 
		 when @DOperator2='/' then case when @dPriceRate2=0 then 0 else   @DPrice*100/@DPriceRate2 -@DPrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@EBaseOn)='l' then @latestCost else @averageCost end;

		SET @EPrice = @baseCost +
		case 
		 when @EOperator1='+' then @EPriceRate
		 when @EOperator1='-' then (@EPriceRate * -1)
		 when @EOperator1='*' then case when @EPriceRate=0 then 0 else   (@EPriceRate/100-1) * @baseCost end 
		 when @EOperator1='/' then case when @EPriceRate=0 then 0 else   @baseCost*100/@EPriceRate - @baseCost end 
		 end
		 SET @EPrice = @EPrice +
		 case 
		 when @EOperator2='+' then @EPriceRate2
		 when @EOperator2='-' then (@EPriceRate2 * -1)
		 when @EOperator2='*' then case when @EPriceRate2=0 then 0 else    (@EPriceRate2/100-1) * @EPrice  end 
		 when @EOperator2='/' then case when @EPriceRate2=0 then 0 else   @EPrice*100/@EPriceRate2 -@EPrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------


		select @APrice as APrice, @BPrice as BPrice, @CPrice as CPrice, @DPrice as DPrice, @EPrice as EPrice;


END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetCategoryByDepartIDs]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetCategoryByDepartIDs]
	@DepartmentIds varchar(8000),
	@LocationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @str varchar(max);
	declare @tablename table(value varchar(200));
	set @str = @DepartmentIds + ',';
	set @str = replace(@str,' ','');
	set @str = replace(@str,',,',',');
	set @str = replace(@str,',,',',');
	set @str = replace(@str,',,',',');
	Declare @insertStr varchar(50) --
	Declare @newstr varchar(8000) --
	set @insertStr = left(@str,charindex(',',@str)-1)
	set @insertStr = ltrim(rtrim(replace(@insertStr,char(13),'')));
	set @insertStr = replace(@insertStr,char(10),'');
	set @newstr = stuff(@str,1,charindex(',',@str),'')
	Insert @tableName Values(@insertStr)
	
	Declare @intLoopLimit int;
	set @intLoopLimit = 300;
	while(len(@newstr)>0)
	begin
		set @insertStr = left(@newstr,charindex(',',@newstr)-1)
		set @insertStr = ltrim(rtrim(replace(@insertStr,char(13),'')));
		set @insertStr = replace(@insertStr,char(10),'');
		Insert @tableName Values(@insertStr)
		set @newstr = stuff(@newstr,1,charindex(',',@newstr),'')
		print '[' + @insertStr + ']'
		--Here to avoid the loop to be unlimited loop----------
		set @intLoopLimit =@intLoopLimit-1
		if @intLoopLimit <=0 
		begin
			set @newstr = ''
		end
		-- End ------------------------------------------------
	end
   
  select ROW_NUMBER() over(partition by a.id  order by c.StockTakeDate desc)as row, 
	a.id,c.Id as stockTakeId,c.StockTakeDate,c.Remarks
	   into #tbl1
	   from PKCategory a
	   inner join PKStockDepartmentCategory b on b.DepartmentCategoryID = a.ID
	   inner join PKStockTake c on b.StockTakeID = c.ID and c.StockTakeStatus <> 'Completed' and c.LocationID = @LocationId
   ;
	select a.ID,a.stockTakeId,a.StockTakeDate,a.Remarks
		into #tbl2
	from #tbl1 a 
	where row = 1;
 SELECT distinct a.ID, 
	   a.DepartmentID, 
	   a.PLU, 
	   a.Name, 
	   a.OtherName, 
	   a.Remarks, 
	   a.CreateTime, 
	   a.UpdateTime,
	   isnull(d.stockTakeId,'') as stockTakeId,
	   d.StockTakeDate,
	   d.Remarks as stockTakeRemarks
   FROM PKCategory a
   inner join PKDepartment b on a.DepartmentID = b.id
   inner join @tableName c on ltrim(rtrim(c.value)) = a.DepartmentID
   left outer join #tbl2 d on d.ID = a.ID
		
   WHERE a.PLU != '0000'  order by a.plu
   drop table #tbl1;
   drop table #tbl2;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetCommissionGroupsAndSingleSales]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetCommissionGroupsAndSingleSales]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	select PU.EmployeeID
	into #tblEmployee
	
	from PKUserRole PUR 
	inner join PKUsers PU on PUR.UserID = PU.UserID
	inner join PKEmployee PE on PU.EmployeeID = PE.ID
	where PUR.RoleID = 4


    select CommissionCategory as Name,  
	'G_' + cast( id as varchar) as value, 
	'G' as [type] 
	from PKCommissionCategory 
	union
	select PE.FirstName + ' ' + PE.LastName as Name,
		'S_' + TE.EmployeeID as value,
		'S' as [type]
		 from PKEmployee PE
			inner join #tblEmployee TE on PE.ID = TE.EmployeeID
			
			where not exists ( select PCCE.* from PKCommissionCategoryEmployee PCCE where PCCE.employeeId = TE.EmployeeId)
	
	order by [type], name
	drop table #tblEmployee;


END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetCommissionRangeByEmployeeID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetCommissionRangeByEmployeeID]
	@employeeid varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
SELECT * 
INTO   #tbl1 
FROM   (SELECT id, 
               categoryid, 
               singleemployeeid, 
               iscategoryorsingle, 
               department, 
               category, 
               productid, 
               baseprice, 
               commissiontype, 
               commission, 
               createdtime, 
               createdby 
        FROM   pkcommissioncategoryrate 
        WHERE  singleemployeeid = @employeeId 
               AND Lower(iscategoryorsingle) = 's' 
        UNION 
        SELECT PCCR.id, 
               PCCR.categoryid, 
               PCCR.singleemployeeid, 
               PCCR.iscategoryorsingle, 
               PCCR.department, 
               PCCR.category, 
               PCCR.productid, 
               PCCR.baseprice, 
               PCCR.commissiontype, 
               PCCR.commission, 
               PCCR.createdtime, 
               PCCR.createdby 
        FROM   pkcommissioncategoryrate PCCR 
               INNER JOIN pkcommissioncategoryemployee PCCE 
                       ON PCCR.categoryid = PCCE.categoryid 
                          AND PCCE.employeeid = @employeeId 
        WHERE  Lower(PCCR.iscategoryorsingle) = 'g') tbl1 

SELECT * 
FROM   #tbl1 

DROP TABLE #tbl1; 


END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetCommissionRatesByIdAndType]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetCommissionRatesByIdAndType]
	@GroupOrEmployeeId varchar(50),
	@Type varchar(1)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    if LOWER(@Type)='g'
	begin
		select distinct PkCCR.[id]
      ,PkCCR.[CategoryId]
      ,PkCCR.[SingleEmployeeId]
      ,PkCCR.[isCategoryOrSingle]
      ,PkCCR.[Department]
	  ,case PkCCR.[Department] when '-1' then 'All' else pd.Name end  as departmentName
      ,PkCCR.[Category]
	  ,case PkCCR.[Category] when '-1' then 'All' else pc.Name end  as CategoryName
      ,PkCCR.[ProductId]
	  ,case PkCCR.[ProductId] when '-1' then 'All' else pk.Name1 end  as productName
      ,PkCCR.[BasePrice]
	  ,PCCBP.PriceType as BasePriceName
      ,PkCCR.[CommissionType]
      ,PkCCR.[Commission]
      ,PkCCR.[CreatedTime]
      ,PkCCR.[createdBy]
	  from PKCommissionCategoryRate PkCCR
	  left outer join PKCategory Pc on Pc.ID = PkCCR.Category
	  left outer join PKDepartment pD on pd.ID = PkCCR.Department
	  left outer join PKProduct pk on pk.ID = PkCCR.ProductId
	  inner join PKCommissionCategoryBasePriceType PCCBP on PCCBP.PriceValue = PkCCR.BasePrice
	  where PkCCR.CategoryId = cast(@GroupOrEmployeeId as int);
	end
	else
	begin
	select distinct PkCCR.[id]
      ,PkCCR.[CategoryId]
      ,PkCCR.[SingleEmployeeId]
      ,PkCCR.[isCategoryOrSingle]
      ,PkCCR.[Department]
	  ,case PkCCR.[Department] when '-1' then 'All' else pd.Name end  as departmentName    
      ,PkCCR.[Category]
	  ,case PkCCR.[Category] when '-1' then 'All' else pc.Name end  as CategoryName
      ,PkCCR.[ProductId]
	  ,case PkCCR.[ProductId] when '-1' then 'All' else pk.Name1 end  as productName
      ,PkCCR.[BasePrice]
	  ,PCCBP.PriceType as BasePriceName
      ,PkCCR.[CommissionType]
      ,PkCCR.[Commission]
      ,PkCCR.[CreatedTime]
      ,PkCCR.[createdBy]
	  from PKCommissionCategoryRate PkCCR
	  left outer join PKCategory Pc on Pc.ID = PkCCR.Category
	  left outer join PKDepartment pD on pd.ID = PkCCR.Department
	  left outer join PKProduct pk on pk.ID = PkCCR.ProductId
	   inner join PKCommissionCategoryBasePriceType PCCBP on PCCBP.PriceValue = PkCCR.BasePrice
	  where PkCCR.SingleEmployeeId = @GroupOrEmployeeId;
	end
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetCommissionRatesByIdAndTypeBooking]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[PK_GetCommissionRatesByIdAndTypeBooking]
	@GroupOrEmployeeId varchar(50),
	@Type varchar(1)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    if LOWER(@Type)='g'
	begin
		select distinct PkCCR.[id]
      ,PkCCR.[CategoryId]
      ,PkCCR.[SingleEmployeeId]
      ,PkCCR.[isCategoryOrSingle]
      ,PkCCR.[Department]
	  ,case PkCCR.[Department] when '-1' then 'All' else pd.Name end  as departmentName
      ,PkCCR.[Category]
	  ,case PkCCR.[Category] when '-1' then 'All' else pc.Name end  as CategoryName
      ,PkCCR.[ProductId]
	  ,case PkCCR.[ProductId] when '-1' then 'All' else pk.Name1 end  as productName
      ,PkCCR.[BasePrice]
	  ,PCCBP.PriceType as BasePriceName
      ,PkCCR.[CommissionType]
      ,PkCCR.[Commission]
      ,PkCCR.[CreatedTime]
      ,PkCCR.[createdBy]
	  from PKCommissionCategoryRate PkCCR
	  left outer join PKCategory Pc on Pc.ID = PkCCR.Category
	  left outer join PKDepartment pD on pd.ID = PkCCR.Department
	  left outer join PKProduct pk on pk.ID = PkCCR.ProductId
	  inner join PKCommissionCategoryBasePriceTypeBooking PCCBP on PCCBP.PriceValue = PkCCR.BasePrice
	  where PkCCR.CategoryId = cast(@GroupOrEmployeeId as int);
	end
	else
	begin
	select distinct PkCCR.[id]
      ,PkCCR.[CategoryId]
      ,PkCCR.[SingleEmployeeId]
      ,PkCCR.[isCategoryOrSingle]
      ,PkCCR.[Department]
	  ,case PkCCR.[Department] when '-1' then 'All' else pd.Name end  as departmentName    
      ,PkCCR.[Category]
	  ,case PkCCR.[Category] when '-1' then 'All' else pc.Name end  as CategoryName
      ,PkCCR.[ProductId]
	  ,case PkCCR.[ProductId] when '-1' then 'All' else pk.Name1 end  as productName
      ,PkCCR.[BasePrice]
	  ,PCCBP.PriceType as BasePriceName
      ,PkCCR.[CommissionType]
      ,PkCCR.[Commission]
      ,PkCCR.[CreatedTime]
      ,PkCCR.[createdBy]
	  from PKCommissionCategoryRate PkCCR
	  left outer join PKCategory Pc on Pc.ID = PkCCR.Category
	  left outer join PKDepartment pD on pd.ID = PkCCR.Department
	  left outer join PKProduct pk on pk.ID = PkCCR.ProductId
	   inner join PKCommissionCategoryBasePriceTypeBooking PCCBP on PCCBP.PriceValue = PkCCR.BasePrice
	  where PkCCR.SingleEmployeeId = @GroupOrEmployeeId;
	end
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetCommissionSalesByGroupID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetCommissionSalesByGroupID]
	@CommissionGroupID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	select PU.EmployeeID
	into #tblEmployee
	
	from PKUserRole PUR 
	inner join PKUsers PU on PUR.UserID = PU.UserID
	inner join PKEmployee PE on PU.EmployeeID = PE.ID
	where PUR.RoleID = 4


	if @CommissionGroupID = 0 
	begin
		select PE.FirstName + ' ' + PE.LastName as Name,
		TE.EmployeeID,
		'0' as Category
		 from PKEmployee PE
			inner join #tblEmployee TE on PE.ID = TE.EmployeeID
			
			where not exists ( select PCCE.* from PKCommissionCategoryEmployee PCCE where PCCE.employeeId = TE.EmployeeId)
    end
	else if @CommissionGroupID = -1
	Begin
		select PE.FirstName + ' ' + PE.LastName + '['+ PCC.CommissionCategory +']' as Name,
		TE.EmployeeID,
		PCC.CommissionCategory as Category
		 from PKEmployee PE
			inner join #tblEmployee TE on PE.ID = TE.EmployeeID
			inner join PKCommissionCategoryEmployee PCCE on PCCE.employeeId = TE.EmployeeId
			inner join PKCommissionCategory PCC on PCC.id = PCCE.CategoryId
		order by Category,name
	End
	else
	begin
		select PE.FirstName + ' ' + PE.LastName + '['+ PCC.CommissionCategory +']' as Name,
		TE.EmployeeID,
		PCC.CommissionCategory as Category
		 from PKEmployee PE
			inner join #tblEmployee TE on PE.ID = TE.EmployeeID
			inner join PKCommissionCategoryEmployee PCCE on PCCE.employeeId = TE.EmployeeId
			inner join PKCommissionCategory PCC on PCC.id = PCCE.CategoryId
		where PCC.id = @CommissionGroupID
		order by Category,name
	end
	drop table #tblEmployee;

END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetCommissionSalesByGroupIDBooking]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetCommissionSalesByGroupIDBooking]
	@CommissionGroupID int,
	@Locationid nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	select distinct PU.EmployeeID
	into #tblEmployee
	
	from PKUserRole PUR 
	inner join PKUsers PU on PUR.UserID = PU.UserID
	inner join PKEmployee PE on PU.EmployeeID = PE.ID
	inner join PKUserLocation PUL on PUL.UserID = PU.userid and PUL.LocationID = @locationId
	where PUR.RoleID >3


	if @CommissionGroupID = 0 
	begin
		select PE.FirstName + ' ' + PE.LastName as Name,
		TE.EmployeeID,
		'0' as Category
		 from PKEmployee PE
			inner join #tblEmployee TE on PE.ID = TE.EmployeeID
			
			where not exists ( 
				select PCCE.* from PKCommissionCategoryEmployee PCCE 
				inner join PKCommissionCategory PCC on PCC.id = PCCE.CategoryId and PCC.locationID = @Locationid
				where PCCE.employeeId = TE.EmployeeId 
			)
    end
	else if @CommissionGroupID = -1
	Begin
		select PE.FirstName + ' ' + PE.LastName + '['+ PCC.CommissionCategory +']' as Name,
		TE.EmployeeID,
		PCC.CommissionCategory as Category
		 from PKEmployee PE
			inner join #tblEmployee TE on PE.ID = TE.EmployeeID
			inner join PKCommissionCategoryEmployee PCCE on PCCE.employeeId = TE.EmployeeId
			inner join PKCommissionCategory PCC on PCC.id = PCCE.CategoryId and PCC.locationID = @Locationid
		order by Category,name
	End
	else
	begin
		select PE.FirstName + ' ' + PE.LastName + '['+ PCC.CommissionCategory +']' as Name,
		TE.EmployeeID,
		PCC.CommissionCategory as Category
		 from PKEmployee PE
			inner join #tblEmployee TE on PE.ID = TE.EmployeeID
			inner join PKCommissionCategoryEmployee PCCE on PCCE.employeeId = TE.EmployeeId
			inner join PKCommissionCategory PCC on PCC.id = PCCE.CategoryId and PCC.locationID = @Locationid
		where PCC.id = @CommissionGroupID
		order by Category,name
	end
	drop table #tblEmployee;

END





GO
/****** Object:  StoredProcedure [dbo].[PK_GetCustomerDeposit]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetCustomerDeposit] 
	@CardNo VARCHAR(50)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	DECLARE @IsMultiCard nvarchar(50);
	SELECT @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

	IF(@IsMultiCard = 'true')
	BEGIN
		SELECT ISNULL(Balance, 0.00) AS Deposit FROM CustomerCard WHERE CardNo = @cardNo
	END
	ELSE
	BEGIN
		SELECT ISNULL(Points, 0.00) AS Deposit FROM Customer WHERE CustomerNo = @cardNo
	END
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetCustomers]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetCustomers] @SearchName  NVARCHAR(50), 
                                        @SearchValue NVARCHAR(200), 
                                        @Status      NVARCHAR(50), 
                                        @SalesName   NVARCHAR(50) 
AS 
  BEGIN 
      SET nocount ON; 
      SET @SearchName = Lower(@SearchName); 

      -- SET NOCOUNT ON added to prevent extra result sets from  
      -- interfering with SELECT statements.  
      DECLARE @str VARCHAR(max); 
      DECLARE @tablename TABLE 
        ( 
           value VARCHAR(200) 
        ); 

      SET @str = @SalesName + ','; 
      SET @str = Replace(@str, ' ', ''); 
      SET @str = Replace(@str, ',,', ','); 
      SET @str = Replace(@str, ',,', ','); 
      SET @str = Replace(@str, ',,', ','); 

      DECLARE @insertStr VARCHAR(50) -- 
      DECLARE @newstr VARCHAR(8000) -- 

      SET @insertStr = LEFT(@str, Charindex(',', @str) - 1) 
      SET @insertStr = Ltrim(Rtrim(Replace(@insertStr, Char(13), ''))); 
      SET @insertStr = Replace(@insertStr, Char(10), ''); 
      SET @newstr = Stuff(@str, 1, Charindex(',', @str), '') 

      INSERT @tableName 
      VALUES(@insertStr) 

      DECLARE @intLoopLimit INT; 

      SET @intLoopLimit = 300; 

      WHILE( Len(@newstr) > 0 ) 
        BEGIN 
            SET @insertStr = LEFT(@newstr, Charindex(',', @newstr) - 1) 
            SET @insertStr = Ltrim(Rtrim(Replace(@insertStr, Char(13), ''))); 
            SET @insertStr = Replace(@insertStr, Char(10), ''); 

            INSERT @tableName 
            VALUES(@insertStr) 

            SET @newstr = Stuff(@newstr, 1, Charindex(',', @newstr), '') 

            PRINT '[' + @insertStr + ']' 

            --Here to avoid the loop to be unlimited loop---------- 
            SET @intLoopLimit =@intLoopLimit - 1 

            IF @intLoopLimit <= 0 
              BEGIN 
                  SET @newstr = '' 
              END 
        -- End ------------------------------------------------ 
        END 

      DECLARE @s NVARCHAR(max); 

      SELECT c.id, 
             a.id                 AS AddID, 
             c.companyname, 
             c.companytype, 
             a.contact, 
             a.tel, 
             a.city, 
             s.salesname, 
             c.createtime, 
             Ltrim(a.primaryflag) AS primaryFlag ,
			 isnull(C.Online,'') as online
      INTO   #tbl1 
      FROM   pkcustomermultiadd AS c 
             LEFT JOIN (SELECT id, 
                               contact, 
                               cell, 
                               tel, 
                               fax, 
                               city, 
                               zip, 
                               referenceid, 
                               primaryflag 
                        FROM   pkmultiadd) AS a 
                    ON c.id = a.referenceid 
             INNER JOIN pksalescustomermp AS s 
                     ON c.id = s.customerid 
             INNER JOIN @tableName t 
                     ON s.salesname = t.value 
       WHERE  (@SearchValue = '' 
              OR ( @SearchValue <> '' 
                   AND ( ( @SearchName = 'company' 
                           AND c.companyname LIKE '%' + @SearchValue + '%' ) 
                          OR ( @SearchName = 'type' 
                               AND c.companytype LIKE '%' + @SearchValue + '%' ) 
						  
                          OR ( @SearchName <> 'company' 
                               AND @SearchName <> 'type' ) ) ) )
                 AND ( ( @Status = '' ) 
                        OR ( c.status = @Status ) ) 
                 AND (( @SalesName <> '' 
                        AND t.value <> '' )) 


      SELECT id, 
             addid, 
             companyname, 
             companytype, 
             createtime, 
             primaryflag, 
			 online,
             dbo.Pk_getaggregatestring(id, 'tel')     AS tel, 
             dbo.Pk_getaggregatestring(id, 'contact') AS contact, 
             dbo.Pk_getaggregatestring(id, 'city')    AS city, 
             Row_number() 
               OVER( 
                 partition BY id 
                 ORDER BY primaryflag DESC)           AS row 
      INTO   #tbl2 
      FROM   #tbl1 
      WHERE  @SearchValue = '' 
              OR ( @SearchValue <> '' 
                   AND ( ( @SearchName = 'phone' 
                           AND tel LIKE '%' + @SearchValue + '%' ) 
                          OR ( @SearchName = 'city' 
                               AND city LIKE '%' + @SearchValue + '%' ) 
                          OR ( @SearchName = 'contact' 
                               AND contact LIKE '%' + @SearchValue + '%' ) 
                          OR ( @SearchName <> 'phone' 
                               AND @SearchName <> 'city' 
                               AND @SearchName <> 'contact' ) ) ) 

      SELECT * 
      FROM   #tbl2 
      WHERE  row = 1; 

      DROP TABLE #tbl1; 

      DROP TABLE #tbl2; 
  END 


GO
/****** Object:  StoredProcedure [dbo].[PK_GetCustomersBySalesList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetCustomersBySalesList]
	@SalesList [dbo].[PKSalesTableType] READONLY
AS
BEGIN
	SELECT c.ID AS ID, a.ID AS AddID, c.CompanyName AS CompanyName, c.CompanyType AS Type, c.Terms AS Terms, c.CreditLimit AS CreditLimit,
	c.PriceList AS PriceList, c.PercentDiscount AS PercentDiscount, c.DollarsDiscount AS DollarsDiscount, c.Classification AS Classification,
	c.Status AS Status, c.WebSite AS WebSite, c.CourierName AS CourierName, c.CourierTEL AS CourierTEL, c.CourierFAX CourierFAX, c.CourierAccountNo AS CourierAccountNo,
	c.CreateTime AS CreateTime, c.UpdateTime AS UpdateTime, c.CustomerRemarks AS CustomerRemarks, c.Warning AS Warning, c.OtherName AS OtherName, c.PSTNo AS PSTNo, 
	c.CreditAmount AS CreditAmount, c.IsRememberShippingAddr AS IsRememberShippingAddr, c.ReferenceID AS ReferenceID, a.Contact AS Contact, a.TEL AS TEL, a.City AS City, 
	a.Street AS Street, s.SalesName AS Sales, Ltrim(a.PrimaryFlag) AS PrimaryFlag, LOWER(isnull(c.Online,'')) AS Online FROM pkcustomermultiadd AS c 
	LEFT JOIN (SELECT id, contact, cell, tel, fax, city, street1 as street, zip, referenceid, primaryflag FROM pkmultiadd where primaryflag='yes') AS a ON c.id = a.referenceid 
	LEFT JOIN pksalescustomermp AS s ON c.id = s.customerid WHERE s.SalesName IN (SELECT SalesName FROM @SalesList) ORDER BY c.CompanyName
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetDayEndReport]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetDayEndReport] 
	@StoreName varchar(50),
	@ComputerName varchar(50),
	@FromDateTime varchar(50),
	@ToDateTime varchar(50),
	@DepartmentID varchar(50),
	@CategoryId varchar(50),
	@EmployeeId varchar(50),
	@Status varchar(50)

AS
BEGIN

	--*************************************************************
	--******** BY KEVIN ON JAN 15 2015 ********
	--\\poskingdc\documents\kevin\My Documents\SQL Server Management Studio
	--*************************************************************

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--=======================================================================================
	SELECT PP.StoreName, 
		PP.computerName, 
		PP.Type, 
		PP.Method, 
		--count(*) as 'Count', 
		Sum(PP.PaymentAmount) AS PaymentAmount ,
		SUM(PP.ChangeAmount) AS ChangeAmount, 
		CONVERT(varchar(10), PP.StatusDateTime, 120) AS Date, 
		Sum(0 - Isnull(PP.PennyRounding,0)) as PennyRounding
		into #tbl1
		FROM POSPayment PP
		inner join POSTransaction PT on PP.TransactionID = PT.ID
		WHERE PP.StatusDateTime>=@FromDateTime 
			AND PP.StatusDateTime<= @ToDateTime 
			AND PP.Status = @Status 
			and PP.StoreName = case @StoreName When '' then PP.StoreName else @StoreName end
			and PP.computerName = case @ComputerName When '' then PP.ComputerName else @ComputerName end
			and PT.Cashier =  case @EmployeeId When '' then PT.Cashier else @EmployeeId end
			and not exists(select TransactionID from TourTransaction where pp.TransactionID = TourTransaction.TransactionID)
		GROUP BY  PP.StoreName,PP.computerName, CONVERT(varchar(10), PP.StatusDateTime, 120), PP.Type, PP.Method;
	
	SELECT StoreName, 
		computerName, 
		Type,
		--sum(Count) as  Count, 
		sum(PaymentAmount) as  PaymentAmount,
		sum(ChangeAmount) as  ChangeAmount, 
		Date, 
		sum(PennyRounding) as  PennyRounding
		into #tblFinal
		from #tbl1
		group by StoreName,computerName,Type,date
	--=======================================================================================
	Select
		PT.StoreName
		,pT.ComputerName
		,TT.ItemDiscountAmount
		,TT.ItemTaxTotalAmount
		,TT.ItemSubTotal
		,TT.StatusDateTime
		,TT.Type
		into #tbl3
		From POSTransaction PT
			Left join TransactionItem TT on PT.ID = TT.TransactionID
		where
			PT.Cashier =  case @EmployeeId When '' then PT.Cashier else @EmployeeId end 
			and TT.Status = @Status 
			and PT.StoreName = case @StoreName When '' then PT.StoreName else @StoreName end
			and PT.computerName = case @ComputerName When '' then PT.ComputerName else @ComputerName end
			and PT.StatusDateTime >=@FromDateTime
			and PT.StatusDateTime <= @ToDateTime
			and PT.Status = @Status
			and not exists(select TransactionID from TourTransaction where pt.id = TourTransaction.TransactionID)

	 Select 
		StoreName
		,ComputerName
		,CONVERT(varchar(10), StatusDateTime, 120) as date
		,SUM(ItemTaxTotalAmount) as ItemTaxTotalAmount
		,SUM(ItemSubTotal) as ItemSubTotal
		,Type
		into #tbl4
		from #tbl3
		group by StoreName,computerName,CONVERT(varchar(10), StatusDateTime, 120), type

	Select 
		StoreName
		,ComputerName
		,date
		,SUM(ItemSubTotal) as decTotalNet
		into #tblNet
		from #tbl4
		where type<>'CRF' AND TYPE <> 'Deposit' and Type <> 'EHF'
		group by StoreName,computerName,date

	Select 
		StoreName
		,ComputerName
		,date
		,SUM(ItemSubTotal) as decDeposit
		into #tblDeposit
		from #tbl4
		where TYPE = 'Deposit' 
		group by StoreName,computerName,date

	Select 
		StoreName
		,ComputerName
		,date
		,SUM(ItemSubTotal) as decCRF
		into #tblCRF
		from #tbl4
		where TYPE = 'CRF' 
		group by StoreName,computerName,date

	Select 
		StoreName
		,ComputerName
		,date
		,SUM(ItemSubTotal) as decEHF
		into #tblEHF
		from #tbl4
		where TYPE = 'EHF' 
		group by StoreName,computerName,date

	Select 
		StoreName
		,ComputerName
		,date
		,sum(ItemTaxTotalAmount) as decTotalTax
		into #tblTotalTax
		from #tbl4
		group by StoreName,computerName,date

	--=======================================================================================
	Select 
		POSTransaction.StoreName AS Location, 
		POSTransaction.computerName, 
		CONVERT(varchar(10), ti.StatusDateTime, 120) AS date,
		TaxName, 
		SUM(Tix.ItemTaxAmount) AS Amount 
		into #tblTax
		FROM POSTransaction 
		INNER JOIN TransactionItem AS ti ON POSTransaction.ID=ti.TransactionID 
		INNER JOIN TransactionItemTax AS Tix ON Tix.TransactionID = ti.TransactionID AND Tix.TransactionItemID = ti.ID 
		WHERE POSTransaction.Status = @Status
			AND ti.Status=@Status
			AND POSTransaction.StatusDateTime>=@FromDateTime 
			AND POSTransaction.StatusDateTime<=@ToDateTime
			AND POSTransaction.StoreName = case @StoreName When '' then POSTransaction.StoreName else @StoreName end
			AND POSTransaction.computerName = case @ComputerName When '' then POSTransaction.ComputerName else @ComputerName end
			and not exists(select TransactionID from TourTransaction where POSTransaction.id = TourTransaction.TransactionID)
		Group By POSTransaction.StoreName, 
			POSTransaction.computerName, 
			CONVERT(varchar(10), ti.StatusDateTime, 120),TaxName 

	--=======================================================================================
	 if @StoreName = ''
	 begin 
		SELECT  a.StoreName, 
			--sum(a.Count) as  Count, 
			sum(a.PaymentAmount) as  PaymentAmount,
			sum(a.ChangeAmount) as  ChangeAmount, 
			a.Date, 
			sum(PennyRounding) as  PennyRounding
			into #tblWhole
			from #tblFinal a
			group by a.StoreName,a.date;
		------------------------------------------------------------------------------------

		Select 
		   StoreName
		  ,date
		  ,sum(decTotalNet) as decTotalNet
			into #tblNet1
			from #tblNet
			group by StoreName,date;
		
		Select 
		   StoreName
		  ,date
		  ,sum(decDeposit) as decDeposit
			into #tblDeposit1
			from #tblDeposit
			group by StoreName,date;

		Select 
		   StoreName
		  ,date
		  , sum(decCRF) as decCRF
			into #tblCRF1
			from #tblCRF
			group by StoreName,date;
		
		
		Select 
		   StoreName
		  ,date
		  , sum(decEHF) as decEHF
			into #tblEHF1
			from #tblEHF
			group by StoreName,date;
		
		Select 
		   StoreName
		  ,date
		  , sum(decTotalTax) as decTotalTax
			into #tblTotalTax1
			from #tblTotalTax
			group by StoreName,date;
		------------------------------------------------------------------------------------
		select Location,
			date,
			TaxName,
			sum(amount) as Amount
			into #tblGST
			from #tbltax
			where TaxName = 'GST'
			group by Location,date,TaxName;
		select Location,
			date,
			TaxName,
			sum(amount) as Amount
			into #tblPST
			from #tbltax
			where TaxName = 'PST'
			group by Location,date,TaxName;
		------------------------------------------------------------------------------------

		SELECT  a.StoreName as StoreId,
			a.StoreName as StoreName,
			--a.computerName,
			--Count, 
			cast(PaymentAmount as decimal(18, 2)) as PaymentAmount,
			cast(ChangeAmount as decimal(18, 2)) as ChangeAmount,
			a.Date, 
			PennyRounding,
			cast(isnull(net.decTotalNet,0) as decimal(18, 2)) as [Net Sales],
			cast(isnull(TotalTax.decTotalTax,0) as decimal(18, 2)) as decTotalTax,
			cast(isnull(Deposit.decDeposit,0) as decimal(18, 2)) as Deposit,
			cast(isnull(CRF.decCRF,0) as decimal(18, 2)) as CRF,
			cast(isnull(EHF.decEHF,0) as decimal(18, 2)) as EHF,

			cast(isnull(net.decTotalNet,0) +   
			isnull(TotalTax.decTotalTax,0) +
			isnull(Deposit.decDeposit,0) +
			isnull(CRF.decCRF,0) +
			isnull(EHF.decEHF,0) as decimal(18, 2)) as [Gross Sales],
			cast(a.PaymentAmount - a.ChangeAmount + a.PennyRounding as decimal(18, 2)) as Payment,
			cast(isnull(GST.Amount,0) as decimal(18, 2)) as GST,
			cast(isnull(PST.Amount,0) as decimal(18, 2)) as PST
			from #tblWhole a
			left outer join #tblNet1 net 
						on a.StoreName = net.StoreName and 
							a.Date = net.date 
			left outer join #tblDeposit1 Deposit 
						on a.StoreName = Deposit.StoreName and 
							a.Date = Deposit.date 
			left outer join #tblCRF1 CRF 
						on a.StoreName = CRF.StoreName and 
							a.Date = CRF.date 
			left outer join #tblEHF1 EHF 
						on a.StoreName = EHF.StoreName and 
							a.Date = EHF.date 
			left outer join #tblTotalTax1 TotalTax 
						on a.StoreName = TotalTax.StoreName and 
							a.Date = TotalTax.date 
			left outer join #tblGST GST 
						on a.StoreName = GST.Location and 
							a.Date = GST.date 
			left outer join #tblPST PST 
						on a.StoreName = PST.Location and 
							a.Date = PST.date 

		drop table #tblNet1;
		drop table #tblDeposit1;
		drop table #tblCRF1;
		drop table #tblEHF1;
		drop table #tblTotalTax1;
		drop table #tblWhole;
		drop table #tblGST;
		drop table #tblPST;
		
	 end 
	 else
	 begin
	
		SELECT  a.StoreName, 
			computerName, 
			--sum(a.Count) as  Count, 
			sum(a.PaymentAmount) as  PaymentAmount,
			sum(a.ChangeAmount) as  ChangeAmount, 
			a.Date, 
			sum(PennyRounding) as  PennyRounding
			into #tblOneLocation
			from #tblFinal a
			group by a.StoreName,computerName,a.date;
		------------------------------------------------------------------------------------
		select Location,
			computerName,
			date,
			TaxName,
			sum(amount) as Amount
			into #tblLocationGST
			from #tbltax
			where TaxName = 'GST'
			group by Location,computerName, date,TaxName;
		select Location,
			computerName,
			date,
			TaxName,
			sum(amount) as Amount
			into #tblLocationPST
			from #tbltax
			where TaxName = 'PST'
			group by Location,computerName,date,TaxName;
		------------------------------------------------------------------------------------

		SELECT  a.StoreName as StoreId,
			a.StoreName as StoreName,
			a.computerName,
			--Count, 
			cast(PaymentAmount as decimal(18, 2)) as PaymentAmount,
			cast(ChangeAmount as decimal(18, 2)) as ChangeAmount,
			a.Date, 
			PennyRounding,
			cast(isnull(net.decTotalNet,0) as decimal(18, 2)) as [Net Sales],
			cast(isnull(TotalTax.decTotalTax,0) as decimal(18, 2)) as decTotalTax,
			cast(isnull(Deposit.decDeposit,0) as decimal(18, 2)) as Deposit,
			cast(isnull(CRF.decCRF,0) as decimal(18, 2)) as CRF,
			cast(isnull(EHF.decEHF,0) as decimal(18, 2)) as EHF,

			cast(isnull(net.decTotalNet,0) +   
			isnull(TotalTax.decTotalTax,0) +
			isnull(Deposit.decDeposit,0) +
			isnull(CRF.decCRF,0) +
			isnull(EHF.decEHF,0) as decimal(18, 2)) as [Gross Sales],
			cast(a.PaymentAmount - a.ChangeAmount + a.PennyRounding as decimal(18, 2)) as Payment,
			cast(isnull(GST.Amount,0) as decimal(18, 2)) as GST,
			cast(isnull(PST.Amount,0) as decimal(18, 2)) as PST
			from #tblOneLocation a
			left outer join #tblNet net 
						on a.StoreName = net.StoreName and 
							a.Date = net.date and 
							a.ComputerName = net.ComputerName
			left outer join #tblDeposit Deposit 
						on a.StoreName = Deposit.StoreName and 
							a.Date = Deposit.date  and 
							a.ComputerName = Deposit.ComputerName
			left outer join #tblCRF CRF 
						on a.StoreName = CRF.StoreName and 
							a.Date = CRF.date  and 
							a.ComputerName = CRF.ComputerName
			left outer join #tblEHF EHF 
						on a.StoreName = EHF.StoreName and 
							a.Date = EHF.date  and 
							a.ComputerName = EHF.ComputerName
			left outer join #tblTotalTax TotalTax 
						on a.StoreName = TotalTax.StoreName and 
							a.Date = TotalTax.date  and 
							a.ComputerName = TotalTax.ComputerName
			left outer join #tblLocationGST GST 
						on a.StoreName = GST.Location and 
							a.Date = GST.date and 
							a.ComputerName = GST.ComputerName
			left outer join #tblLocationPST PST 
						on a.StoreName = PST.Location and 
							a.Date = PST.date and 
							a.ComputerName = PST.ComputerName
						;
		drop table #tblOneLocation;
		drop table #tblLocationGST;
		drop table #tblLocationPST;
	 end


	drop table #tbl1;
	drop table #tbl3;
	drop table #tbl4;
	drop table #tblNet;
	drop table #tblDeposit;
	drop table #tblCRF;
	drop table #tblEHF;
	drop table #tblTotalTax;
	drop table #tblFinal;
	drop table #tblTax;

END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetDayEndReportPrint]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_GetDayEndReportPrint] 
	@StoreName varchar(50),
	@ComputerName varchar(50),
	@FromDateTime varchar(50),
	@ToDateTime varchar(50),
	@DepartmentID varchar(50),
	@CategoryId varchar(50),
	@EmployeeId varchar(50),
	@Status varchar(50),
	@PrintBy varchar(50)
AS
BEGIN
	declare @s nvarchar(max);

	declare @StoreName2ndTime varchar(50)
	declare @ComputerName2ndTime varchar(50)
	declare @FromDateTime2ndTime varchar(50)
	declare @ToDateTime2ndTime varchar(50)
	declare @DepartmentID2ndTime varchar(50)
	declare @CategoryId2ndTime varchar(50)
	declare @EmployeeId2ndTime varchar(50)
	declare @Status2ndTime varchar(50)
	declare @PrintBy2ndTime varchar(50)


	set @StoreName2ndTime = @StoreName
	set @ComputerName2ndTime =@ComputerName
	set @FromDateTime2ndTime =@FromDateTime
	set @ToDateTime2ndTime =@ToDateTime
	set @DepartmentID2ndTime =@DepartmentID
	set @CategoryId2ndTime =@CategoryId
	set @EmployeeId2ndTime =@EmployeeId
	set @Status2ndTime =@Status
	set @PrintBy2ndTime =@PrintBy

	BEGIN TRY
		drop table test2;		
	END TRY
	BEGIN CATCH
			print '';
	END CATCH
	--*************************************************************
	--******** BY KEVIN ON JAN 15 2015 ********
	--\\poskingdc\documents\kevin\My Documents\SQL Server Management Studio
	--*************************************************************
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	--=======================================================================================
	SELECT PP.StoreName, 
		PP.computerName, 
		PP.Type, 
		PP.Method,
		PT.Cashier,
		count(PP.ID) as 'Count', 
		Sum(PP.PaymentAmount) AS PaymentAmount ,
		SUM(PP.ChangeAmount) AS ChangeAmount, 
		CONVERT(varchar(10), PP.StatusDateTime, 120) AS Date, 
		Sum(0 - Isnull(PP.PennyRounding,0)) as PennyRounding
		into #tbl1
		FROM POSPayment	 PP
		inner join POSTransaction PT on PP.TransactionID = PT.ID
		WHERE PP.StatusDateTime>=@FromDateTime2ndTime 
			AND PP.StatusDateTime<= @ToDateTime2ndTime 
			AND PP.Status = @Status2ndTime 
			and PP.StoreName = case @StoreName2ndTime When '' then PP.StoreName else @StoreName2ndTime end
			and PP.computerName = case @ComputerName2ndTime When '' then PP.ComputerName else @ComputerName2ndTime end
			and PT.Cashier =  case @EmployeeId2ndTime When '' then PT.Cashier else @EmployeeId2ndTime end
			and not exists(select TransactionID from TourTransaction where pp.TransactionID = TourTransaction.TransactionID)

		GROUP BY  PP.StoreName,PP.computerName, CONVERT(varchar(10), PP.StatusDateTime, 120), PP.Type, PP.Method,PT.Cashier;
	
	SELECT StoreName, 
		computerName, 
		Method,
		Cashier,
		Type,
		sum(Count) as  Count, 
		sum(PaymentAmount) as  PaymentAmount,
		sum(ChangeAmount) as  ChangeAmount, 
		Date, 
		sum(PennyRounding) as  PennyRounding
		into #tblFinal
		from #tbl1
		group by StoreName,computerName,Type,date,Method,Cashier;
	--=======================================================================================
	Select
		PT.StoreName
		,pT.ComputerName
		,PT.Cashier
		,TT.ItemDiscountAmount
		,TT.ItemTaxTotalAmount
		,TT.ItemSubTotal
		,TT.StatusDateTime
		,TT.Type
		into #tbl3
		From POSTransaction PT
			Left join TransactionItem TT on PT.ID = TT.TransactionID
		where 
			PT.Cashier =  case @EmployeeId2ndTime When '' then PT.Cashier else @EmployeeId2ndTime end
			and TT.Status = @Status2ndTime 
			and PT.StoreName = case @StoreName2ndTime When '' then PT.StoreName else @StoreName2ndTime end
			and PT.computerName = case @ComputerName2ndTime When '' then PT.ComputerName else @ComputerName2ndTime end
			and PT.StatusDateTime >=@FromDateTime2ndTime
			and PT.StatusDateTime <= @ToDateTime2ndTime
			and PT.Status = @Status2ndTime
			and not exists(select TransactionID from TourTransaction where PT.ID = TourTransaction.TransactionID)

	 Select 
		StoreName
		,ComputerName
		,Cashier
		,CONVERT(varchar(10), StatusDateTime, 120) as date
		,SUM(ItemTaxTotalAmount) as ItemTaxTotalAmount
		,SUM(ItemSubTotal) as ItemSubTotal
		,Type
		into #tbl4
		from #tbl3
		group by StoreName,computerName,Cashier,CONVERT(varchar(10), StatusDateTime, 120), type
	Select 
		StoreName
		,ComputerName
		,Cashier
		,date
		,SUM(ItemSubTotal) as decTotalNet
		into #tblNet
		from #tbl4
		where type<>'CRF' AND TYPE <> 'Deposit' and Type <> 'EHF'
		group by StoreName,computerName,Cashier,date
	Select 
		StoreName
		,ComputerName
		,Cashier
		,date
		,SUM(ItemSubTotal) as decDeposit
		into #tblDeposit
		from #tbl4
		where TYPE = 'Deposit' 
		group by StoreName,computerName,Cashier,date
	Select 
		StoreName
		,ComputerName
		,Cashier
		,date
		,SUM(ItemSubTotal) as decCRF
		into #tblCRF
		from #tbl4
		where TYPE = 'CRF' 
		group by StoreName,computerName,Cashier,date
	Select 
		StoreName
		,ComputerName
		,Cashier
		,date
		,SUM(ItemSubTotal) as decEHF
		into #tblEHF
		from #tbl4
		where TYPE = 'EHF' 
		group by StoreName,computerName,Cashier,date
	Select 
		StoreName
		,ComputerName
		,Cashier
		,date
		,sum(ItemTaxTotalAmount) as decTotalTax
		into #tblTotalTax
		from #tbl4
		group by StoreName,computerName,Cashier,date
	--=======================================================================================
	Select 
		POSTransaction.StoreName AS Location, 
		POSTransaction.computerName, 
		POSTransaction.Cashier,
		CONVERT(varchar(10), ti.StatusDateTime, 120) AS date,
		TaxName, 
		SUM(Tix.ItemTaxAmount) AS Amount 
		into #tblTax
		FROM POSTransaction 
		INNER JOIN TransactionItem AS ti ON POSTransaction.ID=ti.TransactionID 
		INNER JOIN TransactionItemTax AS Tix ON Tix.TransactionID = ti.TransactionID AND Tix.TransactionItemID = ti.ID 
		WHERE POSTransaction.Status = @Status2ndTime
			AND ti.Status=@Status2ndTime
			AND POSTransaction.StatusDateTime>=@FromDateTime2ndTime 
			AND POSTransaction.StatusDateTime<=@ToDateTime2ndTime
			AND POSTransaction.StoreName = case @StoreName2ndTime When '' then POSTransaction.StoreName else @StoreName2ndTime end
			AND POSTransaction.computerName = case @ComputerName2ndTime When '' then POSTransaction.ComputerName else @ComputerName2ndTime end
			and not exists(select TransactionID from TourTransaction where POSTransaction.ID = TourTransaction.TransactionID)

		Group By POSTransaction.StoreName, 
			POSTransaction.computerName, 
			POSTransaction.Cashier,
			CONVERT(varchar(10), ti.StatusDateTime, 120),TaxName 
	--=======================================================================================


	--=======================================================================================
	 if @StoreName2ndTime = ''
	 begin 
		SELECT  a.StoreName, 
			--a.Date, 
			a.Type,
			dbo.PayMethodShortName(Method) as Method,
			sum(a.Count) as  Count, 
			sum(a.PaymentAmount) as  PaymentAmount,
			sum(a.ChangeAmount) as  ChangeAmount, 
			sum(PennyRounding) as  PennyRounding
			into #tblWhole
			from #tblFinal a
			group by a.StoreName,a.Type,a.Method;
		------------------------------------------------------------------------------------
		Select 
		   StoreName
		  --,date
		  ,sum(Count) as wholeCount
		  --,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
		  ,sum(PaymentAmount - ChangeAmount) as wholePayment
		  ,sum(PennyRounding) as wholePennyRounding
			into #tblWholeCountPayment
			from #tblWhole
			group by StoreName--,date
			;
		Select 
		   StoreName
		  --,date
		  ,sum(decTotalNet) as decTotalNet
			into #tblNet1
			from #tblNet
			group by StoreName--,date
			;
		
		Select 
		   StoreName
		  --,date
		  ,sum(decDeposit) as decDeposit
			into #tblDeposit1
			from #tblDeposit
			group by StoreName--,date
			;
		Select 
		   StoreName
		  --,date
		  , sum(decCRF) as decCRF
			into #tblCRF1
			from #tblCRF
			group by StoreName--,date
			;
		
		
		Select 
		   StoreName
		  --,date
		  , sum(decEHF) as decEHF
			into #tblEHF1
			from #tblEHF
			group by StoreName--,date
			;
		
		Select 
		   StoreName
		  --,date
		  , sum(decTotalTax) as decTotalTax
			into #tblTotalTax1
			from #tblTotalTax
			group by StoreName--,date
			;
		------------------------------------------------------------------------------------
		--Select 
		--   StoreName
		--  --,Type
		--  , sum(ChangeAmount) as ChangeAmount
		--	into #tblChangeAmount
		--	from #tblWhole
		--	group by StoreName--,Type
		--	;
		Select 
		   StoreName
			--,Type
			,sum(PennyRounding) as PennyRounding
			into #tblPennyRounding
			from #tblWhole
			group by StoreName--,Type
			;
		------------------------------------------------------------------------------------
		select Location,
			--date,
			TaxName,
			sum(amount) as Amount
			into #tblGST
			from #tbltax
			where TaxName = 'GST'
			group by Location,TaxName;
		select Location,
			--date,
			TaxName,
			sum(amount) as Amount
			into #tblPST
			from #tbltax
			where TaxName = 'PST'
			group by Location,TaxName;
		
		---------------------------------------
		Select 
		   StoreName
		  --,date
		  --,Type
		  ,Method
		  ,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
			into #tblTest
			from #tblWhole
			group by StoreName,Method;
		Select 
		   StoreName
		  --,date
		  --,Type
		  ,Method
		  ,sum(Count) as wholeCount
			into #tblTest2
			from #tblWhole
			group by StoreName,Method;
		
		
		select * into #tblTestFinal from #tblTest 
		PIVOT(
			sum(wholePayment) for method in(
			Cash,Debit,VISA,USD,GC,MC,AE,
			SC,JCB,UP,EBT,Discover,[Check],AR
			)
		)as aaa;
		
		
		--select * from #tblTest;
		--select * from #tblTestFinal;
		select * into #tblTestFinal2 from #tblTest2 
		PIVOT(
			sum(wholeCount) for method in(
			Cash,Debit,VISA,USD,GC,MC,AE,
			SC,JCB,UP,EBT,Discover,[Check],AR
			)
		)as aaa;
		------------------------------------------------------------------------------------
		SELECT distinct a.StoreName as StoreId,
			a.StoreName as LOCATION,
			'All Terminal' as computerName,
			--a.Date, 
			--Count, 
			--a.type,
			--a.Method,
			--PaymentAmount,
			--ChangeAmount, 
			--PennyRounding,
			CAST(isnull(wholeCP.wholeCount,0) as int) as [Count],
			CAST(isnull(net.decTotalNet,0) as decimal(18, 2))			as [Total Sales],
			0 as SpaceRow1,--------------------------------------------------------------
			CAST(tf.Cash as decimal(18, 2)) as Cash,
			tf2.Cash  as CashCount  ,
			CAST(tf.Debit as decimal(18, 2)) as Debit,
			tf2.Debit as  DebitCount,
			CAST(tf.VISA as decimal(18, 2)) as VISA,
			tf2.VISA as   VISACount,
			CAST(tf.USD as decimal(18, 2)) as USD,
			tf2.USD as    USDCount,
			CAST(tf.GC as decimal(18, 2)) as GC,
			tf2.GC as 	   GCCount,
			CAST(tf.MC as decimal(18, 2)) as MC,
			tf2.MC as 	   MCCount,
			CAST(tf.AE as decimal(18, 2)) as AE,
			tf2.AE as 	   AECount,
			CAST(tf.SC as decimal(18, 2)) as SC,
			tf2.SC as 	   SCCount,
			CAST(tf.JCB as decimal(18, 2)) as JCB,
			tf2.JCB as    JCBCount,
			CAST(tf.UP as decimal(18, 2)) as UP,
			tf2.UP as 	   UPCount,
			CAST(tf.EBT as decimal(18, 2)) as EBT,
			tf2.EBT as    EBTCount,
			CAST(tf.Discover as decimal(18, 2)) as Discover,
			tf2.Discover as DiscoverCount,
			CAST(tf.[Check] as decimal(18, 2)) as [Check],
			tf2.[Check] as CheckCount,
			CAST(tf.AR as decimal(18, 2)) as AR,
			tf2.AR	 as  ARCount,
			CAST(isnull(wholeCP.wholePayment,0)  as decimal(18, 2))as TotalPayment,
			0 as SpaceRow2,--------------------------------------------------------------
			CAST(isnull(GST.Amount,0) as decimal(18, 2)) as GST,
			CAST(isnull(PST.Amount,0) as decimal(18, 2)) as PST,
			CAST(isnull(Deposit.decDeposit,0) as decimal(18, 2)) as Deposit,
			CAST(isnull(CRF.decCRF,0) as decimal(18, 2)) as CRF,
			CAST(isnull(EHF.decEHF,0) as decimal(18, 2)) as EHF,
			CAST(isnull(TotalTax.decTotalTax,0) as decimal(18, 2))	as TotalTax,
			0 as SpaceRow3,--------------------------------------------------------------
			--CAST(CA.ChangeAmount as decimal(18, 2))as ChangeAmount ,
			CAST(PR.PennyRounding as decimal(18, 2)) as PennyRounding,
			CAST(isnull(net.decTotalNet,0) +   
			isnull(TotalTax.decTotalTax,0) +
			isnull(Deposit.decDeposit,0) +
			isnull(CRF.decCRF,0) +
			isnull(EHF.decEHF,0) as decimal(18, 2)) as [Gross Sales],
			0 as SpaceRow4--------------------------------------------------------------
			--a.PaymentAmount - a.ChangeAmount + a.PennyRounding as Payment,
			--CAST(isnull(wholeCP.wholePennyRounding,0) as decimal(18, 2)) as TotalPennyRounding
			into #tblAll
			from #tblWhole a
			left outer join #tblNet1 net 
						on a.StoreName = net.StoreName --and 
							--a.Date = net.date 
			left outer join #tblDeposit1 Deposit 
						on a.StoreName = Deposit.StoreName --and 
							--a.Date = Deposit.date 
			left outer join #tblCRF1 CRF 
						on a.StoreName = CRF.StoreName --and 
							--a.Date = CRF.date 
			left outer join #tblEHF1 EHF 
						on a.StoreName = EHF.StoreName --and 
							--a.Date = EHF.date 
			left outer join #tblTotalTax1 TotalTax 
						on a.StoreName = TotalTax.StoreName --and 
							--a.Date = TotalTax.date 
			left outer join #tblGST GST 
						on a.StoreName = GST.Location --and 
							--a.Date = GST.date 
			left outer join #tblPST PST 
						on a.StoreName = PST.Location --and 
							--a.Date = PST.date 
			left outer join #tblWholeCountPayment wholeCP
						on a.StoreName = wholeCP.StoreName --and 
							--a.Date = wholeCP.date
			--left outer join #tblChangeAmount CA
			--			on a.StoreName = CA.StoreName --and 
							--a.Type = CA.Type
			left outer join #tblPennyRounding PR
						on a.StoreName = PR.StoreName --and 
							--a.Type = PR.Type
			left outer join #tblTestFinal TF
						on a.StoreName = TF.StoreName --and 
							--a.Type = TF.Type
			left outer join #tblTestFinal2 TF2
						on a.StoreName = TF2.StoreName --and 
							--a.Type = TF2.Type
			;
		--alter table #tblAll add RealColumnName varchar(100);
		--update #tblAll set realColumnName = storeId ;
		--------------------------------------------------
		set @s = 'create table test2(sName nvarchar(50)';
		select @s = @s + ',[' + storeId + '] nvarchar(50)' from #tblAll;
		set @s = @s + ')';
		exec(@s)

		BEGIN TRY
			drop table test3;		
		END TRY
		BEGIN CATCH
				print '';
		END CATCH
		--print @s
		declare @name nvarchar(50)
		--exec('');
		declare t_cursor cursor for 
		select name from tempdb.dbo.syscolumns 
		where id=object_id('Tempdb.dbo.#tblAll') and colid > 1 order by colid
		open t_cursor
		fetch next from t_cursor into @name
		while @@fetch_status = 0
		begin
			BEGIN TRY
				exec('select [' + @name + '] as t into test3 from #tblAll')
				set @s='insert into test2 select ''' + @name + ''''
				select @s = @s + ',N''' + rtrim(isnull(t,0)) + '''' from test3;
				print @s;
				exec(@s)
				exec('drop table test3')			
			END TRY
			BEGIN CATCH
				 print ERROR_MESSAGE() ;
				 print '';
			END CATCH
			fetch next from t_cursor into @name
		end
		--delete from test2 where sName = 'StoreName';
		delete from test2 where sName = 'computerName';
		update test2 set sName = 'SpaceRow' where sName like 'SpaceRow%';
		select * from test2;
		close t_cursor
		deallocate t_cursor
		drop table test2
		---------------------------------------
		drop table #tblNet1;
		drop table #tblDeposit1;
		drop table #tblCRF1;
		drop table #tblEHF1;
		drop table #tblTotalTax1;
		drop table #tblWhole;
		drop table #tblGST;
		drop table #tblPST;
		drop table #tblWholeCountPayment;
		drop table #tblTest;
		drop table #tblTest2;
		drop table #tblTestFinal;
		drop table #tblTestFinal2;
		--drop table #tblChangeAmount;
		drop table #tblPennyRounding;
		drop table #tblAll;
		
	 end 
	 else
	 begin
		if @PrintBy2ndTime='Terminal' 
		Begin
			SELECT  a.StoreName, 
				a.computerName, 
				a.Date, 
				a.Type,
				dbo.PayMethodShortName(a.Method) as Method,
				sum(a.Count) as  Count, 
				sum(a.PaymentAmount) as  PaymentAmount,
				sum(a.ChangeAmount) as  ChangeAmount, 
				sum(PennyRounding) as  PennyRounding
				into #tblOneLocation
				from #tblFinal a
				group by a.StoreName,computerName,a.date, a.type,a.Method;
			------------------------------------------------------------------------------------
			select StoreName
					,computerName
				  ,sum(Count) as wholeCount
				  ,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
				  ,sum(PennyRounding) as wholePennyRounding
				into #tblWholeOneLocationCountPayment
				from #tblOneLocation
				group by StoreName,computerName;
			------------------------------------------------------------------------------------
			Select 
			   StoreName
			  ,ComputerName
			  ,sum(decTotalNet) as decTotalNet
				into #tblNet2
				from #tblNet
				group by StoreName,ComputerName
				;
		
			Select 
			   StoreName
			  ,ComputerName
			  ,sum(decDeposit) as decDeposit
				into #tblDeposit2
				from #tblDeposit
				group by StoreName,ComputerName
				;
			Select 
			   StoreName
			  ,ComputerName
			  , sum(decCRF) as decCRF
				into #tblCRF2
				from #tblCRF
				group by StoreName,ComputerName
				;
		
		
			Select 
			   StoreName
			  ,ComputerName
			  , sum(decEHF) as decEHF
				into #tblEHF2
				from #tblEHF
				group by StoreName,ComputerName
				;
		
			Select 
			   StoreName
			  ,ComputerName
			  , sum(decTotalTax) as decTotalTax
				into #tblTotalTax2
				from #tblTotalTax
				group by StoreName,ComputerName
				;		
			------------------------------------------------------------------------------------
			select Location,
				computerName,
				TaxName,
				sum(amount) as Amount
				into #tblLocationGST
				from #tbltax
				where TaxName = 'GST'
				group by Location,computerName, TaxName;
			select Location,
				computerName,
				TaxName,
				sum(amount) as Amount
				into #tblLocationPST
				from #tbltax
				where TaxName = 'PST'
				group by Location,computerName,TaxName;
			------------------------------------------------------------------------------------
			Select 
			   StoreName
			  ,computerName
			  --,Type
			  ,Method
			  ,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
				into #tblTestOneLocation
				from #tblOneLocation
				group by StoreName,computerName,Method;
			Select 
			   StoreName
			  ,computerName
			  --,Type
			  ,Method
			  ,sum(Count) as wholeCount
				into #tblTest2OneLocation
				from #tblOneLocation
				group by StoreName,computerName,Method;
		
		
			select * into #tblTestFinalOneLocation from #tblTestOneLocation 
			PIVOT(
				sum(wholePayment) for method in(
				Cash,Debit,VISA,USD,GC,MC,AE,
				SC,JCB,UP,EBT,Discover,[Check],AR
				)
			)as aaa;
		
		
			select * into #tblTestFinal2OneLocation from #tblTest2OneLocation 
			PIVOT(
				sum(wholeCount) for method in(
				Cash,Debit,VISA,USD,GC,MC,AE,
				SC,JCB,UP,EBT,Discover,[Check],AR
				)
			)as aaa;
			------------------------------------------------------------------------------------
			SELECT distinct
				a.computerName as computerId,
				a.computerName as TERMINAL,
				--a.Date, 
				--Count, 
				--a.type,
				--a.Method,
				--PaymentAmount,
				--ChangeAmount, 
				--PennyRounding,
				CAST(isnull(wholeCP.wholeCount,0) as int) as [Count],
				CAST(isnull(net.decTotalNet,0) as decimal(18, 2))			as [Total Sales],
				0 as SpaceRow1,--------------------------------------------------------------
				CAST(tf.Cash as decimal(18, 2)) as Cash,
				tf2.Cash  as CashCount  ,
				CAST(tf.Debit as decimal(18, 2)) as Debit,
				tf2.Debit as  DebitCount,
				CAST(tf.VISA as decimal(18, 2)) as VISA,
				tf2.VISA as   VISACount,
				CAST(tf.USD as decimal(18, 2)) as USD,
				tf2.USD as    USDCount,
				CAST(tf.GC as decimal(18, 2)) as GC,
				tf2.GC as 	   GCCount,
				CAST(tf.MC as decimal(18, 2)) as MC,
				tf2.MC as 	   MCCount,
				CAST(tf.AE as decimal(18, 2)) as AE,
				tf2.AE as 	   AECount,
				CAST(tf.SC as decimal(18, 2)) as SC,
				tf2.SC as 	   SCCount,
				CAST(tf.JCB as decimal(18, 2)) as JCB,
				tf2.JCB as    JCBCount,
				CAST(tf.UP as decimal(18, 2)) as UP,
				tf2.UP as 	   UPCount,
				CAST(tf.EBT as decimal(18, 2)) as EBT,
				tf2.EBT as    EBTCount,
				CAST(tf.Discover as decimal(18, 2)) as Discover,
				tf2.Discover as DiscoverCount,
				CAST(tf.[Check] as decimal(18, 2)) as [Check],
				tf2.[Check] as CheckCount,
				CAST(tf.AR as decimal(18, 2)) as AR,
				tf2.AR	 as  ARCount,
				CAST(isnull(wholeCP.wholePayment,0)  as decimal(18, 2))as TotalPayment,
				0 as SpaceRow2,--------------------------------------------------------------
				CAST(isnull(GST.Amount,0) as decimal(18, 2)) as GST,
				CAST(isnull(PST.Amount,0) as decimal(18, 2)) as PST,
				CAST(isnull(Deposit.decDeposit,0) as decimal(18, 2)) as Deposit,
				CAST(isnull(CRF.decCRF,0) as decimal(18, 2)) as CRF,
				CAST(isnull(EHF.decEHF,0) as decimal(18, 2)) as EHF,
				CAST(isnull(TotalTax.decTotalTax,0) as decimal(18, 2))	as TotalTax,
				0 as SpaceRow3,--------------------------------------------------------------
				--CAST(CA.ChangeAmount as decimal(18, 2))as ChangeAmount ,
				CAST(wholeCP.wholePennyRounding as decimal(18, 2)) as PennyRounding,
				CAST(isnull(net.decTotalNet,0) +   
				isnull(TotalTax.decTotalTax,0) +
				isnull(Deposit.decDeposit,0) +
				isnull(CRF.decCRF,0) +
				isnull(EHF.decEHF,0) as decimal(18, 2)) as [Gross Sales],
				0 as SpaceRow4--------------------------------------------------------------
				--a.PaymentAmount - a.ChangeAmount + a.PennyRounding as Payment,
				--CAST(isnull(wholeCP.wholePennyRounding,0) as decimal(18, 2)) as TotalPennyRounding
				into #tblAllOneLocation
				from #tblOneLocation a
				left outer join #tblNet2 net 
							on a.StoreName = net.StoreName and 
								a.ComputerName = net.ComputerName
				left outer join #tblDeposit2 Deposit 
							on a.StoreName = Deposit.StoreName and 
								a.ComputerName = Deposit.ComputerName
				left outer join #tblCRF2 CRF 
							on a.StoreName = CRF.StoreName and 
								a.ComputerName = CRF.ComputerName
				left outer join #tblEHF2 EHF 
							on a.StoreName = EHF.StoreName and 
								a.ComputerName = EHF.ComputerName
				left outer join #tblTotalTax2 TotalTax 
							on a.StoreName = TotalTax.StoreName and 
								a.ComputerName = TotalTax.ComputerName
				left outer join #tblLocationGST GST 
							on a.StoreName = GST.Location and 
								a.ComputerName = GST.ComputerName
				left outer join #tblLocationPST PST 
							on a.StoreName = PST.Location and 
								a.ComputerName = PST.ComputerName
				left outer join #tblWholeOneLocationCountPayment wholeCP 
							on a.StoreName = wholeCP.StoreName and 
								a.ComputerName = wholeCP.computerName
				left outer join #tblTestFinalOneLocation TF
							on a.StoreName = TF.StoreName and 
								a.ComputerName = TF.computerName 
				left outer join #tblTestFinal2OneLocation TF2
							on a.StoreName = TF2.StoreName and 
								a.ComputerName = TF2.computerName
				;
			
			
				--------------------------------------------------
			set @s = 'create table test2(sName nvarchar(50)';
			select @s = @s + ',[' + computerId + '] nvarchar(50)' from #tblAllOneLocation;
			set @s = @s + ')';
			exec(@s);
		
			--print @s
			declare @nameOneLocation nvarchar(50)
			--exec('');
			declare t_cursor cursor for 
			select name from tempdb.dbo.syscolumns 
			where id=object_id('Tempdb.dbo.#tblAllOneLocation') and colid > 1 order by colid
			open t_cursor
			fetch next from t_cursor into @nameOneLocation
			while @@fetch_status = 0
			begin
				BEGIN TRY
					exec('select [' + @nameOneLocation + '] as t into test3 from #tblAllOneLocation')
					set @s='insert into test2 select ''' + @nameOneLocation + ''''
					select @s = @s + ',N''' + rtrim(isnull(t,0)) + '''' from test3;
					print @s;
					exec(@s)
					exec('drop table test3')			
				END TRY
				BEGIN CATCH
					 print ERROR_MESSAGE() ;
					 print '';
				END CATCH
				fetch next from t_cursor into @nameOneLocation
			end
			--delete from test2 where sName = 'StoreName';
			delete from test2 where sName = 'computerName';
			update test2 set sName = 'SpaceRow' where sName like 'SpaceRow%';
			select * from test2;
			close t_cursor
			deallocate t_cursor
			drop table test2
			---------------------------------------
			drop table #tblNet2;
			drop table #tblDeposit2;
			drop table #tblCRF2;
			drop table #tblEHF2;
			drop table #tblTotalTax2;
			drop table #tblOneLocation;
			drop table #tblLocationGST;
			drop table #tblLocationPST;
			drop table #tblWholeOneLocationCountPayment;
			drop table #tblTestOneLocation;
			drop table #tblTest2OneLocation;
			drop table #tblTestFinalOneLocation;
			drop table #tblTestFinal2OneLocation;
			drop table #tblAllOneLocation;
		end
		else if @PrintBy2ndTime='Employee' 
		Begin
			SELECT  a.StoreName, 
				a.Cashier, 
				a.Date, 
				a.Type,
				dbo.PayMethodShortName(a.Method) as Method,
				sum(a.Count) as  Count, 
				sum(a.PaymentAmount) as  PaymentAmount,
				sum(a.ChangeAmount) as  ChangeAmount, 
				sum(PennyRounding) as  PennyRounding
				into #tblOneLocationEmployee
				from #tblFinal a
				group by a.StoreName,Cashier,a.date, a.type,a.Method;
			------------------------------------------------------------------------------------
			select StoreName
					,Cashier
				  ,sum(Count) as wholeCount
				  ,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
				  ,sum(PennyRounding) as wholePennyRounding
				into #tblWholeOneLocationCountPaymentEmployee
				from #tblOneLocationEmployee
				group by StoreName,Cashier;
			------------------------------------------------------------------------------------
			Select 
			   StoreName
			  ,Cashier
			  ,sum(decTotalNet) as decTotalNet
				into #tblNet2Employee
				from #tblNet
				group by StoreName,Cashier
				;
		
			Select 
			   StoreName
			  ,Cashier
			  ,sum(decDeposit) as decDeposit
				into #tblDeposit2Employee
				from #tblDeposit
				group by StoreName,Cashier
				;
			Select 
			   StoreName
			  ,Cashier
			  , sum(decCRF) as decCRF
				into #tblCRF2Employee
				from #tblCRF
				group by StoreName,Cashier
				;
		
		
			Select 
			   StoreName
			  ,Cashier
			  , sum(decEHF) as decEHF
				into #tblEHF2Employee
				from #tblEHF
				group by StoreName,Cashier
				;
		
			Select 
			   StoreName
			  ,Cashier
			  , sum(decTotalTax) as decTotalTax
				into #tblTotalTax2Employee
				from #tblTotalTax
				group by StoreName,Cashier
				;		
			------------------------------------------------------------------------------------
			select Location,
				Cashier,
				TaxName,
				sum(amount) as Amount
				into #tblLocationGSTEmployee
				from #tbltax
				where TaxName = 'GST'
				group by Location,Cashier, TaxName;

			select Location,
				Cashier,
				TaxName,
				sum(amount) as Amount
				into #tblLocationPSTEmployee
				from #tbltax
				where TaxName = 'PST'
				group by Location,Cashier,TaxName;
			------------------------------------------------------------------------------------
			Select 
			   StoreName
			  ,Cashier
			  --,Type
			  ,Method
			  ,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
				into #tblTestOneLocationEmployee
				from #tblOneLocationEmployee
				group by StoreName,Cashier,Method;
			Select 
			   StoreName
			  ,Cashier
			  --,Type
			  ,Method
			  ,sum(Count) as wholeCount
				into #tblTest2OneLocationEmployee
				from #tblOneLocationEmployee
				group by StoreName,Cashier,Method;
		
		
			select * into #tblTestFinalOneLocationEmployee from #tblTestOneLocationEmployee 
			PIVOT(
				sum(wholePayment) for method in(
				Cash,Debit,VISA,USD,GC,MC,AE,
				SC,JCB,UP,EBT,Discover,[Check],AR
				)
			)as aaa;
		
		
			select * into #tblTestFinal2OneLocationEmployee from #tblTest2OneLocationEmployee 
			PIVOT(
				sum(wholeCount) for method in(
				Cash,Debit,VISA,USD,GC,MC,AE,
				SC,JCB,UP,EBT,Discover,[Check],AR
				)
			)as aaa;
			------------------------------------------------------------------------------------
			SELECT distinct
				a.Cashier as CashierId,
				isnull(p.FirstName,a.cashier) + ' ' + isnull(p.LastName, '') as Employee,
				--a.Date, 
				--Count, 
				--a.type,
				--a.Method,
				--PaymentAmount,
				--ChangeAmount, 
				--PennyRounding,
				CAST(isnull(wholeCP.wholeCount,0) as int) as [Count],
				CAST(isnull(net.decTotalNet,0) as decimal(18, 2))			as [Total Sales],
				0 as SpaceRow1,--------------------------------------------------------------
				CAST(tf.Cash as decimal(18, 2)) as Cash,
				tf2.Cash  as CashCount  ,
				CAST(tf.Debit as decimal(18, 2)) as Debit,
				tf2.Debit as  DebitCount,
				CAST(tf.VISA as decimal(18, 2)) as VISA,
				tf2.VISA as   VISACount,
				CAST(tf.USD as decimal(18, 2)) as USD,
				tf2.USD as    USDCount,
				CAST(tf.GC as decimal(18, 2)) as GC,
				tf2.GC as 	   GCCount,
				CAST(tf.MC as decimal(18, 2)) as MC,
				tf2.MC as 	   MCCount,
				CAST(tf.AE as decimal(18, 2)) as AE,
				tf2.AE as 	   AECount,
				CAST(tf.SC as decimal(18, 2)) as SC,
				tf2.SC as 	   SCCount,
				CAST(tf.JCB as decimal(18, 2)) as JCB,
				tf2.JCB as    JCBCount,
				CAST(tf.UP as decimal(18, 2)) as UP,
				tf2.UP as 	   UPCount,
				CAST(tf.EBT as decimal(18, 2)) as EBT,
				tf2.EBT as    EBTCount,
				CAST(tf.Discover as decimal(18, 2)) as Discover,
				tf2.Discover as DiscoverCount,
				CAST(tf.[Check] as decimal(18, 2)) as [Check],
				tf2.[Check] as CheckCount,
				CAST(tf.AR as decimal(18, 2)) as AR,
				tf2.AR	 as  ARCount,
				CAST(isnull(wholeCP.wholePayment,0)  as decimal(18, 2))as TotalPayment,
				0 as SpaceRow2,--------------------------------------------------------------
				CAST(isnull(GST.Amount,0) as decimal(18, 2)) as GST,
				CAST(isnull(PST.Amount,0) as decimal(18, 2)) as PST,
				CAST(isnull(Deposit.decDeposit,0) as decimal(18, 2)) as Deposit,
				CAST(isnull(CRF.decCRF,0) as decimal(18, 2)) as CRF,
				CAST(isnull(EHF.decEHF,0) as decimal(18, 2)) as EHF,
				CAST(isnull(TotalTax.decTotalTax,0) as decimal(18, 2))	as TotalTax,
				0 as SpaceRow3,--------------------------------------------------------------
				--CAST(CA.ChangeAmount as decimal(18, 2))as ChangeAmount ,
				CAST(wholeCP.wholePennyRounding as decimal(18, 2)) as PennyRounding,
				CAST(isnull(net.decTotalNet,0) +   
				isnull(TotalTax.decTotalTax,0) +
				isnull(Deposit.decDeposit,0) +
				isnull(CRF.decCRF,0) +
				isnull(EHF.decEHF,0) as decimal(18, 2)) as [Gross Sales],
				0 as SpaceRow4--------------------------------------------------------------
				--a.PaymentAmount - a.ChangeAmount + a.PennyRounding as Payment,
				--CAST(isnull(wholeCP.wholePennyRounding,0) as decimal(18, 2)) as TotalPennyRounding
				into #tblAllOneLocationEmployee
				from #tblOneLocationEmployee a
				left outer join PKUsers pu ON a.Cashier = pu.username
                left outer join PKUserLocation PUL on pul.userId = pu.userId and PUL.LocationId = @StoreName2ndTime
				left outer join PKEmployee P on p.ID = pu.EmployeeID 
			
				left outer join #tblNet2Employee net 
							on a.StoreName = net.StoreName and 
								a.Cashier = net.Cashier
				left outer join #tblDeposit2Employee Deposit 
							on a.StoreName = Deposit.StoreName and 
								a.Cashier = Deposit.Cashier
				left outer join #tblCRF2Employee CRF 
							on a.StoreName = CRF.StoreName and 
								a.Cashier = CRF.Cashier
				left outer join #tblEHF2Employee EHF 
							on a.StoreName = EHF.StoreName and 
								a.Cashier = EHF.Cashier
				left outer join #tblTotalTax2Employee TotalTax 
							on a.StoreName = TotalTax.StoreName and 
								a.Cashier = TotalTax.Cashier
				left outer join #tblLocationGSTEmployee GST 
							on a.StoreName = GST.Location and 
								a.Cashier = GST.Cashier
				left outer join #tblLocationPSTEmployee PST 
							on a.StoreName = PST.Location and 
								a.Cashier = PST.Cashier
				left outer join #tblWholeOneLocationCountPaymentEmployee wholeCP 
							on a.StoreName = wholeCP.StoreName and 
								a.Cashier = wholeCP.Cashier
				left outer join #tblTestFinalOneLocationEmployee TF
							on a.StoreName = TF.StoreName and 
								a.Cashier = TF.Cashier 
				left outer join #tblTestFinal2OneLocationEmployee TF2
							on a.StoreName = TF2.StoreName and 
								a.Cashier = TF2.Cashier
				;
			
			
				--------------------------------------------------
			set @s = 'create table test2(sName nvarchar(50)';
			select @s = @s + ',[' + CashierId + '] nvarchar(50)' from #tblAllOneLocationEmployee;
			set @s = @s + ')';
			exec(@s);
		
			--print @s
			declare @nameCashier nvarchar(50)
			--exec('');
			declare t_cursor cursor for 
			select name from tempdb.dbo.syscolumns 
			where id=object_id('Tempdb.dbo.#tblAllOneLocationEmployee') and colid > 1 order by colid
			open t_cursor
			fetch next from t_cursor into @nameCashier
			while @@fetch_status = 0
			begin
				BEGIN TRY
					exec('select [' + @nameCashier + '] as t into test3 from #tblAllOneLocationEmployee')
					set @s='insert into test2 select N''' + @nameCashier + ''''
					select @s = @s + ',N''' + rtrim(isnull(t,0)) + '''' from test3;
					--print @s;
					exec(@s)
					exec('drop table test3')			
				END TRY
				BEGIN CATCH
					 print ERROR_MESSAGE() ;
					 print '';
				END CATCH
				fetch next from t_cursor into @nameCashier
			end
			--delete from test2 where sName = 'StoreName';
			--delete from test2 where sName = 'computerName';
			SELECT distinct isnull(p.FirstName + ' ' + p.LastName,'-') as uName
                          ,isnull(pu.UserName,'-') as UserName
				into #Employee
                FROM PKEmployee P

                inner join PKUsers pu ON p.ID = pu.EmployeeID 
                inner join PKUserLocation PUL on pul.userId = pu.userId where PUL.LocationId = @StoreName2ndTime;
			
			update test2 set sName = 'SpaceRow' where sName like 'SpaceRow%';
			select * from test2;
			close t_cursor
			deallocate t_cursor
			drop table test2
			---------------------------------------
			drop table #tblNet2Employee;
			drop table #tblDeposit2Employee;
			drop table #tblCRF2Employee;
			drop table #tblEHF2Employee;
			drop table #tblTotalTax2Employee;
			drop table #tblOneLocationEmployee;
			drop table #tblLocationGSTEmployee;
			drop table #tblLocationPSTEmployee;
			drop table #tblWholeOneLocationCountPaymentEmployee;
			drop table #tblTestOneLocationEmployee;
			drop table #tblTest2OneLocationEmployee;
			drop table #tblTestFinalOneLocationEmployee;
			drop table #tblTestFinal2OneLocationEmployee;
			drop table #tblAllOneLocationEmployee;
			drop table #Employee;
		End
		else
		Begin
			SELECT  a.StoreName, 
				a.computerName, 
				a.Date, 
				a.Type,
				dbo.PayMethodShortName(a.Method) as Method,
				sum(a.Count) as  Count, 
				sum(a.PaymentAmount) as  PaymentAmount,
				sum(a.ChangeAmount) as  ChangeAmount, 
				sum(PennyRounding) as  PennyRounding
				into #tblDate
				from #tblFinal a
				group by a.StoreName,computerName,a.date, a.type,a.Method;
			------------------------------------------------------------------------------------
			select StoreName
					,Date
				  ,sum(Count) as wholeCount
				  ,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
				  ,sum(PennyRounding) as wholePennyRounding
				into #tblWholeDateCountPayment
				from #tblDate
				group by StoreName,Date;
			------------------------------------------------------------------------------------
			Select 
			   StoreName
			  ,date
			  ,sum(decTotalNet) as decTotalNet
				into #tblNet3
				from #tblNet
				group by StoreName,date
				;
		
			Select 
			   StoreName
			  ,date
			  ,sum(decDeposit) as decDeposit
				into #tblDeposit3
				from #tblDeposit
				group by StoreName,date
				;
			Select 
			   StoreName
			  ,date
			  , sum(decCRF) as decCRF
				into #tblCRF3
				from #tblCRF
				group by StoreName,date
				;
		
		
			Select 
			   StoreName
			  ,date
			  , sum(decEHF) as decEHF
				into #tblEHF3
				from #tblEHF
				group by StoreName,date
				;
		
			Select 
			   StoreName
			  ,date
			  , sum(decTotalTax) as decTotalTax
				into #tblTotalTax3
				from #tblTotalTax
				group by StoreName,date
				;		
			------------------------------------------------------------------------------------
			select Location,
				date,
				TaxName,
				sum(amount) as Amount
				into #tblDateGST
				from #tbltax
				where TaxName = 'GST'
				group by Location,date, TaxName;
			select Location,
				date,
				TaxName,
				sum(amount) as Amount
				into #tblDatePST
				from #tbltax
				where TaxName = 'PST'
				group by Location,date,TaxName;
			------------------------------------------------------------------------------------
			Select 
			   StoreName
			  ,date
			  --,Type
			  ,Method
			  ,sum(PaymentAmount - ChangeAmount + PennyRounding) as wholePayment
				into #tblTestDate
				from #tblDate
				group by StoreName,date,Method;
			Select 
			   StoreName
			  ,date
			  --,Type
			  ,Method
			  ,sum(Count) as wholeCount
				into #tblTest2Date
				from #tblDate
				group by StoreName,date,Method;
		
		
			select * into #tblTestFinalDate from #tblTestDate 
			PIVOT(
				sum(wholePayment) for method in(
				Cash,Debit,VISA,USD,GC,MC,AE,
				SC,JCB,UP,EBT,Discover,[Check],AR
				)
			)as aaa;
		
		
			select * into #tblTestFinal2Date from #tblTest2Date 
			PIVOT(
				sum(wholeCount) for method in(
				Cash,Debit,VISA,USD,GC,MC,AE,
				SC,JCB,UP,EBT,Discover,[Check],AR
				)
			)as aaa;
			------------------------------------------------------------------------------------
			SELECT distinct
				a.date as DateID,
				a.date as DATE,
				--a.Date, 
				--Count, 
				--a.type,
				--a.Method,
				--PaymentAmount,
				--ChangeAmount, 
				--PennyRounding,
				CAST(isnull(wholeCP.wholeCount,0) as int) as [Count],
				CAST(isnull(net.decTotalNet,0) as decimal(18, 2))			as [Total Sales],
				0 as SpaceRow1,--------------------------------------------------------------
				CAST(tf.Cash as decimal(18, 2)) as Cash,
				tf2.Cash  as CashCount  ,
				CAST(tf.Debit as decimal(18, 2)) as Debit,
				tf2.Debit as  DebitCount,
				CAST(tf.VISA as decimal(18, 2)) as VISA,
				tf2.VISA as   VISACount,
				CAST(tf.USD as decimal(18, 2)) as USD,
				tf2.USD as    USDCount,
				CAST(tf.GC as decimal(18, 2)) as GC,
				tf2.GC as 	   GCCount,
				CAST(tf.MC as decimal(18, 2)) as MC,
				tf2.MC as 	   MCCount,
				CAST(tf.AE as decimal(18, 2)) as AE,
				tf2.AE as 	   AECount,
				CAST(tf.SC as decimal(18, 2)) as SC,
				tf2.SC as 	   SCCount,
				CAST(tf.JCB as decimal(18, 2)) as JCB,
				tf2.JCB as    JCBCount,
				CAST(tf.UP as decimal(18, 2)) as UP,
				tf2.UP as 	   UPCount,
				CAST(tf.EBT as decimal(18, 2)) as EBT,
				tf2.EBT as    EBTCount,
				CAST(tf.Discover as decimal(18, 2)) as Discover,
				tf2.Discover as DiscoverCount,
				CAST(tf.[Check] as decimal(18, 2)) as [Check],
				tf2.[Check] as CheckCount,
				CAST(tf.AR as decimal(18, 2)) as AR,
				tf2.AR	 as  ARCount,
				CAST(isnull(wholeCP.wholePayment,0)  as decimal(18, 2))as TotalPayment,
				0 as SpaceRow2,--------------------------------------------------------------
				CAST(isnull(GST.Amount,0) as decimal(18, 2)) as GST,
				CAST(isnull(PST.Amount,0) as decimal(18, 2)) as PST,
				CAST(isnull(Deposit.decDeposit,0) as decimal(18, 2)) as Deposit,
				CAST(isnull(CRF.decCRF,0) as decimal(18, 2)) as CRF,
				CAST(isnull(EHF.decEHF,0) as decimal(18, 2)) as EHF,
				CAST(isnull(TotalTax.decTotalTax,0) as decimal(18, 2))	as TotalTax,
				0 as SpaceRow3,--------------------------------------------------------------
				--CAST(CA.ChangeAmount as decimal(18, 2))as ChangeAmount ,
				CAST(wholeCP.wholePennyRounding as decimal(18, 2)) as PennyRounding,
				CAST(isnull(net.decTotalNet,0) +   
				isnull(TotalTax.decTotalTax,0) +
				isnull(Deposit.decDeposit,0) +
				isnull(CRF.decCRF,0) +
				isnull(EHF.decEHF,0) as decimal(18, 2)) as [Gross Sales],
				0 as SpaceRow4--------------------------------------------------------------
				--a.PaymentAmount - a.ChangeAmount + a.PennyRounding as Payment,
				--CAST(isnull(wholeCP.wholePennyRounding,0) as decimal(18, 2)) as TotalPennyRounding
				into #tblAllDate
				from #tblDate a
				left outer join #tblNet3 net 
							on a.StoreName = net.StoreName and 
								a.date = net.date
				left outer join #tblDeposit3 Deposit 
							on a.StoreName = Deposit.StoreName and 
								a.date = Deposit.date
				left outer join #tblCRF3 CRF 
							on a.StoreName = CRF.StoreName and 
								a.date = CRF.date
				left outer join #tblEHF3 EHF 
							on a.StoreName = EHF.StoreName and 
								a.date = EHF.date
				left outer join #tblTotalTax3 TotalTax 
							on a.StoreName = TotalTax.StoreName and 
								a.date = TotalTax.date
				left outer join #tblDateGST GST 
							on a.StoreName = GST.Location and 
								a.date = GST.date
				left outer join #tblDatePST PST 
							on a.StoreName = PST.Location and 
								a.date = PST.date
				left outer join #tblWholeDateCountPayment wholeCP 
							on a.StoreName = wholeCP.StoreName and 
								a.date = wholeCP.date
				left outer join #tblTestFinalDate TF
							on a.StoreName = TF.StoreName and 
								a.date = TF.date 
				left outer join #tblTestFinal2Date TF2
							on a.StoreName = TF2.StoreName and 
								a.date = TF2.date
				;
			
			
				--------------------------------------------------
			set @s = 'create table test2(sName nvarchar(50)';
			select @s = @s + ',[' + date + '] nvarchar(50)' from #tblAllDate;
			set @s = @s + ')';
			exec(@s);
		
			--print @s
			declare @nameDate nvarchar(50)
			--exec('');
			declare t_cursor cursor for 
			select name from tempdb.dbo.syscolumns 
			where id=object_id('Tempdb.dbo.#tblAllDate') and colid > 1 order by colid
			open t_cursor
			fetch next from t_cursor into @nameDate
			while @@fetch_status = 0
			begin
				BEGIN TRY
					exec('select [' + @nameDate + '] as t into test4 from #tblAllDate')
					set @s='insert into test2 select ''' + @nameDate + ''''
					select @s = @s + ',''' + rtrim(isnull(t,0)) + '''' from test4;
					print @s;
					exec(@s)
					exec('drop table test4')			
				END TRY
				BEGIN CATCH
					 print ERROR_MESSAGE() ;
					 print '';
				END CATCH
				fetch next from t_cursor into @nameDate
			end
			--delete from test2 where sName = 'StoreName';
			delete from test2 where sName = 'DateId';
			update test2 set sName = 'SpaceRow' where sName like 'SpaceRow%';
			select * from test2;
			close t_cursor
			deallocate t_cursor
			drop table test2
			---------------------------------------
			drop table #tblNet3;
			drop table #tblDeposit3;
			drop table #tblCRF3;
			drop table #tblEHF3;
			drop table #tblTotalTax3;
			drop table #tblDate;
			drop table #tblDateGST;
			drop table #tblDatePST;
			drop table #tblWholeDateCountPayment;
			drop table #tblTestDate;
			drop table #tblTest2Date;
			drop table #tblTestFinalDate;
			drop table #tblTestFinal2Date;
			drop table #tblAllDate;
		End
	 end
	drop table #tbl1;
	drop table #tbl3;
	drop table #tbl4;
	drop table #tblNet;
	drop table #tblDeposit;
	drop table #tblCRF;
	drop table #tblEHF;
	drop table #tblTotalTax;
	drop table #tblFinal;
	drop table #tblTax;
	select 1;
	select 2;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetDictSelectAll]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetDictSelectAll]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @currentLanguage varchar(50);
	declare @SqlStr varchar(500);

	select @currentLanguage = isnull(value,'') from pksetting where fieldname = 'LanguangeSetting';

	if len(@currentLanguage)=0
	begin
		return;
	end

	set @SqlStr = 'select id,fieldName,english, '+ @currentLanguage +' as name2 from PK_Dictionary order by id desc'
	exec(@SqlStr);

END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetDictSelectByDictID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[PK_GetDictSelectByDictID]
	@intDict int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @currentLanguage varchar(50);
	declare @SqlStr varchar(500);

	select @currentLanguage = isnull(value,'') from pksetting where fieldname = 'LanguangeSetting';

	if len(@currentLanguage)=0
	begin
		return;
	end

	set @SqlStr = 'select id,fieldName,english, '+ @currentLanguage +' as name2 from PK_Dictionary where id = ' + cast(@intDict as varchar(50))
	exec(@SqlStr);

END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetExpenseList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetExpenseList]
	@locationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	SELECT PKPurchasePackageOrder.transferId, PKLocation.LocationName AS Location INTO #tbl1 FROM PKPurchasePackageOrder
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId

	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount INTO #tbl2 FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance
	SELECT PKPurchasePackagePaymentItem.transferId INTO #tbl3 FROM #tbl2 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)

	SELECT PKPurchasePackage.PurchaseId AS ID, CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, PKPurchasePackage.CardNumber AS Card,  PKPurchasePackage.CardHolders AS Customer, 
	(CASE WHEN ISNULL(PKPromotion.Name2, '') = '' THEN PKPromotion.Name1 ELSE (PKPromotion.Name1 + ' / ' + PKPromotion.Name2 ) END) AS Product,
	PKPurchasePackage.amount AS Price, Location.Location,createdBy FROM PKPurchasePackage
	INNER JOIN PKPromotion ON PKPromotion.ID = PKPurchasePackage.BomOrProductID
	INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
	INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
	WHERE itemType = 'B' and PKPurchasePackage.Status = 'Active'
	UNION
	(
		SELECT PKPurchasePackage.PurchaseId AS ID, CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, PKPurchasePackage.CardNumber AS Card,  PKPurchasePackage.CardHolders AS Customer, 
		(CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2 ) END) AS Product,
		PKPurchasePackage.amount AS Price, Location.Location,createdBy FROM PKPurchasePackage
		INNER JOIN PKProduct ON PKProduct.ID = PKPurchasePackage.BomOrProductID
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
		INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
		WHERE itemType = 'P' and PKPurchasePackage.Status = 'Active'
	) 

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetExpenseListNew]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetExpenseListNew]
	@locationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	SELECT PKPurchasePackageOrder.transferId, PKLocation.LocationName AS Location 
	INTO #tbl1 
	FROM PKPurchasePackageOrder
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId
	------------
	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl2 
	FROM PKPurchasePackagePayment 
	GROUP BY PaymentOrderID, Balance
	--------------------
	SELECT PKPurchasePackagePaymentItem.transferId 
	INTO #tbl3 
	FROM #tbl2 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID

	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)
	--------------------------
	SELECT distinct PKPurchasePackage.PurchaseId AS ID, CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, PKPurchasePackage.CardNumber AS Card,  PKPurchasePackage.CardHolders AS Customer, 
	(CASE WHEN ISNULL(PKPromotion.Name2, '') = '' THEN PKPromotion.Name1 ELSE (PKPromotion.Name1 + ' / ' + PKPromotion.Name2 ) END) AS Product,
	PKPurchasePackage.amount AS Price, Location.Location,createdBy ,PU.UserName as Sales, '' as SalesCommission,'' as CreateByCommission
	FROM PKPurchasePackage
	INNER JOIN PKPromotion ON PKPromotion.ID = PKPurchasePackage.BomOrProductID
	INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
	INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
	left outer join PKUsers PU on pu.EmployeeID = PKPurchasePackage.booker
	WHERE itemType = 'B' and PKPurchasePackage.Status = 'Active'
	UNION
	(
		SELECT PKPurchasePackage.PurchaseId AS ID, CAST(PKPurchasePackage.CreateDate AS datetime) AS TimeDate, PKPurchasePackage.CardNumber AS Card,  PKPurchasePackage.CardHolders AS Customer, 
		(CASE WHEN ISNULL(PKProduct.Name2, '') = '' THEN PKProduct.Name1 ELSE (PKProduct.Name1 + ' / ' + PKProduct.Name2 ) END) AS Product,
		PKPurchasePackage.amount AS Price, Location.Location,createdBy , PU.UserName as Sales, '' as SalesCommission,'' as CreateByCommission
		FROM PKPurchasePackage
		INNER JOIN PKProduct ON PKProduct.ID = PKPurchasePackage.BomOrProductID
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKPurchasePackage.transferId
		INNER JOIN #tbl3 AS Payment ON Payment.transferId = PKPurchasePackage.transferId
		left outer join PKUsers PU on pu.EmployeeID = PKPurchasePackage.booker
		WHERE itemType = 'P' and PKPurchasePackage.Status = 'Active'

	) 

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
END




GO
/****** Object:  StoredProcedure [dbo].[PK_GetGiftCardNo]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetGiftCardNo] 
	@CardName VARCHAR(50),
	@CardNo VARCHAR(50)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	SELECT PKGiftCardSN.CardNo, PKGiftCardSN.CardID AS Cardid, ISNULL(PKGiftCardSN.LocationID, '') AS LocationID, PKGiftCardSN.SaleTime, LOWER(PKGiftCardSN.Status) AS CardNoStatus, 
	LOWER(PKGiftCard.Status) AS CardStatus, ISNULL(PKGiftCard.Deposit, 0.00) AS Amount,isnull(PKGiftCardSN.balance, 0) as Balance FROM PKGiftCard 
	INNER JOIN PKGiftCardSN ON PKGiftCardSN.CardID = PKGiftCard.ID WHERE (PKGiftCard.Name1 = @CardName) AND (PKGiftCardSN.CardNo = @CardNo)
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetInventoryAllQtyWithoutCondition]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_GetInventoryAllQtyWithoutCondition] 
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT pI.productid, 
		   pI.averagecost, 
		   pI.qty, 
		   pI.unit 
	INTO   #tbl1 
	FROM   pkinventory pI 
		   INNER JOIN pklocation pL 
				   ON PI.locationid = pl.locationid 
	WHERE  pl.isheadquarter = '1' 

	SELECT pI.productid, 
		   Sum(pI.qty) AS QTy 
	INTO   #tbl2 
	FROM   pkinventory pI 
		   INNER JOIN pklocation pL 
				   ON PI.locationid = pl.locationid 
	WHERE  Isnull(pl.isheadquarter, '') <> '1' 
	GROUP  BY pi.productid 

	SELECT t1.productid, 
		   t1.averagecost, 
		   Isnull(t1.qty, 0) + Isnull(t2.qty, 0) AS QTY, 
		   t1.unit 
	INTO   #tbl3 
	FROM   #tbl1 t1 
		   INNER JOIN #tbl2 t2 
				   ON t1.productid = t2.productid 

	SELECT t3.productid, 
		   t3.averagecost, 
		   --t3.qty,  
		   CASE Abs(t3.qty) - t3.qty 
			 WHEN 0 THEN t3.qty 
			 ELSE 0 
		   END AS QTy, 
		   t3.unit ,
		   p.name1,
		   p.Description1
	FROM   #tbl3 t3 
		   INNER JOIN pkproduct p 
				   ON t3.productid = p.id 
	ORDER  BY t3.productid 


	DROP TABLE #tbl1; 
	DROP TABLE #tbl2; 
	DROP TABLE #tbl3; 

END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetInventoryInboundProdList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetInventoryInboundProdList]
	@locationId varchar(50),
	@ProductId varchar(8000),
	@Status varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @tempDecNumber DECIMAL(18, 4); 
	DECLARE @tempDecNumber2 DECIMAL(18, 2); 

	declare @str varchar(max);
	declare @tablename table(value varchar(50));
	set @str = @ProductId + ',';
	set @str = replace(@str,' ','');
	set @str = replace(@str,',,',',');
	set @str = replace(@str,',,',',');
	set @str = replace(@str,',,',',');
	Declare @insertStr varchar(50) --
	Declare @newstr varchar(8000) --
	set @insertStr = left(@str,charindex(',',@str)-1)
	set @insertStr = ltrim(rtrim(replace(@insertStr,char(13),'')));
	set @insertStr = replace(@insertStr,char(10),'');
	set @newstr = stuff(@str,1,charindex(',',@str),'')
	Insert @tableName Values(@insertStr)
	
	Declare @intLoopLimit int;
	set @intLoopLimit = 300;
	while(len(@newstr)>0)
	begin
		set @insertStr = left(@newstr,charindex(',',@newstr)-1)
		set @insertStr = ltrim(rtrim(replace(@insertStr,char(13),'')));
		set @insertStr = replace(@insertStr,char(10),'');
		Insert @tableName Values(@insertStr)
		set @newstr = stuff(@newstr,1,charindex(',',@newstr),'')
		--print '[' + @insertStr + ']'
		--Here to avoid the loop to be unlimited loop----------
		set @intLoopLimit =@intLoopLimit-1
		if @intLoopLimit <=0 
		begin
			set @newstr = ''
		end
		-- End ------------------------------------------------
	end
	set @tempDecNumber = 1.0000;

    SELECT PKip.id, 
       PKip.locationid, 
       inboundid, 
       productid, 
       PKip.plu, 
       PKip.barcode, 
       productname1, 
       productname2, 
       Isnull(PKip.packl, 0)                      AS PackL, 
       Isnull(PKip.packm, 0)                      AS PackM, 
       Isnull(PKip.packs, 0)                      AS PackS, 
       PKip.size, 
       PKip.unit, 
       PKip.weigh, 
       Isnull(unitcost, 0.00)                AS UnitCost, 
       Isnull(orderqty, 0.00)                AS OrderQty, 
       Isnull(totalcost, 0.00)               AS TotalCost, 
       PKip.remarks, 
       pki.poid, 
       receiveid, 
       Isnull(inbounddate, '')               AS InboundDate, 
       inboundby, 
       PKip.status, 
       Isnull(CONVERT(VARCHAR(10), po.orderdate, 121), '') 
       + Isnull(CONVERT(VARCHAR(10), SR.returndate, 121), '') 
       + CASE WHEN SR.returndate IS NULL THEN Isnull(CONVERT(VARCHAR(10), 
       pkso.orderdate, 121), '') ELSE '' END AS orderdate, 
       Cast(PKi.seq AS VARCHAR(10)) + '/' 
       + Isnull(po.orderid, '') + CASE WHEN SR.soreturnid IS NULL THEN '' ELSE 
       SR.soreturnid +'/' END 
       + Isnull(pkso.orderid, '')            AS OrderID, 
       Pkip.serialnumber,
	   p.Unit as originalUnit,
	   @tempDecNumber as capacity,
	   @tempDecNumber2 as OriginalCost,
	   @tempDecNumber2 as OriginalQty,
	   dbo.PK_FuncGetRatesBetween2Units(p.unit,pkip.Unit) as unitRate,
	   PKip.seq

	into #tblOriginal
	FROM   pkinboundproduct AS PKip 
		inner join @tablename tn on tn.value = pkip.ProductID
		inner join PKProduct p on p.id = tn.value
		   LEFT JOIN pkinbound AS PKi 
				  ON PKip.inboundid = PKi.id 
		   LEFT JOIN pkpo AS po 
				  ON PKi.poid = po.poid 
		   LEFT JOIN pksoreturn AS SR 
				  ON Pki.receiveid = SR.id 
		   LEFT JOIN pkso 
				  ON PKi.poid = pkso.soid 
	WHERE  PKip.locationid = @locationId
		   --AND productid = @ProductId 
		   AND PKip.status = @Status

			  ;
	
	update #tblOriginal set OriginalCost = unitcost * unitRate, OriginalQty = orderqty / unitRate;

	select * from #tblOriginal 	
	ORDER  BY seq DESC ;


	drop table #tblOriginal;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetInventoryProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetInventoryProduct] @ProductId  VARCHAR(50), 
                                               @LocationId VARCHAR(50) 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from 
      -- interfering with SELECT statements. 
      SET nocount ON; 

      DECLARE @isHeaderQuater BIT; 
      DECLARE @AveCost DECIMAL(18, 2); 
      DECLARE @Latest DECIMAL(18, 2); 

      SELECT @isHeaderQuater = isheadquarter 
      FROM   pklocation 
      WHERE  locationid = @LocationId; 

      IF @isHeaderQuater = 1 
        BEGIN 
            SELECT Piv.id, 
                   Piv.locationid, 
                   Piv.productid, 
                   Piv.qty, 
                   pp.unit, 
                   Piv.latestcost, 
                   Piv.averagecost, 
                   Piv.updatetime, 
                   Piv.createtime, 
                   Piv.creater, 
                   Piv.updater 
            FROM   pkinventory Piv
			inner join PKProduct pp on pp.id = piv.ProductID
            WHERE  ( Piv.locationid = @LocationID 
                     AND Piv.productid = @ProductID ) 
        END 
      ELSE 
        BEGIN 
            SELECT @AveCost = averagecost, 
                   @Latest = latestcost 
            FROM   pkinventory a 
                   INNER JOIN pklocation b 
                           ON a.locationid = b.locationid 
            WHERE  a.productid = @ProductId 
                   AND b.isheadquarter = 1 

            SELECT Piv.id, 
                   Piv.locationid, 
                   Piv.productid, 
                   Piv.qty, 
                   pp.unit, 
                   @Latest  AS LatestCost, 
                   @AveCost AS AverageCost, 
                   Piv.updatetime, 
                   Piv.createtime, 
                   Piv.creater, 
                   Piv.updater 
            FROM   pkinventory Piv
			inner join PKProduct pp on pp.id = piv.ProductID
            WHERE  ( Piv.locationid = @LocationID 
                     AND Piv.productid = @ProductID ) 
        END 
  END 



GO
/****** Object:  StoredProcedure [dbo].[Pk_GetInventoryProductInBaseProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Pk_GetInventoryProductInBaseProduct] @LocationId VARCHAR(50), 
                                                            @DepartmentId VARCHAR(50), 
                                                            @CategoryId VARCHAR(50), 
                                                            @Barcode VARCHAR(50), 
                                                            @Brand NVARCHAR(50), 
                                                            @PLU VARCHAR(50), 
                                                            @ProductName NVARCHAR(50), 
                                                            @status VARCHAR(50), 
                                                            @QtyMorethan DECIMAL(18, 2), 
                                                            @QtyLessThan DECIMAL(18, 2) 
--  @SearchType varchar(50),   
--  @SearchValue varchar(200),  
--  @Order varchar(50)--,  
--@PageIndex int,  
--@PageSize int  
AS 
  BEGIN 
        declare @secondLocationId VARCHAR(50)
		declare @secondDepartmentId VARCHAR(50)
		declare @secondCategoryId VARCHAR(50) 
		declare @secondBarcode VARCHAR(50) 
		declare @secondBrand NVARCHAR(50) 
		declare @secondPLU VARCHAR(50) 
		declare @secondProductName NVARCHAR(50) 
		declare @secondstatus VARCHAR(50) 
		declare @secondQtyMorethan DECIMAL(18, 2) 
		declare @secondQtyLessThan DECIMAL(18, 2) 
		declare @tempDecNumber decimal(18,4);
		set @tempDecNumber = 1.00;

		set @secondLocationId			=	@LocationId		
		set @secondDepartmentId		=	@DepartmentId	
		set @secondBarcode			=	@Barcode		
		set @secondBrand				=	@Brand			
		set @secondCategoryId			=	@CategoryId		
		set @secondPLU				=	@PLU			
		set @secondProductName		=	@ProductName	
		set @secondQtyMorethan		=	@QtyMorethan	
		set @secondQtyLessThan		=	@QtyLessThan	
		set @secondStatus				=	@Status			

      SELECT productid, 
             Sum(Isnull(orderqty, 0)) AS ONHold, 
             pksoproduct.locationid 
      INTO   #tbl3 
      FROM   pkso 
             INNER JOIN pksoproduct 
                     ON pkso.soid = pksoproduct.soid 
      WHERE  ( pkso.status = 'Pending' 
                OR pkso.status = 'Back' ) 
             AND pkso.locationid = CASE 
                                     WHEN @secondLocationId = '-1' 
                                           OR @secondLocationId = '' THEN 
                                     pkso.locationid 
                                     ELSE @secondLocationId 
                                   END 
      GROUP  BY productid, 
                pksoproduct.locationid 
	  


      SELECT pkpoproduct.productid, 
             Sum(Isnull(pkpoproduct.orderqty, 0) - Isnull(RP.receiveqty, 0)) AS 
             ONOrder, 
             pkpo.locationid 
      INTO   #tbl4 
      FROM   pkpo 
             INNER JOIN pkpoproduct 
                     ON pkpo.poid = pkpoproduct.poid 
             LEFT OUTER JOIN (SELECT poproductid, 
                                     Sum(Isnull(orderqty, 0)) AS ReceiveQTY 
                              FROM   pkreceiveproduct 
                              GROUP  BY poproductid) AS RP 
                          ON pkpoproduct.poproductid = RP.poproductid 
      WHERE  pkpo.status = 'Pending' 
             AND pkpo.locationid = CASE 
                                     WHEN @secondLocationId = '-1' 
                                           OR @secondLocationId = '' THEN 
                                     pkpo.locationid 
                                     ELSE @secondLocationId 
                                   END 
      GROUP  BY pkpoproduct.productid, 
                pkpo.locationid 




      SELECT pit.productid, 
             pit.averagecost, 
             pit.latestcost 
      INTO   #tblheadquatercost 
      FROM   pkinventory PIt 
             INNER JOIN pklocation pL 
                     ON pl.locationid = PIt.locationid 
                        AND pl.isheadquarter = '1' 
      ORDER  BY productid 
	  

      SELECT DISTINCT PKl.locationid                           AS LocationID, 
                      PKv.id                                   AS ProductID, 
                      PKl.locationname                         AS Location, 
                      PKd.NAME                                 AS Department, 
                      PKc.NAME                                 AS Category, 
                      PKv.plu                                  AS PLU, 
                      PKv.Barcode                              AS Barcode, 
                      PKv.name1                                AS Name1, 
                      PKv.name2                                AS Name2, 
                      PKv.description1                         AS Description1, 
                      PKinv.qty                                AS Qty, 
                      PKv.unit                                 AS Unit, 
                      Isnull(tHQ.latestcost, 0)                AS LatestCost, 
                      Isnull(tHQ.averagecost, 0)               AS AverageCost, 
                      PKinv.updatetime                         AS UpdateTime, 
                      PKinv.updater                            AS Updater, 
                      PKv.status                               AS Status, 
                      PKv.brand                                AS Brand, 
                      Isnull(PKv.packs, 0)                     AS PackSize, 
                      PKinv.qty * Isnull(PKinv.averagecost, 0) AS TotalAmount, 
                      SO.onhold, 
                      PO.onorder, 
                      Pkv.packagecapacity 
      INTO   #tbl1 
      FROM   pkinventory AS PKinv 
             INNER JOIN pkproduct AS PKv 
                     ON PKinv.productid = PKv.id 
             INNER JOIN pklocation AS PKl 
                     ON PKinv.locationid = PKl.locationid 
             JOIN pkcategory AS PKc 
               ON PKv.categoryid = PKc.id 
             JOIN pkdepartment AS PKd 
               ON PKc.departmentid = PKd.id 
             LEFT JOIN #tbl3 SO 
                    ON SO.productid = PKinv.productid 
                       AND SO.locationid = Pkinv.locationid 
             LEFT JOIN #tbl4 PO 
                    ON PKinv.productid = PO.productid 
                       AND PKinv.locationid = PO.locationid 
             LEFT JOIN #tblheadquatercost tHQ 
                    ON tHQ.productid = PKinv.productid 
      WHERE
			(@secondLocationId = '-1' or (@secondLocationId <> '-1' and  PKl.locationid = @secondLocationId))
	  and (@secondDepartmentId = '-1' or (@secondDepartmentId <> '-1' and pkd.id = @secondDepartmentId))
	  and (@secondCategoryId = '-1' or (@secondCategoryId <> '-1' and PKc.id = @secondCategoryId))
	  and ((@secondstatus = '-1' and PKv.status <> 'Deleted') or (@secondstatus <> '-1' and PKv.status = @secondstatus))

	  and ((@secondBarcode = '' or (@secondBarcode <> '' and PKv.barcode like '%' + @secondBarcode + '%'))
		  or (@secondPLU = '' or (@secondPLU <> '' and PKv.plu like '%' + @secondPLU + '%')))

	  and (@secondBrand = '' or (@secondBrand <> '' and PKv.brand like '%' + @secondBrand + '%'))
	  and (@secondProductName = '' or (@secondProductName <> '' and (PKv.name1  like '%' + @secondProductName + '%' or  PKv.name2  like '%' + @secondProductName + '%')))
            

             AND 
             --PKinv.Qty >= isnull(@secondQtyMorethan,-2147483647) --case @secondQtyMorethan when 0 then PKinv.Qty else @secondQtyMorethan end  
             --and   
             --PKinv.Qty <= isnull(@secondQtyLessThan, 2147483647) --case @secondQtyLessThan when 0 then PKinv.Qty else @secondQtyLessThan end  
             ( ( @secondQtyMorethan = 0 
                 AND @secondQtyLessThan = 0 
                 AND pkinv.qty = 0 ) 
                OR ( NOT ( @secondQtyMorethan = 0 
                           AND @secondQtyLessThan = 0 ) 
                     AND PKinv.qty >= Isnull(@secondQtyMorethan, -2147483647) 
                     --case @secondQtyMorethan when 0 then PKinv.Qty else @secondQtyMorethan end  
                     AND PKinv.qty < Isnull(@secondQtyLessThan, 2147483647) 
                    --case @secondQtyLessThan when 0 then PKinv.Qty else @secondQtyLessThan end  
                    ) ) 
		-----------------------------------------------------------------------------
		-- the following code is to get BaseProduct for those child Product in #tbl1.
		-----------------------------------------------------------------------------	
		select distinct pm.BaseProductID as productId 
		into #tblAllProd
		from pkMapping PM
		inner join #tbl1 on #tbl1.ProductID = pm.BaseProductID or #tbl1.ProductID = PM.ProductID
		;
		insert into #tblAllProd
		select ProductId from PKMapping where exists(select * from #tblAllProd where #tblAllProd.productId = PKMapping.BaseProductID)
		delete from #tblAllProd where exists (select * from #tbl1 where #tbl1.ProductID = #tblAllProd.productId)
			
		SELECT DISTINCT PKl.locationid                           AS LocationID, 
                      PKv.id                                   AS ProductID, 
                      PKl.locationname                         AS Location, 
                      PKd.NAME                                 AS Department, 
                      PKc.NAME                                 AS Category, 
                      PKv.plu                                  AS PLU, 
                      PKv.Barcode                              AS Barcode, 
                      PKv.name1                                AS Name1, 
                      PKv.name2                                AS Name2, 
                      PKv.description1                         AS Description1, 
                      PKinv.qty                                AS Qty, 
                      PKv.unit                                 AS Unit, 
                      Isnull(tHQ.latestcost, 0)                AS LatestCost, 
                      Isnull(tHQ.averagecost, 0)               AS AverageCost, 
                      PKinv.updatetime                         AS UpdateTime, 
                      PKinv.updater                            AS Updater, 
                      PKv.status                               AS Status, 
                      PKv.brand                                AS Brand, 
                      Isnull(PKv.packs, 0)                     AS PackSize, 
                      PKinv.qty * Isnull(PKinv.averagecost, 0) AS TotalAmount, 
                      @tempDecNumber as onhold, 
                      @tempDecNumber as onorder, 
                      Pkv.packagecapacity 
      INTO   #tbl1BaseProduct 
      FROM   #tblAllProd t
			 inner join pkinventory AS PKinv on t.productId = PKinv.ProductID
             INNER JOIN pkproduct AS PKv 
                     ON PKinv.productid = PKv.id 
             INNER JOIN pklocation AS PKl 
                     ON PKinv.locationid = PKl.locationid 
             JOIN pkcategory AS PKc 
               ON PKv.categoryid = PKc.id 
             JOIN pkdepartment AS PKd 
               ON PKc.departmentid = PKd.id 
             LEFT JOIN #tblheadquatercost tHQ 
                    ON tHQ.productid = PKinv.productid 
      WHERE
			(@secondLocationId = '-1' or (@secondLocationId <> '-1' and  PKl.locationid = @secondLocationId))
	  and (@secondDepartmentId = '-1' or (@secondDepartmentId <> '-1' and pkd.id = @secondDepartmentId))
	  and (@secondCategoryId = '-1' or (@secondCategoryId <> '-1' and PKc.id = @secondCategoryId))
	  and ((@secondstatus = '-1' and PKv.status <> 'Deleted') or (@secondstatus <> '-1' and PKv.status = @secondstatus))
             AND 
             --PKinv.Qty >= isnull(@secondQtyMorethan,-2147483647) --case @secondQtyMorethan when 0 then PKinv.Qty else @secondQtyMorethan end  
             --and   
             --PKinv.Qty <= isnull(@secondQtyLessThan, 2147483647) --case @secondQtyLessThan when 0 then PKinv.Qty else @secondQtyLessThan end  
             ( ( @secondQtyMorethan = 0 
                 AND @secondQtyLessThan = 0 
                 AND pkinv.qty = 0 ) 
                OR ( NOT ( @secondQtyMorethan = 0 
                           AND @secondQtyLessThan = 0 ) 
                     AND PKinv.qty >= Isnull(@secondQtyMorethan, -2147483647) 
                     --case @secondQtyMorethan when 0 then PKinv.Qty else @secondQtyMorethan end  
                     AND PKinv.qty < Isnull(@secondQtyLessThan, 2147483647) 
                    --case @secondQtyLessThan when 0 then PKinv.Qty else @secondQtyLessThan end  
                    ) ) 
		

      

	  update #tbl1BaseProduct set onhold = 0, onorder = 0;
	  update #tbl1BaseProduct set onhold = t3p.ONHold 
	  from #tbl3 t3P 
	  where t3p.ProductID = #tbl1BaseProduct.ProductID and t3p.LocationID = #tbl1BaseProduct.LocationID;
	  update #tbl1BaseProduct set onorder = t4p.ONOrder
	  from #tbl4 t4P 
	  where t4p.ProductID = #tbl1BaseProduct.ProductID and t4p.LocationID = #tbl1BaseProduct.LocationID;

	  --select * from #tbl1
	  --select * from #tbl1BaseProduct

	  insert into #tbl1 select * from #tbl1BaseProduct 
	  where not exists (select * from #tbl1 where #tbl1.ProductID = #tbl1BaseProduct.ProductID and #tbl1.locationid = #tbl1BaseProduct.LocationID);

	  --select * from #tbl1

		-----------------------------------------------------------------------------
		-----------------------------------------------------------------------------			
		-----------------------------------------------------------------------------			



      SELECT DISTINCT tbl1.locationid, 
                      tbl1.productid, 
                      tbl1.location, 
                      tbl1.department, 
                      tbl1.category, 
                      tbl1.plu, 
                      tbl1.Barcode, 
                      tbl1.name1, 
                      tbl1.name2, 
                      tbl1.description1, 
                      tbl1.qty, 
                      tbl1.unit, 
                      tbl1.latestcost, 
                      tbl1.averagecost, 
                      tbl1.updatetime, 
                      tbl1.updater, 
                      tbl1.status, 
                      tbl1.brand, 
                      tbl1.packsize, 
                      tbl1.totalamount, 
                      tbl1.onhold, 
                      tbl1.onorder, 
                      PM.baseproductid, 
                      tbl1.packagecapacity
      INTO   #tblbaseproduct 
      FROM   #tbl1 tbl1 
             INNER JOIN pkmapping PM 
                     ON ( pm.baseproductid = tbl1.productid ) 

	  insert into #tblbaseproduct
	  select DISTINCT tbl1.locationid, 
                      tbl1.productid, 
                      tbl1.location, 
                      tbl1.department, 
                      tbl1.category, 
                      tbl1.plu, 
                      tbl1.Barcode, 
                      tbl1.name1, 
                      tbl1.name2, 
                      tbl1.description1, 
                      tbl1.qty, 
                      tbl1.unit, 
                      tbl1.latestcost, 
                      tbl1.averagecost, 
                      tbl1.updatetime, 
                      tbl1.updater, 
                      tbl1.status, 
                      tbl1.brand, 
                      tbl1.packsize, 
                      tbl1.totalamount, 
                      tbl1.onhold, 
                      tbl1.onorder, 
                      tbl1.productid, 
                      tbl1.packagecapacity
			FROM   #tbl1 tbl1 
			where not exists(
				select * from PKMapping where PKMapping.BaseProductID = tbl1.ProductID 
				or PKMapping.ProductID = tbl1.ProductID
			)

      --select * from #tblBaseProduct          
      SELECT DISTINCT tbl1.locationid, 
                      tbl1.productid, 
                      tbl1.location, 
                      tbl1.department, 
                      tbl1.category, 
                      tbl1.plu, 
                      tbl1.Barcode, 
                      tbl1.name1, 
                      tbl1.name2, 
                      tbl1.description1, 
                      tbl1.qty ,--AS QtyOriginal, 
                      tbl1.unit, 
                      tbl1.latestcost, 
                      tbl1.averagecost, 
                      tbl1.updatetime, 
                      tbl1.updater, 
                      tbl1.status, 
                      tbl1.brand, 
                      tbl1.packsize, 
                      tbl1.totalamount, 
                      tbl1.onhold,-- AS ONHoldOriginal, 
                      tbl1.onorder,-- AS ONOrderOriginal, 
                      PM.baseproductid, --, 
       --               tbl1.packagecapacity, 
       --               tbl1.qty * ( tbl1.packagecapacity / 
       --                            Isnull(tbB.packagecapacity, 
       --                            tbl1.packagecapacity) ) 
       --               AS Qty, 
       --               tbl1.onhold * ( tbl1.packagecapacity / 
       --                               Isnull(tbB.packagecapacity, 
       --                               tbl1.packagecapacity) )  AS ONHold, 
       --               tbl1.onorder * ( tbl1.packagecapacity / 
       --                                Isnull(tbB.packagecapacity, 
       --                                tbl1.packagecapacity) ) AS ONOrder 
					  --,
			 @tempDecNumber as CapacityRate
      INTO   #tblcommonproduct 
      FROM   #tbl1 tbl1 
             INNER JOIN pkmapping PM 
                     ON ( pm.productid = tbl1.productid ) 
             LEFT OUTER JOIN #tblbaseproduct tbB 
                          ON tbB.baseproductid = PM.baseproductid 
	  update #tblcommonproduct set CapacityRate = dbo.PK_FuncGetCapacityByProdID(productid);

      SELECT baseproductid, 
             Sum(qty * CapacityRate)     AS qty, 
             Sum(onhold * CapacityRate)  AS ONHold, 
             Sum(onorder * CapacityRate) AS ONOrder, 
             locationid
      INTO   #tblqtycountforcommonproduct 
      FROM   #tblcommonproduct 
      GROUP  BY locationid, 
                baseproductid 

      --select * from #tblCommonProduct  
      --select * from #tblQtyCountForCommonProduct  
	  
      UPDATE #tblbaseproduct 
      SET    qty = a.qty + b.qty, 
             onhold = a.onhold + b.onhold, 
             onorder = a.onorder + b.onorder
      FROM   #tblbaseproduct a, 
             #tblqtycountforcommonproduct b 
      WHERE  a.baseproductid = b.baseproductid 
             AND a.locationid = b.locationid; 


      --select * from #tblBaseProduct  
      SELECT DISTINCT tbl1.locationid, 
                      tbl1.productid, 
                      tbl1.location, 
                      tbl1.department, 
                      tbl1.category, 
                      tbl1.plu, 
                      tbl1.Barcode, 
                      tbl1.name1, 
                      tbl1.name2, 
                      tbl1.description1, 
                      tbl1.unit, 
                      tbl1.latestcost, 
                      tbl1.averagecost, 
                      tbl1.updatetime, 
                      tbl1.updater, 
                      tbl1.status, 
                      tbl1.brand, 
                      tbl1.packsize, 
                      tbl1.totalamount, 
                      tbl1.packagecapacity, 
                      Isnull(tblBase.qty, tbl1.qty)         AS Qty, 
                      Isnull(tblBase.onhold, tbl1.onhold)   AS ONHold, 
                      Isnull(tblBase.onorder, tbl1.onorder) AS ONOrder 
      INTO   #tbl2 
      FROM   #tbl1 tbl1 
             LEFT OUTER JOIN #tblbaseproduct tblBase 
                          ON tblBase.productid = tbl1.productid 
                             AND tblBase.locationid = tbl1.locationid 
      WHERE  NOT EXISTS(SELECT productid 
                        FROM   #tblcommonproduct 
                        WHERE  #tblcommonproduct.productid = tbl1.productid) 

      --update table1 set b.kucun=a.shuliang from table1 b,table2 a where b.name=a.t2name  
      --select * from #tblBaseProduct  
      --select * from #tblQtyCountForCommonProduct  
      --select * from #tblCommonProduct  
	  
      IF ( @secondLocationId = '' ) 
        BEGIN 
            SELECT locationid, 
                   productid, 
                   location, 
                   plu, 
                   Barcode, 
                   name1, 
                   name2, 
                   description1, 
                   unit, 
                   qty, 
                   CASE onhold 
                     WHEN 0 THEN NULL 
                     ELSE onhold 
                   END AS ONHold, 
                   CASE onorder 
                     WHEN 0 THEN NULL 
                     ELSE onorder 
                   END AS ONOrder 
            FROM   (SELECT DISTINCT 'ALL'        AS LocationID, 
                                    productid, 
                                    'All'        AS Location, 
                                    plu, 
									barcode,
                                    Ltrim(name1) AS Name1, 
                                    Ltrim(name2) AS Name2, 
                                    description1, 
                                    unit, 
                                    Sum(qty)     AS Qty, 
                                    Sum(onhold)  AS ONHold, 
                                    Sum(onorder) AS ONOrder 
                    FROM   #tbl2 
                    GROUP  BY productid, 
                              plu, 
                              Barcode, 
                              name1, 
                              name2, 
                              description1, 
                              unit) AS ProductList 
        END 
      ELSE 
        BEGIN 
            SELECT DISTINCT locationid, 
                            productid, 
                            location, 
                            department, 
                            category, 
                            plu, 
                            Barcode, 
                            Ltrim(name1) AS Name1, 
                            Ltrim(name2) AS Name2, 
                            description1, 
                            unit, 
                            latestcost, 
                            averagecost, 
                            updatetime, 
                            updater, 
                            status, 
                            brand, 
                            packsize, 
                            totalamount, 
                            packagecapacity, 
                            qty, 
                            CASE onhold 
                              WHEN 0 THEN NULL 
                              ELSE onhold 
                            END          AS ONHold, 
                            CASE onorder 
                              WHEN 0 THEN NULL 
                              ELSE onorder 
                            END          AS ONOrder 
            FROM   #tbl2 
        END 


      DROP TABLE #tbl1; 
      DROP TABLE #tblAllProd; 
      DROP TABLE #tbl1BaseProduct; 

      DROP TABLE #tbl2; 

      DROP TABLE #tbl3; 

      DROP TABLE #tbl4; 

      DROP TABLE #tblbaseproduct; 

      DROP TABLE #tblcommonproduct; 

      DROP TABLE #tblqtycountforcommonproduct; 

      DROP TABLE #tblheadquatercost; 
  END 





GO
/****** Object:  StoredProcedure [dbo].[Pk_GetInventoryQtyAsOneProdFromAllMappingProducts]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetInventoryQtyAsOneProdFromAllMappingProducts]
	@ProductsId varchar(50),
	@Location varchar(50),
	@ReturnedUnit varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   declare @CountBase int;
   declare @CountSub int;
   declare @BaseOrSub varchar(10);
   declare @BaseProductIdInMapping varchar(50);
   declare @DecReturnValue decimal(18,4);
   declare @ProductName varchar(50);
   declare @AverageCost decimal(18,2);


   select @CountBase = count(*) from PKMapping where BaseProductID = @ProductsId;
   select @CountSub = count(*) from PKMapping where ProductID = @ProductsId;
   select @ProductName = Name1 from PKProduct where id = @ProductsId;
   set @AverageCost = 0;

   if @countBase + @CountSub >0
   begin
	   if @CountBase >0
	   begin
		set @BaseOrSub = 'b'
		set @BaseProductIdInMapping = @ProductsId;
	   end 
	   else if @CountSub >0 
	   begin
		set @BaseOrSub = 's' 
		select @BaseProductIdInMapping = BaseProductID from PKMapping where  ProductID = @ProductsId;
	   end
	   set @DecReturnValue = 0;
	   declare @Qty decimal(18,4);
	   declare @Capacity Decimal(18,4);
	   declare @ProductId varchar(50);

	   declare t_cursor cursor for 
		select ProductID from PKMapping where BaseProductID = @BaseProductIdInMapping
		open t_cursor
		fetch next from t_cursor into @ProductId
		while @@fetch_status = 0
		begin
			select @Qty = isnull(Qty,0) from PKInventory where ProductID = @ProductId and LocationID = @Location;
			set @DecReturnValue = @DecReturnValue + dbo.PK_FuncGetCapacityByProdID(@productId)*@Qty;
			fetch next from t_cursor into @ProductId
		end
		close t_cursor
		deallocate t_cursor
		--Do not forget the base product.
		select @Qty = isnull(Qty,0), @AverageCost = AverageCost from PKInventory where ProductID = @BaseProductIdInMapping and LocationID = @Location;
		set @DecReturnValue = @DecReturnValue + dbo.PK_FuncGetCapacityByProdID(@BaseProductIdInMapping)*@Qty;
		
	   
   end
   else
	begin
		set @BaseOrSub = 'n'
		select @DecReturnValue = isnull(Qty,0) from PKInventory where ProductID = @ProductsId and LocationID = @Location;
	
   end
   if len(@ReturnedUnit)>0 
   begin
		declare @capacity2 decimal(18,4);
		declare @capacity3 decimal(18,4);
		set @capacity2 = dbo.PK_FuncGetCapacityByProdID(@ProductsId);
		select @capacity3 = Rate from PKUnitNames where unit = @ReturnedUnit;
		if lower(@ReturnedUnit)<>'ea'
		begin
			set @DecReturnValue = @DecReturnValue * @capacity2/@capacity3;
		end
   end
   set @DecReturnValue = isnull(@DecReturnValue,0);
   set @AverageCost = isnull(@AverageCost,0);
   set @ProductName = isnull(@ProductName,'');

   select cast(@DecReturnValue as decimal(18,2)) as AllQty, @ProductName as productName, @AverageCost as averageCost;


END



GO
/****** Object:  StoredProcedure [dbo].[Pk_getinventorysummaryreport]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_getinventorysummaryreport] @LocationId   VARCHAR(50), 
                                                     @DepartmentID VARCHAR(50), 
                                                     @CategoryId   VARCHAR(50), 
                                                     @Productname  VARCHAR(50), 
                                                     @PLUBarcode   VARCHAR(50), 
                                                     @Brand        VARCHAR(50), 
                                                     @Active       VARCHAR(50), 
                                                     @Inactive     VARCHAR(50), 
                                                     @Deleted      VARCHAR(50), 
                                                     @QtyMin       DECIMAL(18, 2), 
                                                     @QtyMax       DECIMAL(18, 2),
													 @BaseProdOnly varchar(10)
AS 
  BEGIN 
      SET nocount ON; 

      DECLARE @tempDecNumber DECIMAL(18, 2); 
      DECLARE @tempString NVARCHAR(100); 

      SET @tempString =  N'1234567891012345678910123456789101234567891012345678910' 
      ; 
      SET @tempString = @tempString + N'1234567891012345678910123456789101234567891012345678910'; 
      SET @tempDecNumber = 1000000.00; 

      -- SET NOCOUNT ON added to prevent extra result sets from     
      -- interfering with SELECT statements.     
      DECLARE @TotalStockValue DECIMAL(18, 2); 
      DECLARE @TotalRetailValue DECIMAL(18, 2); 
      DECLARE @TotalProfit DECIMAL(18, 2); 
      DECLARE @TotalMargin DECIMAL(18, 2); 


      IF @LocationId = 'All Location' 
          OR @LocationId = '' 
        BEGIN 
            SET @LocationId = '-1' 
        END 
      IF @DepartmentID = 'All Department' 
          OR @DepartmentID = '' 
        BEGIN 
            SET @DepartmentID = '-1' 
        END 
      IF @CategoryId = 'All Category' 
          OR @CategoryId = '' 
        BEGIN 
            SET @CategoryId = '-1' 
        END 

      SELECT pkinventory.locationid             AS Location, 
             pkproduct.id                       AS ProductID, 
             ---pklocation.locationname,     
             PKd.NAME                           AS Department, 
             PKc.NAME                           AS Category, 
             pkproduct.plu                      AS PLU, 
             pkproduct.barcode                  AS Barcode, 
             pkproduct.name1                    AS Name1, 
             pkproduct.name2                    AS Name2, 
             pkproduct.description1             AS Description1, 
             pkinventory.qty                    AS Qty, 
             pkinventory.unit                   AS Unit, 
             Isnull(pkinventory.latestcost, 0)  AS LatestCost, 
             Isnull(pkinventory.averagecost, 0) AS AverageCost, 
             pkproduct.status                   AS Status, 
             pkproduct.brand                    AS Brand, 
             Cast(pkproduct.packl AS VARCHAR) + 'X' 
             + Cast(pkproduct.packm AS VARCHAR) + 'X' 
             + Cast(pkproduct.packs AS VARCHAR) AS PackSize, 
             pkprice.a                          AS PriceA, 
             pkprice.b                          AS PriceB, 
             pkprice.c                          AS PriceC, 
             pkprice.d                          AS PriceD, 
             pkprice.e                          AS PriceE,
			 @tempDecNumber as capacity,
			 @tempString as isBaseProd,
			 @tempDecNumber as QtyInBase,
			 @tempString as baseProdID
			 
      INTO   #tbloriginal 
      FROM   pkinventory 
             --JOIN pklocation     
             --  ON pkinventory.locationid = pklocation.locationid     
             JOIN pkproduct 
               ON pkinventory.productid = pkproduct.id 
             JOIN pkcategory AS PKc 
               ON pkproduct.categoryid = PKc.id 
             JOIN pkdepartment AS PKd 
               ON PKc.departmentid = PKd.id 
             LEFT OUTER JOIN pkprice 
                          ON pkinventory.productid = pkprice.productid 
      WHERE  pkinventory.locationid = CASE @LocationId 
                                        WHEN '-1' THEN pkinventory.locationid 
                                        ELSE @LocationId 
                                      END 
             AND pkd.id = CASE @DepartmentID 
                            WHEN '-1' THEN pkd.id 
                            ELSE @DepartmentID 
                          END 
             AND PKc.id = CASE @CategoryId 
                            WHEN '-1' THEN pkc.id 
                            ELSE @CategoryId 
                          END 
             AND ( ( @QtyMax IS NULL ) 
                    OR ( @QtyMax IS NOT NULL 
                         AND pkinventory.qty <= @QtyMax ) ) 
             AND ( ( @QtyMin IS NULL ) 
                    OR ( @QtyMin IS NOT NULL 
                         AND pkinventory.qty >= @QtyMin ) ) 
             AND ( ( @Productname = '' ) 
                    OR ( @Productname <> '' 
                         AND pkproduct.name1 + pkproduct.name2 LIKE 
                             '%' + @Productname + '%' 
                       ) ) 
             AND ( ( @PLUBarcode = '' ) 
                    OR ( @PLUBarcode <> '' 
                         AND ( pkproduct.plu LIKE '%' + @PLUBarcode + '%' ) 
                          OR ( pkproduct.barcode LIKE '%' + @PLUBarcode + '%' ) 
                       ) 
                 ) 
             AND ( ( @Brand = '' ) 
                    OR ( @Brand <> '' 
                         AND pkproduct.brand LIKE '%' + @Brand + '%' ) ) 
             AND ( ( @Active = 'true' ) 
                    OR ( @Active <> 'true' 
                         AND pkproduct.status <> 'Active' ) ) 
             AND ( ( @Inactive = 'true' ) 
                    OR ( @Inactive <> 'true' 
                         AND pkproduct.status <> 'Inactive' ) ) 
             AND ( ( @Deleted = 'true' ) 
                    OR ( @Deleted <> 'true' 
                         AND pkproduct.status <> 'Deleted' ) ); 
		
	  if lower(@BaseProdOnly) = 'y'
	  begin
		update #tbloriginal set capacity = 1, isBaseProd = 'o', QtyInBase = Qty;
		update #tbloriginal set isBaseProd = 'n',baseProdID=BaseProductID from PKMapping where #tbloriginal.ProductID = PKMapping.ProductID; --For sub product, set his Base product id.
		update #tbloriginal set isBaseProd = 'y',baseProdID=#tbloriginal.ProductID  from PKMapping where #tbloriginal.ProductID = PKMapping.BaseProductID; -- For Base product, set his own prodcutid.
		BEGIN TRY
			update #tbloriginal set QtyInBase = dbo.PK_FuncGetCapacityByProdID(productid)*Qty;		
		END TRY
		BEGIN CATCH
				print ERROR_MESSAGE() ;
		END CATCH

		select sum(QtyInBase) as QtyInBase, baseProdID, Location
		 into #tblBaseProQty
		 from #tbloriginal
		 group by Location,baseProdId
		 ;
		delete from #tbloriginal where isBaseProd = 'n';
		update #tblOriginal set baseProdID = ProductID, isBaseProd = 'y' where isBaseProd = 'o'
		update #tbloriginal set Qty = #tblBaseProQty.QtyInBase from #tblBaseProQty where #tblBaseProQty.baseProdID = #tbloriginal.baseProdID and #tblBaseProQty.Location = #tbloriginal.location;



		drop table #tblBaseProQty;
	  end

      SELECT TOG.location, 
             TOG.productid, 
             TOG.department, 
             TOG.category, 
             TOG.plu, 
             TOG.barcode, 
             TOG.name1, 
             TOG.name2, 
             TOG.description1, 
             TOG.qty, 
             TOG.unit, 
             CASE Isnull(P.latestcost, 0) 
               WHEN 0 THEN TOG.latestcost 
               ELSE p.latestcost 
             END AS LatestCost, 
             CASE Isnull(P.averagecost, 0) 
               WHEN 0 THEN TOG.averagecost 
               ELSE p.averagecost 
             END AS AverageCost, 
             TOG.status, 
             TOG.brand, 
             TOG.packsize, 
             TOG.pricea, 
             TOG.priceb, 
             TOG.pricec, 
             TOG.priced, 
             TOG.pricee, 
             p.locationprice 
      INTO   #tblrough 
      FROM   #tbloriginal TOG 
             LEFT OUTER JOIN (SELECT productid, 
                                     latestcost, 
                                     averagecost, 
                                     locationprice 
                              FROM   pkinventory piv 
                                     INNER JOIN pklocation pl 
                                             ON piv.locationid = pl.locationid 
                              WHERE  pl.isheadquarter = 1) P 
                          ON TOG.productid = p.productid 

      SELECT location, 
             productid, 
             department, 
             category, 
             plu, 
             barcode, 
             name1, 
             name2, 
             description1, 
             qty, 
             unit, 
             latestcost, 
             averagecost, 
             status, 
             brand, 
             packsize, 
             CASE Lower(locationprice) 
               WHEN 'a' THEN pricea 
               WHEN 'b' THEN 
                 CASE Isnull(priceb, 0) 
                   WHEN 0 THEN pricea 
                   ELSE priceb 
                 END 
               WHEN 'c' THEN 
                 CASE Isnull(pricec, 0) 
                   WHEN 0 THEN pricea 
                   ELSE pricec 
                 END 
               WHEN 'e' THEN 
                 CASE Isnull(priced, 0) 
                   WHEN 0 THEN pricea 
                   ELSE priced 
                 END 
               WHEN 'e' THEN 
                 CASE Isnull(pricee, 0) 
                   WHEN 0 THEN pricea 
                   ELSE pricee 
                 END 
               ELSE pricea 
             END AS Price 
      INTO   #tbldetail 
      FROM   #tblrough 

      ALTER TABLE #tbldetail 
        ADD profit DECIMAL(18, 2); 

      ALTER TABLE #tbldetail 
        ADD margin DECIMAL(18, 2); 

      SELECT @tempString    AS location, 
             @tempString    AS productid, 
             @tempDecNumber AS profit, 
             @tempDecNumber AS margin, 
             @tempDecNumber AS QTY, 
             @tempString    AS department, 
             @tempString    AS category, 
             @tempString    AS plu, 
             @tempString    AS barcode, 
             @tempString    AS name1, 
             @tempString    AS name2, 
             @tempString + @tempString+ @tempString+ @tempString+ @tempString    AS description1, 
             @tempString    AS unit, 
             @tempDecNumber AS latestcost, 
             @tempDecNumber AS averagecost, 
             @tempString    AS status, 
             @tempString    AS brand, 
             @tempString    AS packsize, 
             @tempDecNumber AS price 
      INTO   #tblfinal; 

      DELETE FROM #tblfinal; 

      IF @LocationId = '-1' 
        BEGIN 
            INSERT INTO #tblfinal 
            --SELECT 'All Location'                       AS location, 
            SELECT location, 
                   productid, 
                   Sum(price * qty - averagecost * qty) AS profit, 
                   CASE Sum(averagecost * qty) 
                     WHEN 0 THEN 0 
                     ELSE Sum(price * qty) / Sum(averagecost * qty) - 1 
                   END                                  AS margin, 
                   Sum(qty)                             AS QTY, 
                   department, 
                   category, 
                   plu, 
                   barcode, 
                   name1, 
                   name2, 
                   description1, 
                   unit, 
                   latestcost, 
                   averagecost, 
                   status, 
                   brand, 
                   packsize, 
                   price 
            FROM   #tbldetail 
            GROUP  BY location, 
					  productid, 
                      department, 
                      category, 
                      plu, 
                      barcode, 
                      name1, 
                      name2, 
                      description1, 
                      unit, 
                      latestcost, 
                      averagecost, 
                      status, 
                      brand, 
                      packsize, 
                      price 

            SELECT @TotalStockValue = Sum(averagecost * qty), 
                   @TotalRetailValue = Sum(price * qty) 
            FROM   #tbldetail 

            SET @TotalProfit = @TotalRetailValue - @TotalStockValue; 
			SET @TotalMargin = case @TotalStockValue when 0 then 0 else  @TotalProfit/@TotalStockValue end;
       END 
      ELSE 
        BEGIN 
            UPDATE #tbldetail 
            SET    profit = ( price - averagecost ) * qty, 
                   margin = CASE averagecost 
                              WHEN 0 THEN 0 
                              ELSE ( price - averagecost ) / averagecost 
                            END 

            SELECT @TotalStockValue = Sum(averagecost * qty), 
                   @TotalRetailValue = Sum(price * qty) 
            FROM   #tbldetail 

            SET @TotalProfit = @TotalRetailValue - @TotalStockValue; 
			SET @TotalMargin = case @TotalStockValue when 0 then 0 else  @TotalProfit/@TotalStockValue end;

            INSERT INTO #tblfinal 
            SELECT location, 
                   productid, 
                   profit, 
                   margin, 
                   qty, 
                   department, 
                   category, 
                   plu, 
                   barcode, 
                   name1, 
                   name2, 
                   description1, 
                   unit, 
                   latestcost, 
                   averagecost, 
                   status, 
                   brand, 
                   packsize, 
                   price 
            FROM   #tbldetail 
        END 

      SELECT location, 
                   productid, 
                   profit, 
                   margin as ProfitMargin, 
                   qty, 
                   department, 
                   category, 
                   plu, 
                   barcode, 
                   name1, 
                   name2, 
                   --description1, 
                   unit, 
                   latestcost, 
                   averagecost, 
                   status, 
                   brand, 
                   packsize, 

                   price 
      FROM   #tblfinal
	  order by department, category,plu,barcode
	  ; 

      SELECT @TotalStockValue  AS TotalStockValue, 
             @TotalRetailValue AS TotalRetailValue, 
             @TotalProfit      AS TotalProfit ,
			 @TotalMargin	   AS TotalMargin
		
      DROP TABLE #tblrough; 

      DROP TABLE #tbldetail; 

      DROP TABLE #tblfinal; 

      DROP TABLE #tbloriginal; 

  END 




GO
/****** Object:  StoredProcedure [dbo].[Pk_GetInventoryUnitQtyByProdInputunit]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetInventoryUnitQtyByProdInputunit]
	@productId varchar(50),
	@inputUnit varchar(50),
	@inputQty decimal(18,2),
	@inputCost decimal(18,2)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @capacity decimal(18,4);
	declare @unit  varchar(50);
	declare @InputCapacity decimal(18,4);
	declare @Qty  decimal(18,4);
	declare @cost decimal(18,2);

	--set @capacity = dbo.PK_FuncGetCapacityByProdID(@productId);
	select @unit = unit from PKProduct where id = @productId;
	select @capacity = Rate from PKUnitNames where unit = @unit;
	select @InputCapacity = Rate from PKUnitNames where unit = @inputUnit;

	if lower(@inputUnit)='ea'
	begin
		set @Qty = @inputQty 
		set @cost = @inputCost 
	end
	else
	begin
		set @cost = @inputCost * @capacity / @InputCapacity;
		set @Qty = @inputQty * @InputCapacity / @capacity;
	end
	select isnull(@qty,0) as qty, isnull(@unit,'ea') as unit, isnull(@cost,0) as cost ;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetJqueryVipSearch]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetJqueryVipSearch]
	@inputValue nvarchar(200),
	@inputType nvarchar(20)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- The reason for the following is to order the result.
	-- the result which matches more, will be put forword.

	select cc.CardNo as a, 1 as b 
	into #tbl1
	from Customer C
	inner join CustomerCard Cc on CC.CustomerID = C.ID
	where CustomerNo like @inputValue + '%' 

	select cc.CardNo as a, 2 as b 
	into #tbl2
	from Customer  C
	inner join CustomerCard Cc on CC.CustomerID = C.ID
	where cc.CardNo like '%' + @inputValue + '%' 
	and not exists (select * from #tbl1 where #tbl1.a = cc.CardNo)

	select IDCardNo as a, 3 as b 
	into #tbl3
	from Customer 
	where IDCardNo like @inputValue + '%' 

	select IDCardNo as a, 4 as b 
	into #tbl4
	from Customer 
	where IDCardNo like '%' + @inputValue + '%' 
	and not exists (select * from #tbl3 where #tbl3.a = customer.IDCardNo)


	select FirstName + ' ' + LastName as a, 5 as b 
	into #tbl5
	from Customer 
	where FirstName like @inputValue + '%' 

	select FirstName + ' ' + LastName as a, 6 as b 
	into #tbl6
	from Customer 
	where FirstName like '%' + @inputValue + '%' 
	and not exists (select * from #tbl5 where #tbl5.a = customer.FirstName + ' ' + customer.LastName)

	select FirstName + ' ' + LastName as a, 7 as b 
	into #tbl7
	from Customer 
	where LastName like @inputValue + '%' 

	select FirstName + ' ' + LastName as a, 8 as b 
	into #tbl8
	from Customer 
	where LastName like '%' + @inputValue + '%' 
	and not exists (select * from #tbl7 where #tbl7.a = customer.FirstName + ' ' + customer.LastName)

	select Email as a, 9 as b 
	into #tbl9
	from Customer 
	where Email like @inputValue + '%' 

	select Email as a, 10 as b 
	into #tbl10
	from Customer 
	where Email like '%' + @inputValue + '%' 
	and not exists (select * from #tbl9 where #tbl9.a = customer.Email)

	select Phone as a, 11 as b 
	into #tbl11
	from Customer 
	where Phone like @inputValue + '%' 
	or Tel like @inputValue + '%' 
	or FAX like @inputValue + '%' 

	select Phone as a, 12 as b 
	into #tbl12
	from Customer 
	where (Phone like '%' + @inputValue + '%' or TEL like '%' + @inputValue + '%' or FAX like '%' + @inputValue + '%'  )
	and not exists (select * from #tbl11 where #tbl11.a = customer.Phone)



	if lower(@inputType) = 'name'
		begin
			select distinct top 10  a,b from (
				
				select * from #tbl5
				union
				select * from #tbl6
				union
				select * from #tbl7
				union
				select * from #tbl8
				
			) c
			order by b;
		end
	else if lower(@inputType) = 'vipno'
		begin
			select distinct top 10  a,b from (
				select * from #tbl1
				union
				select * from #tbl2
				union
				select * from #tbl3
				union
				select * from #tbl4
				
			) c
			order by b;
		end
	else if lower(@inputType) = 'email'
		begin
			select distinct top 10  a,b from (
				
				select * from #tbl9
				union
				select * from #tbl10
			) c
			order by b;
		end
	else if lower(@inputType) = 'phone'
		begin
			select distinct top 10  a,b from (
				
				select * from #tbl11
				union
				select * from #tbl12
			) c
			order by b;
		end
	else
		begin
			select distinct top 10  a,b from (
				select * from #tbl1
				union
				select * from #tbl2
				union
				select * from #tbl3
				union
				select * from #tbl4
				union
				select * from #tbl5
				union
				select * from #tbl6
				union
				select * from #tbl7
				union
				select * from #tbl8
				union
				select * from #tbl9
				union
				select * from #tbl10
			) c
			order by b;
		end
	
	


	


	drop table #tbl1;
	drop table #tbl2;
	drop table #tbl3;
	drop table #tbl4;
	drop table #tbl5;
	drop table #tbl6;
	drop table #tbl7;
	drop table #tbl8;
	drop table #tbl9;
	drop table #tbl10;
	drop table #tbl11;
	drop table #tbl12;


END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetLowInventoryProductList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetLowInventoryProductList]
	@LocationId varchar(50),
	@DepartmentId varchar(50),
	@CategoryId varchar(50),
	@FlagHighLow varchar(20),
	@Type varchar(20),
	@VendorId varchar(50)
AS
BEGIN
	if @VendorId = '-1'
	begin
		select locationid, 
			DepartmentID,
			departmentname,
			CategoryID,
			categoryname, 
			productid,
			productName, 
			PLU, 
			Barcode, 
			Qty, 
			minthreshold, 
			maxthreshold,
			hold,
			Back
			into #tbl1
		from (
				select pt.locationid as locationid, 
					pd.id as DepartmentID,
					pd.Name as departmentname,
					pc.id as CategoryID,
					pc.Name as  categoryname, 
					pt.productid,
					p.Name1 + '('+ p.Name2 +')' as productName, 
					p.PLU, 
					p.Barcode, 
					Pit.Qty as Qty, 
					pt.minthreshold, 
					pt.maxthreshold,
					c.hold,
					d.Back
				from PKInventoryThresholds PT 
				inner join PKProduct P on pt.productid = P.ID
				inner join PKCategory PC on pc.ID = p.CategoryID
				inner join PKDepartment PD on pd.ID = pc.DepartmentID
				inner join PKInventory Pit on pit.ProductID = pt.productid and pit.LocationID = pt.locationid
				LEFT OUTER JOIN
					 (SELECT ProductID, LocationID, SUM(Qty) AS hold
						FROM (SELECT dbo.PKSOProduct.ProductID, dbo.PKSOProduct.LocationID, CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN orderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS Qty
								FROM dbo.PKSOProduct
								INNER JOIN dbo.PKSO ON dbo.PKSO.SOID = dbo.PKSOProduct.SOID
								WHERE (dbo.PKSO.Status = 'Pending')
							  ) AS SO
						GROUP BY ProductID, LocationID) AS c 
						ON PT.locationid = c.LocationID AND PT.productid = c.ProductID 
				LEFT OUTER JOIN
					(SELECT ProductID, LocationID, SUM(OrderQty) AS Back
					FROM (SELECT PKSOProduct_1.ProductID, PKSOProduct_1.LocationID, CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN OrderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS OrderQty
							FROM dbo.PKSOProduct AS PKSOProduct_1 
							INNER JOIN dbo.PKSO AS PKSO_1 ON PKSO_1.SOID = PKSOProduct_1.SOID
							WHERE (PKSO_1.Status = 'Back')
						) AS SOBack
					GROUP BY ProductID, LocationID) AS d ON PT.locationid = d.LocationID AND PT.productid = d.ProductID
				where pit.Qty < pt.minthreshold or pit.Qty > pt.maxthreshold
				union
				select pt.locationid as locationid, 
					pd.id as DepartmentID,
					pd.Name as departmentname,
					pc.id as CategoryID,
					pc.Name as  categoryname, 
					pt.productid,
					p.Name1 + '('+ p.Name2 +')' as productName, 
					p.PLU, 
					p.Barcode, 
					a.qty, 
					pt.minthreshold, 
					pt.maxthreshold,
					c.hold,
					d.Back
				from PKInventoryThresholds PT 
				inner join PKProduct P on pt.productid = P.ID
				inner join PKCategory PC on pc.ID = p.CategoryID
				inner join PKDepartment PD on pd.ID = pc.DepartmentID
				inner join (select sum(Qty) as qty,ProductID from PKInventory Pit  group by ProductID) a 
							on a.ProductID = pt.productid
				LEFT OUTER JOIN
				 (SELECT ProductID, SUM(Qty) AS hold
					FROM (SELECT dbo.PKSOProduct.ProductID, CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN orderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS Qty
							FROM dbo.PKSOProduct
							INNER JOIN dbo.PKSO ON dbo.PKSO.SOID = dbo.PKSOProduct.SOID
							WHERE (dbo.PKSO.Status = 'Pending')
						  ) AS SO
					GROUP BY ProductID) AS c 
					ON PT.productid = c.ProductID 
				LEFT OUTER JOIN
					(SELECT ProductID,  SUM(OrderQty) AS Back
					FROM (SELECT PKSOProduct_1.ProductID,  CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN OrderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS OrderQty
							FROM dbo.PKSOProduct AS PKSOProduct_1 
							INNER JOIN dbo.PKSO AS PKSO_1 ON PKSO_1.SOID = PKSOProduct_1.SOID
							WHERE (PKSO_1.Status = 'Back')
						) AS SOBack
					GROUP BY ProductID) AS d ON PT.productid = d.ProductID
				where pt.locationid = 'All Location' and (a.Qty < pt.minthreshold or a.Qty > pt.maxthreshold)
			) tbl 
		End
		else
		Begin
			select locationid, 
				DepartmentID,
				departmentname,
				CategoryID,
				categoryname, 
				productid,
				productName, 
				PLU, 
				Barcode, 
				Qty, 
				minthreshold, 
				maxthreshold,
				hold,
				Back
				into #tbl2
			from (
					select distinct  pt.locationid as locationid, 
						pd.id as DepartmentID,
						pd.Name as departmentname,
						pc.id as CategoryID,
						pc.Name as  categoryname, 
						pt.productid,
						p.Name1 + '('+ p.Name2 +')' as productName, 
						p.PLU, 
						p.Barcode, 
						Pit.Qty as Qty, 
						pt.minthreshold, 
						pt.maxthreshold,
						c.hold,
						d.Back
					from PKInventoryThresholds PT 
					inner join PKProduct P on pt.productid = P.ID
					inner join PKCategory PC on pc.ID = p.CategoryID
					inner join PKDepartment PD on pd.ID = pc.DepartmentID
					inner join PKInventory Pit on pit.ProductID = pt.productid and pit.LocationID = pt.locationid
					INNER JOIN (SELECT ProductID,POID FROM PKPOProduct) AS PP ON PT.productid = PP.ProductID 
					INNER JOIN (SELECT POID,VendorID FROM PKPO) AS PO  ON PP.POID = PO.POID 
					LEFT OUTER JOIN
						 (SELECT ProductID, LocationID, SUM(Qty) AS hold
							FROM (SELECT dbo.PKSOProduct.ProductID, dbo.PKSOProduct.LocationID, CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN orderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS Qty
									FROM dbo.PKSOProduct
									INNER JOIN dbo.PKSO ON dbo.PKSO.SOID = dbo.PKSOProduct.SOID
									WHERE (dbo.PKSO.Status = 'Pending')
								  ) AS SO
							GROUP BY ProductID, LocationID) AS c 
							ON PT.locationid = c.LocationID AND PT.productid = c.ProductID 
					LEFT OUTER JOIN
						(SELECT ProductID, LocationID, SUM(OrderQty) AS Back
						FROM (SELECT PKSOProduct_1.ProductID, PKSOProduct_1.LocationID, CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN OrderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS OrderQty
								FROM dbo.PKSOProduct AS PKSOProduct_1 
								INNER JOIN dbo.PKSO AS PKSO_1 ON PKSO_1.SOID = PKSOProduct_1.SOID
								WHERE (PKSO_1.Status = 'Back')
							) AS SOBack
						GROUP BY ProductID, LocationID) AS d ON PT.locationid = d.LocationID AND PT.productid = d.ProductID
					where (pit.Qty < pt.minthreshold or pit.Qty > pt.maxthreshold) and Po.VendorID= @VendorId
					union
					select distinct pt.locationid as locationid, 
						pd.id as DepartmentID,
						pd.Name as departmentname,
						pc.id as CategoryID,
						pc.Name as  categoryname, 
						pt.productid,
						p.Name1 + '('+ p.Name2 +')' as productName, 
						p.PLU, 
						p.Barcode, 
						a.qty, 
						pt.minthreshold, 
						pt.maxthreshold,
						c.hold,
						d.Back
					from PKInventoryThresholds PT 
					inner join PKProduct P on pt.productid = P.ID
					inner join PKCategory PC on pc.ID = p.CategoryID
					inner join PKDepartment PD on pd.ID = pc.DepartmentID
					inner join (select sum(Qty) as qty,ProductID from PKInventory Pit  group by ProductID) a 
								on a.ProductID = pt.productid
					INNER JOIN (SELECT distinct ProductID,POID FROM PKPOProduct) AS PP ON PT.productid = PP.ProductID 
					INNER JOIN (SELECT distinct POID,VendorID FROM PKPO) AS PO  ON PP.POID = PO.POID 
					LEFT OUTER JOIN
					 (SELECT ProductID, SUM(Qty) AS hold
						FROM (SELECT dbo.PKSOProduct.ProductID, CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN orderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS Qty
								FROM dbo.PKSOProduct
								INNER JOIN dbo.PKSO ON dbo.PKSO.SOID = dbo.PKSOProduct.SOID
								WHERE (dbo.PKSO.Status = 'Pending')
							  ) AS SO
						GROUP BY ProductID) AS c 
						ON PT.productid = c.ProductID 
					LEFT OUTER JOIN
						(SELECT ProductID,  SUM(OrderQty) AS Back
						FROM (SELECT PKSOProduct_1.ProductID,  CASE Weigh WHEN 'Y' THEN CASE WHEN Unit IN ('2', 'kg') THEN OrderQty * 2.2 ELSE OrderQty END ELSE OrderQty END AS OrderQty
								FROM dbo.PKSOProduct AS PKSOProduct_1 
								INNER JOIN dbo.PKSO AS PKSO_1 ON PKSO_1.SOID = PKSOProduct_1.SOID
								WHERE (PKSO_1.Status = 'Back')
							) AS SOBack
						GROUP BY ProductID) AS d ON PT.productid = d.ProductID
					where pt.locationid = 'All Location' and (a.Qty < pt.minthreshold or a.Qty > pt.maxthreshold) and Po.VendorID= @VendorId
				) tbl 		
		End
		
		if @LocationId <> '-1' 
		begin
			if @VendorId = '-1'
			begin
				delete from #tbl1 
					where locationid <> @LocationId
			end
			else
			begin
				delete from #tbl2
					where locationid <> @LocationId
			end
		end
		
		if @FlagHighLow = '0' --Products with lower qty than the minthreshold.
		begin
			
			if @VendorId = '-1'
			begin
				delete from #tbl1 
				where qty >= minthreshold
			end
			else
			begin
				delete from #tbl2 
				where qty >= minthreshold
			end
		end 
		else if @FlagHighLow = '1'
		begin
			if @VendorId = '-1'
			begin
				delete from #tbl1 
				where qty <= maxthreshold
			end
			else
			begin
				delete from #tbl2 
				where qty <= maxthreshold
			end
			
		end
		if @DepartmentId <> '-1' 
		begin
				
			if @VendorId = '-1'
			begin
				delete from #tbl1 
					where DepartmentID <> @DepartmentId
				if @CategoryId <> '-1' 
				begin
					delete from #tbl1 
						where CategoryID <> @CategoryId
				end
			end
			else
			begin
				delete from #tbl2 
					where DepartmentID <> @DepartmentId
				if @CategoryId <> '-1' 
				begin
					delete from #tbl2 
						where CategoryID <> @CategoryId
				end
			end
		end
		if @Type='2'
		begin
			if @VendorId = '-1'
			begin
				delete from #tbl1 
				where isnull(hold,0) <=0;
			end
			else
			begin
				delete from #tbl2 
				where isnull(hold,0) <=0;
			end
			
		end 
		else if @Type = '3'
		begin
			if @VendorId = '-1'
			begin
				delete from #tbl1 
				where isnull(Back,0) <=0;
			end
			else
			begin
				delete from #tbl2 
				where isnull(Back,0) <=0;
			end
			
		end
		
		if @VendorId= '-1'
		begin
			select * from #tbl1;
			drop table #tbl1;
		end 
		else
		begin
			select * from #tbl2;
			drop table #tbl2;
		end
		
	  
	   --
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetMappingProdsByPLUBarcodeNames]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create PROCEDURE [dbo].[PK_GetMappingProdsByPLUBarcodeNames]
	@PluBarcodeName varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @s NVARCHAR(max); 
    DECLARE @tempDecNumber DECIMAL(18, 2); 
    DECLARE @tempString NVARCHAR(50); 

    SET @tempString = 
    '1234567891012345678910123456789101234567891012345678910'; 
    SET @tempDecNumber = 1000000.00; 

	select @tempString as productId into #tblProd;
	select @tempString as BaseProdId into #tblBase;
	delete  from #tblProd;
	delete  from #tblBase;

	declare @ProductId varchar(50);

	declare t_cursor cursor for 
		select ID FROM PKProduct WHERE (Status = 'active') AND (Barcode = @PluBarcodeName or PLU = @PluBarcodeName or Name1 like '%'+ @PluBarcodeName + '%' ) 
		open t_cursor
		fetch next from t_cursor into @ProductId
		while @@fetch_status = 0
		begin
			print @ProductId
			insert into #tblProd select productId from PKMapping where  productid = @ProductId;
			insert into #tblProd select ProductID from PKMapping where BaseProductID = @ProductId;
			insert into #tblBase select BaseProductID as BaseProdId from PKMapping where  productid = @ProductId;
			insert into #tblBase select BaseProductID as BaseProdId from PKMapping where BaseProductID = @ProductId;

			fetch next from t_cursor into @ProductId
		end
		close t_cursor
		deallocate t_cursor
		
		select distinct productId from #tblProd;
		select distinct BaseProdId from #tblBase;


	drop table #tblProd;
	drop table #tblBase;

END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetModifierConnectionByFoodId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create PROCEDURE [dbo].[PK_GetModifierConnectionByFoodId]
	@FoodId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	if @FoodId = ''
	begin
		SELECT FoodID ,FoodIDType ,ModifierGroupID ,SyncStamp  FROM PKModifierConnection
	end
	else
	Begin
		SELECT FoodID ,FoodIDType ,ModifierGroupID ,SyncStamp  FROM PKModifierConnection where FoodID = @FoodId
	end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetModifierConnectionByModifierId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetModifierConnectionByModifierId]
	@ModifierID varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	if @ModifierID = ''
	begin
		SELECT FoodID ,FoodIDType ,ModifierGroupID ,SyncStamp  FROM PKModifierConnection
	end
	else
	Begin
		SELECT FoodID ,FoodIDType ,ModifierGroupID ,SyncStamp  FROM PKModifierConnection where ModifierGroupID = @ModifierID;
	end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetNewBarcodeByBaseProductId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetNewBarcodeByBaseProductId]
	-- Add the parameters for the stored procedure here
	@ProductId varchar(50),
	@inputPLU varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @Plu varchar(50);
	declare @Barcode varchar(50);


	if @inputPLU=''
	begin
		select @Plu = plu
			from PKProduct
			where id = @ProductId;		
		if isnull(@plu,'') = ''
		begin
			set @plu = @inputPLU;
		end
	end
	else
	begin
		set @plu = @inputPLU;
	end

	declare @count int;
	declare @BarcoundCount int;
	set @count = 1;
	set @BarcoundCount =0;

	select @BarcoundCount = count(*) from PKProduct where Barcode = @plu;
	if @BarcoundCount=0 
		begin
			select @plu as barcode
		end
	else
		begin
			while @count < 99
			begin
				set @Barcode = @plu + right('00' + cast(@count as varchar(50)),2);
				select @BarcoundCount = count(*) from PKProduct where Barcode = @Barcode;
		
				if @BarcoundCount = 0 
				begin
					break;
				end

				set @count = @count + 1;
			end
			select @Barcode as barcode;
		end



END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetNewOnlineOrderCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetNewOnlineOrderCustomer]
	@CustomerId  VARCHAR(50), 
    @CompanyName VARCHAR(200)
AS
BEGIN
	IF (@CustomerId = '' or @CustomerId is null) and (@CompanyName = '' or @CompanyName is null)
	BEGIN
		RETURN;
	END

	IF @CompanyName = '' or @CompanyName is null
	BEGIN
		SELECT c.ID AS ID, c.CompanyName AS CompanyName, c.OtherName AS OtherName,
		(a.Street1 + 
		CASE isnull(a.Street2, '')
		WHEN '' THEN ''
		ELSE ' ' + a.Street2
		END +
		CASE isnull(a.City,'')
		WHEN '' THEN ''
		ELSE ' ' + a.City
		END +
		CASE isnull(p.Province,'')
		WHEN '' THEN ''
		ELSE ' ' + p.Province
		END +
		CASE isnull(a.ZIP,'')
		WHEN '' THEN ''
		ELSE ' ' + a.ZIP
		END +
		CASE isnull(a.Country,'')
		WHEN '' THEN ''
		ELSE ' ' + a.Country
		END
		) AS Address,
		a.Contact AS Contact, a.TEL AS TEL, c.PSTNo AS PSTNo
		FROM pkcustomermultiadd AS c 
		LEFT JOIN (SELECT ReferenceID, Street1, Street2, City, Province, ZIP, Country, Contact, TEL FROM PKMultiADD where LOWER(PrimaryFlag)='yes') AS a ON a.ReferenceID = c.ID 
		LEFT JOIN PKProvince AS p ON a.Province = p.ProvinceID
		WHERE c.ID = @CustomerId
	END
	ELSE
	BEGIN
	SELECT c.ID AS ID,
		(c.CompanyName +
		CASE isnull(c.OtherName, '')
		WHEN '' THEN ''
		ELSE ' (' + c.OtherName + ')'  
		END ) AS CompanyName,
		(a.Street1 + 
		CASE isnull(a.Street2, '')
		WHEN '' THEN ''
		ELSE ' ' + a.Street2
		END +
		CASE isnull(a.City,'')
		WHEN '' THEN ''
		ELSE ' ' + a.City
		END +
		CASE isnull(p.Province,'')
		WHEN '' THEN ''
		ELSE ' ' + p.Province
		END +
		CASE isnull(a.ZIP,'')
		WHEN '' THEN ''
		ELSE ' ' + a.ZIP
		END +
		CASE isnull(a.Country,'')
		WHEN '' THEN ''
		ELSE ' ' + a.Country
		END
		) AS Address,
		a.Contact AS Contact, a.TEL AS TEL, c.PSTNo AS PSTNo
		FROM pkcustomermultiadd AS c 
		LEFT JOIN (SELECT ReferenceID, Street1, Street2, City, Province, ZIP, Country, Contact, TEL FROM PKMultiADD where LOWER(PrimaryFlag)='yes') AS a ON a.ReferenceID = c.ID 
		LEFT JOIN PKProvince AS p ON a.Province = p.ProvinceID
		WHERE (c.CompanyName like '%' + @CompanyName + '%') AND (c.CompanyName != @CompanyName)
	END
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetOwnPackage]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetOwnPackage] 
	@CardNo nVARCHAR(50),
	@BookedAllType varchar(50),
	@deptId varchar(50),
	@LocationId NVarchar(50)
AS 
 BEGIN
	DECLARE @tempString NVARCHAR(100); 
	DECLARE @PurchaseId uniqueidentifier 
	DECLARE @count int 
	DECLARE @isBookingConsolidateProducts NVARCHAR(100); 

	SET @tempString = N'1234567891012345678910123456789101234567891012345678910'; 
	SET @tempString = @tempString + @tempString; 
	select @isBookingConsolidateProducts = isnull(value, 'false') from PKSetting where FieldName = 'isBookingConsolidateProducts'
	if @isBookingConsolidateProducts is null
	begin
		set @isBookingConsolidateProducts = 'false'
	end

	select distinct ppp.*, @tempString as IfBookedAll, @tempString as IfBookedAny into #tbl1 from PKPurchasePackage ppp 
	inner join PKPurchasePackageOrder pppo on pppo.transferId = ppp.transferId and pppo.Locationid = case @LocationId when '' then pppo.Locationid else @LocationId end 
	where  ppp.CardNumber = @CardNo and ppp.itemType = 'B' and ppp.Status = 'Active'

	update #tbl1 set IfBookedAll = '', IfBookedAny = '';

	DECLARE t_cursor CURSOR FOR SELECT PurchaseId FROM #tbl1

	OPEN t_cursor
	FETCH next FROM t_cursor INTO @PurchaseId
	WHILE @@fetch_status = 0
	BEGIN 
		select @count = Count(PurchaseItemId) from PKPurchaseItem where  PurchaseId = @PurchaseId and ISNULL(resourceTimeFrom, '') = '';
		if @count = 0
		begin
			update #tbl1 set IfBookedAll = 'true' where PurchaseId = @PurchaseId 
		end 
		select @count = Count(PurchaseItemId) from PKPurchaseItem where  PurchaseId = @PurchaseId and ISNULL(resourceTimeFrom, '') <> '';
		if @count > 0
		begin
			update #tbl1 set IfBookedAny = 'true' where PurchaseId = @PurchaseId
		end 
		FETCH next FROM t_cursor INTO @PurchaseId
	END 
	CLOSE t_cursor 
	DEALLOCATE t_cursor 

	select distinct PPm.Name1 + ' ' + PPm.Name2 as Name, Substring(PPm.name1, 0, 20) as name1, CONVERT(varchar(12), ppp.createdate, 102) as createDate, 
	ppp.createdate as originalCreateDate, PPP.amount AS Price, ppp.purchaseId, ppp.IfBookedAll, ppp.IfBookedAny, 'package' as packageType, ppp.transferId ,'false' as IfPaid
	into #tbl2 from pkPromotion PPm 
	inner join #tbl1 PPP on PPP.BomOrProductId = PPM.Id 
	inner join PKPromotionPrice Pprice on Pprice.promotionid = PPM.Id 
	inner join PKPromotionProduct PMP on pmp.PromotionID = PPm.ID 
	INNER JOIN PKProduct ON PKProduct.ID = PMP.ProductID 
	inner join PKCategory Pc on pc.ID = PKProduct.CategoryID and pc.departmentId = case @deptId  when 'ALL Department' then pc.DepartmentID else @deptId end 
	inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
	
	select [name], transferId, count(*) as countName
	into #tbl2A
	from #tbl2
	group by name, transferid
	;

	select [name], max(PurchaseId) as PurchaseId,transferId
	into #tbl2B
	from #tbl2
	group by name, transferid
	;

	select distinct tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    t2.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    t2.createDate,
    t2.originalCreateDate,
    t2.Price,
    t2.PurchaseId,
    t2.IfBookedAll,
    t2.IfBookedAny,
    t2.packageType,
    t2.transferId,
	t2.IfPaid
   into #tbl2c
   from #tbl2b tb
   inner join #tbl2a ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tbl2 t2 on t2.PurchaseId = tb.PurchaseId

      --order by ppp.createdate desc 
	select pp.name1 + ' ' + pp.Name2  as Name, 
	Substring(pp.name1, 0, 20) as name1, CONVERT(varchar(12), PPI.createdate, 102) as createDate,
	ppi.CreateDate as originalCreateDate, 
	pkPP.amount as price, 
	ppi.PurchaseItemId as PurchaseId, 
	case ISNULL(resourceTimeFrom, '') when '' then 'false' else 'true' end as IfBookedAll, 
	case ISNULL(resourceTimeFrom, '') when '' then 'false' else 'true' end as IfBookedAny, 
	'product' as packageType, isnull(pkpp.transferId, '') as transferId ,
	'false' as IfPaid
	into #tbl3 from PKPurchaseItem PPI 
	inner join PKProduct PP on ppi.ProductId = pp.ID
	inner join pkcategory PC on Pc.id = pp.categoryId and pc.departmentId = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end 
	inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
	inner join PKPrice PPr on ppr.ProductID = pp.ID 
	inner join PKPurchasePackage pkPP on pkpp.PurchaseId = ppi.PurchaseItemId 
	inner join PKPurchasePackageOrder pppo on pppo.transferId = pkPP.transferId and pppo.Locationid = case @LocationId when '' then pppo.Locationid else @LocationId end 
	where  PPI.CardNumber = @CardNo and packagetype = 'product' and pkpp.Status = 'Active'; 


	select [name], transferId, count(*) as countName
	into #tbl3A
	from #tbl3
	group by name, transferid
	;

	select [name], max(PurchaseId) as PurchaseId,transferId
	into #tbl3B
	from #tbl3
	group by name, transferid
	;

	select distinct tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    t3.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    t3.createDate,
    t3.originalCreateDate,
    t3.Price,
    t3.PurchaseId,
    t3.IfBookedAll,
    t3.IfBookedAny,
    t3.packageType,
    t3.transferId,
	t3.IfPaid
   into #tbl3c
   from #tbl3b tb
   inner join #tbl3a ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tbl3 t3 on t3.PurchaseId = tb.PurchaseId


	-----------------------------------------------------------------------
	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl5 FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance;

	SELECT PKPurchasePackagePaymentItem.transferId INTO #tbl6 FROM #tbl5 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)

	-----------------------------------------------------------------------
	SELECT PKPrepaidPackage.Name1 + ' ' + PKPrepaidPackage.Name2  as Name, 
	SUBSTRING(PKPrepaidPackage.Name1, 0, 20) as name1, 
	CONVERT(varchar(12), PKPrepaidPackageTransaction.CreateTime, 102 ) as createDate, PKPrepaidPackageTransaction.CreateTime AS originalCreateDate, PKPrepaidPackageTransaction.Price, 
	PKPrepaidPackageTransaction.ID, ISNULL(IfBookedAll, '') AS IfBookedAll, ISNULL(IfBookedAny, '') AS IfBookedAny, 'prepaidPackage' as packageType, 
	isnull(PKPrepaidPackageTransaction.transferId,'') as transferId, 'false' as IfPaid into #tbl4 FROM PKPrepaidPackageTransaction 
	INNER JOIN PKPrepaidPackage ON PKPrepaidPackage.ID = PKPrepaidPackageTransaction.PrepaidPackageID
	inner join PKPurchasePackageOrder pppo on pppo.transferId = PKPrepaidPackageTransaction.transferId and pppo.Locationid = case @LocationId when '' then pppo.Locationid else @LocationId end
	LEFT JOIN (SELECT transferId, 'true' AS IfBookedAll, '' AS IfBookedAny FROM #tbl6 GROUP BY transferId) AS payment ON payment.transferId = PKPrepaidPackageTransaction.transferId
	WHERE PKPrepaidPackageTransaction.CardNumber = @CardNo and PKPrepaidPackageTransaction.Type = 'Purchase'

   select [name], transferId, count(*) as countName
   into #tbl4A
   from #tbl4
   group by name, transferid
   ;

   select [name], max(ID) as ID,transferId
   into #tbl4B
   from #tbl4
   group by name, transferid
   ;

   select distinct tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    t4.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    t4.createDate,
    t4.originalCreateDate,
    t4.Price,
    t4.ID,
    t4.IfBookedAll,
    t4.IfBookedAny,
    t4.packageType,
    t4.transferId,
	t4.IfPaid
   into #tbl4c
   from #tbl4b tb
   inner join #tbl4a ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tbl4 t4 on t4.id = tb.ID
   -------------------------------------------------------------------------------------
	SELECT PDP.Name1 + ' ' + PDP.Name2  as Name, 
		SUBSTRING(PDP.Name1, 0, 20) as name1, 
		CONVERT(varchar(12), PDT.CreateTime, 102 ) as createDate, 
		PDT.CreateTime AS originalCreateDate, 
		isnull(PDT.Price,0) as Price, 
		PDT.ID, ISNULL(IfBookedAll, '') AS IfBookedAll, 
		ISNULL(IfBookedAny, '') AS IfBookedAny, 
		'depositPackage' as packageType, 
		isnull(PDT.transferId,'') as transferId ,
		'false' as IfPaid
		into #tblDeposit 
	FROM PKDepositPackageTransaction PDT 
	INNER JOIN PKDepositPackage PDP ON PDP.ID = PDT.PrepaidPackageID 
	inner join PKPurchasePackageOrder pppo on pppo.transferId = PDT.transferId and pppo.Locationid = case @LocationId when '' then pppo.Locationid else @LocationId end
	LEFT JOIN (SELECT transferId, 'true' AS IfBookedAll, '' AS IfBookedAny FROM #tbl6 GROUP BY transferId) AS payment ON payment.transferId = PDT.transferId
	WHERE PDT.CardNumber = @CardNo and PDT.Type = 'Purchase' and PDT.Status='Active'

   select [name], transferId, count(*) as countName
   into #tblDepositA
   from #tblDeposit
   group by name, transferid
   ;

   select [name], max(ID) as ID,transferId
   into #tblDepositB
   from #tblDeposit
   group by name, transferid
   ;

   select distinct tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    td.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    td.createDate,
    td.originalCreateDate,
    td.Price,
    td.ID,
    td.IfBookedAll,
    td.IfBookedAny,
    td.packageType,
    td.transferId,
	td.IfPaid
   into #tblDepositc
   from #tblDepositb tb
   inner join #tblDeposita ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tblDeposit tD on td.id = tb.ID
   -------------------------------------------------------------------------------------
	SELECT PDP.Name1 + ' ' + PDP.Name2  as Name, 
		SUBSTRING(PDP.Name1, 0, 20) as name1, 
		CONVERT(varchar(12), PDT.CreateTime, 102 ) as createDate, 
		PDT.CreateTime AS originalCreateDate, 
		isnull(PDT.Price,0) as Price, 
		PDT.ID, ISNULL(IfBookedAll, '') AS IfBookedAll, 
		ISNULL(IfBookedAny, '') AS IfBookedAny, 
		'giftCard' as packageType, 
		isnull(PDT.transferId,'') as transferId ,
		'false' as IfPaid
		into #tblGiftCard
	FROM PKGiftCardTransaction PDT 
	INNER JOIN PKGiftCard PDP ON PDP.ID = PDT.GiftCardId
	inner join PKPurchasePackageOrder pppo on pppo.transferId = PDT.transferId and pppo.Locationid = case @LocationId when '' then pppo.Locationid else @LocationId end
	LEFT JOIN (SELECT transferId, 'true' AS IfBookedAll, '' AS IfBookedAny FROM #tbl6 GROUP BY transferId) AS payment ON payment.transferId = PDT.transferId
	WHERE PDT.CardNumber = @CardNo and PDT.Type = 'Purchase'

   select [name], transferId, count(*) as countName
   into #tblGiftCardA
   from #tblGiftCard
   group by name, transferid
   ;

   select [name], max(ID) as ID,transferId
   into #tblGiftCardB
   from #tblGiftCard
   group by name, transferid
   ;

   select distinct tb.Name + case ta.countName when 1 then '' else +'(X'+ cast(ta.countName as varchar(10)) +')' end as Name,  
    td.name1 + case ta.countName when 1 then '' else +'(X '+ cast(ta.countName as varchar(10)) +')' end as Name1,
    td.createDate,
    td.originalCreateDate,
    td.Price,
    td.ID,
    td.IfBookedAll,
    td.IfBookedAny,
    td.packageType,
    td.transferId,
	td.IfPaid
   into #tblGiftCardc
   from #tblGiftCardb tb
   inner join #tblGiftCarda ta on ta.Name = tb.Name and ta.transferId = tb.transferId
   inner join #tblGiftCard tD on td.id = tb.ID
   -------------------------------------------------------------------------------------
  
  if @isBookingConsolidateProducts = 'true'
  begin 
		if @BookedAllType = 'available'
		begin
			select * from 
			(
				select * from #tbl2c where IfBookedAll <> 'true' 
				union 
				select * from #tbl3c where IfBookedAll <> 'true' 
				union
				select * from #tbl4c where IfBookedAll <> 'true'
				union
				select * from #tblDepositc where IfBookedAll <> 'true'
				union
				select * from #tblGiftCardc where IfBookedAll <> 'true'

			) a order  by originalCreateDate desc 
		end 
		else if @BookedAllType = 'completed' 
		begin
			select * from 
			(
				select * from #tbl2c where IfBookedAll = 'true' 
				union 
				select * from #tbl3c where IfBookedAll = 'true' 
				union
				select * from #tbl4c where IfBookedAll = 'true'
				union
				select * from #tblDepositc where IfBookedAll = 'true'		
				union
				select * from #tblGiftCardc where IfBookedAll = 'true'		
			) a order  by originalCreateDate desc 
		end 
		else
		begin 
			select * from 
			(
				select * from #tbl2c 
				union 
				select * from #tbl3c 
				union 
				select * from #tbl4c
				union 
				select * from #tblDepositc
				union 
				select * from #tblGiftCardc
			) a order  by originalCreateDate desc 
		end 
  end 
  else
  begin
		if @BookedAllType = 'available'
		begin
			select * from 
			(
				select * from #tbl2 where IfBookedAll <> 'true' 
				union 
				select * from #tbl3 where IfBookedAll <> 'true' 
				union
				select * from #tbl4c where IfBookedAll <> 'true'
				union
				select * from #tblDepositc where IfBookedAll <> 'true'
				union
				select * from #tblGiftCardc where IfBookedAll <> 'true'

			) a order  by originalCreateDate desc 
		end 
		else if @BookedAllType = 'completed' 
		begin
			select * from 
			(
				select * from #tbl2 where IfBookedAll = 'true' 
				union 
				select * from #tbl3 where IfBookedAll = 'true' 
				union
				select * from #tbl4c where IfBookedAll = 'true'
				union
				select * from #tblDepositc where IfBookedAll = 'true'		
				union
				select * from #tblGiftCardc where IfBookedAll = 'true'		
			) a order  by originalCreateDate desc 
		end 
		else
		begin 
			select * from 
			(
				select * from #tbl2 
				union 
				select * from #tbl3 
				union 
				select * from #tbl4c
				union 
				select * from #tblDepositc
				union 
				select * from #tblGiftCardc
			) a order  by originalCreateDate desc 
		end 
	end
	drop table #tbl1; 
    drop table #tbl2; 
    drop table #tbl3; 
    drop table #tbl4;
	drop table #tbl5;
	drop table #tbl6;
	drop table #tbl4A;
	drop table #tbl4B;
	drop table #tbl4c;
	drop table #tblDeposit;
	drop table #tblDepositA;
	drop table #tblDepositB;
	drop table #tblDepositc;
	drop table #tblGiftCard;
	drop table #tblGiftCardA;
	drop table #tblGiftCardB;
	drop table #tblGiftCardc;

	drop table #tbl3A;
	drop table #tbl3B;
	drop table #tbl3c;

	drop table #tbl2A;
	drop table #tbl2B;
	drop table #tbl2c;



END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetOwnPackageItems]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetOwnPackageItems] @PurchaseId VARCHAR(50), 
                                              @Type       VARCHAR(50), 
                                              @CardID VARCHAR(50),
											  @packageType varchar(50),
											  @deptId varchar(50),
											  @LocationId NVarchar(50)
AS 
  BEGIN 
       DECLARE @tempString NVARCHAR(100); 

      SET @tempString = 
      N'1234567891012345678910123456789101234567891012345678910' 
      ; 
      SET @tempString = @tempString + @tempString; 

      IF @PurchaseId = '' 
          OR @PurchaseId = '''''' 
        BEGIN 
            SELECT PPI.purchaseitemid, 
                   PP.name1 + ' ' + pp.name2                       AS 
                   ProductName, 
                   Isnull(Cast(PPI.resourceid AS VARCHAR(50)), '') AS ResourceId 
                   , 
                   Isnull(resourcedate, '') 
                   AS ResourceDate 
                   , 
                   Isnull(resourcetimefrom, '') 
                   AS ResourceTimeFrom 
                   , 
                   Isnull(resourcetimeto, '')                      AS 
                   ResourceTimeTo, 
                   ppi.remark, 
                   @tempString                                     AS                    isResourceEmpty, 
                   @tempString                                     AS                    ResourceEntireDate,
				   ppp.createDate,
				   ppi.packsize,
				   isnull(ppi.itemOrder, 0) as itemOrder,
				   ppi.ProductId,
				   ppi.sales,
				   ppi.forcesales,
				   2 as StatusOrder
            INTO   #tbl1 
            FROM   pkpurchasepackage PPP 
				   
                   INNER JOIN pkpurchaseitem PPI 
                           ON PPP.purchaseid = PPI.purchaseid 
                   INNER JOIN pkproduct PP 
                           ON PP.id = PPI.productid 
				   inner join pkcategory PC 
							on Pc.id = pp.categoryId and
							pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
				   inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
				   inner join PKPurchasePackageOrder pppo 
                     on pppo.transferId = PPP.transferId 
                        and pppo.Locationid = case @LocationId 
                                                when '' then pppo.Locationid 
                                                else @LocationId 
                                              end 
            WHERE  PPP.CardNumber = @CardID 
			and ppp.itemType = 'B'
            --and ( 
            --(@type = 'history' and len(isnull(PPI.ResourceTimeTo,''))>0) or  
            --(@type = 'available' and len(isnull(PPI.ResourceTimeTo,''))=0) 
            --) 
            ORDER  BY ppi.productid, 
                      ppi.resourcedate DESC, 
                      ppi.resourcetimefrom DESC ;

					  --select 1 as a into #tbl1a;


			SELECT purchaseitemid, 
					   Isnull(Cast(isnull(PPI.resourceid, newid()) AS VARCHAR(50)), '') AS ResourceId , 
					   Isnull(resourcedate, '') AS ResourceDate , 
					   Isnull(resourcetimefrom, '') AS ResourceTimeFrom , 
					   Isnull(resourcetimeto, '')                      AS ResourceTimeTo, 
					   PP.name1 + ' ' + pp.name2                       AS ProductName, 
					   @tempString                                     AS isResourceEmpty, 
					   @tempString                                     AS ResourceEntireDate , 
					   PPI.remark,
					   PPI.createdate,
					   ppi.packsize,
					   isnull(ppi.itemOrder, 0) as itemOrder,
					   ppi.ProductId,
					   ppi.sales,
						ppi.forcesales
				INTO   #tbl1a 
				FROM   pkpurchaseitem PPI 
					   INNER JOIN pkproduct PP 
							   ON PPI.productid = PP.id 
					   inner join pkcategory PC 
							on Pc.id = pp.categoryId and
							pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
						inner join PKPurchasePackage pkPP 
								on pkpp.PurchaseId = ppi.PurchaseId 
						inner join PKPurchasePackageOrder pppo 
								on pppo.transferId = pkPP.transferId 
								and pppo.Locationid = case @LocationId 
														when '' then pppo.Locationid 
														else @LocationId 
														end 

					   inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
						--inner join Customer c on c.CustomerNo = ppi.CardNumber
						--inner join customerCard CC on cc.cardNo = PPi.cardNumber
				WHERE  PPI.CardNumber = @CardID and ppi.packagetype = 'product'

				insert into #tbl1(
					PurchaseItemId,
					ResourceId,
					ResourceDate,
					ResourceTimeFrom,
					ResourceTimeTo,
					ProductName,
					isResourceEmpty, 
					ResourceEntireDate,
					Remark,
					CreateDate,
					packsize,
					itemOrder,
					ProductId,
					sales,
					forcesales,
					StatusOrder
				) 
				select PurchaseItemId,
				ResourceId,
				ResourceDate,
				ResourceTimeFrom,
				ResourceTimeTo,
				ProductName,
				isResourceEmpty, 
				ResourceEntireDate,
				Remark,
				CreateDate,
				packsize ,
				itemOrder,
				ProductId,
				sales,
				forcesales,
				2
				from #tbl1a;

            UPDATE #tbl1 
            SET    isresourceempty = CASE resourcedate + resourcetimefrom 
                                          + resourcetimeto 
                                       WHEN '' THEN 'true' 
                                       ELSE 'false' 
                                     END; 

            UPDATE #tbl1 
            SET    resourceentiredate = resourcedate + ' ' + resourcetimefrom + 
                                        ' ' 
                                        + resourcetimeto; 
			
            UPDATE #tbl1 SET statusOrder = 3 where isnull(ResourceDate,'') <> '';
            UPDATE #tbl1 SET statusOrder = 1 where statusOrder = 3 and cast(ResourceDate + ' ' + ResourceTimeTo as datetime)>getdate();
			

			if @Type = 'all'
			begin
				SELECT productname, 
					   isresourceempty, 
					   packsize,
					   Count(productname)  as iCount
				into #tbl3_all
				FROM   #tbl1 
				GROUP  BY productname, 
						  isresourceempty,
						  packsize
				ORDER  BY productname, 
						  isresourceempty; 

				alter table #tbl3_all alter column iCount decimal(18,1);
				update #tbl3_all set icount = icount/2 where packsize = '.5'
				update #tbl3_all set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'


				SELECT productname, 
						isresourceempty, 
						sum(iCount) as iCount 
					into #tbl3_a_all
					FROM   #tbl3_all 
					GROUP  BY productname, 
								isresourceempty 
					ORDER  BY productname, 
								isresourceempty; 



				select distinct productName 
				into #tbl4_all
				from #tbl3_a_all;

				select t4.ProductName,
				'true' as trueResourceEmpty,
				isnull(t3.iCount,0) as trueCount,
				'false' as falseResourceEmpty,
				isnull(t5.iCount,0) as falseCount,
				isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
				into #tbl4_All_final
				from #tbl4_all t4
				left outer join #tbl3_a_all t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
				left outer join #tbl3_a_all t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'


				SELECT t1.*,t2.trueCount 
				FROM   #tbl1 t1
				inner join #tbl4_All_final t2 on t2.ProductName = t1.ProductName
				ORDER  BY t1.StatusOrder, itemOrder desc,
				CASE WHEN ISNULL(resourcedate, '') = '' then GETDATE()
				ELSE CONVERT(datetime, resourcedate + ' ' + resourcetimefrom) END DESC, 
				resourcetimefrom DESC, packsize;

				drop table #tbl3_all;
				drop table #tbl3_a_all;
				drop table #tbl4_all;
				drop table #tbl4_All_final;
			end
			else if @Type = 'count'
			begin
				SELECT productname, 
					   isresourceempty, 
					   packsize,
					   Count(productname)  as iCount
				into #tbl3
				FROM   #tbl1 
				GROUP  BY productname, 
						  isresourceempty,
						  packsize
				ORDER  BY productname, 
						  isresourceempty; 

				alter table #tbl3 alter column iCount decimal(18,1);
				update #tbl3 set icount = icount/2 where packsize = '.5'
				update #tbl3 set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'


				SELECT productname, 
						isresourceempty, 
						sum(iCount) as iCount 
					into #tbl3_a
					FROM   #tbl3 
					GROUP  BY productname, 
								isresourceempty 
					ORDER  BY productname, 
								isresourceempty; 



				select distinct productName 
				into #tbl4
				from #tbl3_a;

				select t4.ProductName,
				'true' as trueResourceEmpty,
				isnull(t3.iCount,0) as trueCount,
				'false' as falseResourceEmpty,
				isnull(t5.iCount,0) as falseCount,
				isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
				from #tbl4 t4
				left outer join #tbl3_a t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
				left outer join #tbl3_a t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'


				drop table #tbl3;
				drop table #tbl3_a;
				drop table #tbl4;
			end
            DROP TABLE #tbl1; 
            DROP TABLE #tbl1a; 
        END 
      ELSE 
        BEGIN 
			if @packageType = 'package'
			begin
				SELECT purchaseitemid, 
					   Isnull(Cast(PPI.resourceid AS VARCHAR(50)), '') AS ResourceId 
					   , 
					   Isnull(resourcedate, '') 
					   AS ResourceDate 
					   , 
					   Isnull(resourcetimefrom, '') 
					   AS ResourceTimeFrom 
					   , 
					   Isnull(resourcetimeto, '')                      AS 
					   ResourceTimeTo, 
					   PP.name1 + ' ' + pp.name2                       AS 
					   ProductName, 
					   @tempString                                     AS 
					   isResourceEmpty, 
					   @tempString                                     AS 
					   ResourceEntireDate 
					   , 
					   PPI.remark,
					   PPI.createdate,
					   ppi.packsize,
					   isnull(PPI.itemOrder,0) as itemorder,
					   ppi.ProductId,
					   ppi.sales,
						ppi.forcesales,
						2 as StatusOrder
				INTO   #tbl2 
				FROM   pkpurchaseitem PPI 
					   INNER JOIN pkproduct PP 
							   ON PPI.productid = PP.id 
					   inner join pkcategory PC 
							on Pc.id = pp.categoryId and
							pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
					   inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
					   inner join PKPurchasePackage pkPP 
								on pkpp.PurchaseId = ppi.PurchaseId 
					   inner join PKPurchasePackageOrder pppo 
								on pppo.transferId = pkPP.transferId 
								and pppo.Locationid = case @LocationId 
														when '' then pppo.Locationid 
														else @LocationId 
														end 
				WHERE  PPI.purchaseid = @PurchaseId; 

				UPDATE #tbl2 
				SET    isresourceempty = CASE resourcedate + resourcetimefrom 
											  + resourcetimeto 
										   WHEN '' THEN 'true' 
										   ELSE 'false' 
										 END; 

				UPDATE #tbl2 
				SET    resourceentiredate = resourcedate + ' ' + resourcetimefrom + 
											' ' 
											+ resourcetimeto; 
				UPDATE #tbl2 SET statusOrder = 3 where isnull(ResourceDate,'') <> '';
				UPDATE #tbl2 SET statusOrder = 1 where statusOrder = 3 and cast(ResourceDate + ' ' + ResourceTimeTo as datetime)>getdate();
            

				if @Type = 'all'
				begin
					SELECT productname, 
						   isresourceempty, 
						   packsize,
						   Count(productname) as iCount 
					into #tbl3a_all
					FROM   #tbl2 
					GROUP  BY productname, 
							  isresourceempty ,
							  packsize
					ORDER  BY productname, 
							  isresourceempty; 
					

					alter table #tbl3a_all alter column iCount decimal(18,1);
					update #tbl3a_all set icount = icount/2 where packsize = '.5'
					update #tbl3a_all set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'

					SELECT productname, 
						   isresourceempty, 
						   sum(iCount) as iCount 
					into #tbl3aa_all
					FROM   #tbl3a_all 
					GROUP  BY productname, 
							  isresourceempty 
					ORDER  BY productname, 
							  isresourceempty; 



					select distinct productName 
					into #tbl4a_all
					from #tbl3aa_all;

					select t4.ProductName,
					'true' as trueResourceEmpty,
					isnull(t3.iCount,0) as trueCount,
					'false' as falseResourceEmpty,
					isnull(t5.iCount,0) as falseCount,
					isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
					into #tbl4a_all_final
					from #tbl4a_all t4
					left outer join #tbl3aa_all t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
					left outer join #tbl3aa_all t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'



					SELECT t1.*,t2.trueCount
					FROM   #tbl2 t1
					inner join #tbl4a_all_final t2 on t2.ProductName = t1.ProductName
					ORDER  BY t1.StatusOrder, itemOrder desc,
					CASE WHEN ISNULL(resourcedate, '') = '' then GETDATE()
					ELSE CONVERT(datetime, resourcedate + ' ' + resourcetimefrom) END DESC, 
					resourcetimefrom DESC, packsize;

					drop table #tbl3a_all;
					drop table #tbl3aa_all;
					drop table #tbl4a_all_final;
					drop table #tbl4a_all;
				end
				else if @Type = 'count'
				begin
					SELECT productname, 
						   isresourceempty, 
						   packsize,
						   Count(productname) as iCount 
					into #tbl3a
					FROM   #tbl2 
					GROUP  BY productname, 
							  isresourceempty ,
							  packsize
					ORDER  BY productname, 
							  isresourceempty; 
					

					alter table #tbl3a alter column iCount decimal(18,1);
					update #tbl3a set icount = icount/2 where packsize = '.5'
					update #tbl3a set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'

					SELECT productname, 
						   isresourceempty, 
						   sum(iCount) as iCount 
					into #tbl3aa
					FROM   #tbl3a 
					GROUP  BY productname, 
							  isresourceempty 
					ORDER  BY productname, 
							  isresourceempty; 



					select distinct productName 
					into #tbl4a
					from #tbl3aa;

					select t4.ProductName,
					'true' as trueResourceEmpty,
					isnull(t3.iCount,0) as trueCount,
					'false' as falseResourceEmpty,
					isnull(t5.iCount,0) as falseCount,
					isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
					from #tbl4a t4
					left outer join #tbl3aa t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
					left outer join #tbl3aa t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'


					drop table #tbl3a;
					drop table #tbl3aa;
					drop table #tbl4a;

				end

				DROP TABLE #tbl2; 
			end
			else if @packageType = 'product'
			begin
				SELECT purchaseitemid, 
					   Isnull(Cast(PPI.resourceid AS VARCHAR(50)), '') AS ResourceId 
					   , 
					   Isnull(resourcedate, '') 
					   AS ResourceDate 
					   , 
					   Isnull(resourcetimefrom, '') 
					   AS ResourceTimeFrom 
					   , 
					   Isnull(resourcetimeto, '')                      AS 
					   ResourceTimeTo, 
					   PP.name1 + ' ' + pp.name2                       AS 
					   ProductName, 
					   @tempString                                     AS 
					   isResourceEmpty, 
					   @tempString                                     AS 
					   ResourceEntireDate 
					   , 
					   PPI.remark,
					   PPI.createdate,ppi.packsize,
					   isnull(ppi.itemorder, 0) as itemOrder,
					   ppi.ProductId,
					   ppi.sales,
						ppi.forcesales,
						2 as StatusOrder
				INTO   #tbl5 
				FROM   pkpurchaseitem PPI 
					   INNER JOIN pkproduct PP 
							   ON PPI.productid = PP.id 
					   inner join pkcategory PC 
							on Pc.id = pp.categoryId and
							pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
					   inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
					   inner join PKPurchasePackage pkPP 
								on pkpp.PurchaseId = ppi.PurchaseId 
						inner join PKPurchasePackageOrder pppo 
								on pppo.transferId = pkPP.transferId 
								and pppo.Locationid = case @LocationId 
														when '' then pppo.Locationid 
														else @LocationId 
														end 


				WHERE  PPI.PurchaseItemId = @PurchaseId; 

				UPDATE #tbl5 
				SET    isresourceempty = CASE resourcedate + resourcetimefrom 
											  + resourcetimeto 
										   WHEN '' THEN 'true' 
										   ELSE 'false' 
										 END; 

				UPDATE #tbl5 
				SET    resourceentiredate = resourcedate + ' ' + resourcetimefrom + 
											' ' 
											+ resourcetimeto; 

				UPDATE #tbl5 SET statusOrder = 3 where isnull(ResourceDate,'') <> '';
				UPDATE #tbl5 SET statusOrder = 1 where statusOrder = 3 and cast(ResourceDate + ' ' + ResourceTimeTo as datetime)>getdate();

				if @Type = 'all'
				begin

					SELECT productname, 
						   isresourceempty, 
						   packsize,
						   Count(productname) as iCount 
					into #tbl3b_all
					FROM   #tbl5 
					GROUP  BY productname, 
							  isresourceempty,
							  packsize
					ORDER  BY productname, 
							  isresourceempty; 


					alter table #tbl3b_all alter column iCount decimal(18,1);
					update #tbl3b_all set icount = icount/2 where packsize = '.5'
					update #tbl3b_all set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'

					SELECT productname, 
						   isresourceempty, 
						   sum(iCount) as iCount 
					into #tbl3ba_all
					FROM   #tbl3b_all 
					GROUP  BY productname, 
							  isresourceempty 
					ORDER  BY productname, 
							  isresourceempty; 

					select distinct productName 
					into #tbl4b_all
					from #tbl3b_all;

					select t4.ProductName,
					'true' as trueResourceEmpty,
					isnull(t3.iCount,0) as trueCount,
					'false' as falseResourceEmpty,
					isnull(t5.iCount,0) as falseCount,
					isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
					into #tbl4b_all_final
					from #tbl4b_all t4
					left outer join #tbl3ba_all t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
					left outer join #tbl3ba_all t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'

					SELECT t1.* ,t2.trueCount
					FROM   #tbl5 t1
					inner join #tbl4b_all_final t2 on t2.ProductName = t1.ProductName
					ORDER  BY t1.StatusOrder, itemOrder desc,
					CASE WHEN ISNULL(resourcedate, '') = '' then GETDATE()
					ELSE CONVERT(datetime, resourcedate + ' ' + resourcetimefrom) END DESC, 
					resourcetimefrom DESC, packsize;

					drop table #tbl3ba_all;
					drop table #tbl3b_all;
					drop table #tbl4b_all;
					drop table #tbl4b_all_final;



				end
				else if @Type = 'count'
				begin
					SELECT productname, 
						   isresourceempty, 
						   packsize,
						   Count(productname) as iCount 
					into #tbl3b
					FROM   #tbl5 
					GROUP  BY productname, 
							  isresourceempty,
							  packsize
					ORDER  BY productname, 
							  isresourceempty; 


					alter table #tbl3b alter column iCount decimal(18,1);
					update #tbl3b set icount = icount/2 where packsize = '.5'
					update #tbl3b set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'

					SELECT productname, 
						   isresourceempty, 
						   sum(iCount) as iCount 
					into #tbl3ba
					FROM   #tbl3b 
					GROUP  BY productname, 
							  isresourceempty 
					ORDER  BY productname, 
							  isresourceempty; 

					select distinct productName 
					into #tbl4b
					from #tbl3b;

					select t4.ProductName,
					'true' as trueResourceEmpty,
					isnull(t3.iCount,0) as trueCount,
					'false' as falseResourceEmpty,
					isnull(t5.iCount,0) as falseCount,
					isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
					from #tbl4b t4
					left outer join #tbl3ba t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
					left outer join #tbl3ba t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'


					drop table #tbl3ba;
					drop table #tbl3b;
					drop table #tbl4b;
				end

				DROP TABLE #tbl5; 
			end
        END 
  END 




GO
/****** Object:  StoredProcedure [dbo].[PK_GetOwnPackageItemsForReceipt]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetOwnPackageItemsForReceipt] @PurchaseId VARCHAR(50), 
                                              @Type       VARCHAR(50), 
                                              @CardID VARCHAR(50),
											  @packageType varchar(50),
											  @deptId varchar(50),
											  @LocationId NVarchar(50)
AS 
  BEGIN 
      DECLARE @tempString NVARCHAR(100); 

      SET @tempString = 
      N'1234567891012345678910123456789101234567891012345678910' 
      ; 
      SET @tempString = @tempString + @tempString; 

      IF @PurchaseId = '' 
          OR @PurchaseId = '''''' 
        BEGIN 
            SELECT PPI.purchaseitemid, 
                   PP.name1 + ' ' + pp.name2                       AS 
                   ProductName, 
                   Isnull(Cast(PPI.resourceid AS VARCHAR(50)), '') AS ResourceId 
                   , 
                   Isnull(resourcedate, '') 
                   AS ResourceDate 
                   , 
                   Isnull(resourcetimefrom, '') 
                   AS ResourceTimeFrom 
                   , 
                   Isnull(resourcetimeto, '')                      AS 
                   ResourceTimeTo, 
                   ppi.remark, 
                   @tempString                                     AS                    isResourceEmpty, 
                   @tempString                                     AS                    ResourceEntireDate,
				   ppp.createDate,
				   ppi.packsize,
				   isnull(ppi.itemOrder, 0) as itemOrder
            INTO   #tbl1 
            FROM   pkpurchasepackage PPP 
				   
                   INNER JOIN pkpurchaseitem PPI 
                           ON PPP.purchaseid = PPI.purchaseid 
                   INNER JOIN pkproduct PP 
                           ON PP.id = PPI.productid 
				   inner join pkcategory PC 
							on Pc.id = pp.categoryId and
							pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
				   inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
				   inner join PKPurchasePackageOrder pppo 
                     on pppo.transferId = PPP.transferId 
                        and pppo.Locationid = case @LocationId 
                                                when '' then pppo.Locationid 
                                                else @LocationId 
                                              end 
            WHERE  PPP.CardNumber = @CardID 
			and ppp.itemType = 'B'
			and  CONVERT(varchar(100), cast(ResourceDate as smalldatetime), 23) =  CONVERT(varchar(100), getdate(), 23)
            --and ( 
            --(@type = 'history' and len(isnull(PPI.ResourceTimeTo,''))>0) or  
            --(@type = 'available' and len(isnull(PPI.ResourceTimeTo,''))=0) 
            --) 
            ORDER  BY ppi.productid, 
                      ppi.resourcedate DESC, 
                      ppi.resourcetimefrom DESC ;

					  --select 1 as a into #tbl1a;


			SELECT distinct purchaseitemid, 
					   Isnull(Cast(isnull(PPI.resourceid, newid()) AS VARCHAR(50)), '') AS ResourceId , 
					   Isnull(resourcedate, '') AS ResourceDate , 
					   Isnull(resourcetimefrom, '') AS ResourceTimeFrom , 
					   Isnull(resourcetimeto, '')                      AS ResourceTimeTo, 
					   PP.name1 + ' ' + pp.name2                       AS ProductName, 
					   @tempString                                     AS isResourceEmpty, 
					   @tempString                                     AS ResourceEntireDate , 
					   PPI.remark,
					   PPI.createdate,
					   ppi.packsize,
					   isnull(ppi.itemOrder, 0) as itemOrder
				INTO   #tbl1a 
				FROM   pkpurchaseitem PPI 
					   INNER JOIN pkproduct PP 
							   ON PPI.productid = PP.id 
				   inner join pkcategory PC 
							on Pc.id = pp.categoryId and
							pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
				   inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
				   inner join PKPurchasePackage pkPP 
								on pkpp.PurchaseId = ppi.PurchaseId 
						inner join PKPurchasePackageOrder pppo 
								on pppo.transferId = pkPP.transferId 
								and pppo.Locationid = case @LocationId 
														when '' then pppo.Locationid 
														else @LocationId 
														end 
						--inner join Customer c on c.CustomerNo = ppi.CardNumber
						--inner join customerCard CC on cc.cardNo = PPi.cardNumber
				WHERE  PPI.CardNumber = @CardID and ppi.packagetype = 'product'
				and  CONVERT(varchar(100), cast(ResourceDate as smalldatetime), 23) =  CONVERT(varchar(100), getdate(), 23)

				insert into #tbl1(
					PurchaseItemId,
					ResourceId,
					ResourceDate,
					ResourceTimeFrom,
					ResourceTimeTo,
					ProductName,
					isResourceEmpty, 
					ResourceEntireDate,
					Remark,
					CreateDate,
					packsize,
					itemOrder
				) 
				select PurchaseItemId,
				ResourceId,
				ResourceDate,
				ResourceTimeFrom,
				ResourceTimeTo,
				ProductName,
				isResourceEmpty, 
				ResourceEntireDate,
				Remark,
				CreateDate,
				packsize ,
				itemOrder
				from #tbl1a;

            UPDATE #tbl1 
            SET    isresourceempty = CASE resourcedate + resourcetimefrom 
                                          + resourcetimeto 
                                       WHEN '' THEN 'true' 
                                       ELSE 'false' 
                                     END; 

            UPDATE #tbl1 
            SET    resourceentiredate = resourcedate + ' ' + resourcetimefrom + 
                                        ' ' 
                                        + resourcetimeto; 
			if @Type = 'all'
			begin
				--SELECT --CONVERT(varchar(100), cast(ResourceDate as smalldatetime), 23)  as a , CONVERT(varchar(100), GETDATE(), 23) as b,
				----case CONVERT(varchar(100), ResourceDate, 23)  when CONVERT(varchar(100), GETDATE(), 23) then 'true' else 'false' end as c,
				-- * 
				--FROM   #tbl1 
				--ORDER  BY  itemOrder desc,
				--CASE WHEN ISNULL(resourcedate, '') = '' then GETDATE()
				--ELSE CONVERT(datetime, resourcedate + ' ' + resourcetimefrom) END DESC, 
				--resourcetimefrom DESC, packsize;

				select 
				ProductName,
				packsize,
				count(ProductName) as qty,
				'' as remark,
				'' as time
				from #tbl1
				group by ProductName, packsize
				order by ProductName
				;
			end
			else if @Type = 'count'
			begin
				SELECT productname, 
					   isresourceempty, 
					   packsize,
					   Count(productname)  as iCount
				into #tbl3
				FROM   #tbl1 
				GROUP  BY productname, 
						  isresourceempty,
						  packsize
				ORDER  BY productname, 
						  isresourceempty; 

				alter table #tbl3 alter column iCount decimal(18,1);
				update #tbl3 set icount = icount/2 where packsize = '.5'
				update #tbl3 set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'

				SELECT productname, 
						isresourceempty, 
						sum(iCount) as iCount 
					into #tbl3_a
					FROM   #tbl3 
					GROUP  BY productname, 
								isresourceempty 
					ORDER  BY productname, 
								isresourceempty; 



				select distinct productName 
				into #tbl4
				from #tbl3_a;

				select t4.ProductName,
				'true' as trueResourceEmpty,
				isnull(t3.iCount,0) as trueCount,
				'false' as falseResourceEmpty,
				isnull(t5.iCount,0) as falseCount,
				isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
				from #tbl4 t4
				left outer join #tbl3_a t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
				left outer join #tbl3_a t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'


				drop table #tbl3;
				drop table #tbl3_a;
				drop table #tbl4;
			end
            DROP TABLE #tbl1; 
            DROP TABLE #tbl1a; 
        END 
      ELSE 
        BEGIN 
			if @packageType = 'package'
			begin
				SELECT distinct purchaseitemid, 
					   Isnull(Cast(PPI.resourceid AS VARCHAR(50)), '') AS ResourceId 
					   , 
					   Isnull(resourcedate, '') 
					   AS ResourceDate 
					   , 
					   Isnull(resourcetimefrom, '') 
					   AS ResourceTimeFrom 
					   , 
					   Isnull(resourcetimeto, '')                      AS 
					   ResourceTimeTo, 
					   PP.name1 + ' ' + pp.name2                       AS 
					   ProductName, 
					   @tempString                                     AS 
					   isResourceEmpty, 
					   @tempString                                     AS 
					   ResourceEntireDate 
					   , 
					   PPI.remark,
					   PPI.createdate,
					   ppi.packsize,
					   isnull(PPI.itemOrder,0) as itemorder
				INTO   #tbl2 
				FROM   pkpurchaseitem PPI 
					   INNER JOIN pkproduct PP 
							   ON PPI.productid = PP.id 
					   inner join pkcategory PC 
								on Pc.id = pp.categoryId and
								pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
					   inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
					   inner join PKPurchasePackage pkPP 
								on pkpp.PurchaseId = ppi.PurchaseId 
					   inner join PKPurchasePackageOrder pppo 
								on pppo.transferId = pkPP.transferId 
								and pppo.Locationid = case @LocationId 
														when '' then pppo.Locationid 
														else @LocationId 
														end 

				WHERE  PPI.purchaseid = @PurchaseId
				and  CONVERT(varchar(100), cast(ResourceDate as smalldatetime), 23) =  CONVERT(varchar(100), getdate(), 23)
				; 

				UPDATE #tbl2 
				SET    isresourceempty = CASE resourcedate + resourcetimefrom 
											  + resourcetimeto 
										   WHEN '' THEN 'true' 
										   ELSE 'false' 
										 END; 

				UPDATE #tbl2 
				SET    resourceentiredate = resourcedate + ' ' + resourcetimefrom + 
											' ' 
											+ resourcetimeto; 

            

				if @Type = 'all'
				begin
					--SELECT * 
					--FROM   #tbl2 
					--ORDER  BY itemOrder desc,
					--CASE WHEN ISNULL(resourcedate, '') = '' then GETDATE()
					--ELSE CONVERT(datetime, resourcedate + ' ' + resourcetimefrom) END DESC, 
					--resourcetimefrom DESC, packsize;

					select 
					ProductName,
					packsize,
					count(ProductName) as qty,
					'' as remark,
					'' as time
					from #tbl2
					group by ProductName, packsize
					order by ProductName
					;

				end
				else if @Type = 'count'
				begin
					SELECT productname, 
						   isresourceempty, 
						   packsize,
						   Count(productname) as iCount 
					into #tbl3a
					FROM   #tbl2 
					GROUP  BY productname, 
							  isresourceempty ,
							  packsize
					ORDER  BY productname, 
							  isresourceempty; 
					

					alter table #tbl3a alter column iCount decimal(18,1);
					update #tbl3a set icount = icount/2 where packsize = '.5'
					update #tbl3a set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'

					SELECT productname, 
						   isresourceempty, 
						   sum(iCount) as iCount 
					into #tbl3aa
					FROM   #tbl3a 
					GROUP  BY productname, 
							  isresourceempty 
					ORDER  BY productname, 
							  isresourceempty; 



					select distinct productName 
					into #tbl4a
					from #tbl3aa;

					select t4.ProductName,
					'true' as trueResourceEmpty,
					isnull(t3.iCount,0) as trueCount,
					'false' as falseResourceEmpty,
					isnull(t5.iCount,0) as falseCount,
					isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
					from #tbl4a t4
					left outer join #tbl3aa t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
					left outer join #tbl3aa t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'


					drop table #tbl3a;
					drop table #tbl3aa;
					drop table #tbl4a;

				end

				DROP TABLE #tbl2; 
			end
			else if @packageType = 'product'
			begin
				SELECT distinct purchaseitemid, 
					   Isnull(Cast(PPI.resourceid AS VARCHAR(50)), '') AS ResourceId 
					   , 
					   Isnull(resourcedate, '') 
					   AS ResourceDate 
					   , 
					   Isnull(resourcetimefrom, '') 
					   AS ResourceTimeFrom 
					   , 
					   Isnull(resourcetimeto, '')                      AS 
					   ResourceTimeTo, 
					   PP.name1 + ' ' + pp.name2                       AS 
					   ProductName, 
					   @tempString                                     AS 
					   isResourceEmpty, 
					   @tempString                                     AS 
					   ResourceEntireDate 
					   , 
					   PPI.remark,
					   PPI.createdate,ppi.packsize,
					   isnull(ppi.itemorder, 0) as itemOrder
				INTO   #tbl5 
				FROM   pkpurchaseitem PPI 
					   INNER JOIN pkproduct PP 
							   ON PPI.productid = PP.id 
						inner join pkcategory PC 
								on Pc.id = pp.categoryId and
								pc.departmentId  = case @deptId when 'ALL Department' then pc.DepartmentID else @deptId end
						inner join PKDepartmentPMS PDP on pdp.id = pc.departmentId 
						inner join PKPurchasePackage pkPP 
								on pkpp.PurchaseId = ppi.PurchaseId 
						inner join PKPurchasePackageOrder pppo 
								on pppo.transferId = pkPP.transferId 
								and pppo.Locationid = case @LocationId 
														when '' then pppo.Locationid 
														else @LocationId 
														end 
				WHERE  PPI.PurchaseItemId = @PurchaseId
				and  CONVERT(varchar(100), cast(ResourceDate as smalldatetime), 23) =  CONVERT(varchar(100), getdate(), 23)
				; 

				UPDATE #tbl5 
				SET    isresourceempty = CASE resourcedate + resourcetimefrom 
											  + resourcetimeto 
										   WHEN '' THEN 'true' 
										   ELSE 'false' 
										 END; 

				UPDATE #tbl5 
				SET    resourceentiredate = resourcedate + ' ' + resourcetimefrom + 
											' ' 
											+ resourcetimeto; 

            

				if @Type = 'all'
				begin
					--SELECT * 
					--FROM   #tbl5 
					--ORDER  BY itemOrder desc,
					--CASE WHEN ISNULL(resourcedate, '') = '' then GETDATE()
					--ELSE CONVERT(datetime, resourcedate + ' ' + resourcetimefrom) END DESC, 
					--resourcetimefrom DESC, packsize;

					select 
					ProductName,
					packsize,
					count(ProductName) as qty,
					'' as remark,
					'' as time
					from #tbl5
					group by ProductName, packsize
					order by ProductName
					;

				end
				else if @Type = 'count'
				begin
					SELECT productname, 
						   isresourceempty, 
						   packsize,
						   Count(productname) as iCount 
					into #tbl3b
					FROM   #tbl5 
					GROUP  BY productname, 
							  isresourceempty,
							  packsize
					ORDER  BY productname, 
							  isresourceempty; 


					alter table #tbl3b alter column iCount decimal(18,1);
					update #tbl3b set icount = icount/2 where packsize = '.5'
					update #tbl3b set icount = icount * cast(packsize as decimal(18,1)) where packsize <> '.5'

					SELECT productname, 
						   isresourceempty, 
						   sum(iCount) as iCount 
					into #tbl3ba
					FROM   #tbl3b 
					GROUP  BY productname, 
							  isresourceempty 
					ORDER  BY productname, 
							  isresourceempty; 

					select distinct productName 
					into #tbl4b
					from #tbl3b;

					select t4.ProductName,
					'true' as trueResourceEmpty,
					isnull(t3.iCount,0) as trueCount,
					'false' as falseResourceEmpty,
					isnull(t5.iCount,0) as falseCount,
					isnull(t3.iCount,0) + isnull(t5.iCount,0) as totalCount
					from #tbl4b t4
					left outer join #tbl3ba t3 on t3.ProductName = t4.ProductName and t3.isResourceEmpty = 'true'
					left outer join #tbl3ba t5 on t5.ProductName = t4.ProductName and t5.isResourceEmpty = 'false'


					drop table #tbl3ba;
					drop table #tbl3b;
					drop table #tbl4b;
				end

				DROP TABLE #tbl5; 
			end
        END 
  END 



GO
/****** Object:  StoredProcedure [dbo].[PK_getPad2ByDeptId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_getPad2ByDeptId]
	@deptId varchar(50),
	@categoryId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    DECLARE @tempString NVARCHAR(100); 
      SET @tempString =  N'1234567891012345678910123456789101234567891012345678910' 
    -- Insert statements for procedure here
	if @categoryId = ''
	begin
		SELECT ID
		  ,Name1
		  ,Name2
		  ,DeptId
		  ,[Sequence]
		  ,isnull([Columns],4) as [columns]
		  ,isnull([Rows],4) as [Rows]
		  ,isnull(FontSize1,14) as FontSize1
		  ,isnull(FontSize2,14) as FontSize2
		  ,isnull(ForeR,0) as ForeR
		  ,isnull(ForeG,0) as ForeG
		  ,isnull(ForeB,0) as ForeB
		  ,isnull(BackR,255) as BackR
		  ,isnull(BackG,255) as BackG
		  ,isnull(BackB,255) as BackB

		  ,@tempString as Forecolor
		  ,@tempString as BackColor
		into #tbl1
		FROM [POSQuickButtonCategory]
		where DeptId = @deptId;

		update #tbl1 set Forecolor = dbo.PK_GetCertainLength(dbo.inttohex(ForeR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeB),2, 'foot') ,
					   BackColor= dbo.PK_GetCertainLength(dbo.inttohex(BackR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackB),2, 'foot');

		select * from #tbl1 order by [Sequence];
		drop table #tbl1
   End
   else
   begin
		SELECT ID
		  ,Name1
		  ,Name2
		  ,DeptId
		  ,[Sequence]
		  ,isnull([Columns],4) as [columns]
		  ,isnull([Rows],4) as [Rows]
		  ,isnull(FontSize1,14) as FontSize1
		  ,isnull(FontSize2,14) as FontSize2
		  ,isnull(ForeR,0) as ForeR
		  ,isnull(ForeG,0) as ForeG
		  ,isnull(ForeB,0) as ForeB
		  ,isnull(BackR,255) as BackR
		  ,isnull(BackG,255) as BackG
		  ,isnull(BackB,255) as BackB

		  ,@tempString as Forecolor
		  ,@tempString as BackColor
		into #tbl2
		FROM [POSQuickButtonCategory]
		where DeptId = @deptId and id = @categoryId;

		update #tbl2 set Forecolor = dbo.PK_GetCertainLength(dbo.inttohex(ForeR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeB),2, 'foot') ,
					   BackColor= dbo.PK_GetCertainLength(dbo.inttohex(BackR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackB),2, 'foot');

		select * from #tbl2  order by [Sequence];
		drop table #tbl2
   end 
END

GO
/****** Object:  StoredProcedure [dbo].[PK_getPad3ByCategoryId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_getPad3ByCategoryId]
	@categoryId varchar(50),
	@Id varchar(50),
	@referenceId varchar(50)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    DECLARE @tempString NVARCHAR(100); 
      SET @tempString =  N'1234567891012345678910123456789101234567891012345678910' 
    -- Insert statements for procedure here
	if @Id = ''
	begin
		SELECT POSQuickButton.ID
		  ,referenceId 
		  ,Name1
		  ,Name2
		  ,categoryId
		  ,[Sequence]
		  ,isnull(FontSize1,14) as FontSize1
		  ,isnull(FontSize2,14) as FontSize2
		  ,isnull(ForeR,0) as ForeR
		  ,isnull(ForeG,0) as ForeG
		  ,isnull(ForeB,0) as ForeB
		  ,isnull(BackR,255) as BackR
		  ,isnull(BackG,255) as BackG
		  ,isnull(BackB,255) as BackB

		  ,@tempString as Forecolor
		  ,@tempString as BackColor
		  ,pp.A as price
		into #tbl1
		FROM [POSQuickButton]
		inner join PKPrice PP on pp.ProductID = POSQuickButton.ReferenceID
		where CategoryId = @categoryId;

		update #tbl1 set Forecolor = dbo.PK_GetCertainLength(dbo.inttohex(ForeR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeB),2, 'foot') ,
					   BackColor= dbo.PK_GetCertainLength(dbo.inttohex(BackR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackB),2, 'foot');

		select * from #tbl1 order by [Sequence];
		drop table #tbl1
   End
   else if @Id <> '' and @referenceId = ''
   begin
		SELECT POSQuickButton.ID
		  ,referenceId 
		  ,Name1
		  ,Name2
		  ,categoryId
		  ,[Sequence]
		  ,isnull(FontSize1,14) as FontSize1
		  ,isnull(FontSize2,14) as FontSize2
		  ,isnull(ForeR,0) as ForeR
		  ,isnull(ForeG,0) as ForeG
		  ,isnull(ForeB,0) as ForeB
		  ,isnull(BackR,255) as BackR
		  ,isnull(BackG,255) as BackG
		  ,isnull(BackB,255) as BackB

		  ,@tempString as Forecolor
		  ,@tempString as BackColor
		  ,pp.A as price
		into #tbl2
		FROM [POSQuickButton]
		inner join PKPrice PP on pp.ProductID = POSQuickButton.ReferenceID
		where CategoryId = @categoryId and POSQuickButton.id = @Id;

		update #tbl2 set Forecolor = dbo.PK_GetCertainLength(dbo.inttohex(ForeR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeB),2, 'foot') ,
					   BackColor= dbo.PK_GetCertainLength(dbo.inttohex(BackR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackB),2, 'foot');

		select * from #tbl2 order by [Sequence];
		drop table #tbl2
   end 
   else
   begin
		SELECT POSQuickButton.ID
		  ,referenceId 
		  ,Name1
		  ,Name2
		  ,categoryId
		  ,[Sequence]
		  ,isnull(FontSize1,14) as FontSize1
		  ,isnull(FontSize2,14) as FontSize2
		  ,isnull(ForeR,0) as ForeR
		  ,isnull(ForeG,0) as ForeG
		  ,isnull(ForeB,0) as ForeB
		  ,isnull(BackR,255) as BackR
		  ,isnull(BackG,255) as BackG
		  ,isnull(BackB,255) as BackB

		  ,@tempString as Forecolor
		  ,@tempString as BackColor
		  ,pp.A as price
		into #tbl3
		FROM [POSQuickButton]
		inner join PKPrice PP on pp.ProductID = POSQuickButton.ReferenceID
		where CategoryId = @categoryId and ReferenceID = @referenceId 

		update #tbl3 set Forecolor = dbo.PK_GetCertainLength(dbo.inttohex(ForeR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(ForeB),2, 'foot') ,
					   BackColor= dbo.PK_GetCertainLength(dbo.inttohex(BackR),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackG),2, 'foot') + dbo.PK_GetCertainLength(dbo.inttohex(BackB),2, 'foot');

		select * from #tbl3 order by [Sequence];
		drop table #tbl3
   end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetPayment]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_GetPayment]
	@StrFromDate varchar(50),
	@StrToDate varchar(50),
	@CustomerId varchar(50),
	@InvoiceNo varchar(50),
	@IsForReport bit,
	@balanceMin decimal(18,2),
	@balanceMax decimal(18,2),
	@WholeInvoiceAmount decimal(18,2) out,
	@WholePaymentAmount decimal(18,2) out,
	@WholeBalance decimal(18,2) out
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	declare @isPayOver bit
 if @balanceMax=0 and @balanceMin =0 
 begin
	set @isPayOver = 1;
 end
 else
 begin
	set @isPayOver = 0;
 end

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	Declare @innerStrFromDate varchar(50);
	Declare @innerStrToDate varchar(50);
	set @WholeInvoiceAmount = 0;
	set @WholePaymentAmount = 0;
	set @WholeBalance = 0;
	IF LEN(LTRIM(@StrFromDate))=0
	Begin
		set @innerStrFromDate = '1990-01-01 00:00:00';
	End
	Else
	Begin
		set @innerStrFromDate = @StrFromDate + ' 00:00:00';
	End
	IF LEN(LTRIM(@StrToDate))=0
	Begin
		set @innerStrToDate = CONVERT(varchar(100), GETDATE(), 120)
	End
	Else
	Begin
		set @innerStrToDate = @StrToDate + ' 23:59:59';
	End
	
		--Select InvoiceNo, 
		--InvoiceAmount, 
		--PaymentAmount, 
		--Remarks, 
		--Convert(varchar(10),PaymentDate,120) as PaymentDate, 
		--Balance - PaymentAmount as Balance,
		--PKCustomerMultiAdd.CompanyName as CompanyName
		--into #tbl1 
  --      From PKPayment
  --      Join PKSO on PKPayment.OrderID = PKSO.SOID 
  --      Join PKCustomerMultiAdd on PKSO.CustomerID = PKCustomerMultiAdd.ID 
		--where PaymentDate between cast(@innerStrFromDate as datetime) and cast(@innerStrToDate as datetime) 
		--and PKCustomerMultiAdd.ID = case @CustomerId when '' then PKCustomerMultiAdd.ID when '-1' then PKCustomerMultiAdd.ID else @CustomerId end 
		--and InvoiceNo = case @InvoiceNo when '' then InvoiceNo when '-1' then InvoiceNo else @InvoiceNo end 
		Select --PKSO.* 
		distinct
		pkso.status,
		PKSO.OrderId,
		isnull(InvoiceNo,PKSO.OrderId) as aa,
		replace(PKSO.OrderId,'S','I') as InvoiceNo,
		--case len(ltrim(isnull(InvoiceNo,''))) when '' then  replace(isnull(InvoiceNo,PKSO.OrderId),'S','I') else InvoiceNo end as InvoiceNo, 
		TotalAmount as InvoiceAmount,--isnull(InvoiceAmount,TotalAmount) as InvoiceAmount,
		isnull(PaymentAmount,0) as PaymentAmount, 
		Remarks, 
		isnull(Convert(varchar(10),PaymentDate,120),Convert(varchar(10),pkso.ShipDate,120)) as PaymentDate, 
		TotalAmount as Balance,--InvoiceAmount as Balance, --isnull(InvoiceAmount,TotalAmount)-isnull(PaymentAmount,0) as Balance,
		PKCustomerMultiAdd.CompanyName as CompanyName
		--,pkpayment.paymentdate
		--,pkpayment.InvoiceNo
		into #tbl1 
        From PKSO
        --Join PKSO 
		left outer join PKPayment on PKPayment.OrderID = PKSO.SOID 
        left outer Join PKCustomerMultiAdd on PKSO.CustomerID = PKCustomerMultiAdd.ID 
		where (
		--PaymentDate between cast(@innerStrFromDate as datetime) and cast(@innerStrToDate as datetime)  
		--or 
		(--paymentDate is null and
		@isPayOver = 0 and pkso.ShipDate between cast(@innerStrFromDate as datetime) and cast(@innerStrToDate as datetime) 
		) or
		@isPayOver = 1
		)
		and PKCustomerMultiAdd.ID = case @CustomerId when '' then PKCustomerMultiAdd.ID when '-1' then PKCustomerMultiAdd.ID else @CustomerId end 
		and PKSO.OrderId = case @InvoiceNo when '' then PKSO.OrderId when '-1' then PKSO.OrderId else replace(@InvoiceNo,'I','S') end 
		and  pkso.status = 'Shipped'
		--and Balance >= @balanceMin
		--and Balance <=@balanceMax

		--select * from #tbl1 where InvoiceNo like '%2339' order by InvoiceNo;

		select sum(PaymentAmount) as PaymentAmount,  InvoiceNo
		into #tbl2
		from #tbl1
		where aa not like 'SR%'
		group by InvoiceNo;
		
		--select * from #tbl2 where InvoiceNo like '%2339' order by InvoiceNo ---

		select max(paymentdate) as paymentDate, InvoiceNo 
		into #tbl3
		from #tbl1
		group by InvoiceNo
		;
		
		--select * from #tbl3 where InvoiceNo like '%2339' order by InvoiceNo

		select distinct Remarks, t1.InvoiceNo
		into #tbl5 
		from #tbl1 t1
		inner join #tbl3 t3 on t3.InvoiceNo = t1.InvoiceNo and t3.paymentDate = t1.PaymentDate

		--select max(Remarks) as remarks, InvoiceNo
		--into #tbl51
		--from #tbl5
		--group by InvoiceNo
		
		select #tbl1.remarks, #tbl1.InvoiceNo
		into #tbl51
		from #tbl1
		inner join #tbl3 t3 on t3.paymentDate = #tbl1.PaymentDate
		--group by #tbl1.InvoiceNo

		select distinct t1.Status,
		t1.invoiceNo,
		t1.InvoiceAmount,
		t2.PaymentAmount,
		'' as Remarks,
		t1.PaymentDate,
		t1.Balance,
		t1.CompanyName
		into #tbl4
		
		from #tbl3 t3
		left outer join #tbl1 t1 on t3.InvoiceNo = t1.InvoiceNo and t3.paymentDate = t1.PaymentDate
		left outer join #tbl2 t2 on t2.InvoiceNo = t1.InvoiceNo
		where 
		(
		(
		@isPayOver = 1 and t3.paymentDate between cast(@innerStrFromDate as datetime) and cast(@innerStrToDate as datetime) 
		) or
		@isPayOver = 0
		)
		;
		
		--select * from #tbl4  where InvoiceNo like '%2339'order by InvoiceNo;

		update #tbl4 set Balance = InvoiceAmount - PaymentAmount;

		--select * from #tbl4 where PaymentAmount < InvoiceAmount and InvoiceNo like '%2339';




		delete from #tbl4 where Balance < @balanceMin or Balance >@balanceMax;
		--select * from #tbl4
		--select * from #tbl5;

		select distinct t4.Status,
		t4.invoiceNo,
		t4.InvoiceAmount,
		t4.PaymentAmount,
		t5.Remarks,
		t4.PaymentDate,
		t4.Balance,
		t4.CompanyName

		into #tbl6
		
		from #tbl4 t4
		left outer join #tbl51 t5 on t4.InvoiceNo = t5.InvoiceNo;



	select @WholeInvoiceAmount = SUM(isnull(InvoiceAmount,0.0)), 
		   @WholePaymentAmount=SUM(isnull(PaymentAmount,0.0)),
		   @WholeBalance=SUM(isnull(Balance,0.0))
		from #tbl6;
	if @IsForReport = 1
	BEGIN
		Select InvoiceNo, 
		InvoiceAmount, 
		PaymentAmount, 
		Remarks, 
		PaymentDate as 'InvoiceDate', 
		Balance, 
		CompanyName as 'Customer'  
        From #tbl6 Order By InvoiceNo asc
                
	END
	ELSE
	BEGIN
		Select PaymentDate as 'Payment Date',CompanyName as 'Customer Name',InvoiceNo, 
		InvoiceAmount as 'Invoice Amount', 
		PaymentAmount as 'Payment Amount', Balance,
		Remarks   
        From #tbl6 Order By CompanyName asc
	END
    
	
	drop table #tbl1;	
	drop table #tbl2;
	drop table #tbl3;
	drop table #tbl4;
	drop table #tbl5;
	drop table #tbl51;
	drop table #tbl6;

select 	@WholeInvoiceAmount 
select 	@WholePaymentAmount 
select 	@WholeBalance		






END






GO
/****** Object:  StoredProcedure [dbo].[Pk_GetPKPOProductReport]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetPKPOProductReport]
	@LocationList [dbo].[PKPOProductTableType] READONLY,
	@VendorList [dbo].[PKPOProductTableType] READONLY,
	@Attribute1List [dbo].[PKPOProductTableType] READONLY,
	@Attribute2List [dbo].[PKPOProductTableType] READONLY
AS
BEGIN
	DECLARE @LocationCount INT
	DECLARE @VendorCount INT
	DECLARE @Attribute1Count INT
	DECLARE @Attribute2Count INT

	SELECT @LocationCount = COUNT(*) FROM @LocationList
	SELECT @VendorCount = COUNT(*) FROM @VendorList
	SELECT @Attribute1Count = COUNT(*) FROM @Attribute1List
	SELECT @Attribute2Count = COUNT(*) FROM @Attribute2List

	SELECT PKLocation.LocationID, PKLocation.LocationName, PKVendor.VendorID, PKVendor.CompanyName AS Vendor, PKProduct.ID AS ProductID, PKProduct.PLU AS PLU, 
	CASE WHEN COALESCE(PKProduct.Name2,'')='' THEN PKProduct.Name1 ELSE PKProduct.Name1 + ' / ' + PKProduct.Name2 END AS Name, PKProduct.Brand AS Brand,
	Cast(PKProduct.packl AS VARCHAR(10)) + 'X' + Cast(PKProduct.packm AS VARCHAR(10)) + 'X'+ Cast(PKProduct.packs AS VARCHAR(10)) AS Pack,
	PKProduct.packm * PKProduct.packl * PKProduct.packs AS Size, PKProduct.Attribute1, PKProduct.Attribute2,
	PKPrice.A AS Price, CONVERT(VARCHAR(10), p.OrderDate, 111) AS OrderDate FROM PKProduct 
	INNER JOIN (SELECT PKPOProduct.ProductID, PKPO.VendorID, PKPO.LocationID, MAX(PKPO.OrderDate) AS OrderDate FROM PKPO INNER JOIN PKPOProduct ON PKPOProduct.POID = PKPO.POID 
	WHERE PKPO.Status != 'Cancel' Group by PKPOProduct.ProductID, PKPO.VendorID, PKPO.LocationID) P ON P.ProductID = PKProduct.ID
	INNER JOIN PKVendor ON PKVendoR.VendorID = P.VendorID 
	INNER JOIN PKLocation ON P.LocationID = PKLocation.LocationID
	LEFT OUTER JOIN PKPrice ON PKProduct.ID = PKPrice.ProductID
	WHERE ((@LocationCount = 0) OR (@LocationCount != 0 AND PKLocation.LocationID IN (SELECT Value FROM @LocationList)))
			AND ((@VendorCount = 0) OR (@VendorCount != 0 AND PKVendor.VendorID IN (SELECT Value FROM @VendorList)))
			AND ((@Attribute1Count = 0) OR (@Attribute1Count != 0 AND PKProduct.Attribute1 IN (SELECT Text FROM @Attribute1List)))
			AND ((@Attribute2Count = 0) OR (@Attribute2Count != 0 AND PKProduct.Attribute2 IN (SELECT Text FROM @Attribute2List)))
	ORDER BY Vendor, Attribute1, Attribute2, Name1
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetPKStockDepartmentCategory]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_GetPKStockDepartmentCategory]
		@StockTakeID varchar(50),
		@CDType varchar(1)
AS
BEGIN
	

	if LOWER(@CDType)='a'
	begin
		SELECT *  FROM PKStockDepartmentCategory
					where StockTakeId = @StockTakeID
	end
	else if LOWER(@CDType)='c'
	begin
		SELECT *  FROM PKStockDepartmentCategory
					where StockTakeId = @StockTakeID
					and lower(cdtype)='c' 
	end
	else if LOWER(@CDType)='d'
	begin
		SELECT *  FROM PKStockDepartmentCategory
					where StockTakeId = @StockTakeID
					and lower(cdtype)='d' 
	end
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetPKStockProducts]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetPKStockProducts]
	@StockTakeId varchar(50),
	@DataType varchar(50)
AS
BEGIN
	if LOWER(@DataType) = 'diff'
		begin
			SELECT 
				P.Barcode,---------------------------0 column
				P.Name1 as Name,---------------------------1 column
				P.Unit,---------------------------2 column
				pd.Name as Department,---------------------------3 column
				pc.Name as Category,---------------------------4 column
				P.PLU,---------------------------5 column
				PS.InvCaptureQty as ComputerQty,---------------------------6 column
				PKPrice.A as Price,---------------------------7 column
				'' as Qty---------------------------8 column
				--********************************************************************
				--******* The order of QTY here is very IMPORTANT!!!!
				--******* It should be the same order with the qty in importing data.
				--********************************************************************
			FROM PKStockTakeProduct PS
			inner join PKProduct P on P.id = PS.ProductID 
			inner join PKCategory pc on p.CategoryID = pc.id
			inner join PKDepartment pD on pc.DepartmentID = pd.ID
			inner join PKPrice on PKPrice.ProductID = P.id
	
			where ps.StockTakeID = @StockTakeId AND (isnull(PS.InvCaptureQty,0)<>isnull(PS.StockTakeQty,0))
			order by pd.Name, pc.Name, P.Name1;
			--********************************************************************
			--******* The order of QTY here is very IMPORTANT!!!!
			--******* It should be the same order with the order above!!!!!!
			--********************************************************************
			Select 8 as QtyColumn;
		end
	else
		begin
			SELECT 
				P.Barcode,---------------------------0 column
				P.Name1 as Name,---------------------------1 column
				P.Unit,---------------------------2 column
				pd.Name as Department,---------------------------3 column
				pc.Name as Category,---------------------------4 column
				P.PLU,---------------------------5 column
				PKPrice.A as Price,---------------------------6 column
				'' as Qty---------------------------7 column
				--********************************************************************
				--******* The order of QTY here is very IMPORTANT!!!!
				--******* It should be the same order with the qty in importing data.
				--********************************************************************
			FROM PKStockTakeProduct PS
			inner join PKProduct P on P.id = PS.ProductID 
			inner join PKCategory pc on p.CategoryID = pc.id
			inner join PKDepartment pD on pc.DepartmentID = pd.ID
			inner join PKPrice on PKPrice.ProductID = P.id
	
			where ps.StockTakeID = @StockTakeId
			order by pd.Name, pc.Name, P.Name1;
			--********************************************************************
			--******* The order of QTY here is very IMPORTANT!!!!
			--******* It should be the same order with the order above!!!!!!
			--********************************************************************
			Select 7 as QtyColumn;
		end
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetPKStockProductsByLocationCategoryID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetPKStockProductsByLocationCategoryID]
	@LocationID varchar(50),
	@CategoryList [dbo].[PKCategoryTableType] READONLY,
	@IsZeroInclude varchar(50)
AS
BEGIN
	IF LOWER(@IsZeroInclude) = 'yes'
		BEGIN
			SELECT 
				PKProduct.Barcode,---------------------------0 column
				PKProduct.Name1 as Name,---------------------------1 column
				PKProduct.Unit,---------------------------2 column
				pd.Name as Department,---------------------------3 column
				pc.Name as Category,---------------------------4 column
				PKProduct.PLU,---------------------------5 column
				PKPrice.A as Price,---------------------------6 column
				'' as Qty---------------------------7 column
			FROM PKInventory
			inner join PKProduct on PKInventory.ProductID = PKProduct.ID
			inner join PKCategory pc on PKProduct.CategoryID = pc.id
			inner join PKDepartment pD on pc.DepartmentID = pd.ID
			inner join PKPrice on PKPrice.ProductID = PKProduct.ID
			where PKInventory.LocationID = @LocationID and pkproduct.Status='Active' and PKProduct.CategoryID in (SELECT CategoryID FROM @CategoryList)
			order by pd.Name, pc.Name, PKProduct.Name1;
		END
	ELSE
		BEGIN
			SELECT 
				PKProduct.Barcode,---------------------------0 column
				PKProduct.Name1 as Name,---------------------------1 column
				PKProduct.Unit,---------------------------2 column
				pd.Name as Department,---------------------------3 column
				pc.Name as Category,---------------------------4 column
				PKProduct.PLU,---------------------------5 column
				PKPrice.A as Price,---------------------------6 column
				'' as Qty---------------------------7 column
			FROM PKInventory
			inner join PKProduct on PKInventory.ProductID = PKProduct.ID
			inner join PKCategory pc on PKProduct.CategoryID = pc.id
			inner join PKDepartment pD on pc.DepartmentID = pd.ID
			inner join PKPrice on PKPrice.ProductID = PKProduct.ID
			where PKInventory.LocationID = @LocationID and pkproduct.Status='Active' and PKProduct.CategoryID in (SELECT CategoryID FROM @CategoryList) and PKInventory.Qty != 0
			order by pd.Name, pc.Name, PKProduct.Name1;
		END
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetPKStockProductsDifferenceFirst]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetPKStockProductsDifferenceFirst]
	@StockTakeId varchar(50),
	@compareType int
AS
BEGIN
	SELECT ID
      ,StockTakeID
      ,InventoryID
      ,ProductID
      ,InvCaptureQty
      ,InvLastUpdateTime
      ,InvCaptureBy
      ,InvCaptureTime
      ,StockTakeQty
      ,StockTakeBy
      ,StockTakeTime
      ,StockTakeSeq
      ,ConfirmQty
      ,ConfirmBy
      ,ConfirmTime
      ,Remarks
      ,Barcode
      ,StockTakeQty2
      ,StockTakeBy2
      ,StockTakeTime2
      ,ConfirmQty2
      ,ConfirmBy2
      ,ConfirmFinal
	  ,abs(StockTakeQty - InvCaptureQty) as FirstDifference
	  ,abs(StockTakeQty2 - InvCaptureQty) as SecondDifference
	  into #tbl1 

	  FROM PKStockTakeProduct
	  where StockTakeID = @StockTakeId


	  if @compareType = 1
	   begin
		SELECT 
			p.Barcode,
			REPLACE(Name1,'''','`') + 
				case 
					when isnull(p.Name2,'') = '' then ''
					else '[' + REPLACE(p.Name2,'''','`') + ']' 
				end  as Name,
			ps.InvCaptureQty as CurrentQty,
			ps.StockTakeQty as firstQty,
			ps.StockTakeQty2 as secondQty,
			p.Unit,
			ps.FirstDifference,
			Ps.SecondDifference
		FROM #tbl1 PS
		inner join PKProduct P on P.id = PS.ProductID 
		where ps.FirstDifference <> 0
		order by ps.FirstDifference desc
	  end
	else if @compareType = 2
	   begin
		SELECT 
			p.Barcode,
			REPLACE(Name1,'''','`') + 
				case 
					when isnull(p.Name2,'') = '' then ''
					else '[' + REPLACE(p.Name2,'''','`') + ']' 
				end  as Name,
			ps.InvCaptureQty as CurrentQty,
			ps.StockTakeQty as firstQty,
			ps.StockTakeQty2 as secondQty,
			p.Unit,
			ps.FirstDifference,
			Ps.SecondDifference
		FROM #tbl1 PS
		inner join PKProduct P on P.id = PS.ProductID 
		where ps.SecondDifference <> 0
		order by ps.SecondDifference desc
	  end
	else if @compareType = 0
	   begin
		SELECT 
			p.Barcode,
			REPLACE(Name1,'''','`') + 
				case 
					when isnull(p.Name2,'') = '' then ''
					else '[' + REPLACE(p.Name2,'''','`') + ']' 
				end  as Name,
			ps.InvCaptureQty as CurrentQty,
			ps.StockTakeQty as firstQty,
			ps.StockTakeQty2 as secondQty,
			p.Unit,
			ps.FirstDifference,
			Ps.SecondDifference
		FROM #tbl1 PS
		inner join PKProduct P on P.id = PS.ProductID 
		where ps.FirstDifference <> 0 or ps.SecondDifference <> 0
		order by ps.FirstDifference desc
	  end

	drop table #tbl1;
END



GO
/****** Object:  StoredProcedure [dbo].[Pk_GetPKStocktakeReport]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Pk_GetPKStocktakeReport] @LocationId   VARCHAR(50), 
                                         @DepartmentID VARCHAR(50), 
                                         @CategoryId   VARCHAR(50), 
                                         @PLUBarcode   VARCHAR(50), 
                                         @TimeFrom     VARCHAR(50), 
                                         @TimeTo       VARCHAR(50),
										 @StockTakeId  Varchar(50),
										 @stocktakeQtyNoZero varchar(50)
AS 
  BEGIN 
      SET nocount ON; 


	  IF @LocationId = 'All Location' 
          OR @LocationId = '' 
        BEGIN 
            SET @LocationId = '-1' 
        END 
      IF @DepartmentID = 'All Department' 
          OR @DepartmentID = '' 
        BEGIN 
            SET @DepartmentID = '-1' 
        END 
      IF @CategoryId = 'All Category' 
          OR @CategoryId = '' 
        BEGIN 
            SET @CategoryId = '-1' 
        END 

	  DECLARE @tempDecNumber DECIMAL(18, 4); 
      DECLARE @tempString NVARCHAR(100); 

      SET @tempString =  N'1234567891012345678910123456789101234567891012345678910' 
      ; 
      SET @tempString = @tempString + N'1234567891012345678910123456789101234567891012345678910'; 
      SET @tempDecNumber = 1000000.00; 

	SELECT Pd.name as departmentname, 
             pc.name as categoryname,
			 pc.plu + ' - ' + pc.name as categoryidname,
             --pkviewstocktakeproduct.id, 
             pstp.stocktakeid, 
             pstp.inventoryid, 
             pstp.productid, 
             invcaptureqty, 
             invlastupdatetime, 
             invcaptureby, 
             invcapturetime, 
             stocktakeqty, 
             stocktakeqty2, 
             InventoryNewQTYNow, 
             stocktakeby, 
             stocktaketime, 
             stocktakeseq, 
             confirmqty, 
             confirmby, 
             confirmtime, 
             PS.remarks, 
             PS.locationid, 
             PP.name1, 
             PP.name2, 
             PP.plu, 
             PP.barcode, 
             PP.description1, 
             PP.description2, 
             PP.unit as unitName, 
             PP.status, 
             cast(packs as varchar(50)) + 'x'+ cast(packl as varchar(50)) + 'x'+ cast(packm as varchar(50)) AS PackSize, 
             brand, 
             zoning, 
             pkprice.a AS Price, 
			 PS.CreateDate,
			 isnull(PKI.AverageCost,0) as averageCost,
			 Isnull(PKI.LatestCost, 0) as latestCost,
			  pkl.IsHeadquarter,
			 CONVERT(VARCHAR(10),PS.UpdateDate,110) as UpdateDate,
			 @tempDecNumber as capacity,
			 @tempString as isBaseProd,
			 @tempDecNumber as invcaptureqtyInBase,
			 @tempDecNumber as stocktakeqtyInBase,
			 @tempDecNumber as stocktakeqty2InBase,
			 @tempDecNumber as InventoryNewQTYNowInBase,
			 @tempDecNumber as confirmqtyInBase,
			 @tempString as baseProdID
	  into #tbloriginal
      FROM   PKStockTakeProduct pstp
			 inner join PKProduct PP on pstp.ProductID = pp.id
			 inner join pkCategory pC on pp.CategoryID = pc.ID
			 inner join PKDepartment pD on pc.DepartmentID = pd.ID

             JOIN pkprice 
               ON pstp.productid = pkprice.productid 
             JOIN pkstocktake PS
               ON pstp.stocktakeid = PS.id 
			 left outer join PKInventory PKI on pki.ProductID = pstp.ProductID 
			 left outer join PKLocation PKL on pkl.LocationID = pki.LocationID

     Where  PS.locationid = CASE @LocationId 
                                        WHEN '-1' THEN PS.locationid 
                                        ELSE @LocationId 
                                      END 
             AND pD.id = CASE @DepartmentID 
                            WHEN '-1' THEN pD.id 
                            ELSE @DepartmentID 
                          END 
             AND pC.id = CASE @CategoryId 
                            WHEN '-1' THEN pC.id 
                            ELSE @CategoryId 
                          END 
             AND ( (@TimeFrom ='' ) 
                    OR ( @TimeFrom <> '' 
                         AND PS.CreateDate >= @TimeFrom ) ) 
             AND ( ( @TimeTo = '' ) 
                    OR ( @TimeTo <> ''
                         AND PS.CreateDate <= @TimeTo ) ) 
             AND ( ( @PLUBarcode = '' ) 
                    OR ( @PLUBarcode <> '' 
                         AND ( PP.plu LIKE '%' + @PLUBarcode + '%' ) 
                          OR ( PP.barcode LIKE '%' + @PLUBarcode + '%' ) 
                       ) 
                 ) 
			 AND ( ( @StockTakeId = '' ) 
                    OR ( @StockTakeId <> ''
                         AND PS.ID = @StockTakeId ) ) 
			 and PS.StockTakeStatus='Completed'
			 and pkl.IsHeadquarter = '1'
			 and (@stocktakeQtyNoZero = '' or (@stocktakeQtyNoZero='true' and (isnull(pstp.StockTakeQty,0)<>0 or isnull(pstp.StockTakeQty2,0)<>0)))
	declare @isShowBaseOnly varchar(50);
	
	select @isShowBaseOnly = value from PKSetting where fieldName = 'ShowStockTakeInBaseProduct'; 
	set @isShowBaseOnly = isnull(@isShowBaseOnly,'');
	if lower(@isShowBaseOnly) = 'base'
	  begin

		update #tbloriginal 
		set capacity = 1, 
		isBaseProd = 'o', 
		invcaptureqtyInBase = invcaptureqty, 
		stocktakeqtyInBase = stocktakeqty, 
		stocktakeqty2InBase = stocktakeqty2, 
		InventoryNewQTYNowInBase = InventoryNewQTYNow, 
		confirmqtyInBase = confirmqty;

		update #tbloriginal set isBaseProd = 'n',baseProdID=BaseProductID from PKMapping where #tbloriginal.ProductID = PKMapping.ProductID; --For sub product, set his Base product id.
		update #tbloriginal set isBaseProd = 'y',baseProdID=#tbloriginal.ProductID  from PKMapping where #tbloriginal.ProductID = PKMapping.BaseProductID; -- For Base product, set his own prodcutid.
		
		select distinct 
			departmentname, 
             categoryname, 
			 categoryidname,
             stocktakeid, 
             inventoryid, 
             baseProdID as productid, 
             0 as invcaptureqty, 
             invlastupdatetime, 
             invcaptureby, 
             invcapturetime, 
             0 as stocktakeqty, 
             0 as stocktakeqty2, 
             0 as InventoryNewQTYNow, 
             stocktakeby, 
             stocktaketime, 
             stocktakeseq, 
             0 as confirmqty, 
             confirmby, 
             confirmtime, 
             remarks, 
             locationid, 
             name1, 
             name2, 
             plu, 
             barcode, 
             description1, 
             description2, 
             unitName, 
             status, 
             PackSize, 
             brand, 
             zoning, 
             Price, 
			 CreateDate,
			 averageCost,
			 latestCost,
			 IsHeadquarter,
			 UpdateDate,
			 1 as capacity,
			 'y' as isBaseProd,
			 0 as invcaptureqtyInBase,
			 0 as stocktakeqtyInBase,
			 0 as stocktakeqty2InBase,
			 0 as InventoryNewQTYNowInBase,
			 0 as confirmqtyInBase,
			 baseProdID
		 into #tblOriginalLostBaseProd
		 from #tbloriginal where isBaseProd = 'n' and not exists(select b.* from #tbloriginal b where b.ProductID = #tbloriginal.baseProdID);

		 insert into #tbloriginal select * from #tblOriginalLostBaseProd;

		BEGIN TRY
			update #tbloriginal set capacity = dbo.PK_FuncGetCapacityByProdID(productid);		
			update #tbloriginal set 
			invcaptureqtyInBase = capacity*invcaptureqty,
			stocktakeqtyInBase = capacity*stocktakeqty,
			stocktakeqty2InBase = capacity*stocktakeqty2,
			InventoryNewQTYNowInBase = capacity*InventoryNewQTYNow,
			confirmqtyInBase = capacity*confirmqty;		
		END TRY
		BEGIN CATCH
				print ERROR_MESSAGE() ;
		END CATCH

		select 
			sum(invcaptureqtyInBase) as invcaptureqtyInBase, 
			sum(stocktakeqtyInBase) as stocktakeqtyInBase, 
			sum(stocktakeqty2InBase) as stocktakeqty2InBase, 
			sum(InventoryNewQTYNowInBase) as InventoryNewQTYNowInBase, 
			sum(confirmqtyInBase) as confirmqtyInBase, 
		 baseProdID
		 into #tblBaseProQty
		 from #tbloriginal
		 group by baseProdId
		 ;
		delete from #tbloriginal where isBaseProd = 'n';

		update #tblOriginal set baseProdID = ProductID, isBaseProd = 'y' where isBaseProd = 'o'
		update #tbloriginal set 
			invcaptureqty = #tblBaseProQty.invcaptureqtyInBase ,
			stocktakeqty = #tblBaseProQty.stocktakeqtyInBase ,
			stocktakeqty2 = #tblBaseProQty.stocktakeqty2InBase ,
			InventoryNewQTYNow = #tblBaseProQty.InventoryNewQTYNowInBase ,
			confirmqty = #tblBaseProQty.confirmqtyInBase 
		from #tblBaseProQty 
		where #tblBaseProQty.baseProdID = #tbloriginal.baseProdID 
		;

		update #tbloriginal 
		set name1 = pp.Name1,
            name2 = PP.name2, 
            plu = PP.plu, 
            Barcode = PP.barcode, 
            Description1 = PP.description1, 
            Description2 = PP.description2, 
            unitname = PP.unit, 
            status = PP.status, 
            PackSize =  cast(packs as varchar(50)) + 'x'+ cast(packl as varchar(50)) + 'x'+ cast(packm as varchar(50)) 
		from PKProduct pp where pp.id = #tbloriginal.productId;

		drop table #tblBaseProQty;
		drop table #tblOriginalLostBaseProd;
	  end
	  select * from #tbloriginal ;
	  drop table #tbloriginal;
  END 



GO
/****** Object:  StoredProcedure [dbo].[PK_GetPOList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetPOList]
	@LocationID varchar(50),
	@PONO varchar(50),
	@POID varchar(50),
	@TimeFrom varchar(50),
	@TimeTo varchar(50),
	@Status varchar(50),
	@ProductName nvarchar(50),
	@PLU varchar(50),
	@Barcode varchar(50),
	@VendorID varchar(50),
	@VendorPhone varchar(50),
	@Remarks varchar(200)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	 SELECT DISTINCT pkpo.poid, 
					pkpo.locationid, 
					billinglocationid, 
					vendorid, 
					pkpo.orderid, 
					purchaseftitle AS VendorTitle, 
					filestartdate  AS StartDate, 
					orderdate, 
					arrivaldate, 
					poenddate, 
					orderby, 
					fileendby, 
					totaltax, 
					otherfees, 
					totalamount    AS POAmount, 
					currency,
					case LOWER(@Status) when 'draft' then PKPO.OrderDate
						when 'pending' then PKPO.OrderDate
						when 'complete' then PKPO.POEndDate
						when 'cancel' then PKPO.POEndDate
						else PKPO.OrderDate
					 end as OrderbyField
	FROM   pkpo 
		   INNER JOIN pkpoproduct PP 
				   ON pkpo.poid = pp.poid 
	where (@PONO='' or (@PONO<>'' and pkpo.OrderID like '%'+ @PONO +'%'))
	and (@POID='' or (@POID<>'' and pkpo.POID= @POID))
	and (@LocationID='' or (@LocationID<>'' and pkpo.LocationID= @LocationID))
	and (@TimeFrom='' or (@TimeFrom<>'' and pkpo.OrderDate>= @TimeFrom))
	and (@TimeTo='' or (@TimeTo<>'' and pkpo.OrderDate<= @TimeTo))
	and (@Status='' or (@Status<>'' and LOWER(pkpo.Status)= LOWER(@Status)))
	and (@ProductName='' or (@ProductName <>'' and pp.ProductName1+pp.ProductName2 like N'%' + @ProductName + '%'))
	and (@PLU='' or (@PLU<>'' and pp.PLU like '%'+ @PLU +'%'))
	and (@Barcode='' or (@Barcode<>'' and pp.Barcode like '%'+ @Barcode +'%'))
	and (@VendorID='' or (@VendorID<>'' and pkpo.VendorID= @VendorID))
	and (@VendorPhone='' or (@VendorPhone<>'' and pkpo.PurchaseFTEL= @VendorPhone))
	and (@Remarks='' or (@Remarks<>'' and PKPO.PORemarks like N'%'+ @Remarks +'%'))
	order by OrderbyField desc
			 

END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetPOListAllField]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetPOListAllField]
	@LocationID varchar(50),
	@PONO varchar(50),
	@POID varchar(50),
	@TimeFrom varchar(50),
	@TimeTo varchar(50),
	@Status varchar(50),
	@ProductName nvarchar(50),
	@PLU varchar(50),
	@Barcode varchar(50),
	@VendorID varchar(50),
	@VendorPhone varchar(50),
	@Remarks varchar(200)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	 SELECT DISTINCT pkpo.*, 
					purchaseftitle AS VendorTitle, 
					filestartdate  AS StartDate, 
					totalamount    AS POAmount,
					case LOWER(@Status) when 'draft' then PKPO.OrderDate
						when 'pending' then PKPO.OrderDate
						when 'complete' then PKPO.POEndDate
						when 'cancel' then PKPO.POEndDate
						else PKPO.OrderDate
					 end as OrderbyField
	FROM   pkpo 
		   INNER JOIN pkpoproduct PP 
				   ON pkpo.poid = pp.poid 
	where (@PONO='' or (@PONO<>'' and pkpo.OrderID like '%'+ @PONO +'%'))
	and (@POID='' or (@POID<>'' and pkpo.POID= @POID))
	and (@LocationID='' or (@LocationID<>'' and pkpo.LocationID= @LocationID))
	and (@TimeFrom='' or (@TimeFrom<>'' and pkpo.OrderDate>= @TimeFrom))
	and (@TimeTo='' or (@TimeTo<>'' and pkpo.OrderDate<= @TimeTo))
	and (@Status='' or (@Status<>'' and LOWER(pkpo.Status)= LOWER(@Status)))
	and (@ProductName='' or (@ProductName <>'' and pp.ProductName1+pp.ProductName2 like N'%' + @ProductName + '%'))
	and (@PLU='' or (@PLU<>'' and pp.PLU like '%'+ @PLU +'%'))
	and (@Barcode='' or (@Barcode<>'' and pp.Barcode like '%'+ @Barcode +'%'))
	and (@VendorID='' or (@VendorID<>'' and pkpo.VendorID= @VendorID))
	and (@VendorPhone='' or (@VendorPhone<>'' and pkpo.PurchaseFTEL= @VendorPhone))
	and (@Remarks='' or (@Remarks<>'' and PKPO.PORemarks like N'%'+ @Remarks +'%'))
	order by OrderbyField desc

END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetPOListHistory]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetPOListHistory]
	@LocationID varchar(50),
	@PONO varchar(50),
	@POID varchar(50),
	@TimeFrom varchar(50),
	@TimeTo varchar(50),
	@Status varchar(50),
	@ProductName nvarchar(50),
	@PLU varchar(50),
	@Barcode varchar(50),
	@VendorID varchar(50),
	@VendorPhone varchar(50),
	@Remarks varchar(200)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT pkpo.poid, 
                pkpo.locationid, 
                pkpo.billinglocationid, 
                pkpo.vendorid, 
                pkpo.orderid, 
                pkpo.purchaseftitle                               AS VendorTitle, 
                filestartdate 
                AS StartDate, 
                orderdate, 
                arrivaldate, 
                poenddate, 
                orderby, 
                fileendby, 
                PR.totaltax, 
                PR.otherfees, 
                PR.totalamount                                    AS POAmount, 
                pkpo.currency, 
                PR.totalamount - Isnull(Payment.paymentamount, 0) AS Paid ,
				case LOWER(@Status) when 'draft' then PKPO.OrderDate
					when 'pending' then PKPO.OrderDate
					when 'complete' then PKPO.POEndDate
					when 'cancel' then PKPO.POEndDate
					else PKPO.OrderDate
					end as OrderbyField
FROM   pkpo 
       LEFT JOIN (SELECT poid, 
                         Sum(totaltax)    AS TotalTax, 
                         Sum(otherfees)   AS OtherFees, 
                         Sum(totalamount) AS TotalAmount 
                  FROM   pkreceive 
                  WHERE  status = 'Received' 
                  GROUP  BY poid) AS PR 
              ON pkpo.poid = PR.poid 
       LEFT JOIN (SELECT orderid, 
                         Sum(paymentamount) AS PaymentAmount 
                  FROM   pkpayment 
                  GROUP  BY orderid) AS Payment 
              ON pkpo.poid = Payment.orderid 
       INNER JOIN pkpoproduct pp
               ON pkpo.poid = pp.poid 
	where (@PONO='' or (@PONO<>'' and pkpo.OrderID like '%'+ @PONO +'%'))
	and (@POID='' or (@POID<>'' and pkpo.POID= @POID))
	and (@LocationID='' or (@LocationID<>'' and pkpo.LocationID= @LocationID))
	and (@TimeFrom='' or (@TimeFrom<>'' and pkpo.OrderDate>= @TimeFrom))
	and (@TimeTo='' or (@TimeTo<>'' and pkpo.OrderDate<= @TimeTo))
	and (@Status='' or (@Status<>'' and LOWER(pkpo.Status)= LOWER(@Status)))
	and (@ProductName='' or (@ProductName <>'' and pp.ProductName1+pp.ProductName2 like N'%' + @ProductName + '%'))
	and (@PLU='' or (@PLU<>'' and pp.PLU like '%'+ @PLU +'%'))
	and (@Barcode='' or (@Barcode<>'' and pp.Barcode like '%'+ @Barcode +'%'))
	and (@VendorID='' or (@VendorID<>'' and pkpo.VendorID= @VendorID))
	and (@VendorPhone='' or (@VendorPhone<>'' and pkpo.PurchaseFTEL= @VendorPhone))
	and (@Remarks='' or (@Remarks<>'' and PKPO.PORemarks like N'%'+ @Remarks +'%'))
	order by OrderbyField desc

END


GO
/****** Object:  StoredProcedure [dbo].[Pk_GetPOSTransaction]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetPOSTransaction] @Location      VARCHAR(50), 
                                      @FromDateTime  VARCHAR(50), 
                                      @ToDateTime    VARCHAR(50), 
                                      @TransactionNo VARCHAR(50), 
                                      @Category      VARCHAR(50), 
                                      @Cashier       VARCHAR(50), 
                                      @CashierName   VARCHAR(50), 
                                      @DiscountType  VARCHAR(50) 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from 
      -- interfering with SELECT statements. 
      SET Nocount ON; 
	  declare @Location2      VARCHAR(50) 
      declare @FromDateTime2  VARCHAR(50) 
      declare @ToDateTime2    VARCHAR(50) 
      declare @TransactionNo2 VARCHAR(50) 
      declare @Category2      VARCHAR(50) 
      declare @Cashier2       VARCHAR(50) 
      declare @CashierName2   VARCHAR(50) 
      declare @DiscountType2  VARCHAR(50) 
	  set @Location2      = @Location      
      set @FromDateTime2  = @FromDateTime  
      set @ToDateTime2    = @ToDateTime    
      set @TransactionNo2 = @TransactionNo 
      set @Category2      = @Category      
      set @Cashier2       = @Cashier       
      set @CashierName2   = @CashierName   
      set @DiscountType2  = @DiscountType  
		

		BEGIN TRY
			DROP TABLE #tbloriginal; 
		END TRY
		BEGIN CATCH
		END CATCH

		BEGIN TRY
			DROP TABLE #tbltax; 
		END TRY
		BEGIN CATCH
		END CATCH

		BEGIN TRY
			DROP TABLE #tbltaxall; 
		END TRY
		BEGIN CATCH
		END CATCH

		BEGIN TRY
			DROP TABLE Testtransactionreport; 			
		END TRY
		BEGIN CATCH
		END CATCH




	  declare @tempDecNumber decimal(18,2);
	  declare @tempString varchar(50);
	  declare @tempDatetime smalldatetime;
	  set @tempString = '1234567891012345678910123456789101234567891012345678910';
	  set @tempDecNumber = 1000000.00;
	  set @tempDatetime  = getdate();
	  declare @s varchar(8000);
	  ---------------------------------------------------------
	  SELECT @tempString as Id, 
			@tempString as Storeid, 
			@tempString as Computername, 
			@tempString as Cashier, 
			@tempString as Transactionno, 
			@tempString as type, 
			@tempDecNumber as Subtotalamount, 
			@tempDecNumber as Subtotaldiscount, 
			@tempDecNumber as Totalamount, 
			@tempDatetime as Statusdatetime 
		into #tbloriginal;
		Delete from #tbloriginal;
	   ------------------------------------------------------------
	  if @Cashier2='' or LOWER(@Cashier2)='tour'
	  begin
		  insert into #tbloriginal
		  SELECT DISTINCT Postransaction.Id, 
						  Postransaction.Storeid, 
						  Postransaction.Computername, 
						  Postransaction.Cashier, 
						  Postransaction.Transactionno, 
						  '(' + Postransaction.Type + ')' AS type, 
						  Postransaction.Subtotalamount, 
						  Postransaction.Subtotaldiscount, 
						  Postransaction.Totalamount, 
						  Postransaction.Statusdatetime 
      
		  FROM   Postransaction 
		  WHERE 
			(@Location2='' or lower(@Location2)='all location' or (@Location2<>'' and Postransaction.StoreId = @Location2))
		    and (Postransaction.Status = 'Confirmed' ) 
			and (@FromDateTime2='' or (@FromDateTime2<>'' and Statusdatetime >= @FromDateTime2 ))
			and (@ToDateTime2='' or (@ToDateTime2<>'' and Statusdatetime <= @ToDateTime2 ))
			and (@TransactionNo2='' or (@TransactionNo2<>'' and TransactionNO like '%'+ @TransactionNo2 +'%'))
			and (@DiscountType2<>'dollardiscount' or (lower(@DiscountType2)='dollardiscount' and DollarDiscount <> 0 ))

		  ORDER  BY Postransaction.Transactionno ASC 
	  end
	  else
	  begin
	  print 2
		  insert into #tbloriginal
		  SELECT DISTINCT Postransaction.Id, 
						  Postransaction.Storeid, 
						  Postransaction.Computername, 
						  Postransaction.Cashier, 
						  Postransaction.Transactionno, 
						  '(' + Postransaction.Type + ')' AS type, 
						  Postransaction.Subtotalamount, 
						  Postransaction.Subtotaldiscount, 
						  Postransaction.Totalamount, 
						  Postransaction.Statusdatetime 
      
		  FROM    (select * from postransaction where Cashier=@Cashier2 AND ID not in (select transactionid from tourtransaction)) AS POSTransaction  
		  WHERE  	
			(@Location2='' or lower(@Location2)='all location' or (@Location2<>'' and Postransaction.StoreId = @Location2))
		    and (Postransaction.Status = 'Confirmed' ) 
			and (@FromDateTime2='' or (@FromDateTime2<>'' and Statusdatetime >= @FromDateTime2 ))
			and (@ToDateTime2='' or (@ToDateTime2<>'' and Statusdatetime <= @ToDateTime2 ))
			and (@TransactionNo2='' or (@TransactionNo2<>'' and TransactionNO like '%'+ @TransactionNo2 +'%'))
			and (@DiscountType2<>'dollardiscount' or (lower(@DiscountType2)='dollardiscount' and DollarDiscount <> 0 ))

	  end

	  

	  if @DiscountType2<>'-1'
	  begin
		if lower(@DiscountType2)='true'
		begin
			delete from #tbloriginal where not exists( SELECT TransactionID FROM TransactionItem WHERE PriceOverrideFlag ='True' AND Status='Confirmed' and TransactionID = #tbloriginal.Id) 
		end
		else
		begin
			delete from #tbloriginal where not exists( SELECT TransactionID FROM TransactionItem WHERE type=@DiscountType2 AND Status='Confirmed' and TransactionID = #tbloriginal.Id) 
		end
	  end

	  --------------------------------------------------------------------------------
	  ---- The following query is to work on the dynamic Tax.
	  --------------------------------------------------------------------------------
      SELECT b.* 
      INTO   #tbltax 
      FROM   #tbloriginal a 
             INNER JOIN Transactiontax b 
                     ON a.Id = b.Transactionid 

      SELECT Transactionid, 
             Taxname, 
             Taxamount 
      INTO   #tbltaxall 
      FROM   (SELECT Transactionid, 
                     Taxid, 
                     Taxname, 
                     Taxamount 
              FROM   (SELECT Transactionid, 
                             ''             AS TaxID, 
                             'Tax'  AS TaxName, 
                             Sum(Taxamount) AS TaxAmount 
                      FROM   #tbltax 
                      GROUP  BY Transactionid) a 
              UNION 
              SELECT Transactionid, 
                     Taxid, 
                     Taxname, 
                     Taxamount 
              FROM   #tbltax)b 

      DECLARE @TaxNames VARCHAR(200); 
      DECLARE @TaxNamesCast VARCHAR(200); 
      DECLARE @TaxNamesAfter VARCHAR(200); 
	  declare @TaxNamesForTable2nd varchar(200);

      DECLARE @sqlStr VARCHAR(Max); 
	  declare @tempTaxName varchar(200);
	  declare @tempIntPoint int;
	  declare @tempTaxFix varchar(200);

	  SET @TaxNamesCast = '';
	  SET @TaxNamesAfter = '';
	  SET @TaxNamesForTable2nd = '';
	  set @tempIntPoint = 1;
      SET @TaxNames = Substring((SELECT ',' + Taxname 
                                 FROM   (SELECT DISTINCT Taxname 
                                         FROM   #tbltaxall)a 
                                 ORDER  BY Taxname 
                                 FOR Xml Path, Type).value('.', 'varchar(max)'), 2, 100000) 
	  declare t_cursor cursor for 
		SELECT DISTINCT Taxname FROM   #tbltaxall ORDER BY taxname 
		open t_cursor
		fetch next from t_cursor into @tempTaxName
		while @@fetch_status = 0
		begin
			if @tempTaxName='Tax'
			begin
				set @TaxNamesCast = @TaxNamesCast + ',' + @tempTaxName ;
				set @TaxNamesAfter = @TaxNamesAfter + ',' + @tempTaxName ;
			end
			else
			begin
				set @TaxNamesCast = @TaxNamesCast + ',cast(isnull(' + @tempTaxName  + ',0) as varchar(50)) as Tax' + cast(@tempIntPoint as varchar(50)) ;
				set @TaxNamesAfter = @TaxNamesAfter + ',Tax' + cast(@tempIntPoint as varchar(50)) ;
				set @TaxNamesForTable2nd = @TaxNamesForTable2nd + ',''' + @tempTaxName  + ''' as Tax'+ cast(@tempIntPoint as varchar(50))  ;
				set @tempIntPoint = @tempIntPoint + 1;
			end
			fetch next from t_cursor into @tempTaxName
		end
		
		close t_cursor
		deallocate t_cursor


	  set @TaxNamesCast = substring(@TaxNamesCast,2,10000);
	  set @TaxNamesAfter = substring(@TaxNamesAfter,2,10000);
	  set @TaxNamesForTable2nd = substring(@TaxNamesForTable2nd,2,10000);

	  if @tempIntPoint = 1 
	  begin
		set @tempTaxFix = ','''' as tax1,'''' as tax2,'''' as tax3' ;
	  end
	  else if @tempIntPoint = 2 
	  begin
		set @tempTaxFix = ','''' as tax2,'''' as tax3' ;
	  end
	  else if @tempIntPoint = 3 
	  begin
		set @tempTaxFix = ','''' as tax3' ;
	  end     
	  else
	  begin
		set @tempTaxFix = ''
	  end
	  set @TaxNamesAfter = @TaxNamesAfter + @tempTaxFix;
		set @TaxNamesForTable2nd = @TaxNamesForTable2nd + @tempTaxFix;

      SET @sqlStr = 'select transactionId, ' + @TaxNamesCast 
                    + ' into testTransactionReport from #tblTaxAll pivot (sum(taxAmount) for taxname in(' 
                    + @TaxNames + ')) as abc' 
      EXEC(@sqlstr); 

      SET @sqlStr = 'select b.*,  ' + @TaxNamesAfter + '   from testTransactionReport a inner join #tbloriginal b on a.transactionId = b.id;'
      EXEC(@sqlstr); 

      set @sqlStr = 'select ' + @TaxNamesForTable2nd
	  exec(@sqlstr); 

		BEGIN TRY
			DROP TABLE #tbloriginal; 
			DROP TABLE #tbltax; 
			DROP TABLE #tbltaxall; 
			DROP TABLE Testtransactionreport; 			
		END TRY
		BEGIN CATCH

		END CATCH
  END 





GO
/****** Object:  StoredProcedure [dbo].[Pk_GetPOSTransactionItem]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetPOSTransactionItem] @Location      VARCHAR(50), 
                                      @FromDateTime  VARCHAR(50), 
                                      @ToDateTime    VARCHAR(50), 
                                      @TransactionNo VARCHAR(50), 
                                      @Category      VARCHAR(50), 
                                      @Cashier       VARCHAR(50), 
                                      @CashierName   VARCHAR(50), 
                                      @DiscountType  VARCHAR(50) 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from 
      -- interfering with SELECT statements. 
      SET Nocount ON; 
	  declare @Location2      VARCHAR(50) 
      declare @FromDateTime2  VARCHAR(50) 
      declare @ToDateTime2    VARCHAR(50) 
      declare @TransactionNo2 VARCHAR(50) 
      declare @Category2      VARCHAR(50) 
      declare @Cashier2       VARCHAR(50) 
      declare @CashierName2   VARCHAR(50) 
      declare @DiscountType2  VARCHAR(50) 
	  set @Location2      = @Location      
      set @FromDateTime2  = @FromDateTime  
      set @ToDateTime2    = @ToDateTime    
      set @TransactionNo2 = @TransactionNo 
      set @Category2      = @Category      
      set @Cashier2       = @Cashier       
      set @CashierName2   = @CashierName   
      set @DiscountType2  = @DiscountType  
		

		BEGIN TRY
			DROP TABLE #tbloriginal; 
			print 1;
		END TRY
		BEGIN CATCH
		END CATCH

		BEGIN TRY
			DROP TABLE #tbltax; 
			print 2;
		END TRY
		BEGIN CATCH
		END CATCH

		BEGIN TRY
			DROP TABLE #tbltaxall; 
			print 3;
		END TRY
		BEGIN CATCH
		END CATCH

		BEGIN TRY
			DROP TABLE TesttransactionItemReport; 	
			print 4;		
		END TRY
		BEGIN CATCH
		END CATCH

		BEGIN TRY
			exec('select * from  TesttransactionItemReport'); 	
			print 5;		
		END TRY
		BEGIN CATCH
		END CATCH
		

		--BEGIN TRY
		--	DROP TABLE #tbloriginal; 
		--END TRY
		--BEGIN CATCH
		--END CATCH

		--BEGIN TRY
		--	DROP TABLE #tbltax; 
		--END TRY
		--BEGIN CATCH
		--END CATCH

		--BEGIN TRY
		--	DROP TABLE #tbltaxall; 
		--END TRY
		--BEGIN CATCH
		--END CATCH

		--BEGIN TRY
		--	DROP TABLE TesttransactionItemReport; 			
		--END TRY
		--BEGIN CATCH
		--END CATCH


	  declare @tempDecNumber decimal(18,2);
	  declare @tempString varchar(50);
	  declare @tempDatetime smalldatetime;
	  set @tempString = '1234567891012345678910123456789101234567891012345678910';
	  set @tempDecNumber = 1000000.00;
	  set @tempDatetime  = getdate();
	  declare @s varchar(8000);
	  ---------------------------------------------------------
	  SELECT @tempString as Id, 
			@tempString as transactionId, 
			@tempString as name1, 
			@tempDecNumber as QTy, 
			@tempDecNumber as ItemSubTotal
		into #tbloriginal;
		Delete from #tbloriginal;
	   ------------------------------------------------------------
	  if @Cashier2='' or LOWER(@Cashier2)='tour'
	  begin
		  insert into #tbloriginal
		  SELECT DISTINCT TI.Id, 
		  TI.TransactionID,
		  TI.Name1,
		  TI.Qty,
		  TI.ItemSubTotal      
		  FROM   transactionitem TI
		  inner join POSTransaction PT on ti.TransactionID = pt.ID
		  WHERE 
		   (@Location2='' or lower(@Location2)='all location' or (@Location2<>'' and pt.StoreId = @Location2))
			and TI.Status='Confirmed' 
			--and TI.Type = 'Item'
			and (@FromDateTime2='' or (@FromDateTime2<>'' and TI.StatusDateTime >= @FromDateTime2 ))
			and (@ToDateTime2='' or (@ToDateTime2<>'' and TI.StatusDateTime <= @ToDateTime2 ))
			and (@TransactionNo2='' or (@TransactionNo2<>'' and PT.TransactionNO like '%'+ @TransactionNo2 +'%'))
			and (@DiscountType2<>'dollardiscount' or (lower(@DiscountType2)='dollardiscount' and pt.DollarDiscount <> 0 ))

	  end
	  else
	  begin
		insert into #tbloriginal
		  SELECT DISTINCT TI.Id, 
		  TI.TransactionID,
		  TI.Name1,
		  TI.Qty,
		  TI.ItemSubTotal      
		  FROM   transactionitem TI
		  inner join (select * from postransaction where Cashier=@Cashier2 AND ID not in (select transactionid from tourtransaction)) AS PT on ti.TransactionID = pt.ID
		  WHERE 
		   (@Location2='' or lower(@Location2)='all location' or (@Location2<>'' and pt.StoreId = @Location2))
			and TI.Status='Confirmed' 
			--and TI.Type = 'Item'
			and (@FromDateTime2='' or (@FromDateTime2<>'' and TI.StatusDateTime >= @FromDateTime2 ))
			and (@ToDateTime2='' or (@ToDateTime2<>'' and TI.StatusDateTime <= @ToDateTime2 ))
			and (@TransactionNo2='' or (@TransactionNo2<>'' and PT.TransactionNO like '%'+ @TransactionNo2 +'%'))
			and (@DiscountType2<>'dollardiscount' or (lower(@DiscountType2)='dollardiscount' and pt.DollarDiscount <> 0 ))
	  end



	  if @DiscountType2<>'-1'
	  begin
		if lower(@DiscountType2)='true'
		begin
			delete from #tbloriginal where not exists( SELECT TransactionID FROM TransactionItem WHERE PriceOverrideFlag ='True' AND Status='Confirmed' and TransactionID = #tbloriginal.transactionId) 
		end
		else
		begin
			delete from #tbloriginal where not exists( SELECT TransactionID FROM TransactionItem WHERE type=@DiscountType2 AND Status='Confirmed' and TransactionID = #tbloriginal.transactionId) 
		end
	  end
	  
	  --------------------------------------------------------------------------------
	  ---- The following query is to work on the dynamic Tax.
	  --------------------------------------------------------------------------------
      SELECT b.TransactionID
      ,b.TransactionItemID
      ,b.TaxID
      ,b.TaxName
      ,b.ItemTaxAmount
      ,b.Status

      INTO   #tbltax 
      FROM   #tbloriginal a 
             INNER JOIN TransactionItemTax b 
                     ON a.Id = b.TransactionItemID

	--select * from #tblTax;

 SELECT TransactionItemID, 
             Taxname, 
             Taxamount 
      INTO   #tbltaxall 
      FROM   (SELECT TransactionItemID, 
                     Taxid, 
                     Taxname, 
                     Taxamount 
              FROM   (SELECT TransactionItemID, 
                             ''             AS TaxID, 
                             'Tax'  AS TaxName, 
                             Sum(itemTaxAmount) AS TaxAmount 
                      FROM   #tbltax 
                      GROUP  BY TransactionItemID
					  ) a 
              UNION 
              SELECT TransactionItemID, 
                     Taxid, 
                     Taxname, 
                     itemTaxAmount as Taxamount 
              FROM   #tbltax)b 


      DECLARE @TaxNames VARCHAR(200); 
      DECLARE @TaxNamesCast VARCHAR(200); 
      DECLARE @TaxNamesAfter VARCHAR(200); 
	  declare @TaxNamesForTable2nd varchar(200);

      DECLARE @sqlStr VARCHAR(Max); 
	  declare @tempTaxName varchar(200);
	  declare @tempIntPoint int;
	  declare @tempTaxFix varchar(200);
	  declare @tempTaxFixCaption varchar(200);
	  SET @TaxNames = '';
	  SET @TaxNamesCast = '';
	  SET @TaxNamesAfter = '';
	  SET @TaxNamesForTable2nd = '';
	  set @tempIntPoint = 1;
      SET @TaxNames = Substring((SELECT ',' + Taxname 
                                 FROM   (SELECT DISTINCT Taxname 
                                         FROM   #tbltaxall)a 
                                 ORDER  BY Taxname 
                                 FOR Xml Path, Type).value('.', 'varchar(max)'), 2, 100000) 
	  declare t_cursor cursor for 
		SELECT DISTINCT Taxname FROM   #tbltaxall ORDER BY taxname 
		open t_cursor
		fetch next from t_cursor into @tempTaxName
		while @@fetch_status = 0
		begin

			if @tempTaxName='Tax'
			begin
				set @TaxNamesCast = @TaxNamesCast + ',' + @tempTaxName ;
				set @TaxNamesAfter = @TaxNamesAfter + ', isnull(' + @tempTaxName +',0) as ' + @tempTaxName;
			end
			else
			begin
				set @TaxNamesCast = @TaxNamesCast + ',cast(isnull(' + @tempTaxName  + ',0) as decimal(18,2))  as Tax' + cast(@tempIntPoint as varchar(50)) ;
				set @TaxNamesAfter = @TaxNamesAfter + ',isnull(Tax' + cast(@tempIntPoint as varchar(50)) + ',0) as Tax'+ cast(@tempIntPoint as varchar(50));
				set @TaxNamesForTable2nd = @TaxNamesForTable2nd + ',''' + @tempTaxName  + ''' as Tax'+ cast(@tempIntPoint as varchar(50))  ;
				set @tempIntPoint = @tempIntPoint + 1;
			end

			--print @TaxNames + '---' +  @TaxNamesCast+ '---' +  @TaxNamesAfter+ '---' + @TaxNamesForTable2nd 

			fetch next from t_cursor into @tempTaxName
		end
		
		close t_cursor
		deallocate t_cursor


	--select @TaxNames, @TaxNamesCast, @TaxNamesAfter,@TaxNamesForTable2nd 




	  set @TaxNamesCast = substring(@TaxNamesCast,2,10000);
	  set @TaxNamesAfter = substring(@TaxNamesAfter,2,10000);
	  set @TaxNamesForTable2nd = substring(@TaxNamesForTable2nd,2,10000);

	  if @tempIntPoint = 1 
	  begin
		set @tempTaxFix = ',0 as tax1,0 as tax2,0 as tax3' ;
		set @tempTaxFixCaption = ','' '' as tax1,'' '' as tax2,'' '' as tax3' ;
	  end
	  else if @tempIntPoint = 2 
	  begin
		set @tempTaxFix = ',0 as tax2,0 as tax3' ;
		set @tempTaxFixCaption = ','' '' as tax2,'' '' as tax3' ;
	  end
	  else if @tempIntPoint = 3 
	  begin
		set @tempTaxFix = ',0 as tax3' ;
		set @tempTaxFixCaption = ','' '' as tax3' ;
	  end     
	  else
	  begin
		set @tempTaxFix = ''
		set @tempTaxFixCaption = ''
	  end
	  set @TaxNamesAfter = @TaxNamesAfter + @tempTaxFix;
	  set @TaxNamesForTable2nd = @TaxNamesForTable2nd + @tempTaxFixCaption;

	  --select @TaxNames, @TaxNamesCast, @TaxNamesAfter,@TaxNamesForTable2nd 


      SET @sqlStr = 'select TransactionItemID, ' + @TaxNamesCast 
                    + ' into TesttransactionItemReport from #tblTaxAll pivot (sum(taxAmount) for taxname in(' 
                    + @TaxNames + ')) as abc' 
	  --select @sqlStr
      EXEC(@sqlstr); 
	  --print @sqlstr;



      SET @sqlStr = 'select b.*,  ' + @TaxNamesAfter + '   from #tbloriginal b left outer join TesttransactionItemReport a on a.TransactionItemID = b.id;'
      EXEC(@sqlstr); 
	  --print @sqlstr;
	  --print 2;


      set @sqlStr = 'select ' + @TaxNamesForTable2nd
	  exec(@sqlstr); 
	  --print @sqlstr;
	  --print 3;

     DROP TABLE #tbloriginal; 
     DROP TABLE #tbltax; 
     DROP TABLE #tbltaxall; 
     DROP TABLE TesttransactionItemReport; 

  END 





GO
/****** Object:  StoredProcedure [dbo].[PK_GetPOSTransactionSingleDetail]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetPOSTransactionSingleDetail]
	@transactionId varchar(50)
AS
BEGIN
	declare @GST decimal(18,2)
	declare @PST decimal(18,2);


	select TaxName, cast(sum(ItemTaxAmount) as decimal(18,2)) as ItemTaxAmount
	from TransactionItemTax 
	where transactionId = @transactionId
	group by TaxName


	--select @GST = cast(sum(CASE when c.TaxName='GST' then c.ItemTaxAmount END) as decimal(18,2))
	--	from dbo.POSTransaction a 
	--	left join dbo.TransactionItemTax c on a.ID=c.TransactionID
	--	where a.ID =  @transactionId

	--select @PST = cast(sum(CASE when c.TaxName='PST' THEN c.ItemTaxAmount END) as decimal(18,2))
	--	from dbo.POSTransaction a 
	--	left join dbo.TransactionItemTax c on a.ID=c.TransactionID
	--	where a.ID =  @transactionId


	SELECT a.ID
      ,a.StoreID
      ,a.StoreName
      ,a.ComputerName
      ,a.Cashier
      ,a.TransactionNo
      ,a.Type
      ,cast(a.TotalItemCount as decimal(18,2)) as TotalItemCount
      ,cast(a.ItemTotalCost as decimal(18,2)) as ItemTotalCost
      ,cast(a.ItemDiscountTotalAmount as decimal(18,2)) as ItemDiscountTotalAmount
      ,cast(a.SubTotalAmount as decimal(18,2)) as SubTotalAmount
      ,cast(a.SubTotalDiscount as decimal(18,2)) as SubTotalDiscount
      ,cast(a.DollarDiscount as decimal(18,2)) as DollarDiscount
      ,cast(a.AllTaxTotalAmount as decimal(18,2)) as AllTaxTotalAmount
      ,cast(a.TotalAmount as decimal(18,2)) as TotalAmount
      ,a.Status
      ,a.StatusDateTime
      ,a.ReferenceTransactionNo
	  --,isnull(@GST,0) as Gst
	  --,isnull(@PST,0) as pst
  FROM POSTransaction a
  where a.id = @transactionId

END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetPriceByCategoryID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[PK_GetPriceByCategoryID]
(
    @LocationID NVARCHAR(50),
       @CategoryID NVARCHAR(50)
)
AS
BEGIN 
       Select  name1, name2,p.id,pp.A as Price,pp.A as PriceA,pp.B as PriceB,pp.C as PriceC,pp.D as PriceD,pp.E as PriceE,Unit,
       (select top 1 Price from PkBookProductLocationPrice 
       where p.ID = PkBookProductLocationPrice.ProductID and PkBookProductLocationPrice.LocationID = @LocationID order by UpdateTime desc)as PriceF
       into #temp
       from pkproduct P left outer join PKPrice PP on pp.ProductID = p.ID  where p.CategoryID = @CategoryID and status ='Active' order by name1 

       Update #temp set Price = PriceF where PriceF is not null

       Select * from #temp
       drop table #temp
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetProductCapacityBySubProdId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetProductCapacityBySubProdId]
	@productId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @BaseProductId varchar(50);
	declare @count int;
	declare @Capacity decimal(18,4);
	
	select @count = count(*) from PKMapping where ProductID = @productId;

	if @count=0 
	begin
		select @count = count(*) from PKMapping where BaseProductID = @productId;
		if @count = 0 
		begin
			select 0 as Capacity;
		end
		else
		begin
			select 1 as Capacity;
		end
		return;
	end

	select  @BaseProductId = BaseProductID from PKMapping where ProductID = @productId;

	declare @BaseWeigh varchar(50);
	declare @BaseUnit varchar(50);
	declare @BaseNetWeight decimal(18,4);
	declare @BaseNetWeightUnit varchar(50);
	declare @BasePackL int;
	declare @BasePackM int;
	declare @BasePackS int;
	

	declare @ProductWeigh varchar(50);
	declare @ProductUnit varchar(50);
	declare @ProductNetWeight decimal(18,4);
	declare @ProductNetWeightUnit varchar(50);
	declare @ProductPackL int;
	declare @ProductPackM int;
	declare @ProductPackS int;


	select 
		@BaseWeigh =	isnull(Weigh,'N'),
		@BaseUnit =	Unit,
		@BaseNetWeight =	isnull(NetWeight,1),
		@BaseNetWeightUnit =	NetWeightUnit,
		@BasePackL = PackL,
		@BasePackM = PackM,
		@BasePackS = PackS
	from PKProduct where ID = @BaseProductId;

	select 
		@ProductWeigh =	isnull(Weigh,'N'),
		@ProductUnit =	Unit,
		@ProductNetWeight =	NetWeight,
		@ProductNetWeightUnit =	NetWeightUnit,
		@ProductPackL = PackL,
		@ProductPackM = PackM,
		@ProductPackS = PackS
	from PKProduct where ID = @productId;

	declare @BaseRate decimal(18,5);
	declare @ProductRate decimal(18,5);

	if @BaseNetWeight = 0
	begin
		set @BaseNetWeight = 1.00;
	end

	if lower(@BaseWeigh) = 'n'
	begin
		if lower(@BaseNetWeightUnit)='ea'
		begin
			declare @dbname varchar(50);
			SELECT @dbname = Db_name() ;
			print @dbname;

			if CHARINDEX('gibo',lower(@dbname))>0--  lower(SUBSTRING(@dbname,0,4))='gibo'
			begin
				if @ProductNetWeight = 0
				begin
					set @Capacity = @ProductPackL*@ProductPackM*@ProductPackS/(@BasePackL*@BasePackM*@BasePackS)
				end
				else
				begin
					set @Capacity = @ProductPackL*@ProductPackM*@ProductPackS*@ProductNetWeight/(@BasePackL*@BasePackM*@BasePackS)
				end
			end
			else
			begin
				set @Capacity = @ProductPackL*@ProductPackM*@ProductPackS/(@BasePackL*@BasePackM*@BasePackS)
			end
		end
		else
		begin
			if lower(@ProductWeigh) = 'n'
			begin
				select @BaseRate = Rate from PKUnitNames where unit = @BaseNetWeightUnit;
				select @ProductRate = Rate from PKUnitNames where unit = @ProductNetWeightUnit;
				set @BaseRate = isnull(@baseRate,1);
				set @ProductRate = isnull(@ProductRate,1);

				set @Capacity = @ProductNetWeight* @ProductRate/(@BaseRate*@BaseNetWeight);-- Logic: (@ProductNetWeight/@BaseNetWeight)* (@ProductRate/@BaseRate);
			end
			else
			begin
				select @BaseRate = Rate from PKUnitNames where unit = @BaseNetWeightUnit;
				select @ProductRate = Rate from PKUnitNames where unit = @ProductUnit;
				set @BaseRate = isnull(@baseRate,1);
				set @ProductRate = isnull(@ProductRate,1);
				set @Capacity = 1 * @ProductRate/(@BaseRate*@BaseNetWeight);-- Logic: (@ProductNetWeight/@BaseNetWeight)* (@ProductRate/@BaseRate);
			end
		end
	end
	else
	begin
		if lower(@ProductWeigh) = 'n'
		begin
			select @BaseRate = Rate from PKUnitNames where unit = @BaseUnit;
			select @ProductRate = Rate from PKUnitNames where unit = @ProductNetWeightUnit;
			set @BaseRate = isnull(@baseRate,1);
			set @ProductRate = isnull(@ProductRate,1);
			set @Capacity = @ProductNetWeight* @ProductRate/(@BaseRate*1);-- Logic: (@ProductNetWeight/@BaseNetWeight)* (@ProductRate/@BaseRate);
		end
		else
		begin
			select @BaseRate = Rate from PKUnitNames where unit = @BaseUnit;
			select @ProductRate = Rate from PKUnitNames where unit = @ProductUnit;
			set @BaseRate = isnull(@baseRate,1);
			set @ProductRate = isnull(@ProductRate,1);
			set @Capacity = 1* @ProductRate/(@BaseRate*1);-- Logic: (@ProductNetWeight/@BaseNetWeight)* (@ProductRate/@BaseRate);
		end
	end



	select @Capacity  as Capacity


END





GO
/****** Object:  StoredProcedure [dbo].[PK_GetProductColorList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetProductColorList]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	SELECT IDENTITY(Int, 1, 1) AS ID, Color INTO #tbl1 FROM PKProductColor ORDER BY ProductID
	SELECT * FROM #tbl1
	DROP TABLE #tbl1;
END

GO
/****** Object:  StoredProcedure [dbo].[Pk_GetProductFamilyByOneProductId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetProductFamilyByOneProductId]
	@ProductId varchar(50),
	@LocationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	select @ProductId as productId into #tbl1;
	
	---------------------------------------------------------------
	--If the product is baseProduct--------------------------------
	---------------------------------------------------------------
	insert into #tbl1
	select ProductID from PKMapping where BaseProductID = @ProductId;

	---------------------------------------------------------------
	--If the product is a child product--------------------------------
	---------------------------------------------------------------
	declare @BaseProductId varchar(50);
	select @BaseProductId = BaseProductID from PKMapping 
	where ProductID = @ProductId
	if len(isnull(@baseProductId, ''))>0
	begin
		insert into #tbl1 select @BaseProductId as productid;
		insert into #tbl1
		select ProductID from PKMapping 
		where BaseProductID = @BaseProductId 
		and not exists(select * from #tbl1 where #tbl1.productId = PKMapping.ProductID );
	end


	SELECT * 
FROM   (SELECT TOP 300 id, 
                       plu, 
                       barcode, 
                       Name1 = name1 +
                               + ' ' + 
                               CASE netweight WHEN 0 THEN '' ELSE ' ('+Cast( 
                               netweight 
                               AS VARCHAR(10))+ 
                               netweightunit+')' END, 
					   Cast(packl AS VARCHAR(10)) + 'X' 
					   + Cast(packm AS VARCHAR(10)) + 'X' 
					   + Cast(packs AS VARCHAR(10)) AS PackSize, 
					   packm * packl * packs          AS Size, 
					   CASE netweight 
						 WHEN 0.00 THEN '' 
						 ELSE 
						   CASE Isnull(netweightunit, '') 
							 WHEN '' THEN '' 
							 ELSE Cast(netweight AS VARCHAR(10)) 
								  + netweightunit 
						   END 
					   END                            AS NetWeight, 
                       unit, 
                       unitname, 
                       attribute1,
					   --po.qty, --isnull(qty,0) as qty,
					   PackageCapacity
        FROM   pkproduct 
        WHERE  ( status = 'active' ) 
               AND exists(select * from #tbl1 where #tbl1.productId = PKProduct.ID)) AS a 
       LEFT JOIN (SELECT productid AS invproductid, 
                         qty ,
						 averageCost,
						 LatestCost
                  FROM   pkinventory 
                  WHERE  ( pkinventory.locationid = @LocationId )) AS e 
              ON a.id = e.invproductid 
       LEFT JOIN (SELECT productid, 
                         Sum(Isnull(orderqty, 0)) AS QtyOnHold 
                  FROM   pkso 
                         INNER JOIN pksoproduct 
                                 ON pkso.soid = pksoproduct.soid 
                  WHERE  ( pkso.status = 'Pending' 
                            OR pkso.status = 'Back' ) 
                  GROUP  BY productid) AS SO 
              ON SO.productid = a.id 
       LEFT JOIN (SELECT pkpoproduct.productid, 
                         Sum(Isnull(pkpoproduct.orderqty, 0)) - Sum(Isnull( 
                         pkreceiveproduct.orderqty, 0)) 
                         AS QtyOnOrder 
                  FROM   pkpo 
                         INNER JOIN pkpoproduct 
                                 ON pkpo.poid = pkpoproduct.poid 
                         LEFT OUTER JOIN pkreceiveproduct 
                                      ON pkpoproduct.poproductid = 
                                         pkreceiveproduct.poproductid 
                  WHERE  pkpo.status = 'Pending' 
                  GROUP  BY pkpoproduct.productid) AS PO 
              ON PO.productid = a.id 
       LEFT OUTER JOIN pkprice 
                    ON a.id = pkprice.productid 


	drop table #tbl1;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetProductWithQtyStockHoldOrder]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetProductWithQtyStockHoldOrder]
@LocationID varchar(50),
@Extension varchar(50),
@CategoryID varchar(50),
@BarcodePLU varchar(50),
@Name nvarchar(50)
AS
BEGIN
SELECT pki.productid AS invproductid,sum(pki.qty) As qty 
	INTO #Inv
	FROM PKInventory pki
	inner join PKProduct p on p.id = pki.ProductID
	WHERE pki.LocationID=
	CASE WHEN @LocationID='-1' or @LocationID='' THEN LocationID ELSE @LocationID END
	and  p.Status = 'Active' --AND p.ID not in (SELECT ProductID FROM PKMapping)  
	AND  p.CategoryID= CASE WHEN @CategoryID = '-1' or @CategoryID = '' THEN p.CategoryID ELSE @CategoryID END
	AND
	(p.Barcode LIKE '%'+
		  case 
		   when @BarcodePLU= '' 
		   then p.Barcode
		   else
		   @BarcodePLU
		  end +'%'
	  or
	  p.PLU LIKE '%'+ 
		  case 
		   when @BarcodePLU= '' 
		   then p.PLU
		   else
		   @BarcodePLU
		  end +'%')
	  AND
	  (p.Name1 LIKE '%'+
		  case 
		   when @Name= '' 
		   then p.Name1
		   else
		   @Name
		  end +'%'
	  Or
	  p.Name2 LIKE '%'+
		  case 
		   when @Name= '' 
		   then p.Name2
		   else
		   @Name
		  end +'%')
	GROUP BY pki.ProductID
SELECT ProductID, SUM(ISNULL(OrderQty,0)) AS QtyOnHold 
	INTO #SO
	from PKSO 
		INNER JOIN PKSOProduct on PKSO.SOID = PKSOProduct.SOID 
		where (PKSO.Status= 'Pending'  or PKSO.Status= 'Back') 
		AND PKSO.LocationID=
	CASE WHEN @LocationID='-1' or @LocationID='' THEN PKSO.LocationID ELSE @LocationID END
		group by ProductID 
SELECT PKPOProduct.ProductID AS ProductID, SUM(ISNULL(PKReceiveProduct.OrderQty,0)) AS ReceiveOrderQty
	INTO #POReceive
	FROM PKPO 
		INNER JOIN PKPOProduct ON PKPO.POID=PKPOProduct.POID LEFT JOIN PKReceive ON PKPO.POID = PKReceive.POID
		LEFT OUTER JOIN PKReceiveProduct ON  (PKPOProduct.POProductID = PKReceiveProduct.POProductID AND PKReceiveProduct.ReceiveID = PKReceive.ID)
		WHERE PKPO.Status= 'Pending' AND  PKReceive.Status = 'Received'
		AND PKPO.LocationID=
	CASE WHEN @LocationID='-1' or @LocationID='' THEN PKPO.LocationID ELSE @LocationID END
		Group By PKPOProduct.ProductID
SELECT PKPOProduct.ProductID, SUM(ISNULL(PKPOProduct.OrderQty,0)) AS ProductOrderQty
	INTO #POProduct
	FROM PKPO 
		INNER JOIN PKPOProduct ON PKPO.POID=PKPOProduct.POID 
		WHERE PKPO.Status= 'Pending'  
		AND PKPO.LocationID=
	CASE WHEN @LocationID='-1' or @LocationID='' THEN PKPO.LocationID ELSE @LocationID END
	Group By PKPOProduct.ProductID
SELECT PP.ProductID, ISNULL(ProductOrderQty,0)-ISNULL(ReceiveOrderQty,0) AS QtyOnOrder
	INTO #PO
	FROM #POProduct AS PP LEFT OUTER JOIN #POReceive AS PR ON PP.ProductID= PR.ProductID 
SELECT ID, PLU,Barcode, Name1 = CASE @Extension WHEN 'Description1' THEN Name1+ case isnull(Description1,'') when '' then '' else ' - '+Description1+''end WHEN 'Brand' THEN Name1+ case isnull(Brand,'') when '' then '' else ' - '+Brand+'' end ELSE Name1 END+' '+cast(PackL AS varchar(10)) +'X'+
Cast(PackM AS varchar(10))+'X'+CAST(PackS as Varchar)+CASE NetWeight WHEN 0 THEN '' ELSE ' - '+CAST(NetWeight AS Varchar(10))+NetWeightUnit+' ' END,
Unit,UnitName, Attribute1 
	INTO #P
	FROM PKProduct 
		WHERE Status = 'Active' AND --ID not in (SELECT ProductID FROM PKMapping)  AND  
		CategoryID= CASE WHEN @CategoryID = '-1' or @CategoryID = '' THEN CategoryID ELSE @CategoryID END
		AND
		(Barcode LIKE '%'+
		  case 
		   when @BarcodePLU= '' 
		   then Barcode
		   else
		   @BarcodePLU
		  end +'%'
		  or
		  PLU LIKE '%'+ 
		  case 
		   when @BarcodePLU= '' 
		   then PLU
		   else
		   @BarcodePLU
		  end +'%')
		  AND
		  (Name1 LIKE '%'+
		  case 
		   when @Name= '' 
		   then Name1
		   else
		   @Name
		  end +'%'
		  Or
		  Name2 LIKE '%'+
		  case 
		   when @Name= '' 
		   then Name2
		   else
		   @Name
		  end +'%')
select * 
	from #P 
		left join 	#Inv on #P.ID=#Inv.invproductid 
		LEFT JOIN #SO on #SO.ProductID = #P.ID  
		LEFT JOIN #PO on #PO.ProductID= #P.ID 
		LEFT OUTER JOIN PKPrice ON #P.ID = PKPrice.ProductID 
	WHERE  Name1 IS NOT NULL
	ORDER BY Ltrim(Name1) 

drop table #P
drop table #Inv
drop table #SO
drop table #PO
drop table #POReceive
drop table #POProduct

END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetProductWithQtyStockHoldOrderForSO]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetProductWithQtyStockHoldOrderForSO] @LocationID VARCHAR(50), 
                                                                @Extension  VARCHAR(50), 
                                                                @CategoryID VARCHAR(50), 
                                                                @BarcodePLU VARCHAR(50), 
                                                                @Name       NVARCHAR(50), 
                                                                @hasPackSize VARCHAR(50) 
AS 
  BEGIN 
      --***** To get the setting to use Average cost or latest cost.------------------    
      --***** To get the setting to use Average cost or latest cost.------------------    
      DECLARE @averageCostOrLatestCost VARCHAR(2); 

      SELECT @averageCostOrLatestCost = Isnull(value, 'a') 
      FROM   pksetting 
      WHERE  fieldname = 'basePricebyAveOrlastPrice' 

      -- **********************************************************************************  
      SELECT pki.productid   AS invproductid, 
             Sum(pki.qty)    AS qty, 
             CASE @averageCostOrLatestCost 
               WHEN 'a' THEN averagecost 
               ELSE latestcost 
             END             AS AverageCost, 
             Isnull(pr.a, 0) AS MSRP 
      INTO   #inv 
      FROM   pkinventory pki 
             INNER JOIN pkproduct p 
                     ON p.id = pki.productid 
             LEFT JOIN pkprice Pr 
                    ON pr.productid = p.id 
      WHERE  pki.locationid = CASE 
                                WHEN @LocationID = '-1' 
                                      OR @LocationID = '' THEN locationid 
                                ELSE @LocationID 
                              END 
             AND p.status = 'Active' 
             AND p.categoryid = CASE 
                                  WHEN @CategoryID = '-1' 
                                        OR @CategoryID = '' THEN p.categoryid 
                                  ELSE @CategoryID 
                                END 
             AND ( p.barcode LIKE '%' + CASE WHEN @BarcodePLU= '' THEN p.barcode ELSE @BarcodePLU END + '%'
                    OR p.plu LIKE '%' + CASE WHEN @BarcodePLU= '' THEN p.plu ELSE @BarcodePLU END + '%' )
             AND ( p.name1 LIKE '%' + CASE WHEN @Name= '' THEN p.name1 ELSE @Name END + '%' 
                    OR p.name2 LIKE '%' + CASE WHEN @Name= '' THEN p.name2 ELSE @Name END + '%'
                    OR p.description1 LIKE '%' + CASE WHEN @Name= '' THEN p.description1 ELSE @Name END + '%' )
      GROUP  BY pki.productid, 
                averagecost, 
                latestcost, 
                pr.a 

      SELECT productid, 
             Sum(Isnull(orderqty, 0)) AS QtyOnHold 
      INTO   #so 
      FROM   pkso 
             INNER JOIN pksoproduct 
                     ON pkso.soid = pksoproduct.soid 
      WHERE  ( pkso.status = 'Pending' 
                OR pkso.status = 'Back' ) 
             AND pkso.locationid = CASE 
                                     WHEN @LocationID = '-1' 
                                           OR @LocationID = '' THEN pkso.locationid 
                                     ELSE @LocationID 
                                   END 
      GROUP  BY productid 

      SELECT pkpoproduct.productid                     AS ProductID, 
             Sum(Isnull(pkreceiveproduct.orderqty, 0)) AS ReceiveOrderQty 
      INTO   #poreceive 
      FROM   pkpo 
             INNER JOIN pkpoproduct 
                     ON pkpo.poid = pkpoproduct.poid 
             LEFT JOIN pkreceive 
                    ON pkpo.poid = pkreceive.poid 
             LEFT OUTER JOIN pkreceiveproduct 
                          ON ( pkpoproduct.poproductid = pkreceiveproduct.poproductid 
                               AND pkreceiveproduct.receiveid = pkreceive.id ) 
      WHERE  pkpo.status = 'Pending' 
             AND pkreceive.status = 'Post' 
             AND pkpo.locationid = CASE 
                                     WHEN @LocationID = '-1' 
                                           OR @LocationID = '' THEN pkpo.locationid 
                                     ELSE @LocationID 
                                   END 
      GROUP  BY pkpoproduct.productid 

      SELECT pkpoproduct.productid, 
             Sum(Isnull(pkpoproduct.orderqty, 0)) AS ProductOrderQty 
      INTO   #poproduct 
      FROM   pkpo 
             INNER JOIN pkpoproduct 
                     ON pkpo.poid = pkpoproduct.poid 
      WHERE  pkpo.status = 'Pending' 
             AND pkpo.locationid = CASE 
                                     WHEN @LocationID = '-1' 
                                           OR @LocationID = '' THEN pkpo.locationid 
                                     ELSE @LocationID 
                                   END 
      GROUP  BY pkpoproduct.productid 

      SELECT PP.productid, 
             Isnull(productorderqty, 0) - Isnull(receiveorderqty, 0) AS QtyOnOrder 
      INTO   #po 
      FROM   #poproduct AS PP 
             LEFT OUTER JOIN #poreceive AS PR 
                          ON PP.productid = PR.productid 

      SELECT id, 
             plu, 
             barcode, 
             Name1 = CASE @Extension WHEN 'Description1' THEN name1+ CASE Isnull( description1, '') WHEN '' THEN '' ELSE ' - '+description1+'' END WHEN 'Brand' THEN name1+ CASE Isnull(brand, '') WHEN '' THEN '' ELSE ' - '+brand+'' END ELSE name1 END
                     + 
                     ' ' 
                     + CASE  @hasPackSize WHEN '' THEN '' WHEN 'true' THEN Cast( packl AS VARCHAR(10)) + 'X' + Cast(packm AS VARCHAR(10)) + 'X' + Cast(packs AS VARCHAR) else '' END 
					 + CASE netweight WHEN 0 THEN '' ELSE ' - '+Cast (netweight AS VARCHAR(10))+ netweightunit +' ' END, 
             unit, 
             unitname, 
             attribute1 
      INTO   #p 
      FROM   pkproduct 
      WHERE  status = 'Active' 
             AND categoryid = CASE 
                                WHEN @CategoryID = '-1' 
                                      OR @CategoryID = '' THEN categoryid 
                                ELSE @CategoryID 
                              END 
             AND ( barcode LIKE '%' + CASE WHEN @BarcodePLU= '' THEN barcode ELSE @BarcodePLU END + '%'
                    OR plu LIKE '%' + CASE WHEN @BarcodePLU= '' THEN plu ELSE @BarcodePLU END + '%' )
             AND ( name1 LIKE '%' + CASE WHEN @Name= '' THEN name1 ELSE @Name END + '%' 
                    OR name2 LIKE '%' + CASE WHEN @Name= '' THEN name2 ELSE @Name END + '%' 
                    OR description1 LIKE '%' + CASE WHEN @Name= '' THEN description1 ELSE @Name END + '%' )

      SELECT * 
      FROM   #p 
             LEFT JOIN #inv 
                    ON #p.id = #inv.invproductid 
             LEFT JOIN #so 
                    ON #so.productid = #p.id 
             LEFT JOIN #po 
                    ON #po.productid = #p.id 
             LEFT OUTER JOIN pkprice 
                          ON #p.id = pkprice.productid 
      WHERE  name1 IS NOT NULL 
      ORDER  BY Ltrim(name1) 

      DROP TABLE #p 

      DROP TABLE #inv 

      DROP TABLE #so 

      DROP TABLE #po 

      DROP TABLE #poreceive 

      DROP TABLE #poproduct 
  END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetProductWithQtyStockHoldOrderForST]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetProductWithQtyStockHoldOrderForST] @LocationID VARCHAR(50), 
                                                                @Extension  VARCHAR(50), 
                                                                @CategoryID VARCHAR(50), 
                                                                @BarcodePLU VARCHAR(50), 
                                                                @Name       NVARCHAR(50), 
                                                                @hasPackSize VARCHAR(50) 
AS 
  BEGIN 
      --***** To get the setting to use Average cost or latest cost.------------------    
      --***** To get the setting to use Average cost or latest cost.------------------    
      DECLARE @averageCostOrLatestCost VARCHAR(2); 

      SELECT @averageCostOrLatestCost = Isnull(value, 'a') 
      FROM   pksetting 
      WHERE  fieldname = 'basePricebyAveOrlastPrice' 

      -- **********************************************************************************  
      SELECT pki.productid   AS invproductid, 
             Sum(pki.qty)    AS qty, 
             CASE @averageCostOrLatestCost 
               WHEN 'a' THEN averagecost 
               ELSE latestcost 
             END             AS AverageCost, 
             Isnull(pr.a, 0) AS MSRP 
      INTO   #inv 
      FROM   pkinventory pki 
             INNER JOIN pkproduct p 
                     ON p.id = pki.productid 
             LEFT JOIN pkprice Pr 
                    ON pr.productid = p.id 
      WHERE  pki.locationid = CASE 
                                WHEN @LocationID = '-1' 
                                      OR @LocationID = '' THEN locationid 
                                ELSE @LocationID 
                              END 
             AND p.status = 'Active' 
             AND p.categoryid = CASE 
                                  WHEN @CategoryID = '-1' 
                                        OR @CategoryID = '' THEN p.categoryid 
                                  ELSE @CategoryID 
                                END 
             AND ( p.barcode LIKE '%' + CASE WHEN @BarcodePLU= '' THEN p.barcode ELSE @BarcodePLU END + '%'
                    OR p.plu LIKE '%' + CASE WHEN @BarcodePLU= '' THEN p.plu ELSE @BarcodePLU END + '%' )
             AND ( p.name1 LIKE '%' + CASE WHEN @Name= '' THEN p.name1 ELSE @Name END + '%' 
                    OR p.name2 LIKE '%' + CASE WHEN @Name= '' THEN p.name2 ELSE @Name END + '%'
                    OR p.description1 LIKE '%' + CASE WHEN @Name= '' THEN p.description1 ELSE @Name END + '%' )
      GROUP  BY pki.productid, 
                averagecost, 
                latestcost, 
                pr.a 

      SELECT productid, 
             Sum(Isnull(orderqty, 0)) AS QtyOnHold 
      INTO   #so 
      FROM   pkso 
             INNER JOIN pksoproduct 
                     ON pkso.soid = pksoproduct.soid 
      WHERE  ( pkso.status = 'Pending' 
                OR pkso.status = 'Back' ) 
             AND pkso.locationid = CASE 
                                     WHEN @LocationID = '-1' 
                                           OR @LocationID = '' THEN pkso.locationid 
                                     ELSE @LocationID 
                                   END 
      GROUP  BY productid 

      SELECT pkpoproduct.productid                     AS ProductID, 
             Sum(Isnull(pkreceiveproduct.orderqty, 0)) AS ReceiveOrderQty 
      INTO   #poreceive 
      FROM   pkpo 
             INNER JOIN pkpoproduct 
                     ON pkpo.poid = pkpoproduct.poid 
             LEFT JOIN pkreceive 
                    ON pkpo.poid = pkreceive.poid 
             LEFT OUTER JOIN pkreceiveproduct 
                          ON ( pkpoproduct.poproductid = pkreceiveproduct.poproductid 
                               AND pkreceiveproduct.receiveid = pkreceive.id ) 
      WHERE  pkpo.status = 'Pending' 
             AND pkreceive.status = 'Post' 
             AND pkpo.locationid = CASE 
                                     WHEN @LocationID = '-1' 
                                           OR @LocationID = '' THEN pkpo.locationid 
                                     ELSE @LocationID 
                                   END 
      GROUP  BY pkpoproduct.productid 

      SELECT pkpoproduct.productid, 
             Sum(Isnull(pkpoproduct.orderqty, 0)) AS ProductOrderQty 
      INTO   #poproduct 
      FROM   pkpo 
             INNER JOIN pkpoproduct 
                     ON pkpo.poid = pkpoproduct.poid 
      WHERE  pkpo.status = 'Pending' 
             AND pkpo.locationid = CASE 
                                     WHEN @LocationID = '-1' 
                                           OR @LocationID = '' THEN pkpo.locationid 
                                     ELSE @LocationID 
                                   END 
      GROUP  BY pkpoproduct.productid 

      SELECT PP.productid, 
             Isnull(productorderqty, 0) - Isnull(receiveorderqty, 0) AS QtyOnOrder 
      INTO   #po 
      FROM   #poproduct AS PP 
             LEFT OUTER JOIN #poreceive AS PR 
                          ON PP.productid = PR.productid 

      SELECT id, 
             plu, 
             barcode, 
             Name1 = CASE @Extension WHEN 'Description1' THEN name1+ CASE Isnull( description1, '') WHEN '' THEN '' ELSE ' - '+description1+'' END WHEN 'Brand' THEN name1+ CASE Isnull(brand, '') WHEN '' THEN '' ELSE ' - '+brand+'' END ELSE name1 END
                     + 
                     ' ' 
                     + CASE  @hasPackSize WHEN '' THEN '' WHEN 'true' THEN Cast( packl AS VARCHAR(10)) + 'X' + Cast(packm AS VARCHAR(10)) + 'X' + Cast(packs AS VARCHAR) else '' END 
					 + CASE netweight WHEN 0 THEN '' ELSE ' - '+Cast (netweight AS VARCHAR(10))+ netweightunit +' ' END, 
             unit, 
             unitname, 
             attribute1 
      INTO   #p 
      FROM   pkproduct 
      WHERE  status = 'Active' 
             AND categoryid = CASE 
                                WHEN @CategoryID = '-1' 
                                      OR @CategoryID = '' THEN categoryid 
                                ELSE @CategoryID 
                              END 
             AND ( barcode LIKE '%' + CASE WHEN @BarcodePLU= '' THEN barcode ELSE @BarcodePLU END + '%'
                    OR plu LIKE '%' + CASE WHEN @BarcodePLU= '' THEN plu ELSE @BarcodePLU END + '%' )
             AND ( name1 LIKE '%' + CASE WHEN @Name= '' THEN name1 ELSE @Name END + '%' 
                    OR name2 LIKE '%' + CASE WHEN @Name= '' THEN name2 ELSE @Name END + '%' 
                    OR description1 LIKE '%' + CASE WHEN @Name= '' THEN description1 ELSE @Name END + '%' )

      SELECT * 
      FROM   #p 
             LEFT JOIN #inv 
                    ON #p.id = #inv.invproductid 
             LEFT JOIN #so 
                    ON #so.productid = #p.id 
             LEFT JOIN #po 
                    ON #po.productid = #p.id 
      WHERE  name1 IS NOT NULL 
      ORDER  BY Ltrim(name1) 

      DROP TABLE #p 

      DROP TABLE #inv 

      DROP TABLE #so 

      DROP TABLE #po 

      DROP TABLE #poreceive 

      DROP TABLE #poproduct 
  END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetPurchaseList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetPurchaseList]
	@locationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	SELECT PKPurchasePackageOrder.transferId, PKLocation.LocationName AS Location INTO #tbl1 FROM PKPurchasePackageOrder
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId
	------------------
	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl2 
	FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance
	------------------
	SELECT PKPurchasePackagePaymentItem.transferId 
	INTO #tbl3 
	FROM #tbl2 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)
	--------------------
	SELECT PKPrepaidPackageTransaction.ID AS ID, PKPrepaidPackageTransaction.CreateTime AS TimeDate, PKPrepaidPackageTransaction.CardNumber AS Card, 
	PKPrepaidPackageTransaction.CardHolders AS Customer, PKPrepaidPackageTransaction.Price, PKPrepaidPackageTransaction.Deposit, 'Prepaid' AS Type,
	PKPrepaidPackageTransaction.CreateBy, Location.Location FROM PKPrepaidPackageTransaction
	INNER JOIN PKPrepaidPackage ON PKPrepaidPackage.ID = PKPrepaidPackageTransaction.PrepaidPackageID
	INNER JOIN #tbl1 AS Location ON Location.transferId = PKPrepaidPackageTransaction.transferId
	INNER JOIN #tbl3 AS Payment ON payment.transferId = PKPrepaidPackageTransaction.transferId
	UNION
	(
		SELECT PKGiftCardTransaction.ID AS ID, PKGiftCardTransaction.CreateTime AS TimeDate, PKGiftCardTransaction.CardNumber AS Card, 
		PKGiftCardTransaction.CardHolders AS Customer, PKGiftCardTransaction.Price, PKGiftCardTransaction.Deposit, 'GiftCard' AS Type,
		PKGiftCardTransaction.CreateBy, Location.Location FROM PKGiftCardTransaction
		INNER JOIN PKGiftCard ON PKGiftCard.ID = PKGiftCardTransaction.GiftCardId
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKGiftCardTransaction.transferId
		INNER JOIN #tbl3 AS Payment ON payment.transferId = PKGiftCardTransaction.transferId
	)
	UNION
	(
		SELECT PKDepositPackageTransaction.ID AS ID, PKDepositPackageTransaction.CreateTime AS TimeDate, PKDepositPackageTransaction.CardNumber AS Card, 
		PKDepositPackageTransaction.CardHolders AS Customer, PKDepositPackageTransaction.Price, PKDepositPackageTransaction.Deposit, 'Deposit' AS Type,
		PKDepositPackageTransaction.CreateBy, Location.Location FROM PKDepositPackageTransaction
		INNER JOIN PKDepositPackage ON PKDepositPackage.ID = PKDepositPackageTransaction.PrepaidPackageID
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKDepositPackageTransaction.transferId
		INNER JOIN #tbl3 AS Payment ON payment.transferId = PKDepositPackageTransaction.transferId
		where PKDepositPackageTransaction.Status = 'Active'
	) ORDER BY TimeDate DESC, Customer, Card

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetPurchaseListNew]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetPurchaseListNew]
	@locationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	SELECT PKPurchasePackageOrder.transferId, PKLocation.LocationName AS Location INTO #tbl1 FROM PKPurchasePackageOrder
	LEFT join PKLocation ON PKLocation.LocationID = PKPurchasePackageOrder.Locationid
	WHERE PKLocation.LocationID like @locationId
	------------------
	SELECT PaymentOrderID, Balance, SUM(paymentAmount) AS paymentAmount 
	INTO #tbl2 
	FROM PKPurchasePackagePayment GROUP BY PaymentOrderID, Balance
	------------------
	SELECT PKPurchasePackagePaymentItem.transferId 
	INTO #tbl3 
	FROM #tbl2 as PaymentOrder 
	INNER JOIN PKPurchasePackagePaymentItem ON PKPurchasePackagePaymentItem.PaymentOrderID = PaymentOrder.PaymentOrderID
	WHERE (ISNULL(PaymentOrder.paymentAmount, 0) != 0) AND (PaymentOrder.Balance <= PaymentOrder.paymentAmount)
	--------------------
	SELECT PKPrepaidPackageTransaction.ID AS ID, PKPrepaidPackageTransaction.CreateTime AS TimeDate, PKPrepaidPackageTransaction.CardNumber AS Card, 
	PKPrepaidPackageTransaction.CardHolders AS Customer, PKPrepaidPackageTransaction.Price, PKPrepaidPackageTransaction.Deposit, PKPrepaidPackage.Name1 + ' ' + PKPrepaidPackage.Name2 AS Type,
	PKPrepaidPackageTransaction.CreateBy, Location.Location,PU.UserName as Sales, '' as SalesCommission,'' as CreateByCommission
	FROM PKPrepaidPackageTransaction
	INNER JOIN PKPrepaidPackage ON PKPrepaidPackage.ID = PKPrepaidPackageTransaction.PrepaidPackageID
	INNER JOIN #tbl1 AS Location ON Location.transferId = PKPrepaidPackageTransaction.transferId
	INNER JOIN #tbl3 AS Payment ON payment.transferId = PKPrepaidPackageTransaction.transferId
	left outer join PKUsers PU on pu.EmployeeID = PKPrepaidPackageTransaction.Sales
	UNION
	(
		SELECT PKGiftCardTransaction.ID AS ID, PKGiftCardTransaction.CreateTime AS TimeDate, PKGiftCardTransaction.CardNumber AS Card, 
		PKGiftCardTransaction.CardHolders AS Customer, PKGiftCardTransaction.Price, PKGiftCardTransaction.Deposit, PKGiftCard.Name1 + ' ' + PKGiftCard.Name2 AS Type,
		PKGiftCardTransaction.CreateBy, Location.Location ,PU.UserName as Sales, '' as SalesCommission,'' as CreateByCommission
		FROM PKGiftCardTransaction
		INNER JOIN PKGiftCard ON PKGiftCard.ID = PKGiftCardTransaction.GiftCardId
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKGiftCardTransaction.transferId
		INNER JOIN #tbl3 AS Payment ON payment.transferId = PKGiftCardTransaction.transferId
		left outer join PKUsers PU on pu.EmployeeID = PKGiftCardTransaction.Sales
	)
	UNION
	(
		SELECT PKDepositPackageTransaction.ID AS ID, PKDepositPackageTransaction.CreateTime AS TimeDate, PKDepositPackageTransaction.CardNumber AS Card, 
		PKDepositPackageTransaction.CardHolders AS Customer, PKDepositPackageTransaction.Price, PKDepositPackageTransaction.Deposit, PKDepositPackage.Name1 + ' ' + PKDepositPackage.Name2 AS Type,
		PKDepositPackageTransaction.CreateBy, Location.Location ,PU.UserName as Sales, '' as SalesCommission,'' as CreateByCommission
		FROM PKDepositPackageTransaction
		INNER JOIN PKDepositPackage ON PKDepositPackage.ID = PKDepositPackageTransaction.PrepaidPackageID
		INNER JOIN #tbl1 AS Location ON Location.transferId = PKDepositPackageTransaction.transferId
		INNER JOIN #tbl3 AS Payment ON payment.transferId = PKDepositPackageTransaction.transferId
		left outer join PKUsers PU on pu.EmployeeID = PKDepositPackageTransaction.Sales
		where PKDepositPackageTransaction.Status = 'Active'
	) ORDER BY TimeDate DESC, Customer, Card

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
END

GO
/****** Object:  StoredProcedure [dbo].[Pk_getrecurrentsplitsoproducts]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Pk_getrecurrentsplitsoproducts] @SOID VARCHAR(50) 
AS 
  BEGIN 
      SET nocount ON; 

      DECLARE @SOIDSecondTime VARCHAR(50); 

      SET @SOIDSecondTime = @SOID; 

      --Initialize 2 table.----------------------------------------------------- 
      SELECT soproductid, 
             locationid, 
             soid, 
             productid, 
             plu, 
             barcode, 
             productname1, 
             productname2, 
             pack, 
             size, 
             orderqty, 
             weigh, 
             unit, 
             unitcost, 
             discount, 
             markup, 
             taxmarkup, 
             totalcost, 
             soproductremarks, 
             shippingqty, 
             backqty, 
             seq, 
             serialnumbers, 
             referenceid, 
             type, 
             averagecost, 
             seqorder 
      INTO   #tableoriginal 
      FROM   pksoproduct 
      WHERE  soid = @SOIDSecondTime; 

      SELECT soproductid, 
             locationid, 
             soid, 
             productid, 
             plu, 
             barcode, 
             productname1, 
             productname2, 
             pack, 
             size, 
             orderqty, 
             weigh, 
             unit, 
             unitcost, 
             discount, 
             markup, 
             taxmarkup, 
             totalcost, 
             soproductremarks, 
             shippingqty, 
             backqty, 
             seq, 
             serialnumbers, 
             referenceid, 
             type, 
             averagecost, 
             seqorder 
      INTO   #tablecurrent 
      FROM   pksoproduct 
      WHERE  soid = @SOIDSecondTime; 

      --Initialize End.------------------------------------------------------------- 
      UPDATE #tablecurrent 
      SET    orderqty = 0; 

      ------------------------------------------------------------------------------- 
      UPDATE #tablecurrent 
      SET    orderqty = c.qty 
      FROM   #tablecurrent a 
             INNER JOIN pksocontractproduct c 
                     ON a.soproductid = c.soproductid 

      -------------------------------------------------------------------------------- 
      SELECT a.* 
      INTO   #tbl1 
      FROM   pksoproduct a 
             INNER JOIN pkso b 
                     ON a.soid = b.soid 
             INNER JOIN pksocontract c 
                     ON c.contractid = b.contractno 
                        AND c.soid = @SOIDSecondTime 
      -------------------------------------------------------------------------------- 

      SELECT productid, 
             Sum(orderqty) AS orderQty 
      INTO   #tablesold 
      FROM   #tbl1 
      GROUP  BY productid 

      --------------------------------------------------------------------------------- 
      SELECT a.soproductid, 
             a.productid, 
             a.orderqty, 
             b.orderqty AS soldQty, 
             c.orderqty AS currentQty 
	  into #tblFinal
      FROM   #tableoriginal a 
             left outer JOIN #tablesold b 
                     ON a.productid = b.productid 
             INNER JOIN #tablecurrent c 
                     ON a.soproductid = c.soproductid 
	  ------------------------------------------------------------------------------------
	  update #tblFinal set currentQty = OrderQty - soldQty where OrderQty - soldQty - currentQty <0 ;
	    
	  ------------------------------------------------------------------------------------

	  select SOProductID,ProductID,currentQty from #tblFinal;



      DROP TABLE #tbl1; 

      DROP TABLE #tableoriginal; 

      DROP TABLE #tablesold; 

      DROP TABLE #tablecurrent; 
      DROP TABLE #tblFinal; 
  END 


GO
/****** Object:  StoredProcedure [dbo].[PK_GetSalesReportCategoryPrint]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetSalesReportCategoryPrint] 
	@StoreName varchar(50),
	@ComputerName varchar(50),
	@FromDateTime varchar(50),
	@ToDateTime varchar(50),
	@DepartmentID varchar(50),
	@CategoryId varchar(50),
	@Status varchar(50)
AS
BEGIN
	SET NOCOUNT ON;
	declare @tempDecNumber decimal(18,2);
	declare @tempString varchar(50);
	set @tempString = '1234567891012345678910123456789101234567891012345678910';
	set @tempDecNumber = 1000000.00;
	declare @s varchar(8000);
	--=======================================================================================
	
    --=======================================================================================
	
    SELECT @tempString as StoreID, 
	 @tempString as StoreName, 
	 @tempString as Department, 
	 @tempString as DepartmentID, 
	 @tempString as Category, 
	 @tempString as CategoryID, 
	 @tempString as TransactionID, 
	 @tempString as TransactionItemID, 
	 @tempDecNumber as UnitCost, 
	 @tempDecNumber as UnitPrice, 
	 @tempDecNumber as QTY, 
	 @tempDecNumber as AverageCost, 
	 @tempDecNumber as ItemSubTotal
	 into #tblWhole;
	Delete from #tblWhole;
	If @DepartmentId = ''
	Begin
		insert into #tblWhole
		SELECT StoreID, 
		StoreName, 
		isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
		isnull(PKd.ID,'00000') AS DepartmentID, 
		isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
		isnull(PKc.ID,'00000') AS CategoryID, 
		ti.TransactionID,
		ti.ID  as TransactionItemID,
		ti.UnitCost, 
		ti.UnitPrice,
		ti.Qty,
		Pki.AverageCost,
		ti.ItemSubTotal
		FROM TransactionItem AS ti 
		JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
		LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
		LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
		LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
		left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
		WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
			--and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
			and POST.StatusDateTime >=@FromDateTime
			and POST.StatusDateTime <= @ToDateTime
			and ti.Status =@Status
			and post.Status = @Status
			and ti.ItemSubTotal <> 0
			and ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
			;
	End 
	Else 
	Begin
		if @CategoryId = ''
		begin
			insert into #tblWhole
			SELECT StoreID, 
			StoreName, 
			isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
			isnull(PKd.ID,'00000') AS DepartmentID, 
			isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
			isnull(PKc.ID,'00000') AS CategoryID, 
			ti.TransactionID,
			ti.ID as TransactionItemID,
			ti.UnitCost, 
			ti.UnitPrice,
			ti.Qty,
			Pki.AverageCost,
			ti.ItemSubTotal
			FROM TransactionItem AS ti 
			JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
			LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
			LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
			LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
			left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
			WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
				and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
				and POST.StatusDateTime >=@FromDateTime
				and POST.StatusDateTime <= @ToDateTime
				and ti.Status =@Status
				and post.Status = @Status
				and ti.ItemSubTotal <> 0
				and ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
				;
		end
		else
		Begin
			insert into #tblWhole
			SELECT StoreID, 
			StoreName, 
			isnull(PKd.Name,'(No Department)') AS Department, 
			isnull(PKd.ID,'00000') AS DepartmentID, 
			isnull(PKc.Name,'(No Department)') AS Category, 
			isnull(PKc.ID,'00000') AS CategoryID, 
			ti.TransactionID,
			ti.ID as TransactionItemID,
			ti.UnitCost, 
			ti.UnitPrice,
			ti.Qty,
			Pki.AverageCost,
			ti.ItemSubTotal
			FROM TransactionItem AS ti 
			JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
			LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
			LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
			LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
			left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
			WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
				and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
				and PKc.ID = case @CategoryId When '' then PKc.ID else @CategoryId end
				and POST.StatusDateTime >=@FromDateTime
				and POST.StatusDateTime <= @ToDateTime
				and ti.Status =@Status
				and post.Status = @Status
				and ti.ItemSubTotal <> 0
				and ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
				;
		End
	End ;
	SELECT StoreID, 
		Department, 
		DepartmentID, 
		Category, 
		CategoryID, 
		TransactionID,
		TransactionItemID,
		UnitCost, 
		UnitPrice,
		Qty,
		AverageCost,
		ItemSubTotal,
		--isnull(unitPrice,0) * QTY as RealSubtotal,
		isnull(AverageCost,0) * QTy as RealSubCost
		into #tbl2
	from #tblWhole
	SELECT StoreID, 
		Department, 
		DepartmentID, 
		Category, 
		CategoryID, 
		TransactionID,
		TransactionItemID,
		UnitCost, 
		UnitPrice,
		Qty,
		AverageCost,
		ItemSubTotal,
		--RealSubtotal,
		RealSubCost,
		ItemSubTotal - RealSubCost as Profit
		into #tbl3
	from #tbl2
	select distinct Department,replace(Category,'''','') as Category into #tblTempDepartment from #tbl3;
	
	SELECT StoreID, 
		--Department, 
		Category,
		sum(ItemSubTotal) as SubTotal,
		sum(RealSubCost) as SubCost,
		sum(Profit) as Profit
		into #tbl4
	from #tbl3
	group by StoreID,Category
	SELECT StoreID, 
		--Department, 
		Category,
		SubTotal as [   Sales Amount($)],
		SubCost,
		Profit as [  Profit($)],
		case Subcost when 0 then 0 else Profit/SubCost -1 end as [ Margin(%)]
		into #tbl5
	from #tbl4
	
	SELECT @tempString as StoreID, 
	 @tempString as sGroup, 
	 @tempString as sGroupCategory, 
	 @tempString as sName, 
	 @tempString as itemValue
	 into #tblFinal;
	Delete from #tblFinal;
	----------------------------------------------------------------------
	declare @thisStoreId varchar(50);
	declare t_cursorDepart cursor for 
	select distinct storeId from #tbl5 
	open t_cursorDepart
	fetch next from t_cursorDepart into @thisStoreId
	while @@fetch_status = 0
	begin
	----------------------------------------------------------------------
		set @s = 'create table test2(storeId varchar(50), sName varchar(50)';
		select @s =  @s + ',[' + Category + '] varchar(50)' from #tbl5 where StoreID = @thisStoreId;
		set @s = @s + ')';
		exec(@s);
		
		declare @nameDate varchar(50)
		declare t_cursor cursor for 
		select name from tempdb.dbo.syscolumns 
		where id=object_id('Tempdb.dbo.#tbl5') and colid<>1 order by colid
		open t_cursor
		fetch next from t_cursor into @nameDate
		while @@fetch_status = 0
		begin
			BEGIN TRY
				exec('select [' + @nameDate + '] as t into test4 from #tbl5 where storeId = '''+ @thisStoreId +'''')
				set @s='insert into test2 select '''+ @thisStoreId +''',''' + @nameDate + ''''
				select @s = @s + ',''' + replace(rtrim(isnull(t,0)),'''','') + '''' from test4;
				exec(@s)
				exec('drop table test4')			
			END TRY
			BEGIN CATCH
					print ERROR_MESSAGE() ;
					print '';
			END CATCH
			fetch next from t_cursor into @nameDate
		end
		declare @ColumnName varchar(50);
		declare t_cursorTest2 cursor for 
		select name from syscolumns 
		where id=object_id('test2')  and colid>2
		open t_cursorTest2
		fetch next from t_cursorTest2 into @ColumnName
		while @@fetch_status = 0
		begin
			set @s ='declare @CategoryName varchar(50);';
			set @s = @s + 'set @CategoryName = '''';';
			set @s = @s + 'select @CategoryName = ['+ @ColumnName + '] from test2 where sName = ''Category'';'
			set @s = @s + 'insert into #tblFinal select storeId,'''' as sGroup, @CategoryName as sGroupCategory, sName, ['+ @ColumnName +'] as itemValue from test2';
			exec(@s);
			fetch next from t_cursorTest2 into @ColumnName
			
		End
		close t_cursorTest2
		deallocate t_cursorTest2
		--select * from test2;
		close t_cursor
		deallocate t_cursor
		drop table test2
		fetch next from t_cursorDepart into @thisStoreId
	End
	close t_cursorDepart;
	deallocate t_cursorDepart;
	
	-----------------------------------------------------------------------------
	select distinct storeid into #tblTempStoreId from #tblFinal;
	select distinct sGroupCategory into #tblTempCategory from #tblFinal;
	select distinct sName into #tblTempItemName from #tblFinal;
	set @s = 'create table test3(sGroup varchar(50),sGroupCategory varchar(50), sName varchar(50)';
	select @s = @s + ',[' +  StoreID  + '] varchar(50)' from #tblTempStoreId
	set @s = @s + ')';
	exec(@s);
	set @s='insert into test3 select ''  LOCATION'',''  LOCATION'',''  LOCATION'''
	select @s = @s + ',''' + storeid + '''' from #tblTempStoreId;
	exec(@s)
	declare @tempStoreId varchar(50);
	declare @tempDepartment varchar(50);
	declare @tempCategory varchar(50);
	declare @tempItemName varchar(50);
	declare @tempFirstStoreId varchar(50);
	select top 1 @tempFirstStoreId = storeid from #tblTempStoreId;
	declare t_cursorDepartment cursor for 
	select sGroupCategory from #tblTempCategory 
	open t_cursorDepartment
	fetch next from t_cursorDepartment into @tempCategory
	while @@fetch_status = 0
	begin
		--set @s = 'insert into test3(sGroup,sName,['+ @tempFirstStoreId +'])values(';
		--set @s = @s + ''''+ @tempCategory +''','''+ @tempCategory +''',''departmentName''';
		--set @s = @s + ')';
		--exec(@s);
		declare t_cursorItemName cursor for 
		select sName from #tblTempItemName 
		open t_cursorItemName
		fetch next from t_cursorItemName into @tempItemName
		while @@fetch_status = 0
		begin
			declare t_cursorStoreId cursor for 
			select storeId from #tblTempStoreId 
			open t_cursorStoreId
			fetch next from t_cursorStoreId into @tempStoreId
			while @@fetch_status = 0
			begin
				declare @tempItemValue varchar(50);
				set @tempItemValue = '0.00';
				declare @isExist int;
				select @isExist = count(sGroupCategory) from test3 
					where sGroupCategory = @tempCategory and sName= @tempItemName;
				select @tempItemValue= isnull(itemValue,'0') from #tblFinal 
					where storeId = @tempStoreId and sName= @tempItemName and sGroupCategory = @tempCategory;
					
				if @isExist = 0
				Begin
					set @s = 'insert into test3(sGroupCategory,sName,['+ @tempStoreId +'])values(';
					set @s = @s + ''''+ @tempCategory +''','''+ @tempItemName +''','''+ @tempItemValue +'''';
					set @s = @s + ')';
					exec(@s);
				End
				Else
				Begin
					set @s = 'update test3 set ['+ @tempStoreId +'] = '''+ @tempItemValue +''' where ';
					set @s = @s + ' sGroupCategory = '''+ @tempCategory +''' and sName = '''+ @tempItemName +''''
					exec(@s);
				End
				fetch next from t_cursorStoreId into @tempStoreId
			End
			close t_cursorStoreId
			deallocate t_cursorStoreId
			fetch next from t_cursorItemName into @tempItemName
		End
		close t_cursorItemName
		deallocate t_cursorItemName
		--set @s = 'insert into test3(sGroup,sGroupCategory,sName)values(';
		--set @s = @s + ''''','''+ @tempCategory +''',''zzSpaceRow''';
		--set @s = @s + ')';
		--exec(@s);
		fetch next from t_cursorDepartment into @tempCategory
	End
	close t_cursorDepartment
	deallocate t_cursorDepartment
	delete from test3 where sname = 'Category';
	
	--Calculate the Total Amount--------------------------------------
	insert into test3(sGroup,sGroupCategory,sName)values('zzzTotal','zzzTotal','zzzTotal');
	declare t_cursorStoreId cursor for 
	select storeId from #tblTempStoreId 
	open t_cursorStoreId
	fetch next from t_cursorStoreId into @tempStoreId
	while @@fetch_status = 0
	begin
		set @s = 'declare @tempColumnValue decimal(18,4);';
		set @s = @s + 'select @tempColumnValue = sum(cast(isnull(['+ @tempStoreId +'],''0'') as decimal(18,4))) from test3 where sName=''   Sales Amount($)'';';
		set @s = @s + 'update test3 set ['+ @tempStoreId +'] = cast(@tempColumnValue as varchar(50)) where sGroup = ''zzzTotal'';';
		--set @s = @s + 'print @tempColumnValue;';
		exec(@s);
		fetch next from t_cursorStoreId into @tempStoreId
	End
	close t_cursorStoreId
	deallocate t_cursorStoreId
	--INSERT AN SPACE ROW FOR EVERY DEPARTMENT.
	declare t_cursorDepartment cursor for 
	select distinct Department from #tblTempDepartment 
	open t_cursorDepartment
	fetch next from t_cursorDepartment into @tempDepartment
	while @@fetch_status = 0
	begin
		insert into test3(sGroup,sGroupCategory,sName)values(@tempDepartment,'zzSpaceRow','zzSpaceRow');
		fetch next from t_cursorDepartment into @tempDepartment
	End
	close t_cursorDepartment
	deallocate t_cursorDepartment
	--iNSERT END.
	update test3 set sGroup = department from #tblTempDepartment where category = test3.sGroupCategory;
	select * from test3 ORDER By sGroup, sGroupCategory,sName;
	drop table test3;
	--------------------------------------------------------------------------------
	drop table #tblTempStoreId;
	drop table #tblTempDepartment;
	drop table #tblTempCategory;
	drop table #tblTempItemName;
	drop table #tblWhole;
	drop table #tbl2;
	drop table #tbl3;
	drop table #tbl4;	
	drop table #tbl5;	
	drop table #tblFinal;	
END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetSalesReportDepartment]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetSalesReportDepartment] 
	@StoreName varchar(50),
	@ComputerName varchar(50),
	@FromDateTime varchar(50),
	@ToDateTime varchar(50),
	@DepartmentID varchar(50),
	@CategoryId varchar(50),
	@Status varchar(50)

AS
BEGIN
	SET NOCOUNT ON;

	declare @tempDecNumber decimal(18,2);
	declare @tempString nvarchar(50);
	set @tempString = '1234567891012345678910123456789101234567891012345678910';
	set @tempDecNumber = 1000000.00;

	--=======================================================================================
	SELECT @tempString as StoreID, 
	 @tempString as StoreName, 
	 @tempString as ComputerName, 
	 @tempString as Department, 
	 @tempString as DepartmentID, 
	 @tempString as Category, 
	 @tempString as CategoryID, 
	 @tempDecNumber as UnitCost, 
	 @tempDecNumber as ItemTaxTotal, 
	 @tempDecNumber as ItemSubTotal
	 into #tblWhole

	Delete from #tblWhole;


	If @DepartmentId = ''
	Begin
		insert into #tblWhole
		SELECT StoreID, 
		StoreName, 
		ComputerName, 
		isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
		isnull(PKd.ID,'00000') AS DepartmentID, 
		isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
		isnull(PKc.ID,'00000') AS CategoryID, 
		UnitCost, 
		 ti.ItemTaxTotalAmount as ItemTaxTotal, 
		 ItemSubTotal
		
		FROM TransactionItem AS ti 
		JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
		LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
		LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
		LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
		WHERE ti.Status =@Status
			and POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
			and POST.computerName = case @ComputerName When '' then POST.ComputerName else @ComputerName end
			--and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
			--and PKc.ID = case @CategoryId When '' then PKc.ID else @CategoryId end
			and POST.StatusDateTime >=@FromDateTime
			and POST.StatusDateTime <= @ToDateTime
	End 
	Else 
	Begin
		insert into #tblWhole
		SELECT StoreID, 
		StoreName, 
		ComputerName, 
		isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
		isnull(PKd.ID,'00000') AS DepartmentID, 
		isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
		isnull(PKc.ID,'00000') AS CategoryID, 
		UnitCost, 
		 ti.ItemTaxTotalAmount as ItemTaxTotal, 
		 ItemSubTotal
		FROM TransactionItem AS ti 
		JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
		LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
		LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
		LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
		WHERE ti.Status =@Status
			and POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
			and POST.computerName = case @ComputerName When '' then POST.ComputerName else @ComputerName end
			and PKd.ID = @DepartmentId
			--and PKc.ID = case @CategoryId When '' then PKc.ID else @CategoryId end
			and POST.StatusDateTime >=@FromDateTime
			and POST.StatusDateTime <= @ToDateTime
	End ;

   --select * from #tblWhole 
   --where DepartmentID ='00000' and ItemSubTotal <> 0
   ;

	select StoreID, 
		StoreName, 
		ComputerName, 
		Department, 
		DepartmentID, 
		case @CategoryId When '' then '-' else Category end as Category, 
		case @CategoryId When '' then '-' else CategoryID end as CategoryID,  
		UnitCost, 
		ItemTaxTotal, 
		ItemSubTotal
	into #tbl2
	from #tblWhole
	where 
		DepartmentID = case @DepartmentId When '' then DepartmentID else @DepartmentId end
		and CategoryID = case @CategoryId When '' then CategoryID else @CategoryId end
	

	--=======================================================================================
	if @StoreName = ''
	begin 
		select a.storeId,
			--a.ComputerName,
			a.Department,
			a.DepartmentID,
			a.Category,
			a.CategoryID,
			SUM(isnull(a.UnitCost,0)) AS TotalCost, 
			SUM(isnull(a.ItemTaxTotal,0)) AS TotalTax, 
			SUM(isnull(a.ItemSubTotal,0)) AS TotalItemAmount
			from #tbl2 a
			group by a.StoreID,a.Department,a.DepartmentID,a.Category,a.CategoryID
			order by a.StoreID,a.Department,a.DepartmentID,a.Category,a.CategoryID
		
	end 
	else
	begin
		select a.storeId,
			a.ComputerName,
			a.Department,
			a.DepartmentID,
			a.Category,
			a.CategoryID,
			SUM(isnull(a.UnitCost,0)) AS TotalCost, 
			SUM(isnull(a.ItemTaxTotal,0)) AS TotalTax, 
			SUM(isnull(a.ItemSubTotal,0)) AS TotalItemAmount
			from #tbl2 a
			group by a.StoreID,a.ComputerName,a.Department,a.DepartmentID,a.Category,a.CategoryID
			order by a.StoreID,a.Department,a.DepartmentID,a.Category,a.CategoryID,a.ComputerName
	
	end


	drop table #tblWhole;
	drop table #tbl2;

END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetSalesReportDepartmentPrint]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetSalesReportDepartmentPrint] 
	@StoreName varchar(50),
	@ComputerName varchar(50),
	@FromDateTime varchar(50),
	@ToDateTime varchar(50),
	@DepartmentID varchar(50),
	@CategoryId varchar(50),
	@Status varchar(50)
AS
BEGIN
	SET NOCOUNT ON;
	declare @tempDecNumber decimal(18,2);
	declare @tempString nvarchar(50);
	set @tempString = '1234567891012345678910123456789101234567891012345678910';
	set @tempDecNumber = 1000000.00;
	declare @s nvarchar(max);
	--=======================================================================================
	SELECT @tempString as StoreID, 
	 @tempString as StoreName, 
	 @tempString as Department, 
	 @tempString as DepartmentID, 
	 @tempString as Category, 
	 @tempString as CategoryID, 
	 @tempString as TransactionID, 
	 @tempString as TransactionItemID, 
	 @tempDecNumber as UnitCost, 
	 @tempDecNumber as UnitPrice, 
	 @tempDecNumber as QTY, 
	 @tempDecNumber as AverageCost, 
	 @tempDecNumber as ItemSubTotal
	 into #tblWhole;
	Delete from #tblWhole;
	If @DepartmentId = ''
	Begin
		insert into #tblWhole
		SELECT StoreID, 
		StoreName, 
		isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
		isnull(PKd.ID,'00000') AS DepartmentID, 
		isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
		isnull(PKc.ID,'00000') AS CategoryID, 
		ti.TransactionID,
		ti.ID  as TransactionItemID,
		ti.UnitCost, 
		ti.UnitPrice,
		ti.Qty,
		Pki.AverageCost,
		ti.ItemSubTotal
		FROM TransactionItem AS ti 
		JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
		LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
		LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
		LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
		left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
		WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
			--and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
			and POST.StatusDateTime >=@FromDateTime
			and POST.StatusDateTime <= @ToDateTime
			and ti.Status =@Status
			and post.Status = @Status
			and ti.ItemSubTotal <> 0
			and ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
			;
	End 
	Else 
	Begin
		insert into #tblWhole
		SELECT StoreID, 
		StoreName, 
		isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
		isnull(PKd.ID,'00000') AS DepartmentID, 
		isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
		isnull(PKc.ID,'00000') AS CategoryID, 
		ti.TransactionID,
		ti.ID as TransactionItemID,
		ti.UnitCost, 
		ti.UnitPrice,
		ti.Qty,
		Pki.AverageCost,
		ti.ItemSubTotal
		FROM TransactionItem AS ti 
		JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
		LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
		LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
		LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
		left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
		WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
			and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
			and POST.StatusDateTime >=@FromDateTime
			and POST.StatusDateTime <= @ToDateTime
			and ti.Status =@Status
			and post.Status = @Status
			and ti.ItemSubTotal <> 0
			and ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
			;
	End ;

	--select * from #tblWhole;

	SELECT StoreID, 
		Department, 
		DepartmentID, 
		Category, 
		CategoryID, 
		TransactionID,
		TransactionItemID,
		UnitCost, 
		UnitPrice,
		Qty,
		AverageCost,
		ItemSubTotal,
		--isnull(unitPrice,0) * QTY as RealSubtotal,
		isnull(AverageCost,0) * QTy as RealSubCost
		into #tbl2
	from #tblWhole
	SELECT StoreID, 
		Department, 
		DepartmentID, 
		Category, 
		CategoryID, 
		TransactionID,
		TransactionItemID,
		UnitCost, 
		UnitPrice,
		Qty,
		AverageCost,
		ItemSubTotal,
		--RealSubtotal,
		RealSubCost,
		ItemSubTotal - RealSubCost as Profit
		into #tbl3
	from #tbl2
	SELECT StoreID, 
		Department, 
		--sum(RealSubtotal) as SubTotal,
		sum(ItemSubTotal) as SubTotal,
		sum(RealSubCost) as SubCost,
		sum(Profit) as Profit
		into #tbl4
	from #tbl3
	group by StoreID,Department
	SELECT StoreID, 
		Department, 
		SubTotal as [   Sales Amount($)],
		SubCost,
		Profit as [  Profit($)],
		case Subcost when 0 then 0 else (SubTotal/SubCost -1)*100 end as [ Margin(%)]
		into #tbl5
	from #tbl4
	--select * from #tbl5;
	SELECT @tempString as StoreID, 
	 @tempString as sGroup, 
	 @tempString as sName, 
	 @tempString as itemValue
	 into #tblFinal;
	Delete from #tblFinal;
	----------------------------------------------------------------------
	declare @thisStoreId nvarchar(50);
	declare t_cursorDepart cursor for 
	select distinct storeId from #tbl5 
	open t_cursorDepart
	fetch next from t_cursorDepart into @thisStoreId
	while @@fetch_status = 0
	begin
	----------------------------------------------------------------------
		set @s = 'create table test2(storeId nvarchar(50), sName nvarchar(50)';
		select @s = @s + ',[' + Department + '] nvarchar(50)' from #tbl5 where StoreID = @thisStoreId;
		set @s = @s + ')';
		exec(@s);
		declare @nameDate nvarchar(50)
		declare t_cursor cursor for 
		select name from tempdb.dbo.syscolumns 
		where id=object_id('Tempdb.dbo.#tbl5') and colid<>1 order by colid
		open t_cursor
		fetch next from t_cursor into @nameDate
		while @@fetch_status = 0
		begin
			BEGIN TRY
				exec('select [' + @nameDate + '] as t into test4 from #tbl5 where storeId = '''+ @thisStoreId +'''')
				set @s='insert into test2 select '''+ @thisStoreId +''',''' + @nameDate + ''''
				select @s = @s + ',N''' + replace(rtrim(isnull(t,0)),'''','''''') + '''' from test4;
				--print ('')
				--print(@s)
				--print ('')
				exec(@s)
				exec('drop table test4')			
			END TRY
			BEGIN CATCH
					print ERROR_MESSAGE() ;
					print '';
			END CATCH
			fetch next from t_cursor into @nameDate
		end
		declare @ColumnName nvarchar(50);
		declare t_cursorTest2 cursor for 
		select name from syscolumns 
		where id=object_id('test2')  and colid>2
		open t_cursorTest2
		fetch next from t_cursorTest2 into @ColumnName
		while @@fetch_status = 0
		begin
			set @s ='declare @departmentName nvarchar(50);';
			set @s = @s + 'set @departmentName = '''';';
			set @s = @s + 'select @departmentName = ['+ @ColumnName + '] from test2 where sName = ''Department'';'
			set @s = @s + 'insert into #tblFinal select storeId, @departmentName as sGroup, sName, ['+ @ColumnName +'] as itemValue from test2';
			exec(@s);
			fetch next from t_cursorTest2 into @ColumnName
			
		End
		close t_cursorTest2
		deallocate t_cursorTest2
		--select * from test2;
		close t_cursor
		deallocate t_cursor
		drop table test2
		fetch next from t_cursorDepart into @thisStoreId
	End
	close t_cursorDepart;
	deallocate t_cursorDepart;
	--Select * from #tblFinal order by storeId,sGroup;
	-----------------------------------------------------------------------------
	select distinct storeid into #tblTempStoreId from #tblFinal;
	select distinct sGroup into #tblTempDepartment from #tblFinal;
	select distinct sName into #tblTempItemName from #tblFinal;
	set @s = 'create table test3(sGroup nvarchar(50), sName nvarchar(50)';
	select @s = @s + ',[' +  StoreID  + '] nvarchar(50)' from #tblTempStoreId
	set @s = @s + ')';
	exec(@s);
	set @s='insert into test3 select ''  LOCATION'',''  LOCATION'''
	select @s = @s + ',''' + storeid + '''' from #tblTempStoreId;
	exec(@s)
	declare @tempStoreId nvarchar(50);
	declare @tempDepartment nvarchar(50);
	declare @tempItemName nvarchar(50);
	declare @tempFirstStoreId nvarchar(50);
	select top 1 @tempFirstStoreId = storeid from #tblTempStoreId;
	declare t_cursorDepartment cursor for 
	select sGroup from #tblTempDepartment 
	open t_cursorDepartment
	fetch next from t_cursorDepartment into @tempDepartment
	while @@fetch_status = 0
	begin
		--set @s = 'insert into test3(sGroup,sName,['+ @tempFirstStoreId +'])values(';
		--set @s = @s + ''''+ @tempDepartment +''','''+ @tempDepartment +''',''departmentName''';
		--set @s = @s + ')';
		--exec(@s);
		declare t_cursorItemName cursor for 
		select sName from #tblTempItemName 
		open t_cursorItemName
		fetch next from t_cursorItemName into @tempItemName
		while @@fetch_status = 0
		begin
			declare t_cursorStoreId cursor for 
			select storeId from #tblTempStoreId 
			open t_cursorStoreId
			fetch next from t_cursorStoreId into @tempStoreId
			while @@fetch_status = 0
			begin
				declare @tempItemValue nvarchar(50);
				set @tempItemValue = '0.00';
				declare @isExist int;
				--select @isExist = count(sGroup) from test3 
				--	where sGroup = @tempDepartment and sName= @tempItemName;
				select @isExist = count(sGroup) from test3 
					where sGroup = ' ' + @tempDepartment and sName= @tempItemName;
				select @tempItemValue= isnull(itemValue,'0') from #tblFinal 
					where storeId = @tempStoreId and sName= @tempItemName and sGroup = @tempDepartment;
				if @isExist = 0
				Begin
					set @s = 'insert into test3(sGroup,sName,['+ @tempStoreId +'])values(';
					set @s = @s + 'N'' '+ replace(@tempDepartment,'''','''''') +''',N'''+ replace(@tempItemName,'''','''''') +''',N'''+ replace(@tempItemValue,'''','''''') +'''';
					set @s = @s + ')';
					--Print(@s);
					exec(@s);
				End
				Else
				Begin
					set @s = 'update test3 set ['+ @tempStoreId +'] = N'''+ replace(@tempItemValue,'''','''''') +''' where ';
					set @s = @s + ' sGroup = N'' '+replace( @tempDepartment,'''','''''') +''' and sName = N'''+ replace(@tempItemName,'''','''''') +''''
					--Print(@s);
					exec(@s);
				End
				fetch next from t_cursorStoreId into @tempStoreId
			End
			close t_cursorStoreId
			deallocate t_cursorStoreId
			fetch next from t_cursorItemName into @tempItemName
		End
		close t_cursorItemName
		deallocate t_cursorItemName
		--set @s = 'insert into test3(sGroup,sName)values(';
		--set @s = @s + ''''+ @tempDepartment +''',''zzSpaceRow''';
		--set @s = @s + ')';
		--exec(@s);
		fetch next from t_cursorDepartment into @tempDepartment
	End
	close t_cursorDepartment
	deallocate t_cursorDepartment
	delete from test3 where sname = 'department';
	
	select * from test3 ORDER By sGroup,sName;

	--Calculate the Total Amount--------------------------------------
	insert into test3(sGroup,sName)values('zzzTotal','zzzTotal');
	declare t_cursorStoreId cursor for 
	select storeId from #tblTempStoreId 
	open t_cursorStoreId
	fetch next from t_cursorStoreId into @tempStoreId
	while @@fetch_status = 0
	begin
		set @s = 'declare @tempColumnValue decimal(18,4);';
		set @s = @s + 'select @tempColumnValue = sum(cast(isnull(['+ @tempStoreId +'],''0'') as decimal(18,4))) from test3 where sName=''   Sales Amount($)'';';
		set @s = @s + 'update test3 set ['+ @tempStoreId +'] = cast(@tempColumnValue as nvarchar(50)) where sGroup = ''zzzTotal'';';
		--set @s = @s + 'print @tempColumnValue;';
		exec(@s);
		fetch next from t_cursorStoreId into @tempStoreId
	End
	close t_cursorStoreId
	deallocate t_cursorStoreId
	--select * from test3 ORDER By sGroup,sName;
	drop table test3;
	--------------------------------------------------------------------------------
	drop table #tblTempStoreId;
	drop table #tblTempDepartment;
	drop table #tblTempItemName;
	drop table #tblWhole;
	drop table #tbl2;
	drop table #tbl3;
	drop table #tbl4;	
	drop table #tbl5;	
	drop table #tblFinal;	

END



GO
/****** Object:  StoredProcedure [dbo].[Pk_getsalesreportproductexcel]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Pk_getsalesreportproductexcel] @StoreName    VARCHAR(50), 
                                                      @FromDateTime VARCHAR(50), 
                                                      @ToDateTime   VARCHAR(50), 
                                                      @type         VARCHAR(50) 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from  
      -- interfering with SELECT statements.  
      SET nocount ON; 

      SELECT p.id, 
             categoryid, 
             plu, 
             name1, 
             name2, 
             status, 
             pp.a AS price 
      INTO   #tblpksold 
      FROM   pkproduct P 
             INNER JOIN pkprice PP 
                     ON p.id = pp.productid; 

      ALTER TABLE #tblpksold 
        ADD sold DECIMAL(18, 2); 

      ----------------------------------------------------------------  
      UPDATE #tblpksold 
      SET    sold = 0; 

      ----------------------------------------------------------------  
      IF @type = 'SO' 
        BEGIN 
            ----------------------------------------------------------------  
            SELECT Sum(shippingqty) AS qty, 
                   plu, 
                   productid 
            INTO   #tbltemp1 
            FROM   pksoproduct 
            WHERE  soid IN (SELECT soid 
                            FROM   pkso 
                            WHERE  status = 'Shipped' 
                                   AND ( CONVERT(DATE, shipdate) <= @ToDateTime 
                                         AND CONVERT(DATE, shipdate) >= 
                                             @FromDateTime 
                                       ) 
                                   AND locationid = CASE @StoreName 
                                                      WHEN '' THEN locationid 
                                                      ELSE @StoreName 
                                                    END) 
            GROUP  BY plu, 
                      productid 
            ORDER  BY plu; 

            ----------------------------------------------------------------  
            DECLARE @qty DECIMAL(38, 2); 
            DECLARE @id NVARCHAR(50); 
            DECLARE qty_cursor CURSOR FOR 
              SELECT productid, 
                     qty 
              FROM   #tbltemp1 

            OPEN qty_cursor 

            FETCH next FROM qty_cursor INTO @id, @qty; 

            WHILE ( @@fetch_status = 0 ) 
              BEGIN 
                  UPDATE #tblpksold 
                  SET    sold = sold + @qty 
                  WHERE  id = @id; 

                  FETCH next FROM qty_cursor INTO @id, @qty; 
              END 

            CLOSE qty_cursor; 

            DEALLOCATE qty_cursor; 

            DROP TABLE #tbltemp1; 
        END 

      ----------------------------------------------------------------  
      IF @Type = 'POS' 
        BEGIN 
            ----------------------------------------------------------------  
            SELECT Sum(qty) AS qty, 
                   plu, 
                   productid 
            INTO   #tbltemp2 
            FROM   transactionitem 
            WHERE  status = 'Confirmed' 
                   AND ( CONVERT(DATE, statusdatetime) <= @ToDateTime 
                         AND CONVERT(DATE, statusdatetime) >= @FromDateTime ) 
                   AND transactionid IN (SELECT id 
                                         FROM   postransaction 
                                         WHERE  storeid = CASE @StoreName 
                                                            WHEN '' THEN storeid 
                                                            ELSE @StoreName 
                                                          END) 
            GROUP  BY plu, 
                      productid 
            ORDER  BY plu; 

            ---------------------------------------------------------  
            DECLARE qty_cursor CURSOR FOR 
              SELECT productid, 
                     qty 
              FROM   #tbltemp2; 

            OPEN qty_cursor 

            FETCH next FROM qty_cursor INTO @id, @qty; 

            WHILE ( @@fetch_status = 0 ) 
              BEGIN 
                  UPDATE #tblpksold 
                  SET    sold = sold + @qty 
                  WHERE  id = @id; 

                  FETCH next FROM qty_cursor INTO @id, @qty; 
              END; 

            CLOSE qty_cursor; 

            DEALLOCATE qty_cursor; 

            DROP TABLE #tbltemp2; 
        END 

      ----------------------------------------------------------------  
      IF @StoreName = '' 
        BEGIN 
            DECLARE @HeadLocationId VARCHAR(50); 

            SELECT @HeadLocationId = LocationID
            FROM   pklocation 
            WHERE  isheadquarter = '1'; 

			select a.ID,sum(isnull(b.Qty,0)) as CurrentQTY
			into #tempTblQty
			FROM   #tblpksold a 
                   LEFT JOIN pkinventory b 
                          ON a.id = b.productid 
			WHERE  a.status = 'Active' 
			group by a.ID

            SELECT a.PLU, 
                   a.name1 + '[' + a.name2 + ']'    AS ProductName, 
                   c.a                              AS Price, 
                   isnull(b.AverageCost,0) as AverageCost, 
                   isnull(a.sold,0)                           AS QTY, 
				   isnull(d.CurrentQTY,0) as CurrentQTY,
                   cast(isnull(a.sold,0) * isnull(b.AverageCost,0) as numeric(18,2))           AS [Cost Amount], 
                   cast(isnull(a.sold,0) * a.price as numeric(18,2))                 AS [Sales Amount], 
                   cast(isnull(a.sold,0) * ( c.a - isnull(b.AverageCost,0) ) as numeric(18,2)) AS Profit, 
                   CASE 
                     WHEN isnull(b.AverageCost,0) = 0 THEN 0 
                     ELSE cast(c.a / isnull(b.AverageCost,c.a) as numeric(18,2)) 
                   END                              AS [Profit Margin] 
            FROM   #tblpksold a 
                   LEFT JOIN pkinventory b 
                          ON a.id = b.productid 
                             AND locationid = @HeadLocationId 
                   LEFT JOIN pkprice c 
                          ON a.id = c.productid 
				   left join #tempTblQty d on a.ID = d.ID
            WHERE  a.status = 'Active' 
            ORDER  BY plu; 

			drop table #tempTblQty;
        END 
      ELSE 
        BEGIN 
            SELECT a.PLU, 
                   a.name1 + '[' + a.name2 + ']'    AS ProductName, 
                   c.a                              AS Price, 
                   isnull(b.AverageCost,0) as AverageCost, 
                   isnull(a.sold,0)                           AS QTY, 
				   isnull(b.Qty,0) as CurrentQTY,
                   cast(isnull(a.sold,0) * isnull(b.AverageCost,0) as numeric(18,2))           AS [Cost Amount], 
                   cast(isnull(a.sold,0) * a.price as numeric(18,2))                 AS [Sales Amount], 
                   cast(isnull(a.sold,0) * ( c.a - isnull(b.AverageCost,0) ) as numeric(18,2)) AS Profit, 
                   CASE 
                     WHEN isnull(b.AverageCost,0) = 0 THEN 0 
                     ELSE cast(c.a / isnull(b.AverageCost,c.a) as numeric(18,2)) 
                   END                                   AS [Profit Margin] 
            FROM   #tblpksold a 
                   LEFT JOIN pkinventory b 
                          ON a.id = b.productid 
                             AND locationid = @StoreName 
                   LEFT JOIN pkprice c 
                          ON a.id = c.productid 
            WHERE  a.status = 'Active' 
            ORDER  BY plu; 
        END 

      DROP TABLE #tblpksold; 
  END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetSalesReportProductPrint]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetSalesReportProductPrint] 
	@StoreName varchar(50),
	@ComputerName varchar(50),
	@FromDateTime varchar(50),
	@ToDateTime varchar(50),
	@DepartmentID varchar(50),
	@CategoryId varchar(50),
	@Status varchar(50)

AS
BEGIN
	SET NOCOUNT ON;

	declare @tempDecNumber decimal(18,2);
	declare @tempString varchar(50);
	set @tempString = '1234567891012345678910123456789101234567891012345678910';
	set @tempDecNumber = 1000000.00;
	declare @s varchar(max);
	--=======================================================================================
	declare @averageOrLastCost varchar(20);
	select @averageOrLastCost = isnull(Value,'a') from pksetting where FieldName = 'basePricebyAveOrlastPrice'
	set @averageOrLastCost = isnull(@averageOrLastCost,'a')
    --=======================================================================================
	SELECT @tempString as StoreID, 
	 @tempString as StoreName, 
	 @tempString as Department, 
	 @tempString as DepartmentID, 
	 @tempString as Category, 
	 @tempString as CategoryID, 
	 @tempString as ProductId, 
	 @tempString + @tempString as ProductName, 
	 @tempString as TransactionID, 
	 @tempString as TransactionItemID, 
	 @tempDecNumber as UnitCost, 
	 @tempDecNumber as UnitPrice, 
	 @tempDecNumber as QTY, 
	 @tempDecNumber as AverageCost, 
	 @tempDecNumber as ItemSubTotal
	 into #tblWhole;

	Delete from #tblWhole;


	If @DepartmentId = ''
	Begin
		insert into #tblWhole
		SELECT StoreID, 
		StoreName, 
		isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
		isnull(PKd.ID,'00000') AS DepartmentID, 
		isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
		isnull(PKc.ID,'00000') AS CategoryID, 
		isnull(ti.ProductID,'00000') as ProductId,
		isnull(PKp.Name1,'-')  as ProductName,  --+'(' + isnull(PKp.Name2,'-') + ')' 
		ti.TransactionID,
		ti.ID  as TransactionItemID,
		ti.UnitCost, 
		ti.UnitPrice,
		ti.Qty,
		case @averageOrLastCost when 'a' then  Pki.AverageCost else Pki.LatestCost end as AverageCost,
		ti.ItemSubTotal
		FROM TransactionItem AS ti 
		JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
		--Left Outer JOIN TransactionItemTax AS Tix ON Tix.TransactionID = ti.TransactionID AND Tix.TransactionItemID = ti.ID 
		LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
		LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
		LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
		left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
		WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
			--and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
			and POST.StatusDateTime >=@FromDateTime
			and POST.StatusDateTime <= @ToDateTime
			and ti.Status =@Status
			and post.Status = @Status
			and ti.ItemSubTotal <> 0
			and ti.type = 'Item' --ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
			;

	End 
	Else 
	Begin
		if @CategoryId = ''
		begin
			insert into #tblWhole
			SELECT StoreID, 
			StoreName, 
			isnull(PKd.PLU,'00') + ' ' + isnull(PKd.Name,'(No Department)') AS Department, 
			isnull(PKd.ID,'00000') AS DepartmentID, 
			isnull(PKc.PLU,'0000') + ' ' + isnull(PKc.Name,'(No Department)') AS Category, 
			isnull(PKc.ID,'00000') AS CategoryID, 
			isnull(ti.ProductID,'00000') as ProductId,
			isnull(PKp.Name1,'-')  as ProductName,  --+'(' + isnull(PKp.Name2,'-') + ')' 
			ti.TransactionID,
			ti.ID as TransactionItemID,
			ti.UnitCost, 
			ti.UnitPrice,
			ti.Qty,
			case @averageOrLastCost when 'a' then  Pki.AverageCost else Pki.LatestCost end as AverageCost,
			ti.ItemSubTotal
			FROM TransactionItem AS ti 
			JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
			---Left Outer JOIN TransactionItemTax AS Tix ON Tix.TransactionID = ti.TransactionID AND Tix.TransactionItemID = ti.ID 
			LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
			LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
			LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
			left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
			WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
				and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
				and POST.StatusDateTime >=@FromDateTime
				and POST.StatusDateTime <= @ToDateTime
				and ti.Status =@Status
				and post.Status = @Status
				and ti.ItemSubTotal <> 0
				and ti.type = 'Item' --ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
				;
		end
		else
		Begin
			insert into #tblWhole
			SELECT StoreID, 
			StoreName, 
			isnull(PKd.Name,'(No Department)') AS Department, 
			isnull(PKd.ID,'00000') AS DepartmentID, 
			isnull(PKc.Name,'(No Department)') AS Category, 
			isnull(PKc.ID,'00000') AS CategoryID, 
			isnull(ti.ProductID,'00000') as ProductId,
			isnull(PKp.Name1,'-')  as ProductName,  --+'(' + isnull(PKp.Name2,'-') + ')' 
			ti.TransactionID,
			ti.ID as TransactionItemID,
			ti.UnitCost, 
			ti.UnitPrice,
			ti.Qty,
			case @averageOrLastCost when 'a' then  Pki.AverageCost else Pki.LatestCost end as AverageCost,
			ti.ItemSubTotal
			FROM TransactionItem AS ti 
			JOIN POSTransaction AS POST ON ti.TransactionID = POST.ID
			--Left Outer JOIN TransactionItemTax AS Tix ON Tix.TransactionID = ti.TransactionID AND Tix.TransactionItemID = ti.ID 
			LEFT JOIN PKProduct AS PKp on ti.ProductID = PKp.ID 
			LEFT JOIN PKCategory AS PKc on PKp.CategoryID = PKc.ID
			LEFT JOIN PKDepartment AS PKd on PKc.DepartmentID = PKd.ID
			left outer join PKInventory Pki on pki.LocationID = post.StoreID and pki.ProductID = pkp.ID
			WHERE  POST.StoreID = case @StoreName When '' then POST.StoreName else @StoreName end
				and PKd.ID = case @DepartmentId When '' then PKd.ID else @DepartmentId end
				and PKc.ID = case @CategoryId When '' then PKc.ID else @CategoryId end
				and POST.StatusDateTime >=@FromDateTime
				and POST.StatusDateTime <= @ToDateTime
				and ti.Status =@Status
				and post.Status = @Status
				and ti.ItemSubTotal <> 0
				and ti.type = 'Item' --ti.type<>'CRF' AND ti.TYPE <> 'Deposit' and ti.Type <> 'EHF'
				;
		End
	End ;

	SELECT StoreID, 
		Department, 
		DepartmentID, 
		Category, 
		CategoryID, 
		ProductId,
		replace(ProductName,' ','') as ProductName,
		TransactionID,
		TransactionItemID,
		UnitCost, 
		UnitPrice,
		Qty,
		AverageCost,
		ItemSubTotal,
		--isnull(unitPrice,0) * QTY as RealSubtotal,
		isnull(AverageCost,0) * QTy as RealSubCost
		into #tbl2
	from #tblWhole

	--select * from #tbl2;

	SELECT StoreID, 
		Department, 
		DepartmentID, 
		Category, 
		CategoryID, 
		ProductId,
		ProductName,
		TransactionID,
		TransactionItemID,
		UnitCost, 
		UnitPrice,
		Qty,
		AverageCost,
		ItemSubTotal,
		--RealSubtotal,
		RealSubCost,
		ItemSubTotal - RealSubCost as Profit
		into #tbl3
	from #tbl2
	
	

	select distinct Department,Category,ProductId,ProductName into #tblTempDepartment from #tbl3;
	-----------------------------------------------------------------------
	-- Here Need a branch table to hold the Product QTY.

	--_--_--_--_--_--_--_
	-----------------------------------------------------------------------

SELECT StoreID, 
		--Department, 
		--Category,
		productId,
		sum(ItemSubTotal) as SubTotal,
		sum(RealSubCost) as SubCost,
		sum(Profit) as Profit,
		sum(qty) as Qty
		into #tbl4
	from #tbl3
	group by StoreID,productId

	SELECT StoreID, 
		--Department, 
		--Category, 
		ProductId,
		SubTotal as [     Sales Amount($)],
		Qty as [    Qty],
		case qty when 0 then 0 else SubCost/Qty end as [   Average Cost($)],
		SubCost,
		Profit as [  Profit($)],
		case Subcost when 0 then 0 else Profit/SubCost -1 end as [ Margin(%)]
		into #tbl5
	from #tbl4
	
	
	--To deal with the count of productId.-------------------------------
	--because there are too many products in the table, there might be error 
	--in creating middle tables with the productId as the column.
	--So we need to group the productId and deal with them group by group.

	create table #tblProductIdGroup (
		[id] [int] IDENTITY(1,1) NOT NULL,
		[productId] [varchar](50) NULL,
		dealGroup int null
	) ON [PRIMARY];

	insert into #tblProductIdGroup(productId)
		select distinct productid from #tbl5;

	update #tblProductIdGroup set dealGroup = id / 200;
	declare @productDealGroupCount int;
	select @productDealGroupCount = max(dealgroup) from #tblProductIdGroup;
	--select @productDealGroupCount;
	--select * from #tblProductIdGroup;
	declare @i  int;
	set @i = 0;

	--End ---------------------------------------------------------------
	SELECT @tempString as StoreID, 
	 @tempString as sGroup, 
	 @tempString as sGroupCategory, 
	 @tempString as sProductId, 
	 @tempString as sName, 
	 @tempString as itemValue
	 into #tblFinal;

	--select * from #tbl5;

	Delete from #tblFinal;
	--select * from #tbl5;
	----------------------------------------------------------------------
	While @i<=@productDealGroupCount --Begin to group the product Id
	begin
		--Print 'Begin---' + cast(@i as varchar(50)) + '---' + cast(GETUTCDATE() as varchar(50));

		declare @thisStoreId varchar(50);
		declare t_cursorDepart cursor for 
		select distinct storeId from #tbl5 
		open t_cursorDepart
		fetch next from t_cursorDepart into @thisStoreId
		while @@fetch_status = 0
		begin

		----------------------------------------------------------------------
			set @s = 'create table test2(storeId varchar(50), sName varchar(50))';
			exec(@s);

			declare @tempProductId varchar(50);
			declare t_cursorProduct cursor for 
			select distinct a.ProductId from #tbl5 a
				inner join #tblProductIdGroup b on a.ProductId = b.productId COLLATE DATABASE_DEFAULT
				where StoreID = @thisStoreId and b.dealGroup = @i
				;
			open t_cursorProduct
			fetch next from t_cursorProduct into @tempProductId
			while @@fetch_status = 0
			begin

				select @s =  'alter table test2 add [' + @tempProductId + '] varchar(50); ' 
				--print @s;
				exec(@s);

				fetch next from t_cursorProduct into @tempProductId
			End
			close t_cursorProduct
			deallocate t_cursorProduct



			declare @nameDate varchar(50)

			declare t_cursor cursor for 
			select name from tempdb.dbo.syscolumns 
			where id=object_id('Tempdb.dbo.#tbl5') and colid<>1 order by colid
			open t_cursor
			fetch next from t_cursor into @nameDate
			while @@fetch_status = 0
			begin
				BEGIN TRY
					drop table test4;
					print 'Dropped.'
				END TRY
				begin catch
					print '' ;
				end catch
				BEGIN TRY
					exec('select a.[' + @nameDate + '] as t into test4 from #tbl5 a inner join #tblProductIdGroup b on a.ProductId = b.productId COLLATE DATABASE_DEFAULT where a.storeId = '''+ @thisStoreId +'''  and b.dealGroup = ' + @i + '')
					set @s='insert into test2 select '''+ @thisStoreId +''',''' + @nameDate + ''''
					select @s = @s + ',''' + rtrim(isnull(t,0)) + '''' from test4;
					
					exec(@s)
					
					exec('drop table test4')
				END TRY
				BEGIN CATCH
						print ERROR_MESSAGE() ;
						print '';
				END CATCH

				fetch next from t_cursor into @nameDate
			end
			--Print '-------'
			declare @ColumnName varchar(50);
			declare t_cursorTest2 cursor for 
			select name from syscolumns 
			where id=object_id('test2')  and colid>2
			open t_cursorTest2
			fetch next from t_cursorTest2 into @ColumnName
			while @@fetch_status = 0
			begin

				set @s ='declare @ProductId varchar(50);';
				set @s = @s + 'set @ProductId = '''';';
				set @s = @s + 'select @ProductId = ['+ @ColumnName + '] from test2 where sName = ''productId'';'
				set @s = @s + 'insert into #tblFinal select storeId,'''' as sGroup, '''' as sGroupCategory,@ProductId as sProductId, sName, ['+ @ColumnName +'] as itemValue from test2';
				exec(@s);
				fetch next from t_cursorTest2 into @ColumnName
			
			End
			close t_cursorTest2
			deallocate t_cursorTest2

			--select * from test2;

			close t_cursor
			deallocate t_cursor

			drop table test2

			fetch next from t_cursorDepart into @thisStoreId
		End
		close t_cursorDepart;
		deallocate t_cursorDepart;
		
		set @i = @i + 1;
	End
	-----------------------------------------------------------------------------
	select distinct storeid into #tblTempStoreId from #tblFinal;
	select distinct StoreID,sProductId into #tblTempProductId from #tblFinal;
	select distinct sName into #tblTempItemName from #tblFinal;


	set @s = 'create table test3(sGroup varchar(50),sGroupCategory varchar(50), sProductId varchar(110),  sName varchar(50)';
	select @s = @s + ',[' +  StoreID  + '] varchar(50)' from #tblTempStoreId
	set @s = @s + ')';
	exec(@s);

	set @s='insert into test3 select ''  LOCATION'',''  LOCATION'',''  LOCATION'',''  LOCATION'''
	select @s = @s + ',''' + storeid + '''' from #tblTempStoreId;
	exec(@s)
	

	--declare @tempStoreId varchar(50);
	declare @tempDepartment varchar(50);
	declare @tempCategory varchar(50);
	declare @tempProductIdLoop varchar(50); 
	declare @tempProductStoreId varchar(50);
	declare @tempItemName varchar(50);
	declare @tempFirstStoreId varchar(50);

	select top 1 @tempFirstStoreId = storeid from #tblTempStoreId;

	declare t_cursorDepartment cursor for 
	select storeId,sProductId from #tblTempProductId 
	open t_cursorDepartment
	fetch next from t_cursorDepartment into @tempProductStoreId,@tempProductIdLoop
	while @@fetch_status = 0
	begin
		--set @s = 'insert into test3(sGroup,sName,['+ @tempFirstStoreId +'])values(';
		--set @s = @s + ''''+ @tempCategory +''','''+ @tempCategory +''',''departmentName''';
		--set @s = @s + ')';
		--exec(@s);
		--Print 'Begin---' + cast(GETUTCDATE() as varchar(50));

		declare t_cursorItemName cursor for 
		select sName from #tblTempItemName 
		open t_cursorItemName
		fetch next from t_cursorItemName into @tempItemName
		while @@fetch_status = 0
		begin
			--Print 'Begin--------' + cast(GETUTCDATE() as varchar(50));
			--declare t_cursorStoreId cursor for 
			--select storeId from #tblTempStoreId 
			--open t_cursorStoreId
			--fetch next from t_cursorStoreId into @tempStoreId
			--while @@fetch_status = 0
			--begin
				declare @tempItemValue varchar(50);
				set @tempItemValue = '0.00';
				declare @isExist int;
				select @isExist = count(sname) from test3 
					where sProductId = @tempProductIdLoop and sName= @tempItemName;

				select @tempItemValue= isnull(itemValue,'0') from #tblFinal 
					where sName= @tempItemName and sProductId = @tempProductIdLoop;

					

				if @isExist = 0
				Begin
					set @s = 'insert into test3(sProductId,sName,['+ @tempProductStoreId +'])values(';
					set @s = @s + ''''+ @tempProductIdLoop +''','''+ @tempItemName +''','''+ @tempItemValue +'''';
					set @s = @s + ')';
					exec(@s);
				End
				Else
				Begin
					set @s = 'update test3 set ['+ @tempProductStoreId +'] = '''+ @tempItemValue +''' where ';
					set @s = @s + ' sProductId = '''+ @tempProductIdLoop +''' and sName = '''+ @tempItemName +''''
					exec(@s);
				End

			--	fetch next from t_cursorStoreId into @tempStoreId
			--End
			--close t_cursorStoreId
			--deallocate t_cursorStoreId

			fetch next from t_cursorItemName into @tempItemName
		End
		close t_cursorItemName
		deallocate t_cursorItemName

		--set @s = 'insert into test3(sGroup,sGroupCategory,sName)values(';
		--set @s = @s + ''''','''+ @tempCategory +''',''zzSpaceRow''';
		--set @s = @s + ')';
		--exec(@s);

		fetch next from t_cursorDepartment into @tempProductStoreId,@tempProductIdLoop
	End
	close t_cursorDepartment
	deallocate t_cursorDepartment

	delete from test3 where sname = 'productId';
	
	--Calculate the Total Amount--------------------------------------
	insert into test3(sGroup,sGroupCategory,sName)values('zzzTotal','zzzTotal','zzzTotal');

	declare t_cursorStoreId cursor for 
	select storeId from #tblTempStoreId 
	open t_cursorStoreId
	fetch next from t_cursorStoreId into @tempProductIdLoop
	while @@fetch_status = 0
	begin
		set @s = 'declare @tempColumnValue decimal(18,4);';
		set @s = @s + 'select @tempColumnValue = sum(cast(isnull(['+ @tempProductIdLoop +'],''0'') as decimal(18,4))) from test3 where sName=''     Sales Amount($)'';';
		set @s = @s + 'update test3 set ['+ @tempProductIdLoop +'] = cast(@tempColumnValue as varchar(50)) where sGroup = ''zzzTotal'';';
		--set @s = @s + 'print @tempColumnValue;';
		exec(@s);
		set @s = 'update test3 set ['+ @tempProductIdLoop +'] = isnull(['+ @tempProductIdLoop +'],''0'');';
		exec(@s);

		fetch next from t_cursorStoreId into @tempProductIdLoop
	End
	close t_cursorStoreId
	deallocate t_cursorStoreId

	--INSERT AN SPACE ROW FOR EVERY DEPARTMENT.
	declare t_cursorDepartment cursor for 
	select distinct Department,category from #tblTempDepartment 
	open t_cursorDepartment
	fetch next from t_cursorDepartment into @tempDepartment,@tempCategory
	while @@fetch_status = 0
	begin
		insert into test3(sGroup,sGroupCategory,sProductId,sName)values(@tempDepartment,@tempCategory,'zzSpaceRow','zzSpaceRow');
		fetch next from t_cursorDepartment into @tempDepartment,@tempCategory
	End
	close t_cursorDepartment
	deallocate t_cursorDepartment
	--iNSERT END.

	update test3 set sGroup = department, sGroupCategory = Category, sProductId = ProductName  from #tblTempDepartment where ProductId = test3.sproductId;

	select * from test3 ORDER By sGroup, sGroupCategory,sproductId, sName;

	drop table test3;
	--------------------------------------------------------------------------------
	drop table #tblTempStoreId;
	drop table #tblTempDepartment;
	drop table #tblTempProductId;
	drop table #tblTempItemName;
	drop table #tblWhole;
	drop table #tbl2;
	drop table #tbl3;
	drop table #tbl4;	
	drop table #tbl5;	
	drop table #tblFinal;	
	drop table #tblProductIdGroup;	




END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetSerialNumberInfo]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetSerialNumberInfo]
	@SN varchar(50),
	@SONumber varchar(50),
	@PONumber varchar(50),
	@PLUBarcode varchar(50)
AS
BEGIN
	
	Select 
	pkp.plu,
	pkp.barcode,
	pkp.name1 as productName,
	PKPO.POID,
	PKSO.SOID,
	pksn.sn,
	PKPO.Orderid as POOrderid,
	PKSO.Orderid as SOOrderid,
	PKPO.PurchaseFTitle as vendor,
	PKSO.SoldToTitle as customer,
	PKSN.remark

	FROM PKProductSNExpire AS PKSN 
		inner join pkProduct Pkp on pkp.id = pksn.productId
		left join PKReceiveProduct pkrp on pksn.ReceiveProductId = pkrp.ReceiveProductID
		left join pkReceive pkr on pkr.id = pkrp.ReceiveID

		LEFT JOIN PKPOProduct PKPP ON pkpp.POProductID = pkrp.POProductID
		LEFT JOIN PKPO ON PKPP.POID = PKPO.POID 

		LEFT OUTER JOIN PKSOProduct ON PKSN.SOProductID = PKSOProduct.SOProductID 
		LEFT OUTER JOIN PKSO ON PKSOProduct.SOID = PKSO.SOID 
		
		LEFT OUTER JOIN PKInboundProduct ON PKSN.ReceiveProductId = PKInboundProduct.ID 
		LEFT JOIN PKInbound ON PKInbound.ID = PKInboundProduct.InboundID 
		
		--LEFT OUTER JOIN PKOutboundProduct AS OP ON PKSN.SOProductID= OP.ID 
		--LEFT OUTER JOIN PKOutbound AS O ON OP.OutboundID = O.ID 

		where 
		(
			@SN = '' or
			(
				@SN <> '' and 
				(
					pksn.sn = @sn
				)
			)
		)
		and 
		(
			@SONumber = '' or
			(
				@SONumber <> '' and 
				(
					PKSO.OrderId like '%'+ @SONumber +'%'
				)
			)
		)
		and 
		(
			@PONumber = '' or
			(
				@PONumber <> '' and 
				(
					PKPO.OrderId like '%'+ @PONumber +'%'
				)
			)
		)

		and 
		(
			@PLUBarcode = '' or
			(
				@PLUBarcode <> '' and 
				(
					PKP.PLU like '%'+ @PLUBarcode +'%'  
					or
					PKP.Barcode like '%'+ @PLUBarcode +'%'  
				)
			)
		)
		and isnull(pksn.Status,'')=''


		;
	--SELECT 
	--	CASE WHEN PKPOProduct.PLU IS NULL THEN PKInboundProduct.PLU ELSE PKPOProduct.PLU END AS PLU,
	--	CASE WHEN PKPOProduct.ProductName1 IS NULL THEN PKInboundProduct.ProductName1 ELSE PKPOProduct.ProductName1 END AS ProductName,
	--	CASE WHEN PKPO.POID IS NULL THEN PKInbound.ID ELSE PKPO.POID END AS POID, CASE WHEN PKSO.SOID IS NULL THEN O.ID ELSE PKSO.SOID END AS SOID, 
	--	SN,
	--	CASE WHEN PKPO.OrderID IS NULL THEN Convert(nvarchar(50),PKInbound.seq) ELSE PKPO.OrderID END AS POOrderID, 
	--	CASE WHEN PKSO.OrderID IS NULL THEN O.ID ELSE PKSO.OrderID END AS SOOrderID, 
	--	PKPO.PurchaseFTitle AS Vendor, 
	--	PKSO.SoldToTitle AS Customer,  
	--	PKSN.Remark  
	--	into #tbl1
	--	FROM PKProductSNExpire AS PKSN 
	--	LEFT JOIN PKPOProduct  ON PKSN.POProductID = PKPOProduct.POProductID 
	--	LEFT JOIN PKPO ON PKPOProduct.POID = PKPO.POID 
	--	LEFT OUTER JOIN PKSOProduct ON PKSN.SOProductID = PKSOProduct.SOProductID 
	--	LEFT OUTER JOIN PKSO ON PKSOProduct.SOID = PKSO.SOID 
	--	LEFT OUTER JOIN PKInboundProduct ON PKSN.POProductID = PKInboundProduct.ID 
	--	LEFT JOIN PKInbound ON PKInbound.ID = PKInboundProduct.InboundID 
	--	LEFT OUTER JOIN PKOutboundProduct AS OP ON PKSN.SOProductID= OP.ID 
	--	LEFT OUTER JOIN PKOutbound AS O ON OP.OutboundID = O.ID 
	--	where (@SN='' or (@SN<>'' and sn=@SN))
	--	;

	--	select * from #tbl1 
	--	where (@SONumber = '' or (@SONumber <> '' and SOOrderID = @SONumber )) and
	--	      (@PONumber = '' or (@PONumber <> '' and POOrderID = @PONumber ))



	--	drop table #tbl1
END





GO
/****** Object:  StoredProcedure [dbo].[PK_GetSerialNumberList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetSerialNumberList]
	@ProductID varchar(50),
	@SoOrTicket varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from  
	-- interfering with SELECT statements.  
	SET NOCOUNT ON;

	--ID,SN,outBoundProductId

	SELECT * INTO #tbl1 FROM PKProductSNExpire WHERE ProductID = @ProductID and isnull(SOProductId,'') = '' ORDER BY sn

	SELECT PKSOProduct.SOProductID AS outBoundProductId, PKSO.OrderID AS OrderID INTO #tbl2 FROM PKSOProduct 
	INNER JOIN PKSO ON PKSO.SOID = PKSOProduct.SOID 
	WHERE PKSOProduct.ProductID = @ProductID

	INSERT INTO #tbl2(outBoundProductId, OrderID)
	SELECT PKSTProduct.STProductID AS outBoundProductId, PKST.TicketID AS OrderID FROM PKSTProduct 
	INNER JOIN PKSt ON PKST.STID = PKSTProduct.STID 
	WHERE PKSTProduct.ProductID = @ProductID

	if @SoOrTicket = 's' 
	begin
		delete from #tbl2 where orderid like 'T%'
	end
	if @SoOrTicket = 't' 
	begin
		delete from #tbl2 where orderid like 'S%'
	end

	SELECT pksn.ID, pksn.SN, pksn.outBoundProductId, isnull(pkorder.OrderID, '') AS OrderID FROM #tbl1 AS pksn 
	LEFT JOIN #tbl2 AS pkorder ON pksn.outBoundProductId = pkorder.outBoundProductId ORDER BY pksn.SN

	DROP TABLE #tbl1; 
	DROP TABLE #tbl2;
END

GO
/****** Object:  StoredProcedure [dbo].[Pk_getsolist]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Pk_getsolist] @LocationID    VARCHAR(50), 
                              @SONO          VARCHAR(50), 
                              @SOID          VARCHAR(50), 
                              @TimeFrom      VARCHAR(50), 
                              @TimeTo        VARCHAR(50), 
                              @DateType      VARCHAR(50), 
                              @Status        VARCHAR(50), 
                              @ProductName   NVARCHAR(50), 
                              @PLU           VARCHAR(50), 
                              @Barcode       VARCHAR(50), 
                              @CustomerID    VARCHAR(50), 
                              @CustomerPhone VARCHAR(50), 
                              @Sales         VARCHAR(50), 
							  @OrderedBy	 VARCHAR(50),
                              @BrandName     VARCHAR(50), 
                              @ReturnNo      VARCHAR(50), 
                              @Remarks       VARCHAR(200)
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from  
      -- interfering with SELECT statements.  
      SET nocount ON; 
      update PKSOProduct set seqOrder = seq where ISNULL(seqorder,0)=0;
      SELECT DISTINCT pkso.soid, 
                      pkso.orderid, 
                      pkso.soldtotitle, 
                      pkso.filestartdate, 
                      pkso.orderdate, 
                      pkso.filestartdate, 
                      soenddate, 
                      orderby, 
                      fileendby, 
                      pkso.totalamount AS TotalAmount, 
                      pkso.locationid, 
                      CASE Lower(@Status) 
                        WHEN 'draft' THEN pkso.orderdate 
                        WHEN 'pending' THEN pkso.orderdate 
                        WHEN 'complete' THEN pkso.shipdate 
                        WHEN 'cancel' THEN pkso.shipdate 
                        ELSE pkso.orderdate 
                      END              AS OrderbyField ,
			isnull(pkso.TerminalType,'') as TerminalType

      FROM   pkso 
             LEFT OUTER JOIN pksoproduct PSP 
                          ON pkso.soid = PSP.soid 
             --LEFT OUTER JOIN pkproduct pp 
             --             ON PSP.productid = pp.id 
             LEFT OUTER JOIN pksoreturn PSR 
                          ON pkso.soid = PSR.soid 
      WHERE  
		pkso.TYPE != 'Contract' 
             and
	  ( @SONO = '' 
                OR ( @SONO <> '' 
                     AND pkso.orderid LIKE '%' + @SONO + '%' ) ) 
             AND ( @SOID = '' 
                    OR ( @SOID <> '' 
                         AND pkso.soid = @SOID ) ) 
             AND ( @LocationID = '' 
                    OR ( @LocationID <> '' 
                         AND pkso.locationid = @LocationID ) ) 
             AND ( @TimeFrom = '' 
                    OR ( @TimeFrom <> '' 
                         AND ( @DateType = '0' 
                               AND pkso.orderdate >= @TimeFrom ) 
                          OR ( @DateType = '3' 
                               AND pkso.shipdate >= @TimeFrom ) 
                          OR ( @DateType = '1' 
                               AND PSR.returndate >= @TimeFrom ) ) ) 
             AND ( @TimeTo = '' 
                    OR ( @TimeTo <> '' 
                         AND ( @DateType = '0' 
                               AND pkso.orderdate <= @TimeTo ) 
                          OR ( @DateType = '3' 
                               AND pkso.shipdate <= @TimeTo ) 
                          OR ( @DateType = '1' 
                               AND PSR.returndate <= @TimeTo ) ) ) 
             AND ( @Status = '' 
                    OR ( @Status <> '' 
                         AND 
						 (
						 (Lower(@Status)='preorder' and (Lower(pkso.status)='back' or Lower(pkso.status)='pending') and isnull(pkSo.preOrder,'false')='true')
						 or 
						 (Lower(@Status)='back' and Lower(pkso.status)='back'  and isnull(pkSo.preOrder,'false')<>'true')
						 or 
						 (Lower(@Status)='pending' and Lower(pkso.status)='pending'  and isnull(pkSo.preOrder,'false')<>'true')
						 or
						 (Lower(@Status)<>'pending' and Lower(@Status)<>'back' and Lower(@Status)<>'preorder' and Lower(pkso.status) = Lower(@Status) )
						 --
						 )
						 ) ) 
             AND ( @ProductName = '' 
                    OR ( @ProductName <> '' 
                         AND psp.productname1 + psp.productname2 LIKE N'%' + 
                             @ProductName + '%' 
                       ) ) 
             AND ( @PLU = '' 
                    OR ( @PLU <> '' 
                         AND psp.plu LIKE '%' + @PLU + '%' ) ) 
             AND ( @Barcode = '' 
                    OR ( @Barcode <> '' 
                         AND psp.barcode LIKE '%' + @Barcode + '%' ) ) 
             AND ( @CustomerID = '' 
                    OR ( @CustomerID <> '' 
                         AND PKSO.CustomerID = @CustomerID ) ) 
             AND ( @CustomerPhone = '' 
                    OR ( @CustomerPhone <> '' 
                         AND PKSO.ComTEL+PKSO.ShipTTEL LIKE '%' + @CustomerPhone + '%' ) ) 
             AND ( @OrderedBy = '' 
                          OR ( @OrderedBy <> '' 
                               AND pkso.OrderBy = @OrderedBy ) ) 
             AND ( @Remarks = '' 
                    OR ( @Remarks <> '' 
                         AND PKSO.SORemarks LIKE N'%' + @Remarks + '%' ) ) 
      ORDER  BY orderbyfield DESC 

     
  END 



GO
/****** Object:  StoredProcedure [dbo].[PK_GetSOProductForPrint]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

  
CREATE PROCEDURE [dbo].[PK_GetSOProductForPrint] @SOID        VARCHAR(50), 
                                                @OutBoundSeq INT 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from   
      -- interfering with SELECT statements.   
      SET nocount ON; 

      DECLARE @IsPreOrder BIT; 

      SET @isPreorder = 0; 

      SELECT @isPreorder = CASE Isnull(preorder, '') 
                             WHEN 'true' THEN 1 
                             ELSE 0 
                           END 
      FROM   pkso 
      WHERE  soid = @SOID; 

      IF @IsPreOrder = 1 
        BEGIN 
            IF @OutBoundSeq = 0 
              BEGIN 
                  SELECT DISTINCT PSP.plu, 
                                  PSP.barcode, 
                                  PSP.soproductid, 
                                  PSP.soid, 
                                  PSP.productid, 
                                  PSP.productname1, 
								  case isnull(PKProduct.Name1,'') when '' then PSP.productname1 else PKProduct.Name1 end as PureProductname,
								  isnull(PKProduct.Size,'') as Size,
								  isnull(cast(PKProduct.PackL as varchar(50)),'1') + 'x' +isnull(cast(PKProduct.PackM as varchar(50)),'1') + 'x' +isnull(cast(PKProduct.PackS as varchar(50)),'1')  as packSize,
								  isnull(PKProduct.Description1,'') as description1,
                                  CASE 
                                    WHEN PSP.unit = '0' THEN 
                                      CASE 
                                        WHEN unitname = '' 
                                              OR unitname IS NULL THEN 'ea' 
                                        ELSE unitname 
                                      END 
                                    WHEN PSP.unit = '1' THEN 'lb' 
                                    WHEN PSP.unit = '2' THEN 'kg' 
                                    ELSE PSP.unit 
                                  END           AS Unit, 
                                  PSP.unitcost, 
                                  PSP.orderqty, 
                                  PSP.totalcost, 
                                  --shippingqty,   
                                  POBP.orderqty AS shippingqty, 
                                  backqty, 
                                  PSP.seq, 
								  psp.seqOrder,
                                  serialnumbers, 
                                  soproductremarks, 
                                  type 
                  INTO   #tbl1 
                  FROM   pksoproduct PSP 
                         LEFT OUTER JOIN pkoutbound POB 
                                      ON pob.soid = PSP.soid 
                         LEFT OUTER JOIN pkoutboundproduct POBP 
                                      ON POBP.outboundid = pob.id 
                                         AND POBP.productid = PSP.productid 
                         LEFT OUTER JOIN pkproduct 
                                      ON PSP.productid = pkproduct.id 
                  WHERE  PSP.soid = @SOID; 

                  SELECT plu, 
                         barcode, 
                         soproductid, 
                         soid, 
                         productid, 
                         productname1, 
						 PureProductname,
						 packSize,
						 description1,
                         unit, 
                         unitcost, 
                         orderqty, 
                         totalcost, 
                         Sum(shippingqty) AS shippingqty, 
                         backqty, 
                         seq, 
                         serialnumbers, 
                         soproductremarks, 
                         type 
                  FROM   #tbl1 
                  GROUP  BY plu, 
                            barcode, 
                            soproductid, 
                            soid, 
                            productid, 
                            productname1, 
							PureProductname,
							packSize,
						 description1,
                            unit, 
                            unitcost, 
                            orderqty, 
                            totalcost, 
                            backqty, 
                            seq, 
							seqOrder,
                            serialnumbers, 
                            soproductremarks, 
                            type
				  order by seqOrder		
				  ; 
					
                  DROP TABLE #tbl1; 
              END 
            ELSE 
              BEGIN 
                  SELECT DISTINCT PSP.plu, 
                                  PSP.barcode, 
                                  PSP.soproductid, 
                                  PSP.soid, 
                                  PSP.productid, 
                                  PSP.productname1, 
								  case isnull(PKProduct.Name1,'') when '' then PSP.productname1 else PKProduct.Name1 end as PureProductname,
								  isnull(cast(PKProduct.PackL as varchar(50)),'1') + 'x' +isnull(cast(PKProduct.PackM as varchar(50)),'1') + 'x' +isnull(cast(PKProduct.PackS as varchar(50)),'1')  as packSize,
								  isnull(PKProduct.Size,'') as Size,
								  isnull(PKProduct.Description1,'') as description1,
                                  CASE 
                                    WHEN PSP.unit = '0' THEN 
                                      CASE 
                                        WHEN unitname = '' 
                                              OR unitname IS NULL THEN 'ea' 
                                        ELSE unitname 
                                      END 
                                    WHEN PSP.unit = '1' THEN 'lb' 
                                    WHEN PSP.unit = '2' THEN 'kg' 
                                    ELSE PSP.unit 
                                  END           AS Unit, 
                                  PSP.unitcost, 
                                  PSP.orderqty, 
                                  PSP.totalcost, 
                                  --shippingqty,   
                                  POBP.orderqty AS shippingqty, 
                                  backqty, 
                                  PSP.seq, 
								  PSP.seqOrder
                                  serialnumbers, 
                                  soproductremarks, 
                                  type 
                  FROM   pksoproduct PSP 
                         LEFT OUTER JOIN pkoutbound POB 
                                      ON pob.soid = PSP.soid 
                         LEFT OUTER JOIN pkoutboundproduct POBP 
                                      ON POBP.outboundid = pob.id 
                                         AND POBP.productid = PSP.productid 
                         LEFT OUTER JOIN pkproduct 
                                      ON PSP.productid = pkproduct.id 
                  WHERE  PSP.soid = @SOID 
                         AND POB.seq = @OutBoundSeq 
				  order by psp.seqOrder
              END 
        END 
      ELSE 
        BEGIN 
            SELECT PSP.plu, 
                   PSP.barcode, 
                   PSP.soproductid, 
                   PSP.soid, 
                   PSP.productid, 
                   PSP.productname1, 
								  case isnull(PKProduct.Name1,'') when '' then PSP.productname1 else PKProduct.Name1 end as PureProductname,
								  isnull(PKProduct.Size,'') as Size,
								  isnull(cast(PKProduct.PackL as varchar(50)),'1') + 'x' +isnull(cast(PKProduct.PackM as varchar(50)),'1') + 'x' +isnull(cast(PKProduct.PackS as varchar(50)),'1')  as packSize,
								  isnull(PKProduct.Description1,'') as description1,
                   CASE 
                     WHEN PSP.unit = '0' THEN 
                       CASE 
                         WHEN unitname = '' 
                               OR unitname IS NULL THEN 'ea' 
                         ELSE unitname 
                       END 
                     WHEN PSP.unit = '1' THEN 'LB' 
                     WHEN PSP.unit = '2' THEN 'KG' 
                     ELSE PSP.unit 
                   END AS UNIT, 
                   PSP.unitcost, 
                   PSP.orderqty, 
                   PSP.totalcost, 
                   shippingqty, 
                   backqty, 
                   PSP.seq, 
                   serialnumbers, 
                   soproductremarks, 
                   type 
            FROM   pksoproduct PSP 
                   LEFT OUTER JOIN pkproduct 
                                ON PSP.productid = pkproduct.id 
            WHERE  soid = @soid 
		    order by seqOrder
        END 
  END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetSOReportBackOrder]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetSOReportBackOrder] @StoreName    VARCHAR(50), 

                                                --@ComputerName varchar(50), 
                                                @FromDateTime VARCHAR(50), 
                                                @ToDateTime   VARCHAR(50), 
                                                @DepartmentID VARCHAR(50), 
                                                @CategoryId   VARCHAR(50), 
                                                @CustomerId   VARCHAR(50), 
                                                @DateField    VARCHAR(50), 
                                                @ReportType   VARCHAR(50), 
                                                @PLU          VARCHAR(50), 
                                                @Productname  VARCHAR(50), 
                                                @Employee     VARCHAR(50), 
                                                @Price        VARCHAR(50), 
                                                @Status       VARCHAR(50) 
AS 
  BEGIN 
      SET nocount ON; 

      IF @DateField IS NULL 
        BEGIN 
            SET @DateField = ''; 
        END 

      IF @ReportType IS NULL 
        BEGIN 
            SET @ReportType = ''; 
        END 

      IF @customerId IS NULL 
        BEGIN 
            SET @customerId = '-1'; 
        END 

      IF @PLU IS NULL 
        BEGIN 
            SET @PLU = ''; 
        END 

      IF @Productname IS NULL 
        BEGIN 
            SET @Productname = ''; 
        END 

      IF @Price IS NULL 
        BEGIN 
            SET @Price = 0; 
        END 

      IF @CategoryId IS NULL 
        BEGIN 
            SET @CategoryId = 0; 
        END 

      IF @DepartmentID IS NULL 
        BEGIN 
            SET @DepartmentID = 0; 
        END 

      IF @Employee IS NULL 
        BEGIN 
            SET @DepartmentID = 'ALL employee'; 
        END 

      DECLARE @s VARCHAR(max); 
      DECLARE @tempDecNumber DECIMAL(18, 2); 
      DECLARE @tempString VARCHAR(50); 

      SET @tempString = 
      '1234567891012345678910123456789101234567891012345678910'; 
      SET @tempDecNumber = 1000000.00; 

      --======================================================================================= 
      SELECT SOProduct.locationid, 
             plu, 
             productname1, 
             CONVERT(VARCHAR(100), orderdate, 23)            AS OrderDate, 
             orderid, 
             unitcost                                        AS TotalCost, 
             shippingqty, 
             orderqty, 
             backqty, 
             ( unitcost - Isnull(averagecost, 0) ) * backqty AS Profit, 
             Isnull(averagecost, 0) * backqty                AS AverageCost 
      INTO   #tbl1 
      FROM   pkso 
             JOIN pkviewsoreport_orderproduct AS SOProduct 
               ON pkso.soid = SOProduct.soid 
             LEFT JOIN pksoproducttax AS GSTTax 
                    ON SOProduct.soid = GSTTax.soid 
                       AND SOProduct.productid = GSTTax.productid 
                       AND GSTTax.taxname = 'GST' 
             LEFT JOIN pksoproducttax AS PSTTax 
                    ON SOProduct.soid = PSTTax.soid 
                       AND SOProduct.productid = PSTTax.productid 
                       AND PSTTax.taxname = 'PST' 
             LEFT JOIN pkcustomermultiadd 
                    ON pkso.customerid = pkcustomermultiadd.id 
      WHERE  pkso.status = 'Shipped' 
             AND SOProduct.backqty > 0 
             AND CASE @DateField 
                   WHEN 'ShipDate' THEN shipdate 
                   WHEN 'SOEndDate' THEN soenddate 
                   ELSE orderdate 
                 END >= @FromDateTime 
             AND CASE @DateField 
                   WHEN 'ShipDate' THEN shipdate 
                   WHEN 'SOEndDate' THEN soenddate 
                   ELSE orderdate 
                 END <= @ToDateTime 
             AND ( @ReportType <> 'Sales Report - BackOrder' 
                    OR ( @ReportType = 'Sales Report - BackOrder' 
                         AND pkso.status = 'Shipped' 
                         AND SOProduct.backqty > 0 ) ) 
             AND ( @StoreName = '' 
                    OR ( @StoreName <> '' 
                         AND pkso.locationid = @StoreName 
                         AND ( @Employee = 'ALL employee' 
                                OR pkso.orderby = @Employee ) ) ) 
             AND ( @customerId = '-1' 
                    OR ( @customerId <> '-1' 
                         AND pkso.customerid = @customerId ) ) 
             AND ( @DepartmentId = '' 
                    OR ( @DepartmentId <> '' 
                         AND departmentid = @DepartmentId ) ) 
             AND ( @CategoryId = '' 
                    OR ( @CategoryId <> '' 
                         AND categoryid = @CategoryId ) ) 
             AND ( @PLU = '' 
                    OR ( @PLU <> '' 
                         AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
             AND ( @Productname = '' 
                    OR ( @Productname <> '' 
                         AND SOProduct.productname1 LIKE 
                             '%' + @Productname + '%' 
                       ) ) 
             AND ( @Price = 0 
                    OR ( @Price <> 0 
                         AND SOProduct.unitcost = @Price ) ) 
      ORDER  BY orderid ASC; 

      SELECT locationid, 
             plu, 
             productname1, 
             orderdate, 
             orderid, 
             totalcost, 
             shippingqty, 
             orderqty, 
             backqty, 
             profit, 
             averagecost, 
             CASE averagecost 
               WHEN 0 THEN 0 
               ELSE Cast(profit / averagecost AS NUMERIC(18, 4)) * 100 
             END AS ProfitMargin 
      FROM   #tbl1; 

      DROP TABLE #tbl1; 
  END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetSOReportCategory]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetSOReportCategory] @StoreName    VARCHAR(50), 

                                               --@ComputerName varchar(50), 
                                               @FromDateTime VARCHAR(50), 
                                               @ToDateTime   VARCHAR(50), 
                                               @DepartmentID VARCHAR(50), 
                                               @CategoryId   VARCHAR(50), 
                                               @CustomerId   VARCHAR(50), 
                                               @DateField    VARCHAR(50), 
                                               @ReportType   VARCHAR(50), 
                                               @PLU          VARCHAR(50), 
                                               @Productname  VARCHAR(50), 
                                               @Employee     VARCHAR(50), 
                                               @Price        VARCHAR(50), 
                                               @Status       VARCHAR(50) 
AS 
  BEGIN 
      SET nocount ON; 

      IF @DateField IS NULL 
        BEGIN 
            SET @DateField = ''; 
        END 

      IF @ReportType IS NULL 
        BEGIN 
            SET @ReportType = ''; 
        END 

      IF @customerId IS NULL 
        BEGIN 
            SET @customerId = '-1'; 
        END 

      IF @PLU IS NULL 
        BEGIN 
            SET @PLU = ''; 
        END 

      IF @Productname IS NULL 
        BEGIN 
            SET @Productname = ''; 
        END 

      IF @Price IS NULL 
        BEGIN 
            SET @Price = 0; 
        END 

      IF @CategoryId IS NULL 
        BEGIN 
            SET @CategoryId = 0; 
        END 

      IF @DepartmentID IS NULL 
        BEGIN 
            SET @DepartmentID = 0; 
        END 

      IF @Employee IS NULL 
        BEGIN 
            SET @DepartmentID = 'ALL employee'; 
        END 

      DECLARE @s NVARCHAR(max); 
      DECLARE @tempDecNumber DECIMAL(18, 2); 
      DECLARE @tempString NVARCHAR(50); 

      SET @tempString = 
      '1234567891012345678910123456789101234567891012345678910'; 
      SET @tempDecNumber = 1000000.00; 

      --======================================================================================= 
      --======================================================================================= 
      SELECT @tempString    AS LocationID, 
             @tempString    AS DepartmentName, 
             @tempString    AS CategoryID, 
             @tempString    AS CategoryName, 
             @tempDecNumber AS OrderQty, 
             @tempDecNumber AS TotalCost, 
             @tempDecNumber AS Profit, 
             @tempDecNumber AS AverageCost 
      INTO   #tblwhole; 

      DELETE FROM #tblwhole; 

      IF @DateField = 'ShipDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   SOProduct. departmentname, 
                   SOProduct.categoryid, 
                   SOProduct.categoryname, 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) ) 
                   AND pkso.shipdate >= @FromDateTime 
                   AND pkso.shipdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct.departmentname, 
                      SOProduct.categoryid, 
                      SOProduct.categoryname 
        END 
	  ELSE IF @DateField = 'SOEndDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   SOProduct. departmentname, 
                   SOProduct.categoryid, 
                   SOProduct.categoryname, 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE type != 'Contract' 
                   AND (
						(pkso.status = 'Shipped' 
						   AND soenddate >= @FromDateTime 
                           AND soenddate <= @ToDateTime )
						or
						(pkso.status = 'Pending' and isnull(PKSO.PreOrder,'')='true'
						   AND orderdate >= @FromDateTime 
                           AND orderdate <= @ToDateTime
						)
				   )

                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct.departmentname, 
                      SOProduct.categoryid, 
                      SOProduct.categoryname 
        END 
      ELSE 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   SOProduct. departmentname, 
                   SOProduct.categoryid, 
                   SOProduct.categoryname, 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_orderproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) )  
                   AND pkso.orderdate >= @FromDateTime 
                   AND pkso.orderdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct.departmentname, 
                      SOProduct.categoryid, 
                      SOProduct.categoryname 
        END 

      --======================================================================================= 
      SELECT @tempString                       AS Category, 
             locationid                        AS storeId, 
             departmentname                    AS department, 
             categoryid, 
             categoryname                      AS CategoryName, 
             totalcost                         AS [     Sales Amount($)], 
             --OrderQty as [    QTY], 
             --AverageCost as [   AverageCost], 
             profit                            AS [  Profit($)], 
             CASE averagecost 
               WHEN 0 THEN 0 
               ELSE Cast(profit / averagecost AS NUMERIC(18, 4)) 
             END                               AS [ ProfitMargin(%)], 
             Isnull(averagecost, 0) * orderqty AS SubCost 
      INTO   #tbl1 
      FROM   #tblwhole 

      ALTER TABLE #tbl1 
        ADD tempid INT IDENTITY(1, 1); 

      UPDATE #tbl1 
      SET    category = Cast(tempid AS VARCHAR(50)); 

      --declare @intLoop int; 
      --set @intLoop = 1; 
      --declare @thisLoopCategoryId varchar(50); 
      --declare t_LoopCategoryId cursor for  
      --select distinct CategoryId from #tbl1  
      --open t_LoopCategoryId 
      --fetch next from t_LoopCategoryId into @thisLoopCategoryId 
      --while @@fetch_status = 0 
      --begin 
      --  update #tbl1 set Category = cast(@intLoop as varchar(50)) where CategoryId = @thisLoopCategoryId;
      --  set @intLoop = @intLoop + 1;  
      --fetch next from t_LoopCategoryId into @thisLoopCategoryId 
      --End 
      --close t_LoopCategoryId; 
      --deallocate t_LoopCategoryId; 
      --select * from #tbl1 
      SELECT DISTINCT department, 
                      category, 
                      categoryid, 
                      categoryname 
      INTO   #tbltempdepartmentcategory 
      FROM   #tbl1; 

      --======================================================================================= 
      --select * from #tbl1; 
      SELECT @tempString AS StoreID, 
             @tempString AS sGroup, 
             @tempString AS sName, 
             @tempString AS itemValue 
      INTO   #tblfinal; 

      DELETE FROM #tblfinal; 

      ---------------------------------------------------------------------- 
      DECLARE @thisStoreId NVARCHAR(50); 
      DECLARE t_cursordepart CURSOR FOR 
        SELECT DISTINCT storeid 
        FROM   #tbl1 

      OPEN t_cursordepart 

      FETCH next FROM t_cursordepart INTO @thisStoreId 

      WHILE @@fetch_status = 0 
        BEGIN 
            ---------------------------------------------------------------------- 
            SET @s = 
        'create table test2(storeId nvarchar(50), sName nvarchar(50)' 
            ; 

            SELECT @s = @s + ',[' + Cast(category AS NVARCHAR(10)) 
                        + '] nvarchar(50)' 
            FROM   #tbl1 
            WHERE  storeid = @thisStoreId 
            ORDER  BY Len(category) ASC, 
                      category; 

            SET @s = @s + ')'; 

            -- -- print @s; 
            --print len(@s); 
            EXEC(@s); 

            DECLARE @nameDate NVARCHAR(50) 
            -- print '---------------------------------' 
            DECLARE t_cursor CURSOR FOR 
              SELECT NAME 
              FROM   tempdb.dbo.syscolumns 
              WHERE  id = Object_id('Tempdb.dbo.#tbl1') 
              ORDER  BY colid --and colid<>1 

            OPEN t_cursor 

            FETCH next FROM t_cursor INTO @nameDate 

            WHILE @@fetch_status = 0 
              BEGIN 
                  BEGIN try 
                      SET @s ='select replace([' + @nameDate 
                              + 
            '],'''''''','''') as t into test4 from #tbl1 where storeid = ''' 
                    + @thisStoreId + ''''; 

                      -- print @s; 
                      EXEC(@s); 

                      SET @s='insert into test2 select ''' 
                             + @thisStoreId + ''',''' + @nameDate + '''' 

                      SELECT @s = @s + ',N''' + Rtrim(Isnull(t, 0)) + '''' 
                      FROM   test4; 

                      -- print '111111111111111' 
                      -- print @s; 
                      EXEC(@s) 

                      -- print '2222222222222222' 
                      EXEC('DROP TABLE test4;') 
                  END try 

                  BEGIN catch 
                      BEGIN try 
                          EXEC('DROP TABLE test4') 
                      END try 

                      BEGIN catch 
                      END catch 

                      PRINT Error_message(); 

                      PRINT ''; 
                  END catch 

                  FETCH next FROM t_cursor INTO @nameDate 
              END 

            --select 3; 
            --select * from test2; 
            DECLARE @ColumnName NVARCHAR(50); 
            DECLARE t_cursortest2 CURSOR FOR 
              SELECT NAME 
              FROM   syscolumns 
              WHERE  id = Object_id('test2') 
                     AND colid > 2 

            OPEN t_cursortest2 

            FETCH next FROM t_cursortest2 INTO @ColumnName 

            WHILE @@fetch_status = 0 
              BEGIN 
                  SET @s ='declare @departmentName nvarchar(50);'; 
                  SET @s = @s + 'set @departmentName = '''';'; 
                  SET @s = @s + 'select @departmentName = [' 
                           + @ColumnName 
                           + '] from test2 where sName = ''Category'';' 
                  SET @s = @s 
                           + 
'insert into #tblFinal select storeId, @departmentName as sGroup, sName, [' 
         + @ColumnName + '] as itemValue from test2'; 

EXEC(@s); 

FETCH next FROM t_cursortest2 INTO @ColumnName 
END 

CLOSE t_cursortest2 

DEALLOCATE t_cursortest2 

--select * from test2; 
CLOSE t_cursor 

DEALLOCATE t_cursor 

DROP TABLE test2; 

FETCH next FROM t_cursordepart INTO @thisStoreId 
END 

CLOSE t_cursordepart; 

DEALLOCATE t_cursordepart; 

--select 1; 
--select * from #tblFinal; 
DELETE FROM #tblfinal 
WHERE  sname = 'department'; 

-- print '======' 
--==============================================================================================
----------------------------------------------------------------------------- 
SELECT DISTINCT storeid 
INTO   #tbltempstoreid 
FROM   #tblfinal; 

SELECT DISTINCT sgroup 
INTO   #tbltempdepartment 
FROM   #tblfinal; 

SELECT DISTINCT sname 
INTO   #tbltempitemname 
FROM   #tblfinal; 

SET @s = 
'create table test3(sGroupDepartment nvarchar(50), sGroup nvarchar(50), sName nvarchar(50)' 
; 

SELECT @s = @s + ',[' + storeid + '] nvarchar(50)' 
FROM   #tbltempstoreid 

SET @s = @s + ')'; 

EXEC(@s); 

-- print @s; 
SET @s= 
'insert into test3 select ''  LOCATION'',''  LOCATION'',''  LOCATION''' 

SELECT @s = @s + ',''' + storeid + '''' 
FROM   #tbltempstoreid; 

EXEC(@s) 

DECLARE @tempStoreId NVARCHAR(50); 
DECLARE @tempDepartment NVARCHAR(50); 
DECLARE @tempItemName NVARCHAR(50); 
DECLARE @tempFirstStoreId NVARCHAR(50); 

SELECT TOP 1 @tempFirstStoreId = storeid 
FROM   #tbltempstoreid; 

DECLARE t_cursordepartment CURSOR FOR 
  SELECT sgroup 
  FROM   #tbltempdepartment 

OPEN t_cursordepartment 

FETCH next FROM t_cursordepartment INTO @tempDepartment 

WHILE @@fetch_status = 0 
  BEGIN 
      --set @s = 'insert into test3(sGroup,sName,['+ @tempFirstStoreId +'])values('; 
      --set @s = @s + ''''+ @tempDepartment +''','''+ @tempDepartment +''',''departmentName'''; 
      --set @s = @s + ')'; 
      --exec(@s); 
      DECLARE t_cursoritemname CURSOR FOR 
        SELECT sname 
        FROM   #tbltempitemname 

      OPEN t_cursoritemname 

      FETCH next FROM t_cursoritemname INTO @tempItemName 

      WHILE @@fetch_status = 0 
        BEGIN 
            DECLARE t_cursorstoreid CURSOR FOR 
              SELECT storeid 
              FROM   #tbltempstoreid 

            OPEN t_cursorstoreid 

            FETCH next FROM t_cursorstoreid INTO @tempStoreId 

            WHILE @@fetch_status = 0 
              BEGIN 
                  DECLARE @tempItemValue NVARCHAR(50); 

                  SET @tempItemValue = '0.00'; 

                  DECLARE @isExist INT; 

                  SELECT @isExist = Count(sgroup) 
                  FROM   test3 
                  WHERE  sgroup = ' ' + @tempDepartment 
                         AND sname = @tempItemName; 

                  SELECT @tempItemValue = Isnull(itemvalue, '0') 
                  FROM   #tblfinal 
                  WHERE  storeid = @tempStoreId 
                         AND sname = @tempItemName 
                         AND sgroup = @tempDepartment; 

                  --print @isExist; 
                  IF @isExist = 0 
                    BEGIN 
                        SET @s = 'insert into test3(sGroup,sName,[' 
                                 + @tempStoreId + '])values('; 
                        SET @s = @s + ''' ' + @tempDepartment + ''',''' 
                                 + @tempItemName + ''',N''' + @tempItemValue 
                                 + 
                                 ''''; 
                        SET @s = @s + ')'; 

                        -- print @s; 
                        EXEC(@s); 
                    END 
                  ELSE 
                    BEGIN 
                        SET @s = 'update test3 set [' + @tempStoreId + 
                                 '] = ''' 
                                 + @tempItemValue + ''' where '; 
                        SET @s = @s + ' sGroup = '' ' + @tempDepartment 
                                 + ''' and sName = N''' + @tempItemName + 
                                 '''' 

                        -- print @s; 
                        EXEC(@s); 
                    END 

                  FETCH next FROM t_cursorstoreid INTO @tempStoreId 
              END 

            CLOSE t_cursorstoreid 

            DEALLOCATE t_cursorstoreid 

            FETCH next FROM t_cursoritemname INTO @tempItemName 
        END 

      CLOSE t_cursoritemname 

      DEALLOCATE t_cursoritemname 

      --set @s = 'insert into test3(sGroup,sName)values('; 
      --set @s = @s + ''''+ @tempDepartment +''',''zzSpaceRow'''; 
      --set @s = @s + ')'; 
      --exec(@s); 
      FETCH next FROM t_cursordepartment INTO @tempDepartment 
  END 

CLOSE t_cursordepartment 

DEALLOCATE t_cursordepartment 

--select 2; 
--select * from test3; 
--============================================================================================ 
--Calculate the Total Amount-------------------------------------- 
INSERT INTO test3 
            (sgroupdepartment, 
             sgroup, 
             sname) 
VALUES     ('zzzTotal', 
            'zzzTotal', 
            'zzzTotal'); 

DECLARE t_cursorstoreid CURSOR FOR 
  SELECT storeid 
  FROM   #tbltempstoreid 

OPEN t_cursorstoreid 

FETCH next FROM t_cursorstoreid INTO @tempStoreId 

WHILE @@fetch_status = 0 
  BEGIN 
      SET @s = 'declare @tempColumnValue decimal(18,4);'; 
      SET @s = @s 
               + 'select @tempColumnValue = sum(cast(isnull([' 
               + @tempStoreId 
               + 
'],''0'') as decimal(18,4))) from test3 where sName=''     Sales Amount($)'';' 
; 
SET @s = @s + 'update test3 set [' + @tempStoreId 
         + 
'] = cast(@tempColumnValue as nvarchar(50)) where sGroup = ''zzzTotal'';'; 

-- print @s; 
--set @s = @s + 'print @tempColumnValue;'; 
EXEC(@s); 

FETCH next FROM t_cursorstoreid INTO @tempStoreId 
END 

CLOSE t_cursorstoreid 

DEALLOCATE t_cursorstoreid 

--================================================================================================
--INSERT AN SPACE ROW FOR EVERY DEPARTMENT. 
DECLARE t_cursordepartment CURSOR FOR 
  SELECT DISTINCT department 
  FROM   #tbltempdepartmentcategory 

OPEN t_cursordepartment 

FETCH next FROM t_cursordepartment INTO @tempDepartment 

WHILE @@fetch_status = 0 
  BEGIN 
      INSERT INTO test3 
                  (sgroupdepartment, 
                   sgroup, 
                   sname) 
      VALUES     (' ' + @tempDepartment, 
                  'zzSpaceRow', 
                  'zzSpaceRow'); 

      FETCH next FROM t_cursordepartment INTO @tempDepartment 
  END 

CLOSE t_cursordepartment 

DEALLOCATE t_cursordepartment 

--iNSERT END. 
UPDATE test3 
SET    sgroupdepartment = ' ' + department, 
       sgroup = ' ' + categoryname 
FROM   #tbltempdepartmentcategory 
WHERE  category = Ltrim(test3.sgroup); 

--================================================================================================
SELECT * 
FROM   test3 
ORDER  BY sgroupdepartment, 
          sgroup, 
          sname; 

DROP TABLE #tbltempdepartment; 

DROP TABLE test3; 

DROP TABLE #tbltempstoreid; 

DROP TABLE #tbltempdepartmentcategory; 

DROP TABLE #tbltempitemname; 

DROP TABLE #tblfinal; 

DROP TABLE #tblwhole; 

DROP TABLE #tbl1; 
END 


GO
/****** Object:  StoredProcedure [dbo].[PK_GetSOReportCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetSOReportCustomer] @StoreName    VARCHAR(50), 

                                               --@ComputerName varchar(50), 
                                               @FromDateTime VARCHAR(50), 
                                               @ToDateTime   VARCHAR(50), 
                                               @DepartmentID VARCHAR(50), 
                                               @CategoryId   VARCHAR(50), 
                                               @CustomerId   VARCHAR(50), 
                                               @DateField    VARCHAR(50), 
                                               @ReportType   VARCHAR(50), 
                                               @PLU          VARCHAR(50), 
                                               @Productname  VARCHAR(50), 
                                               @Employee     VARCHAR(50), 
                                               @Price        VARCHAR(50), 
                                               @Status       VARCHAR(50) 
AS 
  BEGIN 
      SET nocount ON; 

      IF @DateField IS NULL 
        BEGIN 
            SET @DateField = ''; 
        END 

      IF @ReportType IS NULL 
        BEGIN 
            SET @ReportType = ''; 
        END 

      IF @customerId IS NULL 
        BEGIN 
            SET @customerId = '-1'; 
        END 

      IF @PLU IS NULL 
        BEGIN 
            SET @PLU = ''; 
        END 

      IF @Productname IS NULL 
        BEGIN 
            SET @Productname = ''; 
        END 

      IF @Price IS NULL 
        BEGIN 
            SET @Price = 0; 
        END 

      IF @CategoryId IS NULL 
        BEGIN 
            SET @CategoryId = 0; 
        END 

      IF @DepartmentID IS NULL 
        BEGIN 
            SET @DepartmentID = 0; 
        END 

      IF @Employee IS NULL 
        BEGIN 
            SET @DepartmentID = 'ALL employee'; 
        END 

      DECLARE @s VARCHAR(max); 
      DECLARE @tempDecNumber DECIMAL(18, 2); 
      DECLARE @tempString VARCHAR(50); 

      SET @tempString = 
      '1234567891012345678910123456789101234567891012345678910'; 
      SET @tempDecNumber = 1000000.00; 

      --======================================================================================= 
      SELECT @tempString    AS SOID, 
             @tempString as ProductID,
             @tempString as SOProductID,
			 @tempString as Seller,
			 @tempString as Category,
			 @tempString as Department,
             @tempDecNumber AS OrderQty, 
			 @tempDecNumber AS UnitCost,
             @tempDecNumber AS TotalCost, 
             @tempDecNumber AS Profit, 
             @tempDecNumber AS AverageCost,
			 @tempString as BasePrice,
			 @tempDecNumber as Commission,
			 @tempString as CommissionType,
			 @tempDecNumber as CommissionValue
      INTO   #tblwhole; 


      DELETE FROM #tblwhole; 

      IF @DateField = 'ShipDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.soid, 
                   SOProduct.ProductID,
				   SOProduct.SOProductID,
				   PKSO.OrderBy,
				   SOProduct.CategoryID as Cagetory, 
                   SOProduct.DepartmentID as Department,  
                   orderqty, 
				   SOProduct.UnitCost,
                   totalcost, 
                   ( unitcost - Isnull(averagecost, 0) ) * orderqty AS Profit, 
                   Isnull(averagecost, 0) * orderqty AS AverageCost ,
				   '' as BasePrice,
				   0 as Commission,
				   '' as CommissionType,
				   0 as commissionValue
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) )  
                   AND pkso.shipdate >= @FromDateTime 
                   AND pkso.shipdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            --GROUP  BY SOProduct.soid--,SOProduct.SOProductID 


        END 
	  ELSE IF @DateField = 'SOEndDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.soid, 
                   SOProduct.ProductID,
				   SOProduct.SOProductID,
				   PKSO.OrderBy,
				   SOProduct.CategoryID as Cagetory, 
                   SOProduct.DepartmentID as Department,  
                   orderqty,  
				   SOProduct.UnitCost,
                   totalcost, 
                   ( unitcost - Isnull(averagecost, 0) ) * orderqty AS Profit, 
                   Isnull(averagecost, 0) * orderqty AS AverageCost ,
				   '' as BasePrice,
				   0 as Commission,
				   '' as CommissionType,
				   0 as commissionValue
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND (
						(pkso.status = 'Shipped' 
						   AND soenddate >= @FromDateTime 
                           AND soenddate <= @ToDateTime )
						or
						(pkso.status = 'Pending' and isnull(PKSO.PreOrder,'')='true'
						   AND orderdate >= @FromDateTime 
                           AND orderdate <= @ToDateTime
						)
				   )
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            --GROUP  BY SOProduct.soid--,SOProduct.SOProductID 
        END 
      ELSE 
        BEGIN 
            INSERT INTO #tblwhole 
           SELECT SOProduct.soid, 
                   SOProduct.ProductID,
				   SOProduct.SOProductID,
				   PKSO.OrderBy,
				   SOProduct.CategoryID as Cagetory, 
                   SOProduct.DepartmentID as Department,  
                   orderqty,  
				   SOProduct.UnitCost,
                   totalcost, 
                   ( unitcost - Isnull(averagecost, 0) ) * orderqty AS Profit, 
                   Isnull(averagecost, 0) * orderqty AS AverageCost ,
				   '' as BasePrice,
				   0 as Commission,
				   '' as CommissionType,
				   0 as commissionValue
            FROM   pkso 
                   JOIN pkviewsoreport_orderproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) )  
                   AND pkso.orderdate >= @FromDateTime 
                   AND pkso.orderdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            --GROUP  BY SOProduct.soid--,SOProduct.SOProductID 
        END 

      --======================================================================================= 
	  --Added by Kevin on 2015/09/15 to calculate the commission.
      --======================================================================================= 
	  select distinct u.UserName, u.EmployeeID into #tblUser from #tblwhole t inner join PKUsers u on u.username = t.Seller;

	  declare @userid varchar(50);
	  declare @useridString varchar(max);
	  set @useridString = '';

	  declare t_cursorUserId cursor for 
			select isnull(EmployeeID,'')  from #tblUser
			open t_cursorUserId
			fetch next from t_cursorUserId into @userid
			while @@fetch_status = 0
			begin
				set @useridString = @useridString + @userid + ','
				fetch next from t_cursorUserId into @userid
			end
			close t_cursorUserId
			deallocate t_cursorUserId

			

	  declare @tblInitForCommission table
		(
			id int ,
			CategoryId int ,
			SingleEmployeeId varchar(50) ,
			isCategoryOrSingle nchar(1) ,
			Department varchar(50) ,
			Category varchar(50) ,
			ProductId varchar(50) ,
			BasePrice varchar(50) , 
			CommissionType varchar(5) ,
			Commission decimal(18, 2) ,
			CreatedTime smalldatetime ,
			createdBy nvarchar(50) 
		)
		

			insert into @tblInitForCommission(id,
				CategoryId  ,
				SingleEmployeeId  ,
				isCategoryOrSingle ,
				Department  ,
				Category  ,
				ProductId  ,
				BasePrice  ,
				CommissionType  ,
				Commission  ,
				CreatedTime ,
				createdBy )
			select   
				id,
				CategoryId  ,
				SingleEmployeeId  ,
				isCategoryOrSingle ,
				Department  ,
				Category  ,
				ProductId  ,
				BasePrice  ,
				CommissionType  ,
				Commission  ,
				CreatedTime ,
				createdBy 
			from  pkFunc_GetCommissionRangeByEmployeeID(@useridString)

			declare @BasePrice varchar(50);
			declare @commissionType varchar(5);
			declare @commission decimal(18,2);
			declare @Department varchar(50);
			declare @category varchar(50);
			declare @product varchar(50);

			declare t_cursor cursor for 
			select BasePrice, CommissionType, Commission, Department,Category, ProductId  from @tblInitForCommission
			open t_cursor
			fetch next from t_cursor into @BasePrice, @commissionType, @commission, @Department,@category,@product
			while @@fetch_status = 0
			begin
				if @Department = '-1' 
				begin 
					update #tblwhole set BasePrice = @BasePrice, Commission = @commission, commissionType = @commissionType;
				end
				else if @category = '-1'
				begin
					update #tblwhole set BasePrice = @BasePrice, Commission = @commission, commissionType = @commissionType
						where Department =  @Department
				end
				else if @product = '-1'
				begin
					update #tblwhole set BasePrice = @BasePrice, Commission = @commission, commissionType = @commissionType
						where Department =  @Department and Category = @category
				end
				else
				begin
					update #tblwhole set BasePrice = @BasePrice, Commission = @commission, commissionType = @commissionType
						where Department =  @Department and Category = @category and ProductID = @product
				end

				fetch next from t_cursor into @BasePrice, @commissionType, @commission, @Department,@category,@product
			end
			close t_cursor
			deallocate t_cursor

			
			update #tblwhole
			set CommissionValue = case isnull(BasePrice,'') 
									when '' then 0
									when 'MSRP'			then case CommissionType when '%' then UnitCost * OrderQty * Commission/100		when '$' then (UnitCost + Commission) * OrderQty end 
									when 'NetProfit'	then case CommissionType when '%' then Profit * OrderQty * Commission/100		when '$' then (Profit + Commission) * OrderQty end 
									when 'SubTotal'		then case CommissionType when '%' then UnitCost * OrderQty * Commission/100		when '$' then (UnitCost + Commission) * OrderQty end 
									when 'Amount'		then case CommissionType when '%' then UnitCost * OrderQty * Commission/100		when '$' then (UnitCost + Commission) * OrderQty end 
									when 'Total'		then case CommissionType when '%' then UnitCost * OrderQty * Commission/100		when '$' then (UnitCost + Commission) * OrderQty end 
									when 'QTY'			then case CommissionType when '%' then OrderQty * Commission/100				when '$' then OrderQty * Commission end 
									else 0 
										
									end
		
      --======================================================================================= 
	  SELECT soid, 
                   --SOProduct.SOProductID, 
                   --SOProduct.LocationID, 
                   --SOProduct. DepartmentName,  
                   Sum(orderqty)                                         AS                    OrderQty, 
                   Round(Sum(totalcost), 2)                              AS                    TotalCost, 
                   Sum(Profit) AS  Profit                    , 
                   Sum(AverageCost)                    AS                    AverageCost,
				   sum(CommissionValue) as Commission
			into #tblwhole2 
			from #tblwhole tw
			group by SOID

			
      --======================================================================================= 
      --======================================================================================= 
      --select * from #tblWhole order by soid; 
      SELECT soid, 
             --SOProductId, 
             totalcost                         AS SubTotal, 
             --OrderQty as [    QTY], 
             --AverageCost as [   AverageCost], 
             profit, 
             CASE averagecost 
               WHEN 0 THEN 0 
               ELSE Cast(profit / averagecost AS NUMERIC(18, 4)) 
             END                               AS Margin, 
             Isnull(averagecost, 0) * orderqty AS SubCost,
			 Commission
      INTO   #tbl1 
      FROM   #tblwhole2 
      ORDER  BY soid; 

      ALTER TABLE #tbl1 
        ADD customername NVARCHAR(200); 

      ALTER TABLE #tbl1 
        ADD invoicedate SMALLDATETIME; 

      ALTER TABLE #tbl1 
        ADD invoicenumber VARCHAR(50); 

      ALTER TABLE #tbl1 
        ADD bysales NVARCHAR(100); 

      ALTER TABLE #tbl1 
        ADD total DECIMAL(18, 2); 

      --select * from #tbl1; 
      UPDATE #tbl1 
      SET    invoicedate = soenddate, 
             invoicenumber = Replace(orderid, 'S', 'I'), 
             bysales = orderby, 
             total = totalamount, 
             customername = soldtotitle 
      FROM   pkso 
      WHERE  pkso.soid = #tbl1.soid; 

      --select * from #tbl1; 
      ----======================================================================================= 
      SELECT a.soid, 
             CONVERT(VARCHAR(100), a.invoicedate, 23)             AS InvoiceDate 
             , 
             a.invoicenumber, 
             a.bysales, 
             a.customername, 
             a.subtotal, 
             a.profit, 
             a.margin, 
             a.total, 
             a.subcost, 
             Isnull(b.paymentamount, 0)                           AS 
             paymentAmount 
             , 
             CONVERT(VARCHAR(100), Isnull(b.paymentdate, ''), 23) AS 
             paymentDate,
			 commission
      INTO   #tbl2 
      FROM   #tbl1 a 
             LEFT OUTER JOIN pkpayment b 
                          ON a.soid = b.orderid 
                             AND a.invoicenumber = b.invoiceno COLLATE 
                                                   database_default; 

      ---------------------------------------------------------------------------- 
      SELECT DISTINCT a.soid, 
                      Max(paymentdate) AS paymentdate 
      INTO   #tbl3 
      FROM   #tbl2 a 
      GROUP  BY soid; 

      SELECT DISTINCT a.soid, 
                      a.invoicedate, 
                      a.invoicenumber, 
                      a.bysales, 
                      a.customername, 
                      a.subtotal, 
                      a.profit, 
                      a.margin, 
                      a.total, 
                      a.subcost, 
                      a.paymentamount, 
                      b.paymentdate,
					  a.Commission
      INTO   #tbl4 
      FROM   #tbl2 a 
             INNER JOIN #tbl3 b 
                     ON a.soid = b.soid 

      SELECT DISTINCT soid, 
                      invoicedate, 
                      invoicenumber, 
                      bysales, 
                      customername, 
                      subtotal, 
                      profit, 
                      margin, 
                      total, 
                      subcost, 
                      Sum(paymentamount) AS PaymentAmount, 
                      paymentdate,
					  sum(Commission) as commission
      FROM   #tbl4 
      GROUP  BY soid, 
                invoicedate, 
                invoicenumber, 
                bysales, 
                customername, 
                sUbtotal, 
                profit, 
                margin, 
                total, 
                subcost, 
                paymentdate 

      DROP TABLE #tbl1; 

      DROP TABLE #tbl2; 

      DROP TABLE #tbl3; 

      DROP TABLE #tbl4; 
      DROP TABLE #tblwhole; 
      DROP TABLE #tblwhole2; 
	  drop table #tblUser;

 
  END 


GO
/****** Object:  StoredProcedure [dbo].[PK_GetSOReportDepartment]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetSOReportDepartment] @StoreName    VARCHAR(50), 

                                                 --@ComputerName varchar(50), 
                                                 @FromDateTime VARCHAR(50), 
                                                 @ToDateTime   VARCHAR(50), 
                                                 @DepartmentID VARCHAR(50), 
                                                 @CategoryId   VARCHAR(50), 
                                                 @CustomerId   VARCHAR(50), 
                                                 @DateField    VARCHAR(50), 
                                                 @ReportType   VARCHAR(50), 
                                                 @PLU          VARCHAR(50), 
                                                 @Productname  VARCHAR(50), 
                                                 @Employee     VARCHAR(50), 
                                                 @Price        VARCHAR(50), 
                                                 @Status       VARCHAR(50) 
AS 
  BEGIN 
      SET nocount ON; 

      IF @DateField IS NULL 
        BEGIN 
            SET @DateField = ''; 
        END 

      IF @ReportType IS NULL 
        BEGIN 
            SET @ReportType = ''; 
        END 

      IF @customerId IS NULL 
        BEGIN 
            SET @customerId = '-1'; 
        END 

      IF @PLU IS NULL 
        BEGIN 
            SET @PLU = ''; 
        END 

      IF @Productname IS NULL 
        BEGIN 
            SET @Productname = ''; 
        END 

      IF @Price IS NULL 
        BEGIN 
            SET @Price = 0; 
        END 

      IF @CategoryId IS NULL 
        BEGIN 
            SET @CategoryId = 0; 
        END 

      IF @DepartmentID IS NULL 
        BEGIN 
            SET @DepartmentID = 0; 
        END 

      IF @Employee IS NULL 
        BEGIN 
            SET @DepartmentID = 'ALL employee'; 
        END 

      DECLARE @s VARCHAR(max); 
      DECLARE @tempDecNumber DECIMAL(18, 2); 
      DECLARE @tempString VARCHAR(50); 

      SET @tempString = 
      '1234567891012345678910123456789101234567891012345678910'; 
      SET @tempDecNumber = 1000000.00; 

      --======================================================================================= 
      SELECT @tempString    AS LocationID, 
             @tempString    AS DepartmentName, 
             @tempDecNumber AS OrderQty, 
             @tempDecNumber AS TotalCost, 
             @tempDecNumber AS Profit, 
             @tempDecNumber AS AverageCost 
      INTO   #tblwhole; 

      DELETE FROM #tblwhole; 

      IF @DateField = 'ShipDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   SOProduct. departmentname, 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) ) 
                   AND pkso.shipdate >= @FromDateTime 
                   AND pkso.shipdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct. departmentname 
        END 
	  else  IF @DateField = 'SOEndDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   SOProduct. departmentname, 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND (
						(pkso.status = 'Shipped' 
						   AND soenddate >= @FromDateTime 
                           AND soenddate <= @ToDateTime )
						or
						(pkso.status = 'Pending' and isnull(PKSO.PreOrder,'')='true'
						   AND orderdate >= @FromDateTime 
                           AND orderdate <= @ToDateTime
						)
				   )

                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct. departmentname 
        END 
      ELSE 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   SOProduct. departmentname, 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_orderproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) ) 
                   AND pkso.orderdate >= @FromDateTime 
                   AND pkso.orderdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct. departmentname 
        END 

      --======================================================================================= 
      SELECT locationid                        AS storeId, 
             departmentname                    AS department, 
             totalcost                         AS [     Sales Amount($)], 
             --OrderQty as [    QTY], 
             --AverageCost as [   AverageCost], 
             profit                            AS [  Profit($)], 
             CASE averagecost 
               WHEN 0 THEN 0 
               ELSE Cast(profit / averagecost AS NUMERIC(18, 4)) 
             END                               AS [ ProfitMargin(%)], 
             Isnull(averagecost, 0) * orderqty AS SubCost 
      INTO   #tbl1 
      FROM   #tblwhole 

      --======================================================================================= 
      SELECT @tempString AS StoreID, 
             @tempString AS sGroup, 
             @tempString AS sName, 
             @tempString AS itemValue 
      INTO   #tblfinal; 

      DELETE FROM #tblfinal; 

      ---------------------------------------------------------------------- 
      DECLARE @thisStoreId VARCHAR(50); 
      DECLARE t_cursordepart CURSOR FOR 
        SELECT DISTINCT storeid 
        FROM   #tbl1 

      OPEN t_cursordepart 

      FETCH next FROM t_cursordepart INTO @thisStoreId 

      WHILE @@fetch_status = 0 
        BEGIN 
            ---------------------------------------------------------------------- 
            SET @s = 'create table test2(storeId varchar(50), sName varchar(50)' 
            ; 

            SELECT @s = @s + ',[' + department + '] varchar(50)' 
            FROM   #tbl1 
            WHERE  storeid = @thisStoreId; 

            SET @s = @s + ')'; 

            EXEC(@s); 

            DECLARE @nameDate VARCHAR(50) 
            DECLARE t_cursor CURSOR FOR 
              SELECT NAME 
              FROM   tempdb.dbo.syscolumns 
              WHERE  id = Object_id('Tempdb.dbo.#tbl1') 
                     AND colid <> 1 
              ORDER  BY colid 

            OPEN t_cursor 

            FETCH next FROM t_cursor INTO @nameDate 

            WHILE @@fetch_status = 0 
              BEGIN 
                  BEGIN try 
                      EXEC('select [' + @nameDate + 
                      '] as t into test4 from #tbl1 where storeid = '''+ 
                      @thisStoreId 
                      + 
                      '''') 

                      SET @s='insert into test2 select ''' 
                             + @thisStoreId + ''',''' + @nameDate + '''' 

                      SELECT @s = @s + ',''' + Rtrim(Isnull(t, 0)) + '''' 
                      FROM   test4; 

                      EXEC(@s) 

                      EXEC('DROP TABLE test4') 
                  END try 

                  BEGIN catch 
                      BEGIN try 
                          EXEC('DROP TABLE test4') 
                      END try 

                      BEGIN catch 
                      END catch 

                      PRINT Error_message(); 

                      PRINT ''; 
                  END catch 

                  FETCH next FROM t_cursor INTO @nameDate 
              END 

            DECLARE @ColumnName VARCHAR(50); 
            DECLARE t_cursortest2 CURSOR FOR 
              SELECT NAME 
              FROM   syscolumns 
              WHERE  id = Object_id('test2') 
                     AND colid > 2 

            OPEN t_cursortest2 

            FETCH next FROM t_cursortest2 INTO @ColumnName 

            WHILE @@fetch_status = 0 
              BEGIN 
                  SET @s ='declare @departmentName varchar(50);'; 
                  SET @s = @s + 'set @departmentName = '''';'; 
                  SET @s = @s + 'select @departmentName = [' 
                           + @ColumnName 
                           + '] from test2 where sName = ''Department'';' 
                  SET @s = @s 
                           + 
'insert into #tblFinal select storeId, @departmentName as sGroup, sName, [' 
         + @ColumnName + '] as itemValue from test2'; 

EXEC(@s); 

FETCH next FROM t_cursortest2 INTO @ColumnName 
END 

CLOSE t_cursortest2 

DEALLOCATE t_cursortest2 

--select * from test2; 
CLOSE t_cursor 

DEALLOCATE t_cursor 

DROP TABLE test2 

FETCH next FROM t_cursordepart INTO @thisStoreId 
END 

CLOSE t_cursordepart; 

DEALLOCATE t_cursordepart; 

DELETE FROM #tblfinal 
WHERE  sname = 'department'; 

--==============================================================================================
----------------------------------------------------------------------------- 
SELECT DISTINCT storeid 
INTO   #tbltempstoreid 
FROM   #tblfinal; 

SELECT DISTINCT sgroup 
INTO   #tbltempdepartment 
FROM   #tblfinal; 

SELECT DISTINCT sname 
INTO   #tbltempitemname 
FROM   #tblfinal; 

SET @s = 'create table test3(sGroup varchar(50), sName varchar(50)'; 

SELECT @s = @s + ',[' + storeid + '] varchar(50)' 
FROM   #tbltempstoreid 

SET @s = @s + ')'; 

EXEC(@s); 

SET @s='insert into test3 select ''  LOCATION'',''  LOCATION''' 

SELECT @s = @s + ',''' + storeid + '''' 
FROM   #tbltempstoreid; 

EXEC(@s) 

DECLARE @tempStoreId VARCHAR(50); 
DECLARE @tempDepartment VARCHAR(50); 
DECLARE @tempItemName VARCHAR(50); 
DECLARE @tempFirstStoreId VARCHAR(50); 

SELECT TOP 1 @tempFirstStoreId = storeid 
FROM   #tbltempstoreid; 

DECLARE t_cursordepartment CURSOR FOR 
  SELECT sgroup 
  FROM   #tbltempdepartment 

OPEN t_cursordepartment 

FETCH next FROM t_cursordepartment INTO @tempDepartment 

WHILE @@fetch_status = 0 
  BEGIN 
      --set @s = 'insert into test3(sGroup,sName,['+ @tempFirstStoreId +'])values('; 
      --set @s = @s + ''''+ @tempDepartment +''','''+ @tempDepartment +''',''departmentName'''; 
      --set @s = @s + ')'; 
      --exec(@s); 
      DECLARE t_cursoritemname CURSOR FOR 
        SELECT sname 
        FROM   #tbltempitemname 

      OPEN t_cursoritemname 

      FETCH next FROM t_cursoritemname INTO @tempItemName 

      WHILE @@fetch_status = 0 
        BEGIN 
            DECLARE t_cursorstoreid CURSOR FOR 
              SELECT storeid 
              FROM   #tbltempstoreid 

            OPEN t_cursorstoreid 

            FETCH next FROM t_cursorstoreid INTO @tempStoreId 

            WHILE @@fetch_status = 0 
              BEGIN 
                  DECLARE @tempItemValue VARCHAR(50); 

                  SET @tempItemValue = '0.00'; 

                  DECLARE @isExist INT; 

                  SELECT @isExist = Count(sgroup) 
                  FROM   test3 
                  WHERE  sgroup = ' ' + @tempDepartment 
                         AND sname = @tempItemName; 

                  SELECT @tempItemValue = Isnull(itemvalue, '0') 
                  FROM   #tblfinal 
                  WHERE  storeid = @tempStoreId 
                         AND sname = @tempItemName 
                         AND sgroup = @tempDepartment; 

                  --print @isExist; 
                  IF @isExist = 0 
                    BEGIN 
                        SET @s = 'insert into test3(sGroup,sName,[' 
                                 + @tempStoreId + '])values('; 
                        SET @s = @s + ''' ' + @tempDepartment + ''',''' 
                                 + @tempItemName + ''',''' + @tempItemValue 
                                 + 
                                 '''' 
                        ; 
                        SET @s = @s + ')'; 

                        EXEC(@s); 
                    END 
                  ELSE 
                    BEGIN 
                        SET @s = 'update test3 set [' + @tempStoreId + 
                                 '] = ''' 
                                 + @tempItemValue + ''' where '; 
                        SET @s = @s + ' sGroup = '' ' + @tempDepartment 
                                 + ''' and sName = ''' + @tempItemName + 
                                 '''' 

                        EXEC(@s); 
                    END 

                  FETCH next FROM t_cursorstoreid INTO @tempStoreId 
              END 

            CLOSE t_cursorstoreid 

            DEALLOCATE t_cursorstoreid 

            FETCH next FROM t_cursoritemname INTO @tempItemName 
        END 

      CLOSE t_cursoritemname 

      DEALLOCATE t_cursoritemname 

      --set @s = 'insert into test3(sGroup,sName)values('; 
      --set @s = @s + ''''+ @tempDepartment +''',''zzSpaceRow'''; 
      --set @s = @s + ')'; 
      --exec(@s); 
      FETCH next FROM t_cursordepartment INTO @tempDepartment 
  END 

CLOSE t_cursordepartment 

DEALLOCATE t_cursordepartment 

--============================================================================================ 
--Calculate the Total Amount-------------------------------------- 
INSERT INTO test3 
            (sgroup, 
             sname) 
VALUES     ('zzzTotal', 
            'zzzTotal'); 

DECLARE t_cursorstoreid CURSOR FOR 
  SELECT storeid 
  FROM   #tbltempstoreid 

OPEN t_cursorstoreid 

FETCH next FROM t_cursorstoreid INTO @tempStoreId 

WHILE @@fetch_status = 0 
  BEGIN 
      SET @s = 'declare @tempColumnValue decimal(18,4);'; 
      SET @s = @s 
               + 'select @tempColumnValue = sum(cast(isnull([' 
               + @tempStoreId 
               + 
'],''0'') as decimal(18,4))) from test3 where sName=''     Sales Amount($)'';' 
; 
SET @s = @s + 'update test3 set [' + @tempStoreId 
         + 
'] = cast(@tempColumnValue as varchar(50)) where sGroup = ''zzzTotal'';'; 

PRINT @s; 

--set @s = @s + 'print @tempColumnValue;'; 
EXEC(@s); 

FETCH next FROM t_cursorstoreid INTO @tempStoreId 
END 

CLOSE t_cursorstoreid 

DEALLOCATE t_cursorstoreid 

--================================================================================================
SELECT * 
FROM   test3 
ORDER  BY sgroup, 
          sname; 

DROP TABLE test3; 

DROP TABLE #tbltempstoreid; 

DROP TABLE #tbltempdepartment; 

DROP TABLE #tbltempitemname; 

DROP TABLE #tblfinal; 

DROP TABLE #tblwhole; 

DROP TABLE #tbl1; 
END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetSOReportProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetSOReportProduct] @StoreName    VARCHAR(50), 

                                              --@ComputerName varchar(50), 
                                              @FromDateTime VARCHAR(50), 
                                              @ToDateTime   VARCHAR(50), 
                                              @DepartmentID VARCHAR(50), 
                                              @CategoryId   VARCHAR(50), 
                                              @CustomerId   VARCHAR(50), 
                                              @DateField    VARCHAR(50), 
                                              @ReportType   VARCHAR(50), 
                                              @PLU          VARCHAR(50), 
                                              @Productname  VARCHAR(50), 
                                              @Employee     VARCHAR(50), 
                                              @Price        VARCHAR(50), 
                                              @Status       VARCHAR(50) 
AS 
  BEGIN 
      SET nocount ON; 

      IF @DateField IS NULL 
        BEGIN 
            SET @DateField = ''; 
        END 

      IF @ReportType IS NULL 
        BEGIN 
            SET @ReportType = ''; 
        END 

      IF @customerId IS NULL 
        BEGIN 
            SET @customerId = '-1'; 
        END 

      IF @PLU IS NULL 
        BEGIN 
            SET @PLU = ''; 
        END 

      IF @Productname IS NULL 
        BEGIN 
            SET @Productname = ''; 
        END 

      IF @Price IS NULL 
        BEGIN 
            SET @Price = 0; 
        END 

      IF @CategoryId IS NULL 
        BEGIN 
            SET @CategoryId = 0; 
        END 

      IF @DepartmentID IS NULL 
        BEGIN 
            SET @DepartmentID = 0; 
        END 

      IF @Employee IS NULL 
        BEGIN 
            SET @DepartmentID = 'ALL employee'; 
        END 

      DECLARE @s NVARCHAR(max); 
      DECLARE @tempDecNumber DECIMAL(18, 2); 
      DECLARE @tempString NVARCHAR(50); 

      SET @tempString = 
      '1234567891012345678910123456789101234567891012345678910'; 
      SET @tempDecNumber = 1000000.00; 

      --======================================================================================= 
      --======================================================================================= 
      SELECT @tempString    AS LocationID, 
             --@tempString as DepartmentName,  
             -- @tempString as CategoryName,  
             @tempString    AS ProductID, 
             --@tempString + @tempString as ProductName,  
             @tempDecNumber AS OrderQty, 
             @tempDecNumber AS TotalCost, 
             @tempDecNumber AS Profit, 
             @tempDecNumber AS AverageCost 
      INTO   #tblwhole; 

      DELETE FROM #tblwhole; 

      IF @DateField = 'ShipDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   --SOProduct. DepartmentName,  
                   --SOProduct.CategoryName, 
                   SOProduct.productid, 
                   --SOProduct.ProductName1+'('+SOProduct.ProductName2 + ')', 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) ) 

                   AND pkso.shipdate >= @FromDateTime 
                   AND pkso.shipdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct.productid--,  
        --SOProduct.ProductName1, SOProduct.ProductName2 --SOProduct.DepartmentName,SOProduct.CategoryName,  
        END 
	  else IF @DateField = 'SOEndDate' 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   --SOProduct. DepartmentName,  
                   --SOProduct.CategoryName, 
                   SOProduct.productid, 
                   --SOProduct.ProductName1+'('+SOProduct.ProductName2 + ')', 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_shippedproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND (
						(pkso.status = 'Shipped' 
						   AND soenddate >= @FromDateTime 
                           AND soenddate <= @ToDateTime )
						or
						(pkso.status = 'Pending' and isnull(PKSO.PreOrder,'')='true'
						   AND orderdate >= @FromDateTime 
                           AND orderdate <= @ToDateTime
						)
				   )
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct.productid--,  
        --SOProduct.ProductName1, SOProduct.ProductName2 --SOProduct.DepartmentName,SOProduct.CategoryName,  
        END

      ELSE 
        BEGIN 
            INSERT INTO #tblwhole 
            SELECT SOProduct.locationid, 
                   --SOProduct. DepartmentName,  
                   --SOProduct.CategoryName, 
                   SOProduct.productid, 
                   --SOProduct.ProductName1+'('+SOProduct.ProductName2 + ')', 
                   Sum(orderqty)                                         AS 
                   OrderQty, 
                   Round(Sum(totalcost), 2)                              AS 
                   TotalCost, 
                   Sum(( unitcost - Isnull(averagecost, 0) ) * orderqty) AS 
                   Profit 
                   , 
                   Sum(Isnull(averagecost, 0) * orderqty) 
                   AS 
                   AverageCost 
            FROM   pkso 
                   JOIN pkviewsoreport_orderproduct AS SOProduct 
                     ON pkso.soid = SOProduct.soid 
                   LEFT JOIN pksoproducttax AS GSTTax 
                          ON SOProduct.soid = GSTTax.soid 
                             AND SOProduct.productid = GSTTax.productid 
                             AND GSTTax.taxname = 'GST' 
                   LEFT JOIN pksoproducttax AS PSTTax 
                          ON SOProduct.soid = PSTTax.soid 
                             AND SOProduct.productid = PSTTax.productid 
                             AND PSTTax.taxname = 'PST' 
                   LEFT JOIN pkcustomermultiadd 
                          ON pkso.customerid = pkcustomermultiadd.id 
            WHERE  type != 'Contract' 
                   AND ( pkso.status = 'Shipped' 
                          OR ( pkso.status = 'Pending' 
                               AND pkso.preorder = 'true' ) ) 
                   AND pkso.orderdate >= @FromDateTime 
                   AND pkso.orderdate <= @ToDateTime 
                   AND ( @ReportType <> 'Sales Report - BackOrder' 
                          OR ( @ReportType = 'Sales Report - BackOrder' 
                               AND pkso.status = 'Shipped' 
                               AND SOProduct.backqty > 0 ) ) 
                   AND ( @StoreName = '' 
                          OR ( @StoreName <> '' 
                               AND pkso.locationid = @StoreName 
                               AND ( @Employee = 'ALL employee' 
                                      OR pkso.orderby = @Employee ) ) ) 
                   AND ( @customerId = '-1' 
                          OR ( @customerId <> '-1' 
                               AND pkso.customerid = @customerId ) ) 
                   AND ( @DepartmentId = '' 
                          OR ( @DepartmentId <> '' 
                               AND departmentid = @DepartmentId ) ) 
                   AND ( @CategoryId = '' 
                          OR ( @CategoryId <> '' 
                               AND categoryid = @CategoryId ) ) 
                   AND ( @PLU = '' 
                          OR ( @PLU <> '' 
                               AND SOProduct.plu LIKE '%' + @PLU + '%' ) ) 
                   AND ( @Productname = '' 
                          OR ( @Productname <> '' 
                               AND SOProduct.productname1 LIKE 
                                   '%' + @Productname + '%' 
                             ) ) 
                   AND ( @Price = 0 
                          OR ( @Price <> 0 
                               AND SOProduct.unitcost = @Price ) ) 
            GROUP  BY SOProduct.locationid, 
                      SOProduct.productid--,  
        --SOProduct.ProductName1, SOProduct.ProductName2 --SOProduct.DepartmentName,SOProduct.CategoryName,  
        END 

      --======================================================================================= 
      SELECT locationid                        AS storeId, 
             --departmentname, 
             --categoryname, 
             productid, 
             totalcost                         AS [     Sales Amount($)], 
             --OrderQty as [    QTY], 
             --AverageCost as [   AverageCost], 
             profit                            AS [  Profit($)], 
             CASE averagecost 
               WHEN 0 THEN 0 
               ELSE Cast(profit / averagecost AS NUMERIC(18, 4)) * 100 
             END                               AS [ ProfitMargin(%)], 
             Isnull(averagecost, 0) * orderqty AS SubCost 
      INTO   #tbl1 
      FROM   #tblwhole 

      --select * from #tbl1; 
      SELECT DISTINCT d.NAME                        AS department, 
                      c.NAME                        AS category, 
                      a.productid, 
                      b.name1 + '{' + b.name2 + '}' AS productName 
      INTO   #tbltempdepartmentcategoryproduct 
      FROM   #tblwhole a 
             INNER JOIN pkproduct b 
                     ON a.productid = b.id 
             INNER JOIN pkcategory c 
                     ON b.categoryid = c.id 
             INNER JOIN pkdepartment d 
                     ON c.departmentid = d.id; 

      --======================================================================================= 
      --To deal with the count of productId.------------------------------- 
      --because there are too many products in the table, there might be error  
      --in creating middle tables with the productId as the column. 
      --So we need to group the productId and deal with them group by group. 
      CREATE TABLE #tblproductidgroup 
        ( 
           [id]        [INT] IDENTITY(1, 1) NOT NULL, 
           [productid] [VARCHAR](50) NULL, 
           dealgroup   INT NULL 
        ) 
      ON [PRIMARY]; 

      INSERT INTO #tblproductidgroup 
                  (productid) 
      SELECT DISTINCT productid 
      FROM   #tblwhole; 

      UPDATE #tblproductidgroup 
      SET    dealgroup = id / 200; 

      DECLARE @productDealGroupCount INT; 

      SELECT @productDealGroupCount = Max(dealgroup) 
      FROM   #tblproductidgroup; 

      --select @productDealGroupCount; 
      --select * from #tblProductIdGroup; 
      DECLARE @i INT; 

      SET @i = 0; 

      --End --------------------------------------------------------------- 
      SELECT @tempString AS StoreID, 
             @tempString AS sGroup, 
             @tempString AS sProductId, 
             @tempString AS sName, 
             @tempString AS itemValue 
      INTO   #tblfinal; 

      --select * from #tbl5; 
      DELETE FROM #tblfinal; 

      --select * from #tbl5; 
      ---------------------------------------------------------------------- 
      WHILE @i <= @productDealGroupCount --Begin to group the product Id 
        BEGIN 
            --Print 'Begin---' + cast(@i as nvarchar(50)) + '---' + cast(GETUTCDATE() as nvarchar(50)); 
            DECLARE @thisStoreId NVARCHAR(50); 
            DECLARE t_cursordepart CURSOR FOR 
              SELECT DISTINCT storeid 
              FROM   #tbl1 

            OPEN t_cursordepart 

            FETCH next FROM t_cursordepart INTO @thisStoreId 

            WHILE @@fetch_status = 0 
              BEGIN 
                  ---------------------------------------------------------------------- 
                  SET @s = 
              'create table test2(storeId nvarchar(50), sName nvarchar(50))'; 

                  EXEC(@s); 

                  DECLARE @tempProductId NVARCHAR(50); 
                  DECLARE t_cursorproduct CURSOR FOR 
                    SELECT DISTINCT a.productid 
                    FROM   #tbl1 a 
                           INNER JOIN #tblproductidgroup b 
                                   ON a.productid = b.productid COLLATE 
                                                    database_default 
                    WHERE  a.storeid = @thisStoreId 
                           AND b.dealgroup = @i; 

                  OPEN t_cursorproduct 

                  FETCH next FROM t_cursorproduct INTO @tempProductId 

                  WHILE @@fetch_status = 0 
                    BEGIN 
                        SELECT @s = 'alter table test2 add [' + @tempProductId 
                                    + '] nvarchar(50); ' 

                        EXEC(@s); 

                        FETCH next FROM t_cursorproduct INTO @tempProductId 
                    END 

                  CLOSE t_cursorproduct 

                  DEALLOCATE t_cursorproduct 

                  --select * from  test2;       
                  DECLARE @nameDate NVARCHAR(50) 
                  DECLARE t_cursor CURSOR FOR 
                    SELECT NAME 
                    FROM   tempdb.dbo.syscolumns 
                    WHERE  id = Object_id('Tempdb.dbo.#tbl1') 
                           AND colid <> 1 
                    ORDER  BY colid 

                  OPEN t_cursor 

                  FETCH next FROM t_cursor INTO @nameDate 

                  WHILE @@fetch_status = 0 
                    BEGIN 
                        BEGIN try 
                            DROP TABLE test4; 

                            PRINT 'Dropped.' 
                        END try 

                        BEGIN catch 
                            PRINT ''; 
                        END catch 

                        BEGIN try 
                            EXEC('select a.[' + @nameDate + 
'] as t into test4 from #tbl1 a inner join #tblProductIdGroup b on a.ProductId = b.productId COLLATE DATABASE_DEFAULT where a.storeId = '''
    + @thisStoreId +'''  and b.dealGroup = ' + @i + '') 

    SET @s='insert into test2 select ''' 
           + @thisStoreId + ''',''' + @nameDate + '''' 

    SELECT @s = @s + ',''' + Rtrim(Isnull(t, 0)) + '''' 
    FROM   test4; 

    EXEC(@s) 

    EXEC('DROP TABLE test4') 
END try 

    BEGIN catch 
        PRINT Error_message(); 

        PRINT ''; 
    END catch 

    FETCH next FROM t_cursor INTO @nameDate 
END 

    --Print '-------' 
    DECLARE @ColumnName NVARCHAR(50); 
    DECLARE t_cursortest2 CURSOR FOR 
      SELECT NAME 
      FROM   syscolumns 
      WHERE  id = Object_id('test2') 
             AND colid > 2 

    OPEN t_cursortest2 

    FETCH next FROM t_cursortest2 INTO @ColumnName 

    WHILE @@fetch_status = 0 
      BEGIN 
          SET @s ='declare @ProductId nvarchar(50);'; 
          SET @s = @s + 'set @ProductId = '''';'; 
          SET @s = @s + 'select @ProductId = [' + @ColumnName 
                   + '] from test2 where sName = ''productId'';' 
          SET @s = @s 
                   + 
'insert into #tblFinal select storeId, '''' as sGroup,@ProductId as sProductId, sName, [' 
         + @ColumnName + '] as itemValue from test2'; 

    EXEC(@s); 

    FETCH next FROM t_cursortest2 INTO @ColumnName 
END 

    CLOSE t_cursortest2 

    DEALLOCATE t_cursortest2 

    --select * from test2; 
    CLOSE t_cursor 

    DEALLOCATE t_cursor 

    DROP TABLE test2 

    FETCH next FROM t_cursordepart INTO @thisStoreId 
END 

    CLOSE t_cursordepart; 

    DEALLOCATE t_cursordepart; 

    SET @i = @i + 1; 
END 

    ----------------------------------------------------------------------------- 
    DELETE FROM #tblfinal 
    WHERE  sname = 'productId'; 

    --select * from #tblFinal; 
    --==============================================================================================
    ----------------------------------------------------------------------------- 
    SELECT DISTINCT storeid 
    INTO   #tbltempstoreid 
    FROM   #tblfinal; 

    SELECT DISTINCT storeid, 
                    sproductid 
    INTO   #tbltempproductid 
    FROM   #tblfinal; 

    SELECT DISTINCT sname 
    INTO   #tbltempitemname 
    FROM   #tblfinal; 

    SET @s = 
'create table test3(sGroup nvarchar(50),sGroupCategory nvarchar(50), sProductName nvarchar(110), sProductId nvarchar(110),  sName nvarchar(50)'
    ; 

    SELECT @s = @s + ',[' + storeid + '] nvarchar(50)' 
    FROM   #tbltempstoreid 

    SET @s = @s + ')'; 

    EXEC(@s); 

    SET @s= 
'insert into test3 select ''  LOCATION'',''  LOCATION'',''  LOCATION'',''  LOCATION'',''  LOCATION'''

    SELECT @s = @s + ',''' + storeid + '''' 
    FROM   #tbltempstoreid; 

    EXEC(@s) 

    --declare @tempStoreId nvarchar(50); 
    DECLARE @tempDepartment NVARCHAR(50); 
    DECLARE @tempCategory NVARCHAR(50); 
    DECLARE @tempProductIdLoop NVARCHAR(50); 
    DECLARE @tempProductStoreId NVARCHAR(50); 
    DECLARE @tempItemName NVARCHAR(50); 
    DECLARE @tempFirstStoreId NVARCHAR(50); 

    SELECT TOP 1 @tempFirstStoreId = storeid 
    FROM   #tbltempstoreid; 

    DECLARE t_cursordepartment CURSOR FOR 
      SELECT storeid, 
             sproductid 
      FROM   #tbltempproductid 

    OPEN t_cursordepartment 

    FETCH next FROM t_cursordepartment INTO @tempProductStoreId, 
    @tempProductIdLoop 

    WHILE @@fetch_status = 0 
      BEGIN 
          --set @s = 'insert into test3(sGroup,sName,['+ @tempFirstStoreId +'])values('; 
          --set @s = @s + ''''+ @tempCategory +''','''+ @tempCategory +''',''departmentName'''; 
          --set @s = @s + ')'; 
          --exec(@s); 
          --Print 'Begin---' + cast(GETUTCDATE() as nvarchar(50)); 
          DECLARE t_cursoritemname CURSOR FOR 
            SELECT sname 
            FROM   #tbltempitemname 

          OPEN t_cursoritemname 

          FETCH next FROM t_cursoritemname INTO @tempItemName 

          WHILE @@fetch_status = 0 
            BEGIN 
                DECLARE @tempItemValue NVARCHAR(50); 

                SET @tempItemValue = '0.00'; 

                DECLARE @isExist INT; 

                SELECT @isExist = Count(sname) 
                FROM   test3 
                WHERE  sproductid = @tempProductIdLoop 
                       AND sname = @tempItemName; 

                SELECT @tempItemValue = Isnull(itemvalue, '0') 
                FROM   #tblfinal 
                WHERE  sname = @tempItemName 
                       AND sproductid = @tempProductIdLoop; 

                IF @isExist = 0 
                  BEGIN 
                      SET @s = 'insert into test3(sProductId,sName,[' 
                               + @tempProductStoreId + '])values('; 
                      SET @s = @s + '''' + @tempProductIdLoop + ''',''' 
                               + @tempItemName + ''',''' + @tempItemValue + '''' 
                      ; 
                      SET @s = @s + ')'; 

                      EXEC(@s); 
                  END 
                ELSE 
                  BEGIN 
                      SET @s = 'update test3 set [' + @tempProductStoreId 
                               + '] = ''' + @tempItemValue + ''' where '; 
                      SET @s = @s + ' sProductId = ''' + @tempProductIdLoop 
                               + ''' and sName = ''' + @tempItemName + '''' 

                      EXEC(@s); 
                  END 

                FETCH next FROM t_cursoritemname INTO @tempItemName 
            END 

          CLOSE t_cursoritemname 

          DEALLOCATE t_cursoritemname 

          --set @s = 'insert into test3(sGroup,sGroupCategory,sName)values('; 
          --set @s = @s + ''''','''+ @tempCategory +''',''zzSpaceRow'''; 
          --set @s = @s + ')'; 
          --exec(@s); 
          FETCH next FROM t_cursordepartment INTO @tempProductStoreId, 
          @tempProductIdLoop 
      END 

    CLOSE t_cursordepartment 

    DEALLOCATE t_cursordepartment 

    DELETE FROM test3 
    WHERE  sname = 'productId'; 

    --Calculate the Total Amount-------------------------------------- 
    INSERT INTO test3 
                (sgroup, 
                 sgroupcategory, 
                 sproductname, 
                 sproductid, 
                 sname) 
    VALUES     ('zzzTotal', 
                'zzzTotal', 
                'zzzTotal', 
                'zzzTotal', 
                'zzzTotal'); 

    DECLARE t_cursorstoreid CURSOR FOR 
      SELECT storeid 
      FROM   #tbltempstoreid 

    OPEN t_cursorstoreid 

    FETCH next FROM t_cursorstoreid INTO @tempProductIdLoop 

    WHILE @@fetch_status = 0 
      BEGIN 
          SET @s = 'declare @tempColumnValue decimal(18,4);'; 
          SET @s = @s 
                   + 'select @tempColumnValue = sum(cast(isnull([' 
                   + @tempProductIdLoop 
                   + 
'],''0'') as decimal(18,4))) from test3 where sName=''     Sales Amount($)'';' 
    ; 
    SET @s = @s + 'update test3 set [' + @tempProductIdLoop 
             + 
    '] = cast(@tempColumnValue as nvarchar(50)) where sGroup = ''zzzTotal'';'; 

    --set @s = @s + 'print @tempColumnValue;'; 
    PRINT @s; 

    EXEC(@s); 

    SET @s = 'update test3 set [' + @tempProductIdLoop 
             + '] = isnull([' + @tempProductIdLoop 
             + '],''0'');'; 

    PRINT @s; 

    EXEC(@s); 

    FETCH next FROM t_cursorstoreid INTO @tempProductIdLoop 
END 

    CLOSE t_cursorstoreid 

    DEALLOCATE t_cursorstoreid 

    --select * from test3 order by sproductid,sname; 
    --INSERT AN SPACE ROW FOR EVERY DEPARTMENT. 
    DECLARE t_cursordepartment CURSOR FOR 
      SELECT DISTINCT department, 
                      category 
      FROM   #tbltempdepartmentcategoryproduct 

    OPEN t_cursordepartment 

    FETCH next FROM t_cursordepartment INTO @tempDepartment, @tempCategory 

    WHILE @@fetch_status = 0 
      BEGIN 
          INSERT INTO test3 
                      (sgroup, 
                       sgroupcategory, 
                       sproductid, 
                       sproductname, 
                       sname) 
          VALUES     (' ' + @tempDepartment, 
                      ' ' + @tempCategory, 
                      'zzSpaceRow', 
                      'zzSpaceRow', 
                      'zzSpaceRow'); 

          FETCH next FROM t_cursordepartment INTO @tempDepartment, @tempCategory 
      END 

    CLOSE t_cursordepartment 

    DEALLOCATE t_cursordepartment 

    --iNSERT END. 
    UPDATE test3 
    SET    sgroup = ' ' + department, 
           sgroupcategory = ' ' + category, 
           sproductname = ' ' + productname 
    FROM   #tbltempdepartmentcategoryproduct 
    WHERE  productid = test3.sproductid; 

    --update test3 set sGroupCategory = ProductName  from #tblTempDepartmentCategoryProduct where ProductId = test3.sproductId;
    ALTER TABLE test3 
      DROP COLUMN sproductid; 

    SELECT * 
    FROM   test3 
    ORDER  BY sgroup, 
              sgroupcategory, 
              sproductname, 
              sname; 

    DROP TABLE #tbltempproductid; 

    DROP TABLE test3; 

    DROP TABLE #tbltempstoreid; 

    DROP TABLE #tbltempdepartmentcategoryproduct; 

    DROP TABLE #tbltempitemname; 

    DROP TABLE #tblfinal; 

    DROP TABLE #tblwhole; 

    DROP TABLE #tbl1; 

    DROP TABLE #tblproductidgroup; 
END 

GO
/****** Object:  StoredProcedure [dbo].[Pk_getsosummaryreport]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Pk_getsosummaryreport] @DateType          VARCHAR(50), 
                                              @FromDateTime      VARCHAR(50), 
                                              @ToDateTime        VARCHAR(50), 
                                              @LocationID        VARCHAR(50), 
                                              @CustomerId        VARCHAR(50), 
                                              @Sales             VARCHAR(50), 
                                              @TxtSearch         VARCHAR(50), 
                                              @RadioButtonSelect VARCHAR(50) 
AS 
  BEGIN 
      DECLARE @ReturnAmount DECIMAL(18, 2); 

	  if len(@FromDateTime)<11 
	  begin
		set @FromDateTime = @FromDateTime + ' 00:00:00';
	  end

	  if len(@ToDateTime)<11 
	  begin
		set @ToDateTime = @ToDateTime + ' 23:59:59';
	  end


      SELECT TOP 1 soid, 
                   orderid, 
                   Replace(pkso.orderid, 'S', 'I') AS InvoceNo, 
                   soldtotitle, 
                   filestartdate, 
                   orderdate, 
                   shipdate, 
                   soenddate, 
                   orderby, 
                   fileendby, 
                   subtotal, 
                   totaltax, 
                   pkso.totalamount, 
                   locationid, 
                   shipfee, 
                   otherfees, 
                   @ReturnAmount                   AS ReturnAmount, 
                   Isnull(preorder, 'F')           AS PreOrder 
      INTO   #tblso 
      FROM   pkso; 

      DELETE FROM #tblso; 

      IF @DateType = '1' 
          OR @RadioButtonSelect = '7' 
        BEGIN 
            INSERT INTO #tblso 
            SELECT pkso.soid, 
                   pkso.orderid, 
                   Replace(pkso.orderid, 'S', 'I') AS InvoceNo, 
                   soldtotitle, 
                   filestartdate, 
                   orderdate, 
                   shipdate, 
                   soenddate, 
                   orderby, 
                   fileendby, 
                   subtotal, 
                   totaltax, 
                   pkso.totalamount, 
                   locationid, 
                   shipfee, 
                   otherfees, 
                   Isnull(returnamount, 0)         AS ReturnAmount, 
                   CASE preorder 
                     WHEN 'true'THEN 'Y' 
                     ELSE 'N' 
                   END                             AS PreOrder 
            FROM   pkso 
                   INNER JOIN (SELECT soid, 
                                      Sum(totalamount) AS ReturnAmount 
                               FROM   pksoreturn 
                                WHERE  status = 'POST' 
									  AND 
									  (
									  (
									  (@RadioButtonSelect = '7' and @TxtSearch != ''  
									  and soreturnid like '%' + @TxtSearch + '%')
									  or
									  (
									  @RadioButtonSelect <> '7' or @TxtSearch = '')
									  )
									  )
						  
									  AND returndate >= @FromDateTime 
									  AND returndate <= @ToDateTime  
                               GROUP  BY soid) AS SOReturn 
                           ON pkso.soid = SOReturn.soid 
            WHERE  type != 'Contract' 
                   AND (pkso.status = 'Shipped' or (PKSO.Status='Pending' and pkso.PreOrder='true'))
                   AND locationid = CASE @LocationID 
                                      WHEN '' THEN locationid 
                                      ELSE @LocationID 
                                    END 
                   AND customerid = CASE @CustomerID 
                                      WHEN '' THEN customerid 
                                      ELSE @CustomerID 
                                    END 
                   AND orderby = CASE @Sales 
                                   WHEN '' THEN orderby 
                                   ELSE @Sales 
                                 END 
                   AND soremarks LIKE '%' + CASE WHEN @RadioButtonSelect = '8' 
                                      AND 
                                      @TxtSearch!='' 
                                      THEN 
                                      @TxtSearch ELSE 
                                          soremarks END + '%' 
                   AND soldtotel LIKE '%' + CASE WHEN @RadioButtonSelect = '6' 
                                      AND 
                                      @TxtSearch!='' 
                                      THEN 
                                      @TxtSearch ELSE 
                                          soldtotel END + '%' 
                   AND orderid LIKE '%' + CASE WHEN @RadioButtonSelect = '5' AND 
                                    @TxtSearch 
                                    !='' THEN 
                                    @TxtSearch 
                                        ELSE orderid END + '%' 
            ORDER  BY pkso.soenddate DESC, 
                      pkso.orderid DESC 
        END 
      ELSE IF @DateType = '3' 
        BEGIN 
            INSERT INTO #tblso 
            SELECT pkso.soid, 
                   orderid, 
                   Replace(pkso.orderid, 'S', 'I') AS InvoceNo, 
                   soldtotitle, 
                   filestartdate, 
                   orderdate, 
                   shipdate, 
                   soenddate, 
                   orderby, 
                   fileendby, 
                   subtotal, 
                   totaltax, 
                   pkso.totalamount, 
                   locationid, 
                   shipfee, 
                   otherfees, 
                   Isnull(returnamount, 0)         AS ReturnAmount, 
                   CASE preorder 
                     WHEN 'true'THEN 'Y' 
                     ELSE 'N' 
                   END                             AS PreOrder 
            FROM   pkso 
                   LEFT OUTER JOIN (SELECT soid, 
                                           Sum(totalamount) AS ReturnAmount 
                                    FROM   pksoreturn 
                                    WHERE  status = 'Post' 
                                    GROUP  BY soid) AS SOReturn 
                                ON pkso.soid = SOReturn.soid 
            WHERE  type != 'Contract' 
                   AND (
						(pkso.status = 'Shipped' 
						   AND soenddate >= @FromDateTime 
                           AND soenddate <= @ToDateTime )
						or
						(pkso.status = 'Pending' and isnull(PKSO.PreOrder,'')='true'
						   AND OrderDate >= @FromDateTime 
                           AND OrderDate <= @ToDateTime
						)
				   )
                   AND locationid = CASE @LocationID 
                                      WHEN '' THEN locationid 
                                      ELSE @LocationID 
                                    END 
                   AND customerid = CASE @CustomerID 
                                      WHEN '' THEN customerid 
                                      ELSE @CustomerID 
                                    END 
                   AND orderby = CASE @Sales 
                                   WHEN '' THEN orderby 
                                   ELSE @Sales 
                                 END 
      --             AND ( 
						--( Isnull(preorder, '') = 'true' 

						--) 
      --                    OR
						--( Isnull(preorder, '') <> 'true' 
      --                         AND soenddate >= @FromDateTime 
      --                         AND soenddate <= @ToDateTime 
						--) 
						--) 
                   AND soremarks LIKE '%' + CASE WHEN @RadioButtonSelect = '8' 
                                      AND 
                                      @TxtSearch!='' 
                                      THEN 
                                      @TxtSearch ELSE 
                                          soremarks END + '%' 
                   AND soldtotel LIKE '%' + CASE WHEN @RadioButtonSelect = '6' 
                                      AND 
                                      @TxtSearch!='' 
                                      THEN 
                                      @TxtSearch ELSE 
                                          soldtotel END + '%' 
                   AND orderid LIKE '%' + CASE WHEN @RadioButtonSelect = '5' AND 
                                    @TxtSearch 
                                    !='' THEN 
                                    @TxtSearch 
                                        ELSE orderid END + '%' 
        END 
      ELSE 
        BEGIN 
            INSERT INTO #tblso 
            SELECT pkso.soid, 
                   orderid, 
                   Replace(pkso.orderid, 'S', 'I') AS InvoceNo, 
                   soldtotitle, 
                   filestartdate, 
                   orderdate, 
                   shipdate, 
                   soenddate, 
                   orderby, 
                   fileendby, 
                   subtotal, 
                   totaltax, 
                   pkso.totalamount, 
                   locationid, 
                   shipfee, 
                   otherfees, 
                   Isnull(returnamount, 0)         AS ReturnAmount, 
                   CASE preorder 
                     WHEN 'true'THEN 'Y' 
                     ELSE 'N' 
                   END                             AS PreOrder 
            FROM   pkso 
                   LEFT OUTER JOIN (SELECT soid, 
                                           Sum(totalamount) AS ReturnAmount 
                                    FROM   pksoreturn 
                                    WHERE  status = 'Post' 
                                    GROUP  BY soid) AS SOReturn 
                                ON pkso.soid = SOReturn.soid 
            WHERE  type != 'Contract' 
                    AND (
						pkso.status = 'Shipped' 
						or
						(pkso.status = 'Pending' and isnull(PKSO.PreOrder,'')='true')
				   )
                   AND locationid = CASE @LocationID 
                                      WHEN '' THEN locationid 
                                      ELSE @LocationID 
                                    END 
                   AND customerid = CASE @CustomerID 
                                      WHEN '' THEN customerid 
                                      ELSE @CustomerID 
                                    END 
                   AND orderby = CASE @Sales 
                                   WHEN '' THEN orderby 
                                   ELSE @Sales 
                                 END 
                   AND CASE @DateType 
                         WHEN '0' THEN orderdate 
                         WHEN '2' THEN shipdate 
                       END >= @FromDateTime 
                   AND CASE @DateType 
                         WHEN '0' THEN orderdate 
                         WHEN '2' THEN shipdate 
                       END <= @ToDateTime 
                   AND soremarks LIKE '%' + CASE WHEN @RadioButtonSelect = '8' 
                                      AND 
                                      @TxtSearch!='' 
                                      THEN 
                                      @TxtSearch ELSE 
                                          soremarks END + '%' 
                   AND soldtotel LIKE '%' + CASE WHEN @RadioButtonSelect = '6' 
                                      AND 
                                      @TxtSearch!='' 
                                      THEN 
                                      @TxtSearch ELSE 
                                          soldtotel END + '%' 
                   AND orderid LIKE '%' + CASE WHEN @RadioButtonSelect = '5' AND 
                                    @TxtSearch 
                                    !='' THEN 
                                    @TxtSearch 
                                        ELSE orderid END + '%' 
        --Order by PKSO.SOEndDate desc,PKSO.OrderID desc     
        END 

      SELECT #tblso.soid, 
             Sum(Isnull(paymentamount, 0)) AS PayAmount 
      INTO   #tblpayment 
      FROM   #tblso 
             LEFT JOIN pkpayment 
                    ON #tblso.soid = pkpayment.orderid 
      WHERE  paytype <> 'Credit' 
      GROUP  BY soid 

      SELECT #tblso.*, 
             Isnull(payamount, 0)               AS PayAmount, 
             totalamount - Isnull(payamount, 0) AS Balance 
      INTO   #tblsopayment 
      FROM   #tblso 
             LEFT JOIN #tblpayment 
                    ON #tblso.soid = #tblpayment.soid 

      SELECT DISTINCT #tblsopayment.*, 
                      Isnull(GSTTax.amount, 0) AS GST, 
                      Isnull(PSTTax.amount, 0) AS PST 
      FROM   #tblsopayment 
             LEFT OUTER JOIN (SELECT soid, 
                                     amount 
                              FROM   pksotax 
                              WHERE  taxname = 'GST:') AS GSTTax 
                          ON #tblsopayment.soid = GSTTax.soid 
             LEFT OUTER JOIN (SELECT soid, 
                                     amount 
                              FROM   pksotax 
                              WHERE  taxname = 'PST:') AS PSTTax 
                          ON #tblsopayment.soid = PSTTax.soid 
             LEFT OUTER JOIN pksoproduct 
                          ON #tblsopayment.soid = pksoproduct.soid 
             LEFT OUTER JOIN pkproduct 
                          ON pksoproduct.productid = pkproduct.id 
      WHERE  ( pksoproduct.productname1 IS NULL 
                OR pksoproduct.productname1 LIKE 
                   '%' + CASE WHEN @RadioButtonSelect = 
                   '1' AND 
                   @TxtSearch !='' THEN @TxtSearch ELSE 
                       pksoproduct.productname1 END + 
                   '%' ) 
             AND ( pksoproduct.plu IS NULL 
                    OR pksoproduct.plu LIKE '%' + CASE WHEN @RadioButtonSelect = 
                                            '2' 
                                            AND 
                                            @TxtSearch != 
                                            '' THEN @TxtSearch 
                                                ELSE pksoproduct.plu END + '%' ) 
             AND ( pksoproduct.barcode IS NULL 
                    OR pksoproduct.barcode LIKE 
                       '%' + CASE WHEN @RadioButtonSelect 
                       ='3' 
                       AND 
                       @TxtSearch= 
                       '' THEN @TxtSearch ELSE 
                           pksoproduct.barcode END + '%' 
                 ) 
             AND ( pkproduct.brand IS NULL 
                    OR pkproduct.brand LIKE '%' + CASE WHEN @RadioButtonSelect= 
                                            '4' 
                                            AND 
                                            @TxtSearch 
                                            ='' 
                                            THEN @TxtSearch ELSE 
                                                pkproduct.brand END + '%' ) 
      ORDER  BY orderdate DESC 

      DROP TABLE #tblso; 

      DROP TABLE #tblpayment; 

      DROP TABLE #tblsopayment; 
  END 



GO
/****** Object:  StoredProcedure [dbo].[Pk_getstlist]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_getstlist] @stID		VARCHAR(50),
                              @dateFrom			VARCHAR(50), 
                              @dateTo			VARCHAR(50), 
                              @ticketNo			VARCHAR(50), 
                              @dateType			VARCHAR(50), 
                              @orderBy			VARCHAR(50), 
                              @productName		VARCHAR(50), 
                              @customerID		VARCHAR(50), 
                              @attr1			VARCHAR(50), 
                              @brandName		VARCHAR(50),  --fix it
                              @assign			VARCHAR(50), 
                              @attr2			VARCHAR(50), 
                              @barcode			VARCHAR(50),
							  @type			VARCHAR(50)
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from  
      -- interfering with SELECT statements.  
      SET nocount ON; 
      update PKSTProduct set seqOrder = seq where ISNULL(seqorder,0)=0;
      SELECT DISTINCT pkst.STID,
						pkst.OrderDate,
						pkst.ServiceDate,
						pkst.EndDate,
						pkst.TicketID,
						pkst.InvoiceNo,
						pkst.CustomerName,
						pkst.Assign,
						pkst.OrderBy,
						CASE WHEN pkst.Attr2 = 'Chargeable Service' THEN 'Chargeable'
							 WHEN pkst.Attr2 = 'Non-Chargeable Service' THEN 'Non-Chargeable'
							 WHEN pkst.Attr2 = 'Cancelled' THEN 'Cancelled'
							 ELSE 'Docket' END as [Attribute]
      FROM   pkst 
             LEFT OUTER JOIN pkstproduct psp ON pkst.stid = psp.stid
      WHERE 
		(@stID = ''
			OR (@stID <> ''
					AND pkst.stid = @stID))
		AND (@dateFrom = ''
				OR (@dateFrom <> ''
						AND ((@dateType = '0' AND pkst.orderdate >= @dateFrom)
								OR (@dateType = '1' AND pkst.servicedate >= @datefrom)
								OR (@dateType = '2' AND pkst.EndDate >= @datefrom)) ) )
		AND (@dateTo = ''
				OR (@dateTo <> ''
						AND ((@dateType = '0' AND pkst.orderdate <= @dateTo)
								OR (@dateType = '1' AND pkst.servicedate <= @dateTo)
								OR (@dateType = '2' AND pkst.EndDate <= @dateTo)) ) )
		AND (@ticketNo = ''
				OR (@ticketNo <> ''
						AND pkst.ticketid LIKE '%' + @ticketNo + '%'))
		AND (@orderBy = ''
				OR (@orderBy <> ''
						AND pkst.orderby = @orderBy))
		AND (@productName = '' 
				OR (@productName <> '' 
						AND psp.productname1 + psp.productname2 LIKE N'%' + @productName + '%')) 
		AND (@customerID = '' 
				OR (@customerID <> '' 
						AND pkst.CustomerID = @customerID))
		AND (@attr1 = ''
				OR (@attr1 <> ''
						AND pkst.Attr1 = @attr1))
		AND (@assign = ''
				OR (@assign <> ''
						AND pkst.Assign = @assign))
		AND (@attr2 = ''
				OR (@attr2 <> ''
						AND PKST.Attr2 = @attr2))
		AND (@barcode = ''
				OR (@barcode <> ''
						AND psp.Barcode LIKE '%' + @barcode + '%'))
		AND (@type = ''
				OR (@type <> ''
						AND Lower(pkst.Type) = Lower(@type) ))
END 

GO
/****** Object:  StoredProcedure [dbo].[PK_GetStockTakesList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetStockTakesList]
	@LocationId   VARCHAR(50), 
    @DepartmentID VARCHAR(50), 
    @CategoryId   VARCHAR(50), 
    @PLUBarcode   VARCHAR(50), 
    @TimeFrom     VARCHAR(50), 
    @TimeTo       VARCHAR(50),
	@Status		  VARCHAR(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	
	if @LocationId = '' or @LocationId='ALL Location'
	Begin
		set @locationid = '-1'
	end

	if @DepartmentID = '' or @DepartmentID='ALL Department'
	Begin
		set @DepartmentID = '-1'
	end

	if @CategoryId = '' or @CategoryId='ALL Category'
	Begin
		set @CategoryId = '-1'
	end
	if @PLUBarcode = ''
	begin
		SELECT distinct PS.ID
		  ,PS.[LocationID]
		  ,PS.[StockTakeDate]
		  ,PS.[CreateDate]
		  ,PS.[CreateBy]
		  ,PS.[UpdateDate]
		  ,PS.[UpdateBy]
		  ,PS.[StockTakeStatus]
		  ,PS.[Remarks]
		  ,PS.[uploadtimes]
		  ,PS.[isZeroQtyIncluded]
		  ,PS.[NullWay] 
		FROM [PKStockTake] PS
		left outer join PKStockDepartmentCategory PSDC on Ps.ID = psdc.StockTakeID
		--inner join PKStockTakeProduct PSP on PSP.StockTakeID = ps.ID
		--inner join PKProduct PP on PSP.ProductId = PP.ID
		where 
		((@LocationId = '-1') or
		 (@LocationId<>'-1' and LocationID = @locationid))
		and 
		((@DepartmentID = '-1') or
		 (@DepartmentID<>'-1' and PSDC.DepartmentCategoryID = @DepartmentID and PSDC.CDType = 'D'))
		and 
		((@CategoryId = '-1') or
		 (@CategoryId<>'-1' and PSDC.DepartmentCategoryID = @CategoryId and PSDC.CDType = 'C'))
		--and 
		--((@PLUBarcode = '') or
		-- (@PLUBarcode<>'' and (PSP.Barcode like '%'+@PLUBarcode +'%' or PP.PLU like '%'+@PLUBarcode +'%')))
		and 
		((@TimeFrom = '') or
		 (@TimeFrom<>'' and ps.CreateDate>=@TimeFrom))
		and 
		((@TimeTo = '') or
		 (@TimeTo<>'' and ps.UpdateDate<=@TimeTo))
		and 
		((@Status = '') or
		 (@Status<>'' and ps.StockTakeStatus<=@Status))

		 order by PS.UpdateDate desc
	 end
	 else
	 begin
		SELECT distinct PS.ID
		  ,PS.[LocationID]
		  ,PS.[StockTakeDate]
		  ,PS.[CreateDate]
		  ,PS.[CreateBy]
		  ,PS.[UpdateDate]
		  ,PS.[UpdateBy]
		  ,PS.[StockTakeStatus]
		  ,PS.[Remarks]
		  ,PS.[uploadtimes]
		  ,PS.[isZeroQtyIncluded]
		  ,PS.[NullWay] 
		FROM [PKStockTake] PS
		left outer join PKStockDepartmentCategory PSDC on Ps.ID = psdc.StockTakeID
		inner join PKStockTakeProduct PSP on PSP.StockTakeID = ps.ID
		inner join PKProduct PP on PSP.ProductId = PP.ID
		where 
		((@LocationId = '-1') or
		 (@LocationId<>'-1' and LocationID = @locationid))
		and 
		((@DepartmentID = '-1') or
		 (@DepartmentID<>'-1' and PSDC.DepartmentCategoryID = @DepartmentID and PSDC.CDType = 'D'))
		and 
		((@CategoryId = '-1') or
		 (@CategoryId<>'-1' and PSDC.DepartmentCategoryID = @CategoryId and PSDC.CDType = 'C'))
		and 
		((@PLUBarcode = '') or
		 (@PLUBarcode<>'' and (PSP.Barcode like '%'+@PLUBarcode +'%' or PP.PLU like '%'+@PLUBarcode +'%')))
		and 
		((@TimeFrom = '') or
		 (@TimeFrom<>'' and ps.CreateDate>=@TimeFrom))
		and 
		((@TimeTo = '') or
		 (@TimeTo<>'' and ps.UpdateDate<=@TimeTo))
		and 
		((@Status = '') or
		 (@Status<>'' and ps.StockTakeStatus<=@Status))

		 order by PS.UpdateDate desc
	 end

END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetTax]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_GetTax]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	declare @BasicTaxCount int;
	

	select @BasicTaxCount = count(TaxName) from PKTax where  lower(TaxType) = 'tax';  --where TaxName ='GST' or TaxName= 'PST';


	select ProductID, count(productId) as countProductId,len(ProductID) as lenProductId into #tbl1 from PKProductTax where len(ProductID) < 20 group by ProductID;

	select ProductID,max(taxid) as ataxid into #tbl2 from PKProductTax where len(productId)<20  group by ProductID

	select distinct a.ProductID , 
	case when b.countProductId = @BasicTaxCount then 'all' else c.ataxid end as taxid,
	case when b.countProductId = @BasicTaxCount then 'ALL' else isnull(d.TaxName,'') end as taxName
	,e.TaxType
	,e.TaxName as tName
	
	 from PKProductTax a 
	 inner join #tbl1 b on a.ProductID = b.ProductID
	 inner join #tbl2 c on a.ProductID = c.ProductID
	 left outer join pktax d on d.id = c.ataxid
	 left outer join pktax e on e.id = c.ProductID


	drop table #tbl1;
	drop table #tbl2;

END



GO
/****** Object:  StoredProcedure [dbo].[Pk_GetTherapistByTimesAndResourceItem]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_GetTherapistByTimesAndResourceItem]
	@purchaseItemId varchar(50),
	@StrDate  varchar(50),
	@strTimeFrom varchar(50),
	@strTimeTo varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	if len(@strTimeFrom)=4 and SUBSTRING(@strTimeFrom,2,1)='"'
	begin
		set @strTimeFrom = '0' + @strTimeFrom;
	end
	if len(@strTimeTo)=4 and SUBSTRING(@strTimeTo,2,1)=':'
	begin
		set @strTimeTo = '0' + @strTimeTo;
	end

	select distinct ppi.PurchaseItemId,
	ppi.sales,
	ppi.forceSales

	from PKPurchaseItem PPI
	where cast(PPI.ResourceDate as datetime) =  cast(@StrDate as datetime)
	and (
		((ppi.ResourceTimeFrom <= @strTimeFrom and ppi.ResourceTimeTo>=@strTimeFrom) or (ppi.ResourceTimeFrom <= @strTimeTo and ppi.ResourceTimeTo>=@strTimeTo))
		or
		(ppi.ResourceTimeFrom >= @strTimeFrom and ppi.ResourceTimeTo<=@strTimeTo)
		)
	and ppi.PurchaseItemId <> @purchaseItemId




END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetToolBaseAndSubProdForGibo]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetToolBaseAndSubProdForGibo]
	@SubProductId varchar(50),
	@LocationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @BaseProductId varchar(50);

	
	select @BaseProductId =BaseProductID from PKMapping where ProductID = @subProductId;
	set @BaseProductId = isnull(@baseProductId,'') 

	select P.*,
		cast(packs as varchar(50)) + 'x'+ cast(packl as varchar(50)) + 'x'+ cast(packm as varchar(50)) as packsize  ,
		PIn.Qty
		from pkproduct P
		inner join PKInventory PIn on PIn.ProductID = p.ID and LocationID = @LocationId
		where P.ID = @SubProductId;

	select P.*,
		cast(packs as varchar(50)) + 'x'+ cast(packl as varchar(50)) + 'x'+ cast(packm as varchar(50)) as packsize  ,
		PIn.Qty
		from pkproduct P
		inner join PKInventory PIn on PIn.ProductID = p.ID and LocationID = @LocationId
		where P.id = @baseProductId;


	select PIH.* from PKInventoryHistory PIH
		inner join PKInventory PIy on PIy.ID = PIH.InventoryId and PIy.ProductID = @subProductId and PIy.LocationID = @LocationId
		order by PIH.id desc
		
	select PIH.* from PKInventoryHistory PIH
		inner join PKInventory PIy on PIy.ID = PIH.InventoryId and PIy.ProductID = @BaseProductId and PIy.LocationID = @LocationId
		order by PIH.id desc
	





END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetTourCommission]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetTourCommission] @type                VARCHAR(10), 
                                             @ID                  VARCHAR(50), 
                                             @DateFrom            VARCHAR(20), 
                                             @DateTo              VARCHAR(20), 
                                             @CommissionBeforeTax NVARCHAR(50), 
                                             @timestamp           SMALLDATETIME 
AS 
  BEGIN 
      DECLARE @sqlstr VARCHAR(2000); 

      SELECT tour.tourcode, 
             tourguide.firstname + ' ' + tourguide.lastname AS TLTG, 
             tourtransaction.transactionid 
      INTO   #tbl1 
      FROM   tour 
             LEFT JOIN tourguide 
                    ON ( tour.tl = tourguide.id 
                          OR tour.tg = tourguide.id ) 
             INNER JOIN tourtransaction 
                     ON tourtransaction.tourid = tour.tourcode 
      WHERE  @ID = CASE @type 
                     WHEN 'OA' THEN tour.oa 
                     WHEN 'LA' THEN tour.la 
                     WHEN 'TL' THEN tour.tl 
                     ELSE tour.tg 
                   END 

      --SELECT * FROM #tbl1  
      ---------------------------------------------------------------------- 
      SELECT TT.tourcode, 
             TT.tltg, 
             TT.transactionid, 
             itemsubtotal, 
             TX.itemtaxamount, 
             productid 
      INTO   #tbl2 
      FROM   #tbl1 AS TT 
             INNER JOIN (SELECT id 
                         FROM   postransaction 
                         WHERE  postransaction.status = 'Confirmed' 
                                AND statusdatetime >= CASE @DateFrom 
                                                        WHEN '' THEN '1900-01-01' 
                                                        ELSE @DateFrom 
                                                      END 
                                AND statusdatetime <= CASE @DateTo 
                                                        WHEN '' THEN '2999-01-01' 
                                                        ELSE @DateTo 
                                                      END 
                                AND statusdatetime < CASE @timestamp 
                                                       WHEN '' THEN '2999-01-01' 
                                                       ELSE @timestamp 
                                                     END) AS PT 
                     ON TT.transactionid = PT.id 
             INNER JOIN (SELECT id, 
                                transactionid, 
                                productid, 
                                itemsubtotal 
                         FROM   transactionitem 
                         WHERE  status = 'Confirmed') AS TI 
                     ON PT.id = TI.transactionid 
             LEFT OUTER JOIN (SELECT transactionitemid, 
                                     Sum(itemtaxamount) AS ItemTaxAmount 
                              FROM   transactionitemtax 
                              GROUP  BY transactionitemid) AS TX 
                          ON TX.transactionitemid = TI.id 

      ---------------------------------------------------------------------- 
      SELECT TT.tourcode, 
             TT.tltg, 
             TT.transactionid, 
             itemsubtotal, 
             TX.itemtaxamount, 
             productid 
      INTO   #tbl3 
      FROM   #tbl1 AS TT 
             INNER JOIN (SELECT id 
                         FROM   postransaction 
                         WHERE  postransaction.status = 'Confirmed' 
                                AND statusdatetime >= CASE @DateFrom 
                                                        WHEN '' THEN '1900-01-01' 
                                                        ELSE @DateFrom 
                                                      END 
                                AND statusdatetime <= CASE @DateTo 
                                                        WHEN '' THEN '2999-01-01' 
                                                        ELSE @DateTo 
                                                      END 
                                AND statusdatetime >= CASE @timestamp 
                                                        WHEN '' THEN '1900-01-01' 
                                                        ELSE @timestamp 
                                                      END) AS PT 
                     ON TT.transactionid = PT.id 
             INNER JOIN (SELECT id, 
                                transactionid, 
                                productid, 
                                itemsubtotal 
                         FROM   transactionitem 
                         WHERE  status = 'Confirmed') AS TI 
                     ON PT.id = TI.transactionid 
             LEFT OUTER JOIN (SELECT transactionitemid, 
                                     Sum(itemtaxamount) AS ItemTaxAmount 
                              FROM   transactionitemtax 
                              GROUP  BY transactionitemid) AS TX 
                          ON TX.transactionitemid = TI.id 

      ---------------------------------------------------------------------- 
      --SELECT * FROM #tbl2  
      SELECT Result1.tourcode, 
             Result1.tltg, 
             Result1.categoryname, 
             Sum(itemsubtotal)          AS Net, 
             Sum(Result1.itemtaxamount) AS Tax, 
             CASE 
               WHEN Sum(Result1.itemtaxamount) IS NULL THEN Sum(itemsubtotal) 
               ELSE Sum(itemsubtotal) 
                    + Sum(Result1.itemtaxamount) 
             END                        AS Gross, 
             TCR.oa, 
             TCR.la, 
             TCR.tl, 
             TCR.tg 
      --CASE @Type  
      --  WHEN 'OA' THEN Cast(Sum(itemsubtotal) * TCR.oa * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --  WHEN 'LA' THEN Cast(Sum(itemsubtotal) * TCR.la * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --  WHEN 'TL' THEN Cast(Sum(itemsubtotal) * TCR.tl * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --  WHEN 'TG' THEN Cast(Sum(itemsubtotal) * TCR.tg * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --END                        AS Commission  
      INTO   #tbl4 
      FROM   (SELECT TI.*, 
                     pkproduct.name1, 
                     pkproduct.categoryid, 
                     pkcategory.NAME AS CategoryName 
              FROM   #tbl2 TI 
                     INNER JOIN pkproduct 
                             ON TI.productid = pkproduct.id 
                     INNER JOIN pkcategory 
                             ON pkproduct.categoryid = pkcategory.id) AS Result1 
             LEFT OUTER JOIN (SELECT * 
                              FROM   tourcommitionrate) AS TCR 
                          ON ( Result1.categoryid = TCR.categoryid 
                               AND Result1.tourcode = TCR.tourcode ) 
      GROUP  BY Result1.tourcode, 
                Result1.tltg, 
                Result1.categoryid, 
                Result1.categoryname, 
                TCR.oa, 
                TCR.tg, 
                TCR.la, 
                TCR.tl 
      ORDER  BY Result1.tourcode, 
                Result1.categoryname 

      ---------------------------------------------------------------------- 
      SELECT Result1.tourcode, 
             Result1.tltg, 
             Result1.categoryname, 
             Sum(itemsubtotal)          AS Net, 
             Sum(Result1.itemtaxamount) AS Tax, 
             CASE 
               WHEN Sum(Result1.itemtaxamount) IS NULL THEN Sum(itemsubtotal) 
               ELSE Sum(itemsubtotal) 
                    + Sum(Result1.itemtaxamount) 
             END                        AS Gross, 
             TCR.oa, 
             TCR.la, 
             TCR.tl, 
             TCR.tg 
      --CASE @Type  
      --  WHEN 'OA' THEN Cast(Sum(itemsubtotal) * TCR.oa * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --  WHEN 'LA' THEN Cast(Sum(itemsubtotal) * TCR.la * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --  WHEN 'TL' THEN Cast(Sum(itemsubtotal) * TCR.tl * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --  WHEN 'TG' THEN Cast(Sum(itemsubtotal) * TCR.tg * 0.01 AS  
      --                      DECIMAL(10, 2)  
      --                 )  
      --END                        AS Commission  
      INTO   #tbl5 
      FROM   (SELECT TI.*, 
                     pkproduct.name1, 
                     pkproduct.categoryid, 
                     pkcategory.NAME AS CategoryName 
              FROM   #tbl3 TI 
                     INNER JOIN pkproduct 
                             ON TI.productid = pkproduct.id 
                     INNER JOIN pkcategory 
                             ON pkproduct.categoryid = pkcategory.id) AS Result1 
             LEFT OUTER JOIN (SELECT * 
                              FROM   tourcommitionrate) AS TCR 
                          ON ( Result1.categoryid = TCR.categoryid 
                               AND Result1.tourcode = TCR.tourcode ) 
      GROUP  BY Result1.tourcode, 
                Result1.tltg, 
                Result1.categoryid, 
                Result1.categoryname, 
                TCR.oa, 
                TCR.tg, 
                TCR.la, 
                TCR.tl 
      ORDER  BY Result1.tourcode, 
                Result1.categoryname 

      ---------------------------------------------------------------------- 
      SELECT tourcode, 
             tltg, 
             categoryname, 
             cast(net AS DECIMAL(10, 2)) as net, 
             cast(tax AS DECIMAL(10, 2)) as tax, 
             cast(gross AS DECIMAL(10, 2)) as gross, 
             CASE @Type 
               WHEN 'OA' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN gross 
                                     ELSE net 
                                   END * oa * 0.01 AS DECIMAL(10, 2)) 
               WHEN 'LA' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN gross 
                                     ELSE net 
                                   END * la * 0.01 AS DECIMAL(10, 2)) 
               WHEN 'TL' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN gross 
                                     ELSE net 
                                   END * tl * 0.01 AS DECIMAL(10, 2)) 
               WHEN 'TG' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN gross 
                                     ELSE net 
                                   END * tg * 0.01 AS DECIMAL(10, 2)) 
             END AS Commission 
      FROM   #tbl4 
      ---------------------------------------------------------------------- 
      UNION 
      ---------------------------------------------------------------------- 
      SELECT tourcode, 
             tltg, 
             categoryname, 
             cast(net AS DECIMAL(10, 2)) as net, 
             cast(tax AS DECIMAL(10, 2)) as tax, 
             cast(gross AS DECIMAL(10, 2)) as gross,  
             CASE @Type 
               WHEN 'OA' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN net 
                                     ELSE gross 
                                   END * oa * 0.01 AS DECIMAL(10, 2)) 
               WHEN 'LA' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN net 
                                     ELSE gross 
                                   END * la * 0.01 AS DECIMAL(10, 2)) 
               WHEN 'TL' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN net 
                                     ELSE gross 
                                   END * tl * 0.01 AS DECIMAL(10, 2)) 
               WHEN 'TG' THEN Cast(CASE @CommissionBeforeTax 
                                     WHEN 'true' THEN net 
                                     ELSE gross 
                                   END * tg * 0.01 AS DECIMAL(10, 2)) 
             END AS Commission 
      FROM   #tbl5 

      DROP TABLE #tbl1; 

      DROP TABLE #tbl2; 

      DROP TABLE #tbl3; 

      DROP TABLE #tbl4; 

      DROP TABLE #tbl5; 
  END 


GO
/****** Object:  StoredProcedure [dbo].[Pk_gettransactionandcustomerbytrno]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_gettransactionandcustomerbytrno] @transactionNo 
VARCHAR(50), 
                                                    @CustomerId 
VARCHAR(50), 
@isExistInCustomerTransaction SMALLINT out 
AS 
BEGIN 
-- SET NOCOUNT ON added to prevent extra result sets from  
-- interfering with SELECT statements.  
SET nocount ON; 

DECLARE @customerCount INT; 
DECLARE @TransactionId VARCHAR(50); 

SET @customerCount = 0; 
SET @TransactionId = ''; 
SET @isExistInCustomerTransaction = 0; 

SELECT @TransactionId = id 
FROM   postransaction 
WHERE  transactionno = @transactionNo; 

SELECT pt.transactionno, 
Sum(transactionitem.itemsubtotal) AS totalAmount 
FROM   postransaction pt 
INNER JOIN transactionitem 
ON pt.id = transactionitem.transactionid 
WHERE  transactionitem.type = 'Item' 
AND transactionitem.status = 'Confirmed' 
AND pt.transactionno = @transactionNo 
GROUP  BY pt.transactionno 

SELECT @customerCount = Count(*) 
FROM   customertransaction 
WHERE  transactionid = @TransactionId --and CustomerID = @CustomerId    
SET @isExistInCustomerTransaction = @customerCount; 
END 


GO
/****** Object:  StoredProcedure [dbo].[PK_GetTransactionListByCustomerID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetTransactionListByCustomerID]
	@CustomerID varchar(50),
	@DateTimeFrom datetime,
	@DateTimeTo datetime

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT post.ID, 
		StoreName, 
		ComputerName,
		Cashier, 
		TransactionNo, 
		post.Type, 
		TotalItemCount, 
		ItemTotalCost, 
		ItemDiscountTotalAmount, 
		SubTotalAmount, 
		SubTotalDiscount,
		DollarDiscount, 
		AllTaxTotalAmount, 
		TotalAmount, 
		post.Status, 
		StatusDateTime, 
		ReferenceTransactionNo
    FROM POSTransaction AS post 
		RIGHT JOIN CustomerTransaction AS ct ON post.ID = ct.TransactionID
		LEFT JOIN Customer AS c ON ct.CustomerID = c.ID
    WHERE 
		c.ID=@CustomerID AND 
		StatusDateTime>=@DateTimeFrom AND 
		StatusDateTime<=@DateTimeTo
    ORDER BY StatusDateTime DESC



END


GO
/****** Object:  StoredProcedure [dbo].[pk_gettransferdraftbyid]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[pk_gettransferdraftbyid] 
  @tranferId AS varchar(50)
  AS
BEGIN 
  -- SET NOCOUNT ON added to prevent extra result sets from 
  -- interfering with SELECT statements. 
  set nocount ON; 
  declare @tempString varchar(50);
  set @tempString = '1234567891012345678910123456789101234567891012345678910';
	
  declare @locationId varchar(50);
  select @locationId = LocationID from PKLocation where IsHeadquarter = '1'
  declare @aveOrLatest varchar(50);
  Select @aveOrLatest = Value FROM PKSetting WHERE FieldName='basePricebyAveOrlastPrice';
  declare @status varchar(50);
  
  select @status = Status from PKTransfer where id = @tranferId;






  if LOWER(isnull(@status,'')) = 'draft'
  begin
  	  select     pktransferproduct.id        AS id, 
				 pktransferproduct.productid AS productid, 
				 pkproduct.name1 + ' ' + ' ' + 
				 CASE pkproduct.netweight 
							WHEN 0 THEN '' 
							ELSE '('+ cast(pkproduct.netweight AS varchar(50))+')' 
				 END               AS productname, 
				 pkproduct.plu     AS plu, 
				 pkproduct.barcode AS barcode, 
				 pack, 
				 packingqty, 
				 pktransferproduct.qty, 
				 pktransferproduct.unit, 
				 PPR.A as MSRP, --pktransferproduct.msrp, 
				 pktransferproduct.totalcost, 
				 case @aveOrLatest when 'a' then PPI.AverageCost else ppI.LatestCost end as Price,
				 case @aveOrLatest when 'a' then PPI.AverageCost else ppI.LatestCost end as OriginalPrice,
				 PKProduct.Unit as OriginalUnit,
				 dbo.PK_FuncGetRatesBetween2Units(pktransferproduct.unit,PKProduct.Unit) as Rates
				 --isnull(pktransferproduct.unitprice, cast( pktransferproduct.totalcost / 
				 --CASE isnull(qty, 1) 
				 --           WHEN 0 THEN 1 
				 --           ELSE isnull(qty, 1) 
				 --END AS decimal(18, 2)))AS price 
	  into #tblAll
	  FROM       pktransferproduct 
				INNER JOIN pkproduct ON   pktransferproduct.productid = pkproduct.id 
				left outer join PKPrice PPR on ppr.ProductID = PKProduct.id
				inner join PKInventory PPI on PPI.ProductID = PKProduct.id and ppi.LocationID = @locationId
	  WHERE      transferid = @tranferId ;


	update #tblAll set price = price * Rates, MSRP = MSRP*rates where Rates <> 1;
    
	select * from #tblAll
    ORDER BY   id ;

	drop table #tblAll;
  end

 if LOWER(isnull(@status,'')) = 'post'
  begin

	select     pktransferproduct.id        AS id, 
             pktransferproduct.productid AS productid, 
             pkproduct.name1 + ' ' + ' ' + 
             CASE pkproduct.netweight 
                        WHEN 0 THEN '' 
                        ELSE '('+ cast(pkproduct.netweight AS varchar(50))+')' 
             END               AS productname, 
             pkproduct.plu     AS plu, 
             pkproduct.barcode AS barcode, 
             pack, 
             packingqty, 
             pktransferproduct.qty, 
             pktransferproduct.unit, 
             pktransferproduct.msrp, 
             pktransferproduct.totalcost, 
			 pktransferproduct.UnitPrice as Price,
			 case @aveOrLatest when 'a' then PPI.AverageCost else ppI.LatestCost end as OriginalPrice,
			 PKProduct.Unit as OriginalUnit,
			 dbo.PK_FuncGetRatesBetween2Units(pktransferproduct.unit,PKProduct.Unit) as Rates
             --isnull(pktransferproduct.unitprice, cast( pktransferproduct.totalcost / 
             --CASE isnull(qty, 1) 
             --           WHEN 0 THEN 1 
             --           ELSE isnull(qty, 1) 
             --END AS decimal(18, 2)))AS price 
	  into #tblAll2
	  FROM       pktransferproduct 
				INNER JOIN pkproduct ON   pktransferproduct.productid = pkproduct.id 
				left outer join PKPrice PPR on ppr.ProductID = PKProduct.id
				inner join PKInventory PPI on PPI.ProductID = PKProduct.id and ppi.LocationID = @locationId
	  WHERE      transferid = @tranferId ;

		select * from #tblAll2
		ORDER BY   id ;

		drop table #tblAll2
  end

  end

GO
/****** Object:  StoredProcedure [dbo].[PK_GetTransferProductByPluBarcodeOrName]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetTransferProductByPluBarcodeOrName]
	@BarcodePLUOrName varchar(50),
	@LocationID varchar(50)
AS
BEGIN
	
	--***** To get the basic products.****************************************
	select distinct top 100
	pp.ID,
	PP.PLU,
	PP.Barcode,
	--PP.Name1 +' '+ cast(PP.packL as varchar(50)) + 'X' + cast(PP.packm as varchar(50)) + 'X' + cast(PP.packs as varchar(50)) + ' '+ Case PP.NetWeight WHEN 0 THEN '' ELSE  '('+cast(PP.NetWeight as varchar(50))+')' END AS ProductName,
	PP.Name1  +' - '+ pp.description1 AS ProductName,
	pp.Unit,
	pp.UnitName--,
	--pki.AverageCost,
	---pki.Qty
	into #tbl1
	from  PKProduct pp
	---
	where (
		pp.plu like '%'+ @BarcodePLUOrName +'%'
		--pp.plu = case @BarcodePLUOrName when '' then plu else @BarcodePLUOrName end 
		or 
		pp.Barcode like '%'+ @BarcodePLUOrName +'%'
		--pp.Barcode = case @BarcodePLUOrName when '' then plu else @BarcodePLUOrName end
		or
		pp.Name1 + pp.Name2 like '%' + @BarcodePLUOrName + '%'
)
and pp.Status = 'Active'

	--***** To get the qty and Average cost ***************************************
	declare @AverageOrLatestCost varchar(50);
	select @AverageOrLatestCost = Value from PKSetting where FieldName = 'basePricebyAveOrlastPrice';
	set @AverageOrLatestCost = isnull(@AverageOrLatestCost,'a');



	select 
	a.ID,
	a.Barcode,
	a.PLU,
	a.ProductName,
	a.Unit,
	a.UnitName,
	case @AverageOrLatestCost when 'a' then pki.AverageCost else pki.LatestCost end as AverageCost,
	pki.Qty ,
	isnull(pri.A,0.0) as MSRP
	into #tbl2
	from #tbl1 a 
	left outer join PKInventory PkI on pki.ProductID = a.ID
	left outer join PKPrice pri on pri.ProductID = a.ID
	where pki.LocationID = @LocationID


	--****** To get QTY on Hold****************************************************
	 select 
		a.id,
		SUM(ISNULL(OrderQty,0)) AS QtyOnHold 
	 into #tbl3
	 from PKSO 
	 INNER JOIN PKSOProduct on PKSO.SOID = PKSOProduct.SOID 
	 inner join #tbl1 a  on a.ID = PKSOProduct.ProductID
	 where (PKSO.Status= 'Pending'  or PKSO.Status= 'Back') 
	 group by a.id;

	--***** To get Qty on Order *****************************************************
	SELECT 
		a.id,
		SUM(ISNULL(PKPOProduct.OrderQty,0))-SUM(ISNULL(PKReceiveProduct.OrderQty,0)) AS QtyOnOrder 
	into #tbl4
	FROM PKPO 
	INNER JOIN PKPOProduct ON PKPO.POID=PKPOProduct.POID 
	inner join #tbl1 a  on a.ID = PKPOProduct.ProductID
	LEFT OUTER JOIN PKReceiveProduct ON PKPOProduct.POProductID = PKReceiveProduct.POProductID 
	WHERE PKPO.Status= 'Pending' 
	group by a.id;
	--********************************************************************************************

	select 
	a.ID ,
	a.Barcode,
	a.PLU,
	a.ProductName,
	a.Unit,
	a.UnitName,
	a.AverageCost,
	a.Qty,
	a.MSRP,
	isnull(b.QtyOnHold,0) as QtyOnHold,
	isnull(c.QtyOnOrder,0) as QtyOnOrder
	from  #tbl2 a
	left outer join #tbl3 b on a.ID = b.ID
	left outer join #tbl4 c on a.ID = c.ID


drop table #tbl1;
drop table #tbl2;
drop table #tbl3;
drop table #tbl4;

END



GO
/****** Object:  StoredProcedure [dbo].[PK_GetTransferProductHistoryProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetTransferProductHistoryProduct]
	@BarcodePLU varchar(50),
	@productName varchar(50),
	@LocationID varchar(50)
AS
BEGIN
	
	--***** To get the basic products.****************************************
	select distinct top 100
	pp.ID,
	PP.PLU,
	PP.Barcode,
	PP.Name1 +'('+ cast(PP.packL as varchar(50)) + 'X' + cast(PP.packm as varchar(50)) + 'X' + cast(PP.packs as varchar(50)) + ')' AS ProductName,
	pp.Unit,
	pp.UnitName,
	isnull(pr.A,0) as MSRP
	--pki.AverageCost,
	---pki.Qty
	into #tbl1
	from PKTransferProduct PTP 
	inner join PKTransfer PT on PTP.TransferID = pt.ID
	inner join PKProduct pp on PTP.ProductID = pp.ID
	inner join PKPrice Pr on pr.ProductID = PTP.ProductID
	---
	where (
		pp.plu = case @BarcodePLU when '' then plu else @BarcodePLU end 
		or 
		pp.Barcode = case @BarcodePLU when '' then plu else @BarcodePLU end
	
		)
	and 
		pp.Name1 + pp.Name2 like '%' + @productName + '%'

	--***** To get the setting to use Average cost or latest cost.------------------
	declare @averageCostOrLatestCost varchar(2);
	SELECT @averageCostOrLatestCost = isnull(Value,'a') FROM PKSetting where FieldName = 'basePricebyAveOrlastPrice'
	--***** To get the qty and Average cost ***************************************

	select 
	a.ID,
	a.Barcode,
	a.PLU,
	a.ProductName,
	a.Unit,
	a.UnitName,
	a.MSRP,
	case @averageCostOrLatestCost when 'a' then pki.AverageCost else pki.LatestCost end as AverageCost,
	pki.Qty
	into #tbl2
	from #tbl1 a 
	inner join PKInventory PkI on pki.ProductID = a.ID
	where pki.LocationID = @LocationID

	--****** To get QTY on Hold****************************************************
	 select 
		a.id,
		SUM(ISNULL(OrderQty,0)) AS QtyOnHold 
	 into #tbl3
	 from PKSO 
	 INNER JOIN PKSOProduct on PKSO.SOID = PKSOProduct.SOID 
	 inner join #tbl1 a  on a.ID = PKSOProduct.ProductID
	 where (PKSO.Status= 'Pending'  or PKSO.Status= 'Back') 
	 group by a.id;


	--***** To get Qty on Order *****************************************************
	SELECT 
		a.id,
		SUM(ISNULL(PKPOProduct.OrderQty,0))-SUM(ISNULL(PKReceiveProduct.OrderQty,0)) AS QtyOnOrder 
	into #tbl4
	FROM PKPO 
	INNER JOIN PKPOProduct ON PKPO.POID=PKPOProduct.POID 
	inner join #tbl1 a  on a.ID = PKPOProduct.ProductID
	LEFT OUTER JOIN PKReceiveProduct ON PKPOProduct.POProductID = PKReceiveProduct.POProductID 
	WHERE PKPO.Status= 'Pending' 
	group by a.id;

	--********************************************************************************************

	select 
	a.ID ,
	a.Barcode,
	a.PLU,
	a.ProductName,
	a.Unit,
	a.UnitName,
	a.MSRP,
	a.AverageCost,
	a.Qty,
	b.QtyOnHold,
	c.QtyOnOrder
	from  #tbl2 a
	left outer join #tbl3 b on a.ID = b.ID
	left outer join #tbl4 c on a.ID = c.ID


drop table #tbl1;
drop table #tbl2;
drop table #tbl3;
drop table #tbl4;



END


GO
/****** Object:  StoredProcedure [dbo].[PK_GetVipAllItems]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_GetVipAllItems]
		@Type varchar(50), --available list or expired history.
		@customerId varchar(50)
AS 
  BEGIN 

		
	  DECLARE @tempString NVARCHAR(100); 
	  SET @tempString =  N'1234567891012345678910123456789101234567891012345678910'       ; 
      SET @tempString = @tempString + @tempString; 


	  select 
	  PPI.PurchaseItemId,
	  PP.Name1 + ' ' + pp.name2 as ProductName,
	  isnull(cast(PPI.ResourceId as varchar(50)),'') as ResourceId, 
	   isnull(ResourceDate,'') as ResourceDate, 
	   isnull(ResourceTimeFrom,'') as ResourceTimeFrom,
	   isnull(ResourceTimeTo,'') as ResourceTimeTo,
	  ppi.Remark,
	  @tempString as isResourceEmpty,
	   @tempString as ResourceEntireDate
	   into #tbl1
	  from PKPurchasePackage PPP
	  inner join PKPurchaseItem PPI on PPP.PurchaseId = PPI.PurchaseId
	  inner join PKProduct PP on PP.id = PPI.ProductId
	  where PPP.customerId = @customerId
	  and (
	  (@type = 'history' and len(isnull(PPI.ResourceTimeTo,''))>0) or 
	  (@type = 'available' and len(isnull(PPI.ResourceTimeTo,''))=0)
	  )

	  order by ppi.ProductId,ppi.ResourceDate desc,ppi.ResourceTimeFrom desc
    

	   update #tbl1 set isResourceEmpty = case ResourceDate + ResourceTimeFrom + ResourceTimeTo when '' then 'true' else 'false' end;
	   update #tbl1 set ResourceEntireDate = ResourceDate +' ' + ResourceTimeFrom +' ' + ResourceTimeTo ;

	   select * from #tbl1;

	   drop table #tbl1;

  END 


GO
/****** Object:  StoredProcedure [dbo].[PK_GetVIPCard]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetVIPCard]
	@cardID varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;		 

	declare @IsMultiCard nvarchar(50);
	select @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

	if(@IsMultiCard='true')
	begin
		SELECT 'VIPNo' AS cardType, 'VIPN.' AS cardName, CC.CardNo AS cardNumber, C.firstname + ' ' + C.lastname AS cardHolders FROM customer C
		inner join CustomerCard CC on CC.CustomerID = c.ID 
		WHERE  cc.id = @cardID
	end
	else
	begin 
		SELECT 'VIPNo' AS cardType, 'VIPN.' AS cardName, CustomerNo  AS cardNumber, C.firstname + ' ' + C.lastname AS cardHolders FROM customer C
		WHERE CustomerNo = @cardID
	end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_GetVIPList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_GetVIPList]
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;      

    DECLARE @isMultiCard varchar(50);
    SELECT @isMultiCard = ISNULL(Value, 'false') FROM PKSetting WHERE FieldName = 'isBookingMultiCard';

    IF LOWER(@isMultiCard) = 'true'
    BEGIN
        SELECT CustomerID, [IDCardNo]=stuff((SELECT ','+[CardNo] FROM CustomerCard as Temp2 WHERE Temp2.CustomerID = Temp1.CustomerID AND Temp2.Status = 'Active' FOR XML PATH('')),1,1,''),
        SUM(ISNULL(Balance, 0.00)) AS Balance INTO #tbl1 FROM CustomerCard AS Temp1 GROUP BY CustomerID 

        SELECT transferId, SUM(Amount) AS amount INTO #tbl2 FROM PKPurchasePackageOrderTax GROUP BY transferId

        SELECT CustomerCard.CustomerID, SUM(ISNULL(PKPurchasePackageOrder.amount, 0.00)) + SUM(ISNULL(PurchaseTax.amount, 0.00)) AS Amount INTO #tbl3 FROM PKPurchasePackageOrder
		inner join PKPurchasePackagePaymentItem PPPPI on ppppi.transferId = PKPurchasePackageOrder.transferId
        LEFT JOIN #tbl2 AS PurchaseTax ON PKPurchasePackageOrder.transferId = PurchaseTax.transferId
        LEFT JOIN CustomerCard ON CustomerCard.CardNo = PKPurchasePackageOrder.CardNumber 
		where PKPurchasePackageOrder.Type = 'deposit'
		GROUP BY CustomerCard.CustomerID

        SELECT id, CardNumber, (SELECT MIN(Amount) FROM (VALUES(TotalAmount), (SUM(PayTotalAmount))) AS PaymentOrder(Amount)) AS Amount INTO #tbl4
        FROM PKPurchasePackagePaymentOrder GROUP BY id, CardNumber, TotalAmount

        SELECT CustomerCard.CustomerID AS CustomerID, SUM(PaymentOrder.Amount) AS Amount INTO #tbl5 FROM #tbl4 AS PaymentOrder
        LEFT JOIN CustomerCard ON CustomerCard.CardNo = PaymentOrder.CardNumber GROUP BY CustomerCard.CustomerID

        SELECT ID, CustomerNo, FirstName, LastName, Phone, VipCards.IDCardNo, EMail, Address, 
        CASE WHEN ISNULL(LastName, '') = '' 
            THEN FirstName 
            ELSE (FirstName + ' ' + LastName) END AS Name,
        CASE WHEN City = '-1'
            THEN null
            ELSE City END as City, 
        CASE WHEN Province = '-1'
            THEN null
            ELSE Province END as Province, 
        CASE WHEN Country = '-1'
            THEN null
            ELSE Country END as Country, 
        Postal, CreateDate, UpdateDate, Status, Remarks, TEL, FAX, TotalPurchaseAmount, LockTotalPurchaseAmount, DiscountPercentage, LockDiscountPercentage, Points, 
        --LockPoints, MaxDiscountAmount, DiscountAmountLeft, Birthday, Gender, CustomerType, VIPType, ISNULL(Purchase.Amount, 0.00) - ISNULL(Payment.Amount, 0.00) AS Purchase, 
        LockPoints, MaxDiscountAmount, DiscountAmountLeft, Birthday, Gender, CustomerType, VIPType, ISNULL(Purchase.Amount, 0.00)  AS Purchase, 
        ISNULL(VipCards.Balance, 0.00) AS Balance, regLocation FROM Customer 
        LEFT JOIN #tbl1 AS VipCards ON VipCards.CustomerID = Customer.ID
        LEFT JOIN #tbl3 AS Purchase ON Purchase.CustomerID = Customer.ID
        LEFT JOIN #tbl5 AS Payment ON Payment.CustomerID = Customer.ID
        ORDER BY CustomerNo, VipCards.IDCardNo, FirstName

        DROP TABLE #tbl1;
        DROP TABLE #tbl2;
        DROP TABLE #tbl3;
        DROP TABLE #tbl4;
        DROP TABLE #tbl5;
    END
    ELSE
    BEGIN
        SELECT transferId, SUM(Amount) AS amount INTO #tbl6 FROM PKPurchasePackageOrderTax GROUP BY transferId

        SELECT Customer.ID AS CustomerID, SUM(ISNULL(PKPurchasePackageOrder.amount, 0.00)) + SUM(ISNULL(PurchaseTax.amount, 0.00)) AS Amount INTO #tbl7 FROM PKPurchasePackageOrder
        LEFT JOIN #tbl6 AS PurchaseTax ON PKPurchasePackageOrder.transferId = PurchaseTax.transferId
        LEFT JOIN Customer ON Customer.CustomerNo = PKPurchasePackageOrder.CardNumber 
		where PKPurchasePackageOrder.Type = 'deposit'
		GROUP BY Customer.ID

        SELECT id, CardNumber, (SELECT MIN(Amount) FROM (VALUES(TotalAmount), (SUM(PayTotalAmount))) AS PaymentOrder(Amount)) AS Amount INTO #tbl8
        FROM PKPurchasePackagePaymentOrder GROUP BY id, CardNumber, TotalAmount

        SELECT Customer.ID AS CustomerID, SUM(PaymentOrder.Amount) AS Amount INTO #tbl9 FROM #tbl8 AS PaymentOrder
        LEFT JOIN Customer ON Customer.CustomerNo = PaymentOrder.CardNumber GROUP BY Customer.ID

        SELECT ID, CustomerNo, FirstName, LastName, Phone, '' AS IDCardNo, EMail, Address, 
        CASE WHEN ISNULL(LastName, '') = '' 
            THEN FirstName 
            ELSE (FirstName + ' ' + LastName) END AS Name,
        CASE WHEN City = '-1'
            THEN null
            ELSE City END as City, 
        CASE WHEN Province = '-1'
            THEN null
            ELSE Province END as Province, 
        CASE WHEN Country = '-1'
            THEN null
            ELSE Country END as Country, 
        Postal, CreateDate, UpdateDate, Status, Remarks, TEL, FAX, TotalPurchaseAmount, LockTotalPurchaseAmount, DiscountPercentage, LockDiscountPercentage, Points, 
        --LockPoints, MaxDiscountAmount, DiscountAmountLeft, Birthday, Gender, CustomerType, VIPType, ISNULL(Purchase.Amount, 0.00) - ISNULL(Payment.Amount, 0.00) AS Purchase,  
        LockPoints, MaxDiscountAmount, DiscountAmountLeft, Birthday, Gender, CustomerType, VIPType, ISNULL(Purchase.Amount, 0.00)  AS Purchase,  
        ISNULL(Customer.Points, 0.00) AS Balance, regLocation FROM Customer 
        LEFT JOIN #tbl7 AS Purchase ON Purchase.CustomerID = Customer.ID
        LEFT JOIN #tbl9 AS Payment ON Payment.CustomerID = Customer.ID
        ORDER BY CustomerNo, FirstName

        DROP TABLE #tbl6;
        DROP TABLE #tbl7;
        DROP TABLE #tbl8;
        DROP TABLE #tbl9;
    END
END


GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierGetAllGroups]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_ModifierGetAllGroups]
	@locationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	if len(@locationid)=0
	begin
		select * from PKModifierGroup order by name1;
	end
	else
	begin
		select * from PKModifierGroup where locationid = @locationId or [type] = 'employee' order by name1;
	end
END



GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierGetGroupItems]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_ModifierGetGroupItems]
	@GroupId varchar(50),
	@itemId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	if @itemId = '' or @itemId = '0'
	begin
		select * from PKModifierItem where ModifierGroupID = @GroupId;
	end 
	else
	begin
		select * from PKModifierItem where ModifierGroupID = @GroupId and Id = @itemId;
	end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierGetModifierByProductId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[PK_ModifierGetModifierByProductId]
	@productId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @categoryId varchar(50);
	select @categoryId = CategoryID from PKProduct where id = @productId;

	select PMg.* from PKModifierGroup PMg
        inner join PKModifierConnection PMC on pmg.id = pmc.ModifierGroupID
        where PMC.FoodID = @productId or PMC.FoodID = @categoryId

END

GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierGetModifierItemsByProductId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ModifierGetModifierItemsByProductId]
	@productId varchar(50),
	@locationId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @categoryId varchar(50);
	select @categoryId = CategoryID from PKProduct where id = @productId;

	if @locationId = ''
	begin
		select PMI.*,PMg.name1 as modifierGroupName from PKModifierItem PMI
			inner join PKModifierGroup PMg on pMg.id = pmi.ModifierGroupID
			inner join PKModifierConnection PMC on pmg.id = pmc.ModifierGroupID
			where PMC.FoodID = @productId or PMC.FoodID = @categoryId
			order by ModifierGroupID
	end
	else
	begin
		select PMI.*,PMg.name1 as modifierGroupName from PKModifierItem PMI
			inner join PKModifierGroup PMg on pMg.id = pmi.ModifierGroupID and  (pmg.locationId = @locationId or pmg.Type = 'employee')
			inner join PKModifierConnection PMC on pmg.id = pmc.ModifierGroupID
			where PMC.FoodID = @productId or PMC.FoodID = @categoryId
			order by ModifierGroupID	end
END



GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierRemoveGroup]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ModifierRemoveGroup]
	@ModifierGroupId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	declare @itemCount int;

	select @itemCount = count(*) from PKModifierItem where ModifierGroupID = @ModifierGroupId;

	if @itemCount >0 
	begin 
		select @itemCount as itemCount;
	end
	else
	begin
		delete from PKModifierGroup where id = @ModifierGroupId;
		select 0 as itemcount;
	end

END

GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierSetGroup]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ModifierSetGroup]
	@name1 nvarchar(50),
	@name2 nvarchar(50),
	@min int,
	@max int,
	@type varchar(20),
	@locationId varchar(50)
AS
BEGIN
	insert into PKModifierGroup(id,name1,name2,MinSelectedItems,MaxSelectedItems,[Type],locationid)
	values(NEWID(),@name1,@name2,@min,@max,@type, @locationId)


End


GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierSetGroupConnection]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ModifierSetGroupConnection]
	@FoodInfo varchar(max),
	@ModifierInfo varchar(max),
	@CommondFrom varchar(20)
AS
BEGIN

	--@FoodId varchar(50),
	--@FoodIDType varchar(10),
	--@ModifierGroupId varchar(50),
	--@CommondFrom varchar(20)

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @tableValue varchar(100);
	declare @FoodId varchar(50)
	declare @FoodIDType varchar(10)
	declare @modifierGroupId varchar(50)


	if lower(@CommondFrom)='applyto'
	begin
		delete from PKModifierConnection where ModifierGroupID = @ModifierInfo;
		declare @str varchar(max);
		set @modifierGroupId = @ModifierInfo;

		declare @tablename table(value varchar(200));
		set @str = @FoodInfo + '|';
		set @str = replace(@str,' ','');
		set @str = replace(@str,'||','|');
		set @str = replace(@str,'||','|');
		set @str = replace(@str,'||','|');
		Declare @insertStr varchar(50) --
		Declare @newstr varchar(8000) --
		set @insertStr = left(@str,charindex('|',@str)-1)
		set @insertStr = ltrim(rtrim(replace(@insertStr,char(13),'')));
		set @insertStr = replace(@insertStr,char(10),'');
		set @newstr = stuff(@str,1,charindex('|',@str),'')
		Insert @tableName Values(@insertStr)
	
		Declare @intLoopLimit int;
		set @intLoopLimit = 300;
		while(len(@newstr)>0)
		begin
			set @insertStr = left(@newstr,charindex('|',@newstr)-1)
			set @insertStr = ltrim(rtrim(replace(@insertStr,char(13),'')));
			set @insertStr = replace(@insertStr,char(10),'');
			Insert @tableName Values(@insertStr)
			set @newstr = stuff(@newstr,1,charindex('|',@newstr),'')
			--print '[' + @insertStr + ']'
			--Here to avoid the loop to be unlimited loop----------
			set @intLoopLimit =@intLoopLimit-1
			if @intLoopLimit <=0 
			begin
				set @newstr = ''
			end
			-- End ------------------------------------------------
		end
		DECLARE t_cursor CURSOR FOR 
			SELECT value from @tablename

		  OPEN t_cursor 
		  FETCH next FROM t_cursor INTO @tableValue 
		  WHILE @@fetch_status = 0 
			BEGIN 
				set @FoodIDType = SUBSTRING(@tableValue,1,1);
				set @FoodId = SUBSTRING(@tableValue, 3,len(@tableValue)-2);

				--print @FoodIdType + '----' + @foodID
				insert into PKModifierConnection(foodId, FoodIDType,ModifierGroupID)values(@FoodId,@FoodIDType,@modifierGroupId);


				FETCH next FROM t_cursor INTO @tableValue 
			END 

		  CLOSE t_cursor 
		  DEALLOCATE t_cursor 


	end
    if lower(@CommondFrom)='connected'
	begin
		set @FoodId = @FoodInfo;
		delete from PKModifierConnection where FoodID = @FoodId
		declare @str2 varchar(max);

		declare @tablename2 table(value varchar(200));
		set @str2 = @ModifierInfo + '|';
		set @str2 = replace(@str2,' ','');
		set @str2 = replace(@str2,'||','|');
		set @str2 = replace(@str2,'||','|');
		set @str2 = replace(@str2,'||','|');
		Declare @insertStr2 varchar(50) --
		Declare @newstr2 varchar(8000) --
		set @insertStr2 = left(@str2,charindex('|',@str2)-1)
		set @insertStr2 = ltrim(rtrim(replace(@insertStr2,char(13),'')));
		set @insertStr2 = replace(@insertStr2,char(10),'');
		set @newstr2 = stuff(@str2,1,charindex('|',@str2),'')
		Insert @tablename2 Values(@insertStr2)
	
		Declare @intLoopLimit2 int;
		set @intLoopLimit2 = 300;
		while(len(@newstr2)>0)
		begin
			set @insertStr2 = left(@newstr2,charindex('|',@newstr2)-1)
			set @insertStr2 = ltrim(rtrim(replace(@insertStr2,char(13),'')));
			set @insertStr2 = replace(@insertStr2,char(10),'');
			Insert @tablename2 Values(@insertStr2)
			set @newstr2 = stuff(@newstr2,1,charindex('|',@newstr2),'')
			--print '[' + @insertStr2 + ']'
			--Here to avoid the loop to be unlimited loop----------
			set @intLoopLimit2 =@intLoopLimit2-1
			if @intLoopLimit2 <=0 
			begin
				set @newstr2 = ''
			end
			-- End ------------------------------------------------
		end

		DECLARE t_cursor CURSOR FOR 
			SELECT value from @tablename2

		  OPEN t_cursor 
		  FETCH next FROM t_cursor INTO @tableValue 
		  WHILE @@fetch_status = 0 
			BEGIN 
				set @FoodIDType = SUBSTRING(@tableValue,1,1);
				set @modifierGroupId = SUBSTRING(@tableValue, 3,len(@tableValue)-2);

				--print @FoodIdType + '----' + @foodID
				insert into PKModifierConnection(foodId, FoodIDType,ModifierGroupID)values(@FoodId,@FoodIDType,@modifierGroupId);


				FETCH next FROM t_cursor INTO @tableValue 
			END 

		  CLOSE t_cursor 
		  DEALLOCATE t_cursor 


	end
    

END

GO
/****** Object:  StoredProcedure [dbo].[PK_ModifierSetGroupItems]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_ModifierSetGroupItems]
	@GroupId varchar(50),
	@name1 nvarchar(50),
	@name2 nvarchar(50),
	@Price decimal(18,2)
AS
BEGIN
	insert into PKModifierItem(Id,ModifierGroupID,name1,name2,Price)
	values(NEWID(),@GroupId,@name1,@name2,@Price)


End

GO
/****** Object:  StoredProcedure [dbo].[PK_SetAddDepositPackageToCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetAddDepositPackageToCustomer]
	@PackageId varchar(50),
	@CardID varchar(50),
	@transferId varchar(50),
	@OrderBy varchar(50),
	@PriceValue decimal(18,2),
	@sales nvarchar(50),
	@newPurchaseId varchar(50) out
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from 
		-- interfering with SELECT statements. 
		SET nocount ON; 

		DECLARE @PurchaseId uniqueidentifier;
		DECLARE @cardType NVARCHAR(50); 
		DECLARE @cardName NVARCHAR(50); 
		DECLARE @cardNumber NVARCHAR(50); 
		DECLARE @cardHolders NVARCHAR(50);

		DECLARE @thresholdPrice DECIMAL(18, 2);
		DECLARE @tempColumn1 DECIMAL(18, 2);
		DECLARE @Deposit DECIMAL(18, 2);
		DECLARE @DepositPercentage DECIMAL(18, 2);
		DECLARE @Giftamount  DECIMAL(18, 2);

		declare @customerId nvarchar(50);
		declare @customerTotalPayment decimal(18,2);

		SET @thresholdPrice = 0.00;
		SET @tempColumn1 = 0.00;
		SET @Deposit = 0.00;
		SET @DepositPercentage = 0.00;

		declare @IsMultiCard nvarchar(50);
		select @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

		if(@IsMultiCard='true')
		begin
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CC.CardNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			inner join CustomerCard CC on CC.CustomerID = c.ID 
			WHERE  cc.id = @CardID
		end
		else
		begin 
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CustomerNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			WHERE CustomerNo = @CardID
		end

		SELECT @thresholdPrice = thresholdPrice, @tempColumn1 = tempColumn1, @DepositPercentage = DepositPercentage FROM PKDepositPackage WHERE ID = @PackageId

		--$5000 then 1.2.   Else, 1.1
		--Code needed here

		SELECT @customerId = Isnull(customerid, '') FROM   customercard  WHERE  id = @CardID; 
		------------
		SELECT id, 
			   cardnumber, 
			   (SELECT Min(amount) 
				FROM   (VALUES(totalamount), 
							  (Sum(paytotalamount))) AS PaymentOrder(amount)) AS Amount 
		INTO   #tbl4 
		FROM   pkpurchasepackagepaymentorder 
		GROUP  BY id, 
				  cardnumber, 
				  totalamount ;
		-----------
		SELECT customercard.customerid  AS CustomerID, 
			   Sum(PaymentOrder.amount) AS Amount 
		into #tbl5
		FROM   #tbl4 AS PaymentOrder 
			   LEFT JOIN customercard 
					  ON customercard.cardno = PaymentOrder.cardnumber 
		where CustomerCard.CustomerID = @customerId
		GROUP  BY customercard.customerid ;
		-----------
		BEGIN TRY
			select @customerTotalPayment = Amount  from #tbl5 where CustomerID = @customerId;
			if @customerTotalPayment > 5000
			begin
				set @DepositPercentage = 1.2
			end
		END TRY
		BEGIN CATCH
				print 1
		END CATCH
		----------
		drop table #tbl4;
		drop table #tbl5;

		--------------------------------------
		set @Deposit = @PriceValue * @DepositPercentage;
		set @Giftamount = @Deposit - @PriceValue;

		set @PurchaseId = NEWID();
		set @newPurchaseId = @PurchaseId;

		INSERT INTO PKDepositPackageTransaction (ID, CardType, CardName, CardNumber, CardHolders, PrepaidPackageID, 
			thresholdPrice, Price, DepositPercentage,Deposit, Giftamount, Type, Status, transferId, CreateTime, CreateBy, UpdateTime, UpdateBy,sales)
			VALUES (@PurchaseId, @cardType, @cardName, @cardNumber, @cardHolders, @PackageId, 
			@thresholdPrice, @PriceValue, @DepositPercentage, @Deposit,@Giftamount, 'Purchase', 'Active', @transferId, Getdate(), @OrderBy, Getdate(), @OrderBy,@sales);

END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetAddGiftCardToCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetAddGiftCardToCustomer]
	@GiftCardId varchar(50),
	@CardID varchar(50),
	@transferId varchar(50),
	@OrderBy varchar(50),
	@sales nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from 
		-- interfering with SELECT statements. 
		SET nocount ON; 

		DECLARE @cardType NVARCHAR(50); 
		DECLARE @cardName NVARCHAR(50); 
		DECLARE @cardNumber NVARCHAR(50); 
		DECLARE @cardHolders NVARCHAR(50);

		DECLARE @Cost DECIMAL(18, 2);
		DECLARE @Price DECIMAL(18, 2);
		DECLARE @Deposit DECIMAL(18, 2);

		SET @Cost = 0.00;
		SET @Price = 0.00;
		SET @Deposit = 0.00;

		declare @IsMultiCard nvarchar(50);
		select @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

		if(@IsMultiCard='true')
		begin
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CC.CardNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			inner join CustomerCard CC on CC.CustomerID = c.ID 
			WHERE  cc.id = @CardID
		end
		else
		begin 
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CustomerNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			WHERE CustomerNo = @CardID
		end

		SELECT @Cost = Cost, @Price = Price, @Deposit = Deposit FROM PKGiftCard WHERE ID = @GiftCardId

		INSERT INTO PKGiftCardTransaction (ID, CardType, CardName, CardNumber, CardHolders, 
			GiftCardId, GiftCardNo, Cost, Price, Deposit, Type, Status, transferId, CreateTime, CreateBy, UpdateTime, UpdateBy,sales)
			VALUES (NEWID(), @cardType, @cardName, @cardNumber, @cardHolders, 
			@GiftCardId, '', @Cost, @Price, @Deposit, 'Purchase', 'Active', @transferId, Getdate(), @OrderBy, Getdate(), @OrderBy,@sales);
END




GO
/****** Object:  StoredProcedure [dbo].[PK_SetAddOrderToCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetAddOrderToCustomer]
	@cardID varchar(50),
	@transferId varchar(50),
	@orderPrice decimal(18,2),
	@locationId varchar(50),
	@orderBy varchar(50),
	@orderType varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from 
		-- interfering with SELECT statements. 
		SET nocount ON; 

		DECLARE @cardType NVARCHAR(50); 
		DECLARE @cardName NVARCHAR(50); 
		DECLARE @cardNumber NVARCHAR(50); 
		DECLARE @cardHolders NVARCHAR(50);

		declare @IsMultiCard nvarchar(50);
		select @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

		if(@IsMultiCard='true')
		begin
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CC.CardNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			inner join CustomerCard CC on CC.CustomerID = c.ID 
			WHERE  cc.id = @cardID
		end
		else
		begin 
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CustomerNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			WHERE CustomerNo = @cardID
		end

		INSERT INTO PKPurchasePackageOrder (transferId, amount, createTime, updateTime, updatedBy, Remark, Locationid, CardType, CardName, CardNumber, CardHolders, Type)
			VALUES (@transferId, @orderPrice, Getdate(), Getdate(), @orderBy, '', @locationId, @cardType, @cardName, @cardNumber, @cardHolders, @orderType)
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetAddPackageToCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetAddPackageToCustomer]
	@PackageId varchar(50),
	@CardID varchar(50),
	@packageType varchar(50),
	@transferId varchar(50),
	@packagePrice decimal(18,2),
	@createdBy nvarchar(50),
	@booker nvarchar(50),
	@newPurchaseId varchar(50) out
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from 
		-- interfering with SELECT statements. 
		SET nocount ON; 

		DECLARE @PurchaseId uniqueidentifier;
		DECLARE @cardType NVARCHAR(50); 
		DECLARE @cardName NVARCHAR(50); 
		DECLARE @cardNumber NVARCHAR(50); 
		DECLARE @cardHolders NVARCHAR(50); 
		DECLARE @BomOrProductId NVARCHAR(50); 
		DECLARE @itemType NVARCHAR(50); 
		declare @itemOrder int

		declare @IsMultiCard nvarchar(50);
		select @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

		if(@IsMultiCard='true')
		begin
			SELECT @cardType = 'VIPNo', 
				   @cardName = 'VIPN.', 
				   @cardNumber = CC.CardNo, 
				   @cardHolders = C.firstname + ' ' + C.lastname, 
				   @BomOrProductId = @PackageId, 
				   @itemType = 'B' 
			FROM   customer C
			inner join CustomerCard CC on CC.CustomerID = c.ID
			WHERE  cc.id = @CardID
		end
		else
		begin 
			SELECT @cardType = 'VIPNo', 
				   @cardName = 'VIPN.', 
				   @cardNumber = CustomerNo, 
				   @cardHolders = C.firstname + ' ' + C.lastname, 
				   @BomOrProductId = @PackageId, 
				   @itemType = 'B' 
			FROM   customer C
			where CustomerNo = @CardID
		end


		set @PurchaseId = NEWID();
		set @newPurchaseId = @PurchaseId;

		select @itemOrder = max(isnull(itemorder,0)) from PKPurchaseItem;


		if @packageType = 'package'
		begin

			INSERT INTO pkpurchasepackage 
						(
						PurchaseId,
						cardtype, 
						 cardname, 
						 cardnumber, 
						 cardholders, 
						 bomorproductid, 
						 itemtype, 
						 createdate, 
						 status, 
						 customerId,
						 updatetime, 
						 lastupdator,
						 transferid,
						 amount,
						 createdby,
						 updatedBy,
						 booker
						 ) 
			VALUES     ( 
							@PurchaseId,
							@cardType, 
						 @cardName, 
						 @cardNumber, 
						 @cardHolders, 
						 @BomOrProductId, 
						 @itemType, 
						 Getdate(), 
						 'Active', 
						 @CardID,
						 Getdate(), 
						 '' ,
						 @transferId,
						 @packagePrice,
						 @createdBy,
						 @createdBy,
						 @booker
						 ); 

			DECLARE @productId VARCHAR(50); 
			DECLARE @qty DECIMAL(18, 2); 
			DECLARE t_cursor CURSOR FOR 
			  SELECT ppp.productid, 
					 qty 
			  FROM   pkpromotionproduct PPP where ppp.PromotionID = @BomOrProductId

			OPEN t_cursor 

			FETCH next FROM t_cursor INTO @productId, @qty 

			WHILE @@fetch_status = 0 
			  BEGIN 
				  WHILE( @qty > 0 ) 
					BEGIN 
						INSERT INTO pkpurchaseitem 
									(purchaseitemid, 
									 cardtype, 
									 cardname, 
									 cardnumber, 
									 cardholder, 
									 productid, 
									 createdate, 
									 status, 
									 resourceid, 
									 resourcetimefrom, 
									 resourcetimeto, 
									 remark,
									 PurchaseId,
									 packageType,
									 packsize,
									 itemorder,
									 createdby,
									 updatedBy,
									 booker
								 
									 ) 
						VALUES     ( Newid(), 
									 @cardType, 
									 @cardName, 
									 @cardNumber, 
									 @cardHolders, 
									 @productId, 
									 Getdate(), 
									 'Active', 
									 NULL, 
									 '', 
									 '', 
									 '' ,
									 @PurchaseId,
									 'package',
									 '1',
									 @itemOrder +2,
									 @createdBy,
									 @createdBy,
									 @booker
									 ) 

						SET @qty = @qty - 1 ;
						set @itemOrder = @itemOrder + 2;
					END 

				  FETCH next FROM t_cursor INTO @productId, @qty 
			  END 

			CLOSE t_cursor 

			DEALLOCATE t_cursor 
		end
		else if @packageType = 'product'
		begin
			INSERT INTO pkpurchasepackage 
						(
						PurchaseId,
						cardtype, 
						 cardname, 
						 cardnumber, 
						 cardholders, 
						 bomorproductid, 
						 itemtype, 
						 createdate, 
						 status, 
						 customerId,
						 updatetime, 
						 lastupdator,
						 transferid,
						 amount,
						 createdby,
						 updatedBy,
						 booker
						 ) 
			VALUES     ( 
						@PurchaseId,
						@cardType, 
						 @cardName, 
						 @cardNumber, 
						 @cardHolders, 
						 @PackageId, 
						 'P', 
						 Getdate(), 
						 'Active', 
						 @CardID,
						 Getdate(), 
						 '' ,
						 @transferId,
						 @packagePrice,
						 @createdby,
						 @createdBy,
						 @booker
						 ); 


			INSERT INTO pkpurchaseitem 
						(purchaseitemid, 
							cardtype, 
							cardname, 
							cardnumber, 
							cardholder, 
							productid, 
							createdate, 
							status, 
							resourceid, 
							resourcetimefrom, 
							resourcetimeto, 
							remark,
							PurchaseId,
							packageType,
							packsize,
						    itemOrder,
							 createdby,
							 updatedBy,
							 booker
							) 
			VALUES     (	
							@PurchaseId, 
							@cardType, 
							@cardName, 
							@cardNumber, 
							@cardHolders, 
							@PackageId, 
							Getdate(), 
							'Active', 
							NULL, 
							'', 
							'', 
							'' ,
							@PurchaseId,
							'product',
							'1',
							@itemOrder + 2,
							@createdBy,
							@createdBy,
							@booker

							) 
		end
END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetAddPrepaidPackageToCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetAddPrepaidPackageToCustomer]
	@PackageId varchar(50),
	@CardID varchar(50),
	@transferId varchar(50),
	@OrderBy varchar(50),
	@sales nvarchar(50),
	@newPurchaseId varchar(50) out
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from 
		-- interfering with SELECT statements. 
		SET nocount ON; 

		DECLARE @PurchaseId uniqueidentifier;
		DECLARE @cardType NVARCHAR(50); 
		DECLARE @cardName NVARCHAR(50); 
		DECLARE @cardNumber NVARCHAR(50); 
		DECLARE @cardHolders NVARCHAR(50);

		DECLARE @Cost DECIMAL(18, 2);
		DECLARE @Price DECIMAL(18, 2);
		DECLARE @Deposit DECIMAL(18, 2);

		SET @Cost = 0.00;
		SET @Price = 0.00;
		SET @Deposit = 0.00;

		declare @IsMultiCard nvarchar(50);
		select @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

		if(@IsMultiCard='true')
		begin
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CC.CardNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			inner join CustomerCard CC on CC.CustomerID = c.ID 
			WHERE  cc.id = @CardID
		end
		else
		begin 
			SELECT @cardType = 'VIPNo', @cardName = 'VIPN.', @cardNumber = CustomerNo, @cardHolders = C.firstname + ' ' + C.lastname FROM customer C
			WHERE CustomerNo = @CardID
		end

		SELECT @Cost = Cost, @Price = Price, @Deposit = Deposit FROM PKPrepaidPackage WHERE ID = @PackageId

		set @PurchaseId = NEWID();
		set @newPurchaseId = @PurchaseId;

		INSERT INTO PKPrepaidPackageTransaction (ID, CardType, CardName, CardNumber, CardHolders, 
		PrepaidPackageID, Cost, Price, Deposit, Type, Status, transferId, CreateTime, 
		CreateBy, UpdateTime, UpdateBy,sales)
			VALUES (@PurchaseId, @cardType, @cardName, @cardNumber, 
			@cardHolders, @PackageId, @Cost, @Price, @Deposit, 'Purchase', 'Active', @transferId, Getdate(), 
			@OrderBy, Getdate(), @OrderBy,@sales);
END



GO
/****** Object:  StoredProcedure [dbo].[PK_SetAveAndLatestCostFromInventory]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetAveAndLatestCostFromInventory]
	@productId varchar(50),
	@operator varchar(50)
AS
BEGIN
	
	--declare @productPriceFix bit
	declare @averageCost decimal(8,2)
	declare @latestCost decimal(8,2)
	declare @baseCost decimal(8,2)
	declare @baseCostOriginal decimal(8,2)
	declare @APrice decimal(8,2)
	declare @BPrice decimal(8,2)
	declare @CPrice decimal(8,2)
	declare @DPrice decimal(8,2)
	declare @EPrice decimal(8,2)
	declare @APriceRate decimal(8,2)
	declare @BPriceRate decimal(8,2)
	declare @CPriceRate decimal(8,2)
	declare @DPriceRate decimal(8,2)
	declare @EPriceRate decimal(8,2)
	declare @APriceRate2 decimal(8,2)
	declare @BPriceRate2 decimal(8,2)
	declare @CPriceRate2 decimal(8,2)
	declare @DPriceRate2 decimal(8,2)
	declare @EPriceRate2 decimal(8,2)
	declare @ABaseOn varchar(1)
	declare @BBaseOn varchar(1)
	declare @CBaseOn varchar(1)
	declare @DBaseOn varchar(1)
	declare @EBaseOn varchar(1)
	declare @AOperator1 varchar(1)
	declare @BOperator1 varchar(1)
	declare @COperator1 varchar(1)
	declare @DOperator1 varchar(1)
	declare @EOperator1 varchar(1)
	declare @AOperator2 varchar(1)
	declare @BOperator2 varchar(1)
	declare @COperator2 varchar(1)
	declare @DOperator2 varchar(1)
	declare @EOperator2 varchar(1)
	declare @AIsFixed bit
	declare @BIsFixed bit
	declare @CIsFixed bit
	declare @DIsFixed bit
	declare @EIsFixed bit
	declare @SingleAIsFixed bit
	declare @SingleBIsFixed bit
	declare @SingleCIsFixed bit
	declare @SingleDIsFixed bit
	declare @SingleEIsFixed bit
	declare @IsPriceExisted varchar(50)
	set @baseCost = 0
	set @baseCostOriginal = 0
	set @averageCost = 0
	set @latestCost = 0
	--select @globalAutoChangePrice = value from PKSetting where FieldName='InboundUpdatePrice' --switchForAutoPriceChange
	--select @globalAveOrLatest = value from PKSetting where FieldName='basePricebyAveOrlastPrice'
	--select @productPriceFix = isnull(FixPrice,1)  from PKPrice where ProductID = @productId
	select @SingleAIsFixed = isnull(AisFixed,0),  
		   @SingleBIsFixed = isnull(BisFixed,0),  
		   @SingleCIsFixed = isnull(CisFixed,0),  
		   @SingleDIsFixed = isnull(DisFixed,0),  
		   @SingleEIsFixed = isnull(EisFixed,0)
		from PKPrice where ProductID = @productId
	SELECT @latestCost = isnull(a.LatestCost,0),
		   @averageCost = isnull(a.AverageCost,0) 
		   FROM PKInventory a 
		   inner join PKLocation b on a.LocationID = b.LocationID  where a.ProductID = @productId and b.IsHeadquarter = 1;
	
		SELECT TOP 1 @APriceRate=isnull(RateA,0),
		@BPriceRate=isnull(RateB,0),
		@CPriceRate=isnull(RateC,0),
		@DPriceRate=isnull(RateD,0),
		@EPriceRate=isnull(RateE,0),
		@APriceRate2 = isnull(RateA2,0),
        @BPriceRate2 = isnull(RateB2,0),
        @CPriceRate2 = isnull(RateC2,0),
        @DPriceRate2 = isnull(RateD2,0),
        @EPriceRate2 = isnull(RateE2,0),
        @ABaseOn = isnull(ABaseOn,'a'),
        @BBaseOn = isnull(BBaseOn,'a'),
        @CBaseOn = isnull(CBaseOn,'a'),
        @DBaseOn = isnull(DBaseOn,'a'),
        @EBaseOn = isnull(EBaseOn,'a'),
        @AOperator1 = isnull(AOperator,'*'),
        @BOperator1 = isnull(BOperator,'*'),
        @COperator1 = isnull(COperator,'*'),
        @DOperator1 = isnull(DOperator,'*'),
        @EOperator1 = isnull(EOperator,'*'),
        --isnull(AUnit,'%') as AUnit,
        --isnull(BUnit,'%') as BUnit,
        --isnull(CUnit,'%') as CUnit,
        --isnull(DUnit,'%') as DUnit,
        --isnull(EUnit,'%') as EUnit,
        @AOperator2 = isnull(AOperator2,'+'),
        @BOperator2 = isnull(BOperator2,'+'),
        @COperator2 = isnull(COperator2,'+'),
        @DOperator2 = isnull(DOperator2,'+'),
        @EOperator2 = isnull(EOperator2,'+'),
        --isnull(AUnit2,'$') as AUnit2,
        --isnull(BUnit2,'$') as BUnit2,
        --isnull(CUnit2,'$') as CUnit2,
        --isnull(DUnit2,'$') as DUnit2,
        --isnull(EUnit2,'$') as EUnit2,
        @AIsFixed = isnull(AIsfixed,'1'),
        @BIsFixed = isnull(BIsfixed,'1'),
        @CIsFixed = isnull(CIsfixed,'1'),
        @DIsFixed = isnull(DIsfixed,'1'),
        @EIsFixed = isnull(EIsfixed,'1')
		FROM PKPriceRate
		
		/*
		if lower(@globalAveOrLatest)='l'
			begin
				set @baseCost = @latestCost
			end
		else if lower(@globalAveOrLatest)='a'
			begin
				set @baseCost = @averageCost
			end 
		
		set @APrice = @baseCost + @baseCost * @APriceRate/100;
		set @BPrice = @baseCost + @baseCost * @BPriceRate/100;
		set @CPrice = @baseCost + @baseCost * @CPriceRate/100;
		set @DPrice = @baseCost + @baseCost * @DPriceRate/100;
		set @EPrice = @baseCost + @baseCost * @EPriceRate/100;
		*/
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@ABaseOn)='l' then @latestCost else @averageCost end;
		SET @APrice = @baseCost +
		case 
		 when @AOperator1='+' then @APriceRate
		 when @AOperator1='-' then (@APriceRate * -1)
		-- when @AOperator1='*' then case when @APriceRate=0 then 0 else (@APriceRate/100-1) * @baseCost end 
		 when @AOperator1='*' then case when @APriceRate=0 then 0 else (@APriceRate/100) * @baseCost end 
		 when @AOperator1='/' then case when @APriceRate=0 then 0 else @baseCost*100/@APriceRate - @baseCost end 
		 end
		 
		 SET @APrice = @APrice +
		 case 
		 when @AOperator2='+' then @APriceRate2
		 when @AOperator2='-' then (@APriceRate2 * -1)
		 when @AOperator2='*' then case when @APriceRate2=0 then 0 else (@APriceRate2/100 -1) * @APrice end 
		 when @AOperator2='/' then case when @APriceRate2=0 then 0 else @APrice*100/@APriceRate2 -@APrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@BBaseOn)='l' then @latestCost else @averageCost end;
		SET @BPrice = @baseCost +
		case 
		 when @BOperator1='+' then @BPriceRate
		 when @BOperator1='-' then (@BPriceRate * -1)
		 --when @BOperator1='*' then case when @BPriceRate=0 then 0 else (@BPriceRate/100-1) * @baseCost end
		 when @BOperator1='*' then case when @BPriceRate=0 then 0 else (@BPriceRate/100) * @baseCost end
		 when @BOperator1='/' then case when @BPriceRate=0 then 0 else  @baseCost/@BPriceRate - @baseCost end 
		 end
		SET @BPrice = @BPrice +
		 case 
		 when @BOperator2='+' then @BPriceRate2
		 when @BOperator2='-' then (@BPriceRate2 * -1)
		 when @BOperator2='*' then case when @BPriceRate2=0 then 0 else  (@BPriceRate2/100-1) * @BPrice end 
		 when @BOperator2='/' then case when @BPriceRate2=0 then 0 else  @BPrice*100/@BPriceRate2 -@BPrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@CBaseOn)='l' then @latestCost else @averageCost end;
		SET @CPrice = @baseCost +
		case 
		 when @COperator1='+' then @CPriceRate
		 when @COperator1='-' then (@CPriceRate * -1)
		 --when @COperator1='*' then case when @CPriceRate=0 then 0 else (@CPriceRate/100-1) * @baseCost end 
		 when @COperator1='*' then case when @CPriceRate=0 then 0 else (@CPriceRate/100) * @baseCost end 
		 when @COperator1='/' then case when @CPriceRate=0 then 0 else @baseCost*100/@CPriceRate - @baseCost end 
		 end
		SET @CPrice = @CPrice +
		 case 
		 when @COperator2='+' then @CPriceRate2
		 when @COperator2='-' then (@CPriceRate2 * -1)
		 when @COperator2='*' then case when @CPriceRate2=0 then 0 else   (@CPriceRate2/100 -1) * @CPrice end 
		 when @COperator2='/' then case when @CPriceRate2=0 then 0 else   @CPrice*100/@CPriceRate2 -@CPrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@DBaseOn)='l' then @latestCost else @averageCost end;
		SET @DPrice = @baseCost +
		case 
		 when @DOperator1='+' then @DPriceRate
		 when @DOperator1='-' then (@DPriceRate * -1)
		-- when @DOperator1='*' then case when @DPriceRate=0 then 0 else   (@DPriceRate/100-1) * @baseCost END 
		 when @DOperator1='*' then case when @DPriceRate=0 then 0 else   (@DPriceRate/100) * @baseCost END 
		 when @DOperator1='/' then case when @DPriceRate=0 then 0 else   @baseCost*100/@DPriceRate - @baseCost end 
		 end
		SET @DPrice = @DPrice +
		 case 
		 when @DOperator2='+' then @DPriceRate2
		 when @DOperator2='-' then (@DPriceRate2 * -1)
		 when @DOperator2='*' then case when @dPriceRate2=0 then 0 else   (@DPriceRate2/100-1) * @DPrice end 
		 when @DOperator2='/' then case when @dPriceRate2=0 then 0 else   @DPrice*100/@DPriceRate2 -@DPrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		set @baseCost = case when lower(@EBaseOn)='l' then @latestCost else @averageCost end;
		SET @EPrice = @baseCost +
		case 
		 when @EOperator1='+' then @EPriceRate
		 when @EOperator1='-' then (@EPriceRate * -1)
		 --when @EOperator1='*' then case when @EPriceRate=0 then 0 else   (@EPriceRate/100-1) * @baseCost end 
		 when @EOperator1='*' then case when @EPriceRate=0 then 0 else   (@EPriceRate/100) * @baseCost end 
		 when @EOperator1='/' then case when @EPriceRate=0 then 0 else   @baseCost*100/@EPriceRate - @baseCost end 
		 end
		 SET @EPrice = @EPrice +
		 case 
		 when @EOperator2='+' then @EPriceRate2
		 when @EOperator2='-' then (@EPriceRate2 * -1)
		 when @EOperator2='*' then case when @EPriceRate2=0 then 0 else    (@EPriceRate2/100-1) * @EPrice  end 
		 when @EOperator2='/' then case when @EPriceRate2=0 then 0 else   @EPrice*100/@EPriceRate2 -@EPrice end 
		 end
		---------------------------------------------------------------------------------------------------------------------
		select @IsPriceExisted = isnull(ProductID,'')  from PKPrice where ProductID = @productId;
		if len(@IsPriceExisted)>0 
			begin		
				--*******This sql is to store the price history Just in case.*************************************
				INSERT INTO PKPriceHistory(ProductID,Cost,A,B,C,D,E,Special)select top 1 ProductID,Cost,A,B,C,D,E,Special from PKPrice where ProductID = @productId;
				select @baseCostOriginal =Cost from PKPrice where ProductID = @productId;
				--************************************************************************************************
				
				IF @AIsFixed = 0 AND @SingleAIsFixed = 0
				BEGIN
					UPDATE PKPrice SET A=@APrice WHERE ProductID = @productId;
				END
				IF @BIsFixed = 0 AND @SingleBIsFixed = 0
				BEGIN
					UPDATE PKPrice SET B=@BPrice WHERE ProductID = @productId;
				END
				IF @CIsFixed = 0 and @SingleCIsFixed = 0
				BEGIN
					UPDATE PKPrice SET C=@CPrice WHERE ProductID = @productId;
				END
				IF @DIsFixed = 0 and @SingleDIsFixed = 0
				BEGIN
					UPDATE PKPrice SET D=@DPrice WHERE ProductID = @productId;
				END
				IF @EIsFixed = 0 and @SingleEIsFixed = 0
				BEGIN
					UPDATE PKPrice SET E=@EPrice WHERE ProductID = @productId;
				END
				
				UPDATE PKPrice SET COST = @averageCost, Updater=@operator,UpdateTime=getdate() WHERE ProductID = @productId;
				/*
				if @productPriceFix = 0 
					begin
						--************************************************************************************************
						--The following condition is very important in the future.
						--But for now we comment it for testing.
						--************************************************************************************************
						--if abs((@baseCost-@baseCostOriginal)/@baseCostOriginal)<0.3
							--begin
								UPDATE PKPrice SET COST = @baseCost, A=@APrice, B=@BPrice, C=@CPrice, D=@DPrice, E=@EPrice WHERE ProductID = @productId;
							--end
						--else
						--	begin
						--		UPDATE PKPrice SET COST = @baseCost WHERE ProductID = @productId;
						--	end
					end 
				else
					begin
						update PKPrice set Cost = @baseCost where ProductID=@productId
					End
					*/
			end 
		else
			begin
				INSERT INTO PKPrice
				(ID,ProductID,Cost,A,B,C,D,E,Special,CreateTime,UpdateTime,Creater,Updater,IsAPriceSpecial,FixPrice)
				values(
					NEWID(),
					@productId,
					@baseCost,
					@APrice,
					@BPrice,
					@CPrice,
					@DPrice,
					@EPrice,
					0,
					getdate(),
					getdate(),
					@operator,
					@operator,
					'false',
					0
				);
			end
END

GO
/****** Object:  StoredProcedure [dbo].[Pk_SetAveLatestCostForAllFamily]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Pk_SetAveLatestCostForAllFamily]
	@productId varchar(50),
	@LocationId Varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
		declare @AverageCostNew decimal(18,4);
		declare @LatestCostNew decimal(18,4);

		select @AverageCostNew = a.AverageCost, @LatestCostNew = a.LatestCost from PKInventory a
			inner join PKLocation b on a.LocationID = b.LocationID
			where a.ProductID = @ProductId and b.IsHeadquarter = 1;
		
		DECLARE @tbl1 TABLE 
		  ( 
			 productid VARCHAR(50), 
			 unit      VARCHAR(50), 
			 rate      DECIMAL(18, 4) 
		  ) 

		INSERT INTO @tbl1 
					(productid, 
					 unit, 
					 rate) 
		SELECT pp.id AS productId, 
			   pp.unit, 
			   PU.rate 
		FROM   pkproduct PP 
			   INNER JOIN pkunitnames PU 
					   ON pp.unit = PU.unit 
		WHERE  pp.id = @ProductId 

		--------------------------------------------------------------- 
		--If the product is baseProduct-------------------------------- 
		--------------------------------------------------------------- 
		INSERT INTO @tbl1 
					(productid, 
					 unit, 
					 rate) 
		SELECT pp.id AS productId, 
			   pp.unit, 
			   PU.rate 
		FROM   pkproduct PP 
			   INNER JOIN pkunitnames PU 
					   ON pp.unit = PU.unit 
			   INNER JOIN pkmapping PM 
					   ON pm.productid = pp.id 
		WHERE  baseproductid = @ProductId; 

		--------------------------------------------------------------- 
		--If the product is a child product-------------------------------- 
		--------------------------------------------------------------- 
		DECLARE @BaseProductId VARCHAR(50); 

		SELECT @BaseProductId = baseproductid 
		FROM   pkmapping 
		WHERE  productid = @ProductId; 

		IF Len(Isnull(@baseProductId, '')) > 0 
		  BEGIN 
			  INSERT INTO @tbl1 
						  (productid, 
						   unit, 
						   rate) 
			  SELECT pp.id AS productId, 
					 pp.unit, 
					 PU.rate 
			  FROM   pkproduct PP 
					 INNER JOIN pkunitnames PU 
							 ON pp.unit = PU.unit 
			  WHERE  pp.id = @BaseProductId 

			  INSERT INTO @tbl1 
						  (productid, 
						   unit, 
						   rate) 
			  SELECT pp.id AS productId, 
					 pp.unit, 
					 PU.rate 
			  FROM   pkproduct PP 
					 INNER JOIN pkmapping PM 
							 ON pm.productid = pp.id 
					 INNER JOIN pkunitnames PU 
							 ON pp.unit = PU.unit 
			  WHERE  pm.baseproductid = @BaseProductId 
					 AND NOT EXISTS(SELECT * 
									FROM   @tbl1 a 
									WHERE  a.productid = PM.productid); 
		  END 

		--------------------------------------------------------------- 
		--------------------------------------------------------------- 
		--------------------------------------------------------------- 
		DECLARE @tbl2 TABLE 
		  ( 
			 productid  VARCHAR(50), 
			 averageCostValue        DECIMAL(18, 4), 
			 latestCostValue        DECIMAL(18, 4), 
			 capacity   DECIMAL(18, 4), 
			 locationid VARCHAR(50) 
		  ) 

		--SELECT @returnQty = sum(qty * capacity) 
		INSERT INTO @tbl2 
		SELECT distinct id AS productId, 
			   0.0 as averageCostValue, 
			   0.0 as latestCostValue, 
			   capacity, 
			   locationid 
		FROM   (SELECT id, 
					   unit, 
					   dbo.Pk_funcgetcapacitybyprodid(id) AS capacity
				FROM   pkproduct 
				WHERE  ( status = 'active' ) 
					   AND EXISTS(SELECT * 
								  FROM   @tbl1 b 
								  WHERE  b.productid = pkproduct.id)) AS a 
			   LEFT JOIN (SELECT productid AS invproductid, 
								 
								 locationid 
						  FROM   pkinventory 
						  WHERE  ( pkinventory.locationid = @LocationId 
									OR @LocationId = '' )) AS b 
					  ON a.id = b.invproductid 

		DECLARE @baseCapacity DECIMAL(18, 4); 

		SELECT @baseCapacity = capacity 
		FROM   @tbl2 
		WHERE  productid = @ProductId; 

		SET @baseCapacity = Isnull(@baseCapacity, 1); 

		UPDATE @tbl2 
		SET    capacity = capacity / @baseCapacity; 

		update @tbl2

		set averageCostValue = @AverageCostNew * capacity, latestCostValue = @LatestCostNew * capacity;

		---------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------
		declare @updateCostForOneOrAllLocation varchar(10);
		select @updateCostForOneOrAllLocation = value from PKSetting where FieldName = 'updateCostForOneOrAllLocation';
		if isnull(@updateCostForOneOrAllLocation,'A') = 'a' 
		begin
			update PKInventory 
			set AverageCost = a.averageCostValue,LatestCost = a.latestCostValue, UpdateTime = getdate()--, Updater = @ProductId
			from @tbl2 a where a.productid = PKInventory.ProductID
		end 
		else
		begin 
			update PKInventory 
			set AverageCost = a.averageCostValue,LatestCost = a.latestCostValue, UpdateTime = getdate()--, Updater = @ProductId
			from @tbl2 a where a.productid = PKInventory.ProductID
			and PKInventory.LocationID = @LocationId
		end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetBookingPriceOverride]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetBookingPriceOverride] 
	@orderId VARCHAR(50),
	@packageType VARCHAR(50),
	@packageId VARCHAR(50),
	@price Decimal(18,2),
	@orderBy VARCHAR(50)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	IF (@packageType = 'Product') OR (@packageType = 'Package')
	BEGIN
		UPDATE PKPurchasePackage SET amount = @price, UpdateTime = GETDATE(), LastUpdator = @orderBy WHERE (transferId = @orderId) AND (BomOrProductID = @packageId)
	END
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetBookResourceInfo]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetBookResourceInfo]
	@PurchaseItemId uniqueIdentifier,
	@ResourceId uniqueIdentifier,
	@resourceTimeFrom varchar(50),
	@resourceTimeto varchar(50),
	@resouceDate varchar(50),
	@Remark varchar(max),
	@updatedby nvarchar(50),
	@sales nvarchar(50),
	@forceSales varchar(50),
	@packsize varchar(10)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	if @packsize = '1'
		begin
			update PKPurchaseItem 
			set ResourceId = @ResourceId,
			ResourceTimeFrom = @resourceTimeFrom,
			ResourceTimeTo = @resourceTimeto,
			ResourceDate  = @resouceDate,
			Remark  = @Remark,
			updatedBy = @updatedby,
			sales = @sales,
			forceSales = @forceSales
			where PurchaseItemId = @PurchaseItemId;

		end
		else if @packsize = '.5' or @packsize = '0.5'
		begin
		    declare @count int;

			select @count = count(*) from PKPurchaseItem where PurchaseItemId = @PurchaseItemId and packsize = '.5';
			--select @strExistedResourceId = resourceid from PKPurchaseItem where PurchaseItemId = @UniQuePurchaseItemID

			if @count <> 1
			begin
				declare @currentItemOrder int;
				select @currentItemOrder = isnull(itemOrder,0) from PKPurchaseItem where PurchaseItemId = @PurchaseItemId ;
				insert into PKPurchaseItem([PurchaseItemId]
				  ,[CardType]
				  ,[CardName]
				  ,[CardNumber]
				  ,[CardHolder]
				  ,[ProductId]
				  ,[CreateDate]
				  ,[Status]
				  ,[ResourceId]
				  ,[ResourceTimeFrom]
				  ,[ResourceTimeTo]
				  ,[Remark]
				  ,[PurchaseId]
				  ,[ResourceDate]
				  ,[packagetype]
				  ,[packsize]
				  ,[itemOrder]
				  )
				  select newid() as PurchaseItemId
				  ,[CardType]
				  ,[CardName]
				  ,[CardNumber]
				  ,[CardHolder]
				  ,[ProductId]
				  ,[CreateDate]
				  ,[Status]
				  ,ResourceId
				  ,[ResourceTimeFrom]
				  ,[ResourceTimeTo]
				  ,'' as Remark
				  ,[PurchaseId]
				  ,[ResourceDate]
				  ,[packagetype]
				  ,'.5' as packsize
				  ,@currentItemOrder+1
				  from PKPurchaseItem where PurchaseItemId = @PurchaseItemId;
			end
			update PKPurchaseItem 
				set ResourceId = @ResourceId,
				ResourceTimeFrom = @resourceTimeFrom,
				ResourceTimeTo = @resourceTimeto,
				ResourceDate  = @resouceDate,
				Remark  = @Remark,
				updatedBy = @updatedby,
				sales = @sales,
				forceSales = @forceSales,
				packsize = '.5'
				where PurchaseItemId = @PurchaseItemId;

			
		end
		else
		begin
			declare @locationid nvarchar(50);
			declare @cProductId varchar(50);
			declare @cardNumber nvarchar(50);

			select @locationid = pppo.Locationid
			,@cProductId = ppi.ProductId
			,@cardNumber = ppi.CardNumber
			from PKPurchaseItem PPI
			inner join PKPurchasePackage ppp on ppp.PurchaseId = ppi.PurchaseId
			inner join PKPurchasePackageOrder PPPO on pppo.transferId = ppp.transferId
			where ppi.PurchaseItemId= @PurchaseItemId

			update PKPurchaseItem 
				set ResourceId = @ResourceId,
				ResourceTimeFrom = @resourceTimeFrom,
				ResourceTimeTo = @resourceTimeto,
				ResourceDate  = @resouceDate,
				Remark  = @Remark,
				updatedBy = @updatedby,
				sales = @sales,
				forceSales = @forceSales
				where PurchaseItemId = @PurchaseItemId;

			declare @currentPacksize decimal(18,1);
			set @currentPacksize = cast(@packsize as decimal(18,1));
			set @currentPacksize = @currentPacksize - 1

			declare @loopPurchaseItemID uniqueidentifier;
			declare @loopPacesize  decimal(18,1);
			declare @loopStrPacesize  varchar(10);

			DECLARE t_cursor CURSOR FOR 
				select ppi.PurchaseItemId, packsize
				from PKPurchaseItem PPI
				inner join PKPurchasePackage ppp on ppp.PurchaseId = ppi.PurchaseId
				inner join PKPurchasePackageOrder PPPO on pppo.transferId = ppp.transferId
				where ppi.ProductId = @cProductId and ppi.CardNumber=@cardNumber and pppo.Locationid = @locationid
				and isnull(ppi.ResourceDate, '') = ''
				order by packsize, itemOrder


			OPEN t_cursor
			FETCH next FROM t_cursor INTO @loopPurchaseItemID,@loopStrPacesize
			WHILE @@fetch_status = 0
			BEGIN 
				if @currentPacksize >0
				begin
					if @currentPacksize = 0.5
					begin
						set @loopPacesize= cast(@loopStrPacesize as decimal(18,1))
						if @loopPacesize = 0.5
						begin
							--update PKPurchaseItem set
							--ResourceId = @strResourceId,
							--ResourceDate = @strDate,
							--ResourceTimeFrom = @strTimefrom,
							--ResourceTimeTo = @strTimeTo,
							--Remark = 'Quick Check Out'
							--where PurchaseItemId = @loopPurchaseItemID
							update PKPurchaseItem 
								set ResourceId = @ResourceId,
								ResourceTimeFrom = @resourceTimeFrom,
								ResourceTimeTo = @resourceTimeto,
								ResourceDate  = @resouceDate,
								Remark  = @Remark,
								updatedBy = @updatedby,
								sales = @sales,
								forceSales = @forceSales
								where PurchaseItemId = @loopPurchaseItemID;

						end
						else
						begin
							declare @currentItemOrderLOOP int;
							select @currentItemOrderLOOP = isnull(itemOrder,0) from PKPurchaseItem where PurchaseItemId = @PurchaseItemId ;
							insert into PKPurchaseItem([PurchaseItemId]
							  ,[CardType]
							  ,[CardName]
							  ,[CardNumber]
							  ,[CardHolder]
							  ,[ProductId]
							  ,[CreateDate]
							  ,[Status]
							  ,[ResourceId]
							  ,[ResourceTimeFrom]
							  ,[ResourceTimeTo]
							  ,[Remark]
							  ,[PurchaseId]
							  ,[ResourceDate]
							  ,[packagetype]
							  ,[packsize]
							  ,[itemOrder]
							  )
							  select newid() as PurchaseItemId
							  ,[CardType]
							  ,[CardName]
							  ,[CardNumber]
							  ,[CardHolder]
							  ,[ProductId]
							  ,[CreateDate]
							  ,[Status]
							  ,ResourceId
							  ,[ResourceTimeFrom]
							  ,[ResourceTimeTo]
							  ,'' as Remark
							  ,[PurchaseId]
							  ,[ResourceDate]
							  ,[packagetype]
							  ,'.5' as packsize
							  ,@currentItemOrderLOOP+1
							  from PKPurchaseItem where PurchaseItemId = @loopPurchaseItemID;
						
							update PKPurchaseItem 
								set ResourceId = @ResourceId,
								ResourceTimeFrom = @resourceTimeFrom,
								ResourceTimeTo = @resourceTimeto,
								ResourceDate  = @resouceDate,
								Remark  = @Remark,
								updatedBy = @updatedby,
								sales = @sales,
								forceSales = @forceSales,
								packsize = '.5'
							where PurchaseItemId = @loopPurchaseItemID;
						end
						set @currentPacksize = @currentPacksize - 0.5
					end
					else
					begin
						set @loopPacesize= cast(@loopStrPacesize as decimal(18,1))
						if @loopPacesize = 0.5
						begin
							update PKPurchaseItem 
							set ResourceId = @ResourceId,
							ResourceTimeFrom = @resourceTimeFrom,
							ResourceTimeTo = @resourceTimeto,
							ResourceDate  = @resouceDate,
							Remark  = @Remark,
							updatedBy = @updatedby,
							sales = @sales,
							forceSales = @forceSales,
							packsize = '.5'
							where PurchaseItemId = @loopPurchaseItemID;
							set @currentPacksize = @currentPacksize - 0.5
						end
						else
						begin
							update PKPurchaseItem 
							set ResourceId = @ResourceId,
							ResourceTimeFrom = @resourceTimeFrom,
							ResourceTimeTo = @resourceTimeto,
							ResourceDate  = @resouceDate,
							Remark  = @Remark,
							updatedBy = @updatedby,
							sales = @sales,
							forceSales = @forceSales
							where PurchaseItemId = @loopPurchaseItemID
							set @currentPacksize = @currentPacksize - 1
						end
					end
				end
				FETCH next FROM t_cursor INTO @loopPurchaseItemID,@loopStrPacesize
			END 
			CLOSE t_cursor 
			DEALLOCATE t_cursor 


		end
    

END




GO
/****** Object:  StoredProcedure [dbo].[PK_SetCardMoneyTransfer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetCardMoneyTransfer]
	-- Add the parameters for the stored procedure here
	@originalCardNo varchar(50),
	@transferToCardNo varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @originalCardBalance decimal(18,2);
	declare @transferToCardBalance decimal(18,2);
	
	select @originalCardBalance= isnull(Balance,0) from CustomerCard where CardNo = @originalCardNo;
	select @transferToCardBalance= isnull(Balance,0) from CustomerCard where CardNo = @transferToCardNo;

	update CustomerCard set Balance = 0 where CardNo = @originalCardNo;
	update CustomerCard set Balance = @originalCardBalance + isnull(Balance,0) where CardNo = @transferToCardNo;

    
END
GO
/****** Object:  StoredProcedure [dbo].[PK_SetCommissionAddEmployee]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetCommissionAddEmployee]
	@groupId int,
	@EmployeeId varchar(50),
	@createdBy varchar(50),
	@LocationId nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	delete  from PKCommissionCategoryEmployee 
		where employeeID = @EmployeeId
		and exists ( 
				select * from PKCommissionCategory PCC where PCC.id = PKCommissionCategoryEmployee.CategoryId and isnull(PCC.locationID,'') = @Locationid
			)
		;
	if @groupId>0
	begin
		insert into PKCommissionCategoryEmployee(CategoryId,employeeID,createdBy,createTime)
			values(@groupId,@EmployeeId,@createdBy,getdate());
	end

END



GO
/****** Object:  StoredProcedure [dbo].[PK_SetCommissionAddGroup]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetCommissionAddGroup]
	@GroupName varchar(50),
	@locationid nvarchar(50)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	declare @intGroupCount int

	SET NOCOUNT ON;


	select @intGroupCount = count(*) from PKCommissionCategory where CommissionCategory = @GroupName and LocationId = @locationid;

	if @intGroupCount=0
	begin
	 insert into PKCommissionCategory(CommissionCategory,locationId)values(@GroupName,@locationid);
	 select 0 as error;
	end
	else
	begin
		select  1 as error;
	end



END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetCommissionDeleteRateById]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetCommissionDeleteRateById]
	 @CommissionCategoryRateId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    delete from PKCommissionCategoryRate where id = @CommissionCategoryRateId;


END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetCommissionUpdateInsertRateById]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_SetCommissionUpdateInsertRateById]
	 @CommissionCategoryRateId int,
	 @CategoryId int,  --Group
	 @singleEmployeeId varchar(50),
	 @isCategoryOrSingle nchar(1),
	 @Department varchar(50),
	 @Category varchar(50),
	 @ProductId varchar(50),
	 @BasePrice varchar(50),
	 @CommissionType varchar(5),
	 @commission decimal(18,2),
	 @createdBy varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    if @CommissionCategoryRateId=0 
	begin
		insert into PKCommissionCategoryRate(CategoryId
           ,SingleEmployeeId
           ,isCategoryOrSingle
           ,Department
           ,Category
           ,ProductId
           ,BasePrice
           ,CommissionType
           ,Commission
           ,createdBy
		   )values(
			@CategoryId
           ,@SingleEmployeeId
           ,@isCategoryOrSingle
           ,@Department
           ,@Category
           ,@ProductId
           ,@BasePrice
           ,@CommissionType
           ,@Commission
           ,@createdBy
		   )
	end
	else
	begin
		update PKCommissionCategoryRate set
		CategoryId = @CategoryId,
           SingleEmployeeId = @singleEmployeeId
           ,isCategoryOrSingle = @isCategoryOrSingle
           ,Department= @Department
           ,Category=@Category
           ,ProductId=@ProductId
           ,BasePrice=@BasePrice
           ,CommissionType=@CommissionType
           ,Commission=@commission
           ,createdBy=@createdBy
		   where id = @CommissionCategoryRateId
	end


END



GO
/****** Object:  StoredProcedure [dbo].[Pk_setcustomertransactionbytrno]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Pk_setcustomertransactionbytrno] @transactionNo VARCHAR( 
50), 
                                                         @CustomerId    VARCHAR( 
50) 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from 
      -- interfering with SELECT statements. 
      SET nocount ON; 

      DECLARE @customerCount INT; 
      DECLARE @TransactionId VARCHAR(50); 
      DECLARE @TransferAcount DECIMAL(18, 2); 
      DECLARE @DiscountLeft DECIMAL(18, 2); 
      DECLARE @PointDollarRate DECIMAL(18, 2); 
      DECLARE @AmountForDisc DECIMAL(18, 2); 
      DECLARE @AmountForPoints DECIMAL(18, 2); 
      DECLARE @PointsBalance DECIMAL(18, 2); 

      SET @customerCount = 0; 
      SET @TransactionId = ''; 
      SET @DiscountLeft =0; 
      SET @PointDollarRate =0.0; 
      SET @AmountForDisc =0.0; 
      SET @AmountForPoints =0.0; 
      SET @PointsBalance =0.0; 

      SELECT @TransactionId = id 
      FROM   postransaction 
      WHERE  transactionno = @transactionNo; 

      INSERT INTO [dbo].[customertransaction] 
                  (customerid, 
                   transactionid, 
                   discountleft, 
                   pointdollarrate, 
                   amountfordisc, 
                   amountforpoints, 
                   pointsbalance) 
      VALUES      (@CustomerId, 
                   @TransactionId, 
                   @DiscountLeft, 
                   @PointDollarRate, 
                   @AmountForDisc, 
                   @AmountForPoints, 
                   @PointsBalance ) 

      SELECT pt.transactionno, 
             Sum(transactionitem.itemsubtotal) AS totalAmount 
      INTO   #tbl1 
      FROM   postransaction pt 
             INNER JOIN transactionitem 
                     ON pt.id = transactionitem.transactionid 
      WHERE  transactionitem.type = 'Item' 
             AND transactionitem.status = 'Confirmed' 
             AND pt.transactionno = @transactionNo 
      GROUP  BY pt.transactionno 

      SELECT @TransferAcount = Isnull(totalamount, 0) 
      FROM   #tbl1 
      WHERE  transactionno = @transactionNo; 

      UPDATE customer 
      SET    totalpurchaseamount = totalpurchaseamount + @TransferAcount 
      WHERE  id = @CustomerId; 

      DROP TABLE #tbl1; 
  END 


GO
/****** Object:  StoredProcedure [dbo].[PK_SetDeleteModifierGroup]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetDeleteModifierGroup]
	@ModifierGroupId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE FROM PKModifierItem WHERE ModifierGroupID = @ModifierGroupId
	DELETE FROM PKModifierConnection WHERE ModifierGroupID = @ModifierGroupId
	DELETE FROM PKModifierGroup WHERE ID = @ModifierGroupId

END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetDeletePurchasedpackage]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetDeletePurchasedpackage]
	@PackagedId varchar(50),
	@transferId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @isBookingConsolidateProducts NVARCHAR(100); 

	select @isBookingConsolidateProducts = isnull(value, 'false') from PKSetting where FieldName = 'isBookingConsolidateProducts'
	if @isBookingConsolidateProducts is null
	begin
		set @isBookingConsolidateProducts = 'false'
	end
	
	if @isBookingConsolidateProducts = 'true'
	begin
		--------------------------------------------------------------------------------
		declare @bomOrProductId varchar(50);
		select @bomOrProductId = BomOrProductID from PKPurchasePackage where PurchaseId = cast(@PackagedId as uniqueidentifier);

		delete from PKPurchaseItem where exists(
			select * from PKPurchasePackage where BomOrProductID = @bomOrProductId and transferId = @transferId and PKPurchaseItem.PurchaseId = PKPurchasePackage.PurchaseId
		)
		delete from PKPurchasePackage where BomOrProductID = @bomOrProductId and transferId = @transferId 
		--------------------------------------------------------------------------------
		declare @ProductId varchar(50);
		select @ProductId = ProductId from PKPurchaseItem  where PurchaseItemId = cast(@PackagedId as uniqueidentifier);

		delete from PKPurchaseItem where exists(
			select * from PKPurchasePackage where BomOrProductID = @ProductId and transferId = @transferId and PKPurchaseItem.PurchaseId = PKPurchasePackage.PurchaseId
		)
		delete from PKPurchasePackage where BomOrProductID = @ProductId and transferId = @transferId 
		--------------------------------------------------------------------------------

		delete from PKPrepaidPackageTransaction where transferid = @transferId;
		delete from PKDepositPackageTransaction where id = @PackagedId;
		delete from PKGiftCardTransaction where id = @PackagedId;
	end
	else
	begin

		delete from PKPurchaseItem where PurchaseId = cast(@PackagedId as uniqueidentifier);
		delete from PKPurchasePackage where  PurchaseId = cast(@PackagedId as uniqueidentifier)

		delete from PKPurchaseItem where PurchaseItemId = cast(@PackagedId as uniqueidentifier);
		delete from PKPrepaidPackageTransaction where transferid = @transferId;
		delete from PKDepositPackageTransaction where id = @PackagedId;
		delete from PKGiftCardTransaction where id = @PackagedId;
	end

END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetFeatureRole]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_SetFeatureRole]
	@RoleId int,
	@featureId int,
	@IsChecked varchar(20),
	@whichSystem varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @count int
	
    -- Insert statements for procedure here
	if @whichSystem = 'booking' 
	begin
		--delete from PKRoleFeatureBooking where RoleID = @RoleId and FeatureID = @featureId;
		if lower(@IsChecked)='true'
		begin
			select @count = count(*) from PKRoleFeatureBooking where RoleID = @RoleId and FeatureID = @featureId
			if @count = 0 
			begin
				declare @newRoleId int
				SELECT @newRoleId = Max(ID) FROM PKRoleFeatureBooking ;
				set @newRoleId = isnull(@newroleId,0);
				set @newRoleId = @newRoleId + 1;
				insert into PKRoleFeatureBooking(id,RoleID,FeatureID)values(@newRoleId,@RoleId,@featureId);
			end
		end
	end
	else
	begin
		--delete from PKRoleFeature where RoleID = @RoleId and FeatureID = @featureId;
		if lower(@IsChecked)='true'
		begin
			select @count = count(*) from PKRoleFeature where RoleID = @RoleId and FeatureID = @featureId
			if @count = 0 
			begin
				declare @newRoleId2 int
				SELECT @newRoleId2 = Max(ID) FROM PKRoleFeature ;
				set @newRoleId2 = isnull(@newRoleId2,0);
				set @newRoleId2 = @newRoleId2 + 1;
				insert into PKRoleFeature(id,RoleID,FeatureID)values(@newRoleId2,@RoleId,@featureId);
			end
		end
	end
END




GO
/****** Object:  StoredProcedure [dbo].[PK_SetHeadQuarterInLocation]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetHeadQuarterInLocation]
	@HeadLocationId varchar(50),
	@isChecked varchar(1)
AS
BEGIN
	if @isChecked = '1'
	begin
		update PKLocation set IsHeadquarter = '0';
		update PKLocation set IsHeadquarter = '1' where LocationID = @HeadLocationId;
	end
	else 
	begin
		declare @HeaderCount int;
		select @HeaderCount = count(*) from PKLocation where IsHeadquarter = '1';
		if @HeaderCount=0
		begin
			update PKLocation set IsHeadquarter = '1' where LocationID = @HeadLocationId;
		end
	end
	
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetInsertCity]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetInsertCity]
	@ProvinceID nvarchar(50),
	@CityText nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @errorMessage nvarchar(50);
    declare @intCountCityInProvinceID int;


	select @intCountCityInProvinceID = count(*) from PKCity where ProvinceID = @ProvinceID and City = @CityText;

	if @intCountCityInProvinceID >0 
	begin
		set @errorMessage = '1';
	end
	else
	begin
		insert into PKCity(ProvinceID,City)values(@ProvinceID,@CityText);
		set @errorMessage = '0';

	end
	select @errorMessage as errorMessage;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetInsertCountry]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetInsertCountry]
	@CountryText nvarchar(50),
	@CountryCode nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @errorMessage nvarchar(50);
    declare @intCountProvinceCodeInCountryID int;
	declare @country nvarchar(50);
    declare @countryId int;
	set @countryId = 0;

	select @intCountProvinceCodeInCountryID = count(*) from PKCountry where Country = @CountryText and Code = @CountryCode;

	if @intCountProvinceCodeInCountryID >0 
	begin
		set @errorMessage = '1';
	end
	else
	begin
		insert into PKCountry(Country, Code)values(@CountryText, @CountryCode);
		set @errorMessage = '0';
		select @countryId = CountryID, @country = Country from PKCountry where Country = @CountryText and Code = @CountryCode;

	end
	select @errorMessage as errorMessage, @countryId as countryId, @country as country;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetInsertPKResourceModifierItem]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetInsertPKResourceModifierItem]
	@ResourceID varchar(50),
	@ModifierItemID varchar(50),
	@ModifierType nChar(1)

As
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @ModifierId varchar(50);
	declare @count int

	select @ModifierId = ModifierGroupID from PKModifierItem where id = @ModifierItemID

	select @count = count(*) from PKResourceModifier where SpecialOrResourceId = cast(@resourceId as uniqueidentifier) and ModifierId = @ModifierId

	if @count=0
	begin
		insert into PKResourceModifier(
		SpecialOrResourceId,
		ModifierId,
		ModifierType
		)values( 
		cast(@resourceId as uniqueidentifier),
		@ModifierId,
		@ModifierType
		)
    end

	insert into PKResourceModifierItem(
	ResourceModifierID, 
	SpecialOrResourceId,
	ModifierId,
	ModifierType,
	ModifierItemID)
	values(
	0, 
	cast(@resourceId as uniqueidentifier),
	@ModifierId,
	@ModifierType,
	@ModifierItemID
	)

END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetInsertProvince]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetInsertProvince]
	@CountryID nvarchar(50),
	@ProvinceText nvarchar(50),
	@ProvinceCode nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @errorMessage nvarchar(50);
    declare @intCountProvinceCodeInCountryID int;
    declare @provinceId int;
	set @provinceId = 0;

	select @intCountProvinceCodeInCountryID = count(*) from PKProvince where ProvinceCode = @ProvinceCode and CountryID = @CountryID;

	if @intCountProvinceCodeInCountryID >0 
	begin
		set @errorMessage = '1';
	end
	else
	begin
		insert into PKProvince(countryId, Province,ProvinceCode)values(@CountryID,@ProvinceText,@ProvinceCode);
		set @errorMessage = '0';
		select @provinceId = ProvinceID from PKProvince where ProvinceCode = @ProvinceCode and CountryID = @CountryID;

	end
	select @errorMessage as errorMessage, @provinceId as provinceId;
END



GO
/****** Object:  StoredProcedure [dbo].[PK_SetInventoryHistoryBackById]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[PK_SetInventoryHistoryBackById]
	@InventoryHistoryId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	declare @location varchar(50);
	declare @InventoryId varchar(50);
	declare @OldQty decimal(18,2);
	declare @NewQty decimal(18,2);
	declare @QtyDiff decimal(18,2);

	select
	@location = LocationId,
	@InventoryId = InventoryId,
	@OldQty = OldQty,
	@NewQty = NewQty
	from PKInventoryHistory where id = @InventoryHistoryId;
	

	set @QtyDiff = @NewQty - @OldQty;


	update PKInventory set qty = qty - @QtyDiff,
	Updater = 'Inventory history back. ID: ' + cast(@InventoryHistoryId as varchar(50)) 
	where id = @InventoryId;



END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetInventoryWhenOutbound]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[PK_SetInventoryWhenOutbound]
	@ProductId varchar(50),
	@locationId varchar(50),
	@QTY decimal(18,2),
	@Price decimal(18,2)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	declare @OriginalQty decimal(18,2);
	declare @OriginalCost decimal(18,2);
	declare @NewQty decimal(18,2);
	declare @NewAverageCost decimal(18,2);
	declare @isHeadQuarter varchar(20);

	select @IsHeadquarter = IsHeadquarter from pklocation where locationId = @locationId;
	


	select @OriginalCost= AverageCost from PKInventory 
	where productId = @productId and LocationID = @locationId;
	if @IsHeadquarter = '1'
	Begin
		select @OriginalQty = sum(Qty) from PKInventory 
		where productId = @productId 
		group by ProductID
		;
	End
	else
	Begin
		select @OriginalQty = Qty from PKInventory 
		where productId = @productId and LocationID = @locationId;
	End
	
	set @newQty = @OriginalQty - @Qty;

	set @NewAverageCost = (@OriginalQty * @OriginalCost - @QTY*@Price)/@newQty;

	update PKInventory set qty = qty - @QTY, averagecost = @NewAverageCost
	where productId = @productId and LocationID = @locationId;


END



GO
/****** Object:  StoredProcedure [dbo].[PK_SetLanguageInPKSetting]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetLanguageInPKSetting]
	@language varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @languageName nvarchar(200);
	select @languageName = languagename from pk_DictionaryList where language = @language;


	update pksetting set value = @language where fieldName = 'LanguangeSetting';
	update pksetting set value = @languageName where fieldName = 'The2ndLanguageName';


    

END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetMoveProdInAnotherProd]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetMoveProdInAnotherProd]
	@ProductId varchar(50),
	@NewBaseProductId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @CanBeMove bit;
	declare @PLU varchar(50);
	declare @CategoryId varchar(50);
	declare @count int;
	declare @errorMsg varchar(200);

	set @CanBeMove = 0;
	set @errorMsg = '';

	select @count = count(*) from PKMapping where BaseProductID = @ProductId;
	if @count=0	--If the moving product is a base product with children products , it cannot be moved.
	begin
		Set @CanBeMove = 1;
	end
	else
	begin
		set @errorMsg = 'The moving product has children products and cannot be moved';
	end
	set @PLU = ''

	if @CanBeMove = 1
	begin
		select @count = count(*) from PKMapping where ProductID = @NewBaseProductId;  -- if the new base product is a child product in one family, the movement cannot be proceeded.
		if @count = 0
		begin
			if dbo.Pk_FuncGetProdWeighOrEach(@ProductId)= dbo.Pk_FuncGetProdWeighOrEach(@NewBaseProductId)
			begin
				select @PLU = plu, @CategoryId = CategoryID from PKProduct where id = @ProductId;
				select @count = count(*) from PKProduct where plu = @PLU and id <> @ProductId;
				if @count>0
				begin
					set @plu = dbo.PK_FuncGetNewPLUByCategoryID(@CategoryId);
					update PKProduct set plu = @plu where id = @ProductId;
				end
				delete from PKMapping where productid  = @ProductId;
				insert into PKMapping(BaseProductID,ProductID,MaxStockQty,MinStockQty,Status)
				values(@NewBaseProductId,@ProductId,0,0,'Active')
			end
			else
			begin
				set @errorMsg = 'Please double check to make sure both product has same weigh type.';
			end
		end
		else
		begin
			set @errorMsg = 'The new base product is a child product of another, the movement cannot be proceeded.';
		end

	end
	
	select @plu as newPlu, @errorMsg as errorMsg;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetNewOnlineOrderCustomer]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetNewOnlineOrderCustomer]
	@Type VARCHAR(50),
	@NewCustomerId VARCHAR(50),
	@OldCustomerId VARCHAR(50)
AS
BEGIN
	IF LOWER(@Type) = 'new'
	BEGIN
		UPDATE PKCustomerMultiAdd SET Online='Confirmed' WHERE ((ID=@NewCustomerId) AND (LOWER(Online)='new'))
	END
	ELSE IF LOWER(@Type) = 'exist'
	BEGIN
		UPDATE n set n.CompanyName = coalesce(NULLIF(n.CompanyName, ''), o.CompanyName), 
		n.CompanyType = coalesce(NULLIF(n.CompanyType, ''), o.CompanyType),
		n.Terms = coalesce(NULLIF(n.Terms, ''), o.Terms),
		n.CreditLimit = coalesce(n.CreditLimit, o.CreditLimit),
		n.PriceList = coalesce(NULLIF(n.PriceList, ''), o.PriceList),
		n.PercentDiscount = coalesce(n.PercentDiscount, o.PercentDiscount),
		n.DollarsDiscount = coalesce(n.DollarsDiscount, o.DollarsDiscount),
		n.Classification = coalesce(NULLIF(n.Classification, ''), o.Classification),
		n.Status = coalesce(NULLIF(n.Status, ''), o.Status),
		n.WebSite = coalesce(NULLIF(n.WebSite, ''), o.WebSite),
		n.CourierName = coalesce(NULLIF(n.CourierName, ''), o.CourierName), 
		n.CourierTEL = coalesce(NULLIF(n.CourierTEL, ''), o.CourierTEL), 
		n.CourierFAX = coalesce(NULLIF(n.CourierFAX, ''), o.CourierFAX), 
		n.CourierAccountNo = coalesce(NULLIF(n.CourierAccountNo, ''), o.CourierAccountNo), 
		n.CreateTime = coalesce(n.CreateTime, o.CreateTime),
		n.UpdateTime = coalesce(n.UpdateTime, o.UpdateTime),
		n.CustomerRemarks = coalesce(NULLIF(n.CustomerRemarks, ''), o.CustomerRemarks),
		n.Warning = coalesce(NULLIF(n.Warning, ''), o.Warning),
		n.OtherName = coalesce(NULLIF(n.OtherName, ''), o.OtherName),
		n.PSTNo = coalesce(NULLIF(n.PSTNo, ''), o.PSTNo),
		n.CreditAmount = coalesce(n.CreditAmount, o.CreditAmount),
		n.IsRememberShippingAddr = coalesce(NULLIF(n.IsRememberShippingAddr, ''), o.IsRememberShippingAddr),
		n.ReferenceID = coalesce(NULLIF(n.ReferenceID, ''), o.ReferenceID),
		n.Online = 'Confirmed'
		FROM PKCustomerMultiAdd n inner join PKCustomerMultiAdd o ON (n.ID = @NewCustomerId) AND (o.ID = @OldCustomerId)

		UPDATE CustomerTransaction SET CustomerID = @NewCustomerId WHERE CustomerID = @OldCustomerId
		UPDATE PKSO SET CustomerID = @NewCustomerId WHERE CustomerID = @OldCustomerId
		UPDATE PKSalesCustomerMp SET CustomerID = @NewCustomerId WHERE CustomerID = @OldCustomerId
		UPDATE PKMultiADD SET ReferenceID = @NewCustomerId WHERE ReferenceID = @OldCustomerId

		DELETE FROM PKCustomerMultiAdd WHERE ID = @OldCustomerId
	END
	ELSE IF LOWER(@Type) = 'deny'
	BEGIN
		DELETE pkmultiadd WHERE ReferenceID=@NewCustomerId
		DELETE PKCustomerMultiAdd WHERE ID=@NewCustomerId
	END
END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetPaymentOrderTrigger]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetPaymentOrderTrigger] 
	@paymentOrderId VARCHAR(50),
	@locationId VARCHAR(50),
	@cardNo VARCHAR(50)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	DECLARE @Deposit decimal(18, 2);
	DECLARE @PaymentDeposit decimal(18, 2);

	DECLARE @IsMultiCard nvarchar(50);
	SELECT @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'

	SELECT transferId INTO #tbl1 FROM PKPurchasePackagePaymentItem WHERE paymentOrderId = @paymentOrderId

	SET @Deposit = 0.00;
	SELECT @Deposit = SUM(ISNULL(Deposit, 0.00)) FROM PKPrepaidPackageTransaction 
	WHERE ((Type = 'Purchase') AND (transferId IN (SELECT transferId FROM #tbl1))) 
	IF ISNULL(@Deposit, 0.00) <> 0.00
	BEGIN
		IF(@IsMultiCard = 'true')
		BEGIN
			UPDATE CustomerCard SET Balance = ISNULL(Balance, 0.00) + @Deposit WHERE CardNo = @cardNo
		END
		ELSE
		BEGIN
			UPDATE Customer SET Points = ISNULL(Points, 0.00) + @Deposit WHERE CustomerNo = @cardNo
		END
	END

	SET @Deposit = 0.00;
	SELECT @Deposit = SUM(ISNULL(Deposit, 0.00)) FROM PKDepositPackageTransaction --Different table.
	WHERE ((Type = 'Purchase') AND (transferId IN (SELECT transferId FROM #tbl1))) 
	IF ISNULL(@Deposit, 0.00) <> 0.00
	BEGIN
		IF(@IsMultiCard = 'true')
		BEGIN
			UPDATE CustomerCard SET Balance = ISNULL(Balance, 0.00) + @Deposit WHERE CardNo = @cardNo
		END
		ELSE
		BEGIN
			UPDATE Customer SET Points = ISNULL(Points, 0.00) + @Deposit WHERE CustomerNo = @cardNo
		END
	END

	SELECT GiftCardId, GiftCardNo INTO #tbl2 FROM PKGiftCardTransaction WHERE ((Type = 'Purchase') AND (transferId IN (SELECT transferId FROM #tbl1)))
	UPDATE PKGiftCardSN SET PKGiftCardSN.LocationID = @locationId, PKGiftCardSN.SaleTime = GETDATE() FROM PKGiftCardSN
	INNER JOIN #tbl2 AS PurchaseGiftCard ON (PKGiftCardSN.CardID = PurchaseGiftCard.GiftCardId) AND (PKGiftCardSN.CardNo = PurchaseGiftCard.GiftCardNo)

	SET @PaymentDeposit = 0.00;
	SELECT @PaymentDeposit = SUM(ISNULL(paymentAmount, 0.00)) FROM PKPurchasePackagePayment 
	WHERE (paymentType = 'Deposit') AND (PaymentOrderId = @paymentOrderId) GROUP BY PaymentOrderId
	IF ISNULL(@PaymentDeposit, 0.00) <> 0.00
	BEGIN
		IF(@IsMultiCard = 'true')
		BEGIN
			UPDATE CustomerCard SET Balance = ISNULL(Balance, 0.00) - @PaymentDeposit WHERE CardNo = @cardNo
		END
		ELSE
		BEGIN
			UPDATE Customer SET Points = ISNULL(Points, 0.00) - @PaymentDeposit WHERE CustomerNo = @cardNo
		END
	END

	SELECT CardId, CardNo,paymentAmount INTO #tbl3 FROM PKPurchasePackagePayment WHERE (paymentType = 'GiftCard') AND (PaymentOrderId = @paymentOrderId)
	--UPDATE PKGiftCardSN SET PKGiftCardSN.Status = 'Inactive' FROM PKGiftCardSN
	UPDATE PKGiftCardSN SET Balance = PKGiftCardSN.balance - PaymentGiftCard.paymentAmount FROM PKGiftCardSN
	INNER JOIN #tbl3 AS PaymentGiftCard ON (PaymentGiftCard.CardId = PKGiftCardSN.CardID) AND (PaymentGiftCard.CardNo = PKGiftCardSN.CardNo)

	DROP TABLE #tbl1;
	DROP TABLE #tbl2;
	DROP TABLE #tbl3;
END



GO
/****** Object:  StoredProcedure [dbo].[PK_SetPaymentOrderTriggerNegative]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetPaymentOrderTriggerNegative] 
	@transferId VARCHAR(50),
	@locationId VARCHAR(50),
	@cardNo VARCHAR(50),
	@deposit decimal(18,2)
AS 
BEGIN 
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

	DECLARE @PaymentDeposit decimal(18, 2);
	DECLARE @IsMultiCard nvarchar(50);
	SELECT @IsMultiCard = lower(value) from PKSetting where FieldName = 'isBookingMultiCard'



	--SELECT @Deposit = SUM(ISNULL(Deposit, 0.00)) FROM PKPrepaidPackageTransaction 
	--WHERE ((Type = 'Purchase') AND (transferId IN (SELECT transferId FROM #tbl1))) 

	--select @Deposit = isnull( TotalAmount ,0) from PKPurchasePackagePaymentOrder where id = @paymentOrderId;
	
	IF ISNULL(@Deposit, 0.00) <> 0.00
	BEGIN
		IF(@IsMultiCard = 'true')
		BEGIN
			UPDATE CustomerCard SET Balance = ISNULL(Balance, 0.00) + @Deposit WHERE CardNo = @cardNo
		END
		ELSE
		BEGIN
			UPDATE Customer SET Points = ISNULL(Points, 0.00) + @Deposit WHERE CustomerNo = @cardNo
		END
	END

	update PKPurchasePackage set Status = 'Inactive' where transferId = @transferId;

	--SET @Deposit = 0.00;
	--SELECT @Deposit = SUM(ISNULL(Deposit, 0.00)) FROM PKDepositPackageTransaction 
	--WHERE ((Type = 'Purchase') AND (transferId IN (SELECT transferId FROM #tbl1))) 
	--IF ISNULL(@Deposit, 0.00) <> 0.00
	--BEGIN
	--	IF(@IsMultiCard = 'true')
	--	BEGIN
	--		UPDATE CustomerCard SET Balance = ISNULL(Balance, 0.00) + @Deposit WHERE CardNo = @cardNo
	--	END
	--	ELSE
	--	BEGIN
	--		UPDATE Customer SET Points = ISNULL(Points, 0.00) + @Deposit WHERE CustomerNo = @cardNo
	--	END
	--END

	--SELECT GiftCardId, GiftCardNo INTO #tbl2 FROM PKGiftCardTransaction WHERE ((Type = 'Purchase') AND (transferId IN (SELECT transferId FROM #tbl1)))
	--UPDATE PKGiftCardSN SET PKGiftCardSN.LocationID = @locationId, PKGiftCardSN.SaleTime = GETDATE() FROM PKGiftCardSN
	--INNER JOIN #tbl2 AS PurchaseGiftCard ON (PKGiftCardSN.CardID = PurchaseGiftCard.GiftCardId) AND (PKGiftCardSN.CardNo = PurchaseGiftCard.GiftCardNo)

	--SET @PaymentDeposit = 0.00;
	--SELECT @PaymentDeposit = SUM(ISNULL(paymentAmount, 0.00)) FROM PKPurchasePackagePayment 
	--WHERE (paymentType = 'Deposit') AND (PaymentOrderId = @paymentOrderId) GROUP BY PaymentOrderId
	--IF ISNULL(@PaymentDeposit, 0.00) <> 0.00
	--BEGIN
	--	IF(@IsMultiCard = 'true')
	--	BEGIN
	--		UPDATE CustomerCard SET Balance = ISNULL(Balance, 0.00) - @PaymentDeposit WHERE CardNo = @cardNo
	--	END
	--	ELSE
	--	BEGIN
	--		UPDATE Customer SET Points = ISNULL(Points, 0.00) - @PaymentDeposit WHERE CustomerNo = @cardNo
	--	END
	--END

	--SELECT CardId, CardNo INTO #tbl3 FROM PKPurchasePackagePayment WHERE (paymentType = 'GiftCard') AND (PaymentOrderId = @paymentOrderId)
	--UPDATE PKGiftCardSN SET PKGiftCardSN.Status = 'Inactive' FROM PKGiftCardSN
	--INNER JOIN #tbl3 AS PaymentGiftCard ON (PaymentGiftCard.CardId = PKGiftCardSN.CardID) AND (PaymentGiftCard.CardNo = PKGiftCardSN.CardNo)

	--DROP TABLE #tbl1;
	--DROP TABLE #tbl2;
	--DROP TABLE #tbl3;
END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetPKStockDepartmentCategory]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetPKStockDepartmentCategory]
		@StockTakeID varchar(50),
		@DepartmentCategoryID varchar(50),
		@DepartmentCategoryName varchar(200),
		@CDType varchar(1)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO PKStockDepartmentCategory
           (StockTakeID
           ,DepartmentCategoryID
           ,DepartmentCategoryName
           ,CDType)
     VALUES
          (
			@StockTakeID ,
			@DepartmentCategoryID,
			@DepartmentCategoryName,
			@CDType
		  )


END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetPORemarksByPOID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetPORemarksByPOID]
	@POID varchar(50),
	@Remark varchar(500)
AS
BEGIN
	SET NOCOUNT ON;

	update PKPO set PORemarks = @Remark
	where POID = @POID;




END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetPurchaseItemByTransferId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetPurchaseItemByTransferId]
	-- Add the parameters for the stored procedure here
	@transferId varchar(50),
	@Type varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @purchaseItemId varchar(50)
	declare @UniQuePurchaseItemID uniqueidentifier;
	declare @strDate varchar(50);
	declare @strTimefrom varchar(50);
	declare @strTimeTo varchar(50);
	declare @strResourceId uniqueidentifier;
	declare @dt datetime;

	set @dt =  GETDATE();

	set @strdate = CONVERT(varchar(100), @dt, 23);
	set @strTimefrom = CONVERT(varchar(100), @dt, 8);
	set @strTimeTo = CONVERT(varchar(100), @dt, 8);
	set @strResourceId = NEWID();

	set @UniQuePurchaseItemID = cast(@purchaseItemId as uniqueidentifier);



	DECLARE t_cursor CURSOR FOR 
        select ppi.PurchaseItemId
			from PKPurchasePackage  Ppp
			inner join PKPurchaseItem PPI on ppi.PurchaseId = ppp.PurchaseId
			where ppp.transferId = @transferId

      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @purchaseItemId 
      WHILE @@fetch_status = 0 
        BEGIN 
			set @UniQuePurchaseItemID = cast(@purchaseItemId as uniqueidentifier);

			if @type = 'set'
			begin
				update PKPurchaseItem set
				ResourceId = @strResourceId,
				ResourceDate = @strDate,
				ResourceTimeFrom = @strTimefrom,
				ResourceTimeTo = @strTimeTo,
				Remark = 'Booking Move Products To History When Paid'
				where PurchaseItemId = @UniQuePurchaseItemID
			end
			else if @type = 'remove'
			begin
				update PKPurchaseItem set
				ResourceId = '',
				ResourceDate = '',
				ResourceTimeFrom = '',
				ResourceTimeTo = '',
				Remark = 'Remove Booking Move Products To History When Paid'
				where PurchaseItemId = @UniQuePurchaseItemID
			end
            FETCH next FROM t_cursor INTO @purchaseItemId 
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 

END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetPurchaseItemUPdate]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetPurchaseItemUPdate]
	@purchaseItemId varchar(50),
	@setType varchar(50),
	@packsize varchar(10)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @dt datetime;
	declare @UniQuePurchaseItemID uniqueidentifier;
	declare @strDate varchar(50);
	declare @strTimefrom varchar(50);
	declare @strTimeTo varchar(50);
	declare @strResourceId uniqueidentifier;

	declare @strExistedResourceId varchar(50);

	set @dt =  GETDATE();

	set @strdate = CONVERT(varchar(100), @dt, 23);
	set @strTimefrom = CONVERT(varchar(100), @dt, 8);
	set @strTimeTo = CONVERT(varchar(100), @dt, 8);
	set @strResourceId = NEWID();

	set @UniQuePurchaseItemID = cast(@purchaseItemId as uniqueidentifier);


	

	if @setType = 'set' 
	begin
		if @packsize = '1'
		begin
			update PKPurchaseItem set
			ResourceId = @strResourceId,
			ResourceDate = @strDate,
			ResourceTimeFrom = @strTimefrom,
			ResourceTimeTo = @strTimeTo,
			Remark = '-'
			where PurchaseItemId = @UniQuePurchaseItemID
		end
		else if @packsize = '.5' or @packsize = '0.5'
		begin
		    declare @count int;

			select @count = count(*) from PKPurchaseItem where PurchaseItemId = @UniQuePurchaseItemID and packsize = '.5';
			--select @strExistedResourceId = resourceid from PKPurchaseItem where PurchaseItemId = @UniQuePurchaseItemID

			if @count <> 1
			begin
				declare @currentItemOrder int;
				select @currentItemOrder = isnull(itemOrder,0) from PKPurchaseItem where PurchaseItemId = @UniQuePurchaseItemID ;
				insert into PKPurchaseItem([PurchaseItemId]
				  ,[CardType]
				  ,[CardName]
				  ,[CardNumber]
				  ,[CardHolder]
				  ,[ProductId]
				  ,[CreateDate]
				  ,[Status]
				  ,[ResourceId]
				  ,[ResourceTimeFrom]
				  ,[ResourceTimeTo]
				  ,[Remark]
				  ,[PurchaseId]
				  ,[ResourceDate]
				  ,[packagetype]
				  ,[packsize]
				  ,[itemOrder]
				  )
				  select newid() as PurchaseItemId
				  ,[CardType]
				  ,[CardName]
				  ,[CardNumber]
				  ,[CardHolder]
				  ,[ProductId]
				  ,[CreateDate]
				  ,[Status]
				  ,ResourceId
				  ,[ResourceTimeFrom]
				  ,[ResourceTimeTo]
				  ,'' as Remark
				  ,[PurchaseId]
				  ,[ResourceDate]
				  ,[packagetype]
				  ,'.5' as packsize
				  ,@currentItemOrder+1
				  from PKPurchaseItem where PurchaseItemId = @UniQuePurchaseItemID;
			end
			update PKPurchaseItem set
				ResourceId = @strResourceId,
				ResourceDate = @strDate,
				ResourceTimeFrom = @strTimefrom,
				ResourceTimeTo = @strTimeTo,
				Remark = '.5',
				packsize = '.5'
				where PurchaseItemId = @UniQuePurchaseItemID;

			
		end
		else
		begin
			declare @locationid nvarchar(50);
			declare @cProductId varchar(50);
			declare @cardNumber nvarchar(50);

			select @locationid = pppo.Locationid
			,@cProductId = ppi.ProductId
			,@cardNumber = ppi.CardNumber
			from PKPurchaseItem PPI
			inner join PKPurchasePackage ppp on ppp.PurchaseId = ppi.PurchaseId
			inner join PKPurchasePackageOrder PPPO on pppo.transferId = ppp.transferId
			where ppi.PurchaseItemId= @UniQuePurchaseItemID

			update PKPurchaseItem set
			ResourceId = @strResourceId,
			ResourceDate = @strDate,
			ResourceTimeFrom = @strTimefrom,
			ResourceTimeTo = @strTimeTo,
			Remark = 'Quick Check Out'
			where PurchaseItemId = @UniQuePurchaseItemID

			declare @currentPacksize decimal(18,1);
			set @currentPacksize = cast(@packsize as decimal(18,1));
			set @currentPacksize = @currentPacksize - 1

			declare @loopPurchaseItemID uniqueidentifier;
			declare @loopPacesize  decimal(18,1);
			declare @loopStrPacesize  varchar(10);

			DECLARE t_cursor CURSOR FOR 
				select ppi.PurchaseItemId, packsize
				from PKPurchaseItem PPI
				inner join PKPurchasePackage ppp on ppp.PurchaseId = ppi.PurchaseId
				inner join PKPurchasePackageOrder PPPO on pppo.transferId = ppp.transferId
				where ppi.ProductId = @cProductId and ppi.CardNumber=@cardNumber and pppo.Locationid = @locationid
				and isnull(ppi.ResourceDate, '') = ''
				order by packsize, itemOrder


			OPEN t_cursor
			FETCH next FROM t_cursor INTO @loopPurchaseItemID,@loopStrPacesize
			WHILE @@fetch_status = 0
			BEGIN 
				if @currentPacksize >0
				begin
					if @currentPacksize = 0.5
					begin
						set @loopPacesize= cast(@loopStrPacesize as decimal(18,1))
						if @loopPacesize = 0.5
						begin
							update PKPurchaseItem set
							ResourceId = @strResourceId,
							ResourceDate = @strDate,
							ResourceTimeFrom = @strTimefrom,
							ResourceTimeTo = @strTimeTo,
							Remark = 'Quick Check Out'
							where PurchaseItemId = @loopPurchaseItemID
						end
						else
						begin
							declare @currentItemOrderLOOP int;
							select @currentItemOrderLOOP = isnull(itemOrder,0) from PKPurchaseItem where PurchaseItemId = @UniQuePurchaseItemID ;
							insert into PKPurchaseItem([PurchaseItemId]
							  ,[CardType]
							  ,[CardName]
							  ,[CardNumber]
							  ,[CardHolder]
							  ,[ProductId]
							  ,[CreateDate]
							  ,[Status]
							  ,[ResourceId]
							  ,[ResourceTimeFrom]
							  ,[ResourceTimeTo]
							  ,[Remark]
							  ,[PurchaseId]
							  ,[ResourceDate]
							  ,[packagetype]
							  ,[packsize]
							  ,[itemOrder]
							  )
							  select newid() as PurchaseItemId
							  ,[CardType]
							  ,[CardName]
							  ,[CardNumber]
							  ,[CardHolder]
							  ,[ProductId]
							  ,[CreateDate]
							  ,[Status]
							  ,ResourceId
							  ,[ResourceTimeFrom]
							  ,[ResourceTimeTo]
							  ,'' as Remark
							  ,[PurchaseId]
							  ,[ResourceDate]
							  ,[packagetype]
							  ,'.5' as packsize
							  ,@currentItemOrderLOOP+1
							  from PKPurchaseItem where PurchaseItemId = @loopPurchaseItemID;
						
						update PKPurchaseItem set
							ResourceId = @strResourceId,
							ResourceDate = @strDate,
							ResourceTimeFrom = @strTimefrom,
							ResourceTimeTo = @strTimeTo,
							Remark = '.5',
							packsize = '.5'
							where PurchaseItemId = @loopPurchaseItemID;
						end
						set @currentPacksize = @currentPacksize - 0.5
					end
					else
					begin
						set @loopPacesize= cast(@loopStrPacesize as decimal(18,1))
						if @loopPacesize = 0.5
						begin
							update PKPurchaseItem set
							ResourceId = @strResourceId,
							ResourceDate = @strDate,
							ResourceTimeFrom = @strTimefrom,
							ResourceTimeTo = @strTimeTo,
							Remark = '.5',
							packsize = '.5'
							where PurchaseItemId = @loopPurchaseItemID;
							set @currentPacksize = @currentPacksize - 0.5
						end
						else
						begin
							update PKPurchaseItem set
							ResourceId = @strResourceId,
							ResourceDate = @strDate,
							ResourceTimeFrom = @strTimefrom,
							ResourceTimeTo = @strTimeTo,
							Remark = '-'
							where PurchaseItemId = @loopPurchaseItemID
							set @currentPacksize = @currentPacksize - 1
						end
					end
				end
				FETCH next FROM t_cursor INTO @loopPurchaseItemID,@loopStrPacesize
			END 
			CLOSE t_cursor 
			DEALLOCATE t_cursor 


		end
	end
	else if @setType = 'clear'
	begin
		update PKPurchaseItem set
		
		ResourceDate = '',
		ResourceTimeFrom = '',
		ResourceTimeTo = '',
		remark = 'Cancel Check Out'
		where PurchaseItemId = @UniQuePurchaseItemID
	end

END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetSave5Price]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetSave5Price]
	@ID NVarChar(50),                           
	@ProductID NVarChar(50),                    
	@Cost Decimal(18,2),                              
	@A Decimal(18,2),                                 
	@B Decimal(18,2),                                 
	@C Decimal(18,2),                                 
	@D Decimal(18,2),                                 
	@E Decimal(18,2),                                 
	@Special Decimal(18,2),                           
	@CreateTime DateTime,                       
	@UpdateTime DateTime,                       
	@Creater NVarChar(50),                      
	@Updater NVarChar(50),                      
	@AisFixed bit,                              
	@BisFixed bit,                              
	@CisFixed bit,                              
	@DisFixed bit,                              
	@EisFixed bit,                              
	@Online NVarChar(50)                       

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	insert into PKPrice                               
        (ID, ProductID, Cost, A, B, C, D, E, Special, CreateTime, UpdateTime, Creater, Updater
        ,[AisFixed]
        ,[BisFixed]
        ,[CisFixed]
        ,[DisFixed]
        ,[EisFixed]
        ,online)
        values 
        (@ID, @ProductID, @Cost, @A, @B, @C, @D, @E, @Special, @CreateTime, @UpdateTime,
            @Creater, @Updater,@AisFixed,@BisFixed,@CisFixed,@DisFixed,@EisFixed,@Online)

	if len(@Online)>0 
	begin
		update pkproduct set OnlineProduct = 'True' where id = @ProductID;
		update PKCategory set Online = 'True' where ID = (select top 1 CategoryID from PKProduct where id = @ProductID);
		update PKDepartment set Online = 'True' where id = (select top 1 DepartmentID from PKCategory pc inner join PKProduct PP on pc.ID = pp.CategoryID and pp.id = @ProductID);
	End
	

END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetSaveAndUpdateDictById]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_SetSaveAndUpdateDictById]
	@DictID int,
	@FieldName varchar(50),
	@English nvarchar(500),
	@name2 nvarchar(500)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @currentLanguage varchar(50);
	declare @SqlStr varchar(500);

	select @currentLanguage = isnull(value,'') from pksetting where fieldname = 'LanguangeSetting';

    if @DictID = 0
	begin
		set @SqlStr = 'insert into PK_Dictionary(fieldName,English,'+ @currentLanguage +')values(N'''+ @FieldName +''',N'''+ @English +''',N'''+ @name2 +''')';
		exec (@SqlStr);
	end
	else
	begin
		set @SqlStr = 'update PK_Dictionary set English = N'''+ @English +''','+ @currentLanguage +' = N'''+ @name2 +''' where id = ' + cast(@DictID as varchar(50));
		exec (@SqlStr);
	end
END

GO
/****** Object:  StoredProcedure [dbo].[pk_setsavesoproducts]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pk_setsavesoproducts] 
  @SOProductID  NVARCHAR(50), 
  @LocationID   NVARCHAR(50), 
  @SOID         NVARCHAR(50), 
  @ProductID    NVARCHAR(50), 
  @PLU          NVARCHAR(50), 
  @Barcode      NVARCHAR(50), 
  @ProductName1 NVARCHAR(50), 
  @ProductName2 NVARCHAR(50), 
  @Pack         NVARCHAR(50), 
  @Size         NVARCHAR(50), 
  @OrderQty     DECIMAL(18,2), 
  @Weigh        NVARCHAR(50), 
  @Unit         NVARCHAR(50), 
  @UnitCost     DECIMAL(18,2), 
  @Discount     DECIMAL(18,2), 
  @Markup       DECIMAL(18,2), 
  @TaxMarkup    DECIMAL(18,2), 
  @TotalCost    DECIMAL(18,2), 
  @SOProductRemarks Nvarchar(500), 
  @ShippingQty decimal(18,2), 
  @BackQty     decimal(18,2), 
  @ReferenceID nvarchar(50), 
  @Type nvarchar(50), 
  @AverageCost decimal(18,2) 
AS 
  BEGIN 
    -- SET NOCOUNT ON added to prevent extra result sets from 
    -- interfering with SELECT statements. 
    SET nocount ON; 
    insert INTO pksoproduct 
                ( 
                            soproductid, 
                            locationid, 
                            soid, 
                            productid, 
                            plu, 
                            barcode, 
                            productname1, 
                            productname2, 
                            pack, 
                            size, 
                            orderqty, 
                            weigh, 
                            unit, 
                            unitcost, 
                            discount, 
                            markup, 
                            taxmarkup, 
                            totalcost, 
                            soproductremarks, 
                            shippingqty, 
                            backqty, 
                            referenceid, 
                            type, 
                            averagecost 
                ) 
                VALUES 
                ( 
                            @SOProductID, 
                            @LocationID, 
                            @SOID, 
                            @ProductID, 
                            @PLU, 
                            @Barcode, 
                            @ProductName1, 
                            @ProductName2, 
                            @Pack, 
                            @Size, 
                            @OrderQty, 
                            @Weigh, 
                            @Unit, 
                            @UnitCost, 
                            @Discount, 
                            @Markup, 
                            @TaxMarkup, 
                            @TotalCost, 
                            @SOProductRemarks, 
                            @ShippingQty, 
                            @BackQty, 
                            @ReferenceID, 
                            @Type, 
                            @AverageCost 
                ) ;
			
			BEGIN TRY
				update pksoproduct set seqOrder = seq where SOProductID = @SOProductID;		
			END TRY
			BEGIN CATCH
					
			END CATCH
				
  END
  



GO
/****** Object:  StoredProcedure [dbo].[pk_setsavestproducts]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[pk_setsavestproducts] 
  @STProductID  NVARCHAR(50), 
  @LocationID   NVARCHAR(50), 
  @STID         NVARCHAR(50), 
  @ProductID    NVARCHAR(50), 
  @PLU          NVARCHAR(50), 
  @Barcode      NVARCHAR(50), 
  @ProductName1 NVARCHAR(50), 
  @ProductName2 NVARCHAR(50), 
  @Pack         NVARCHAR(50), 
  @Size         NVARCHAR(50), 
  @OrderQty     DECIMAL(18,2), 
  @Weigh        NVARCHAR(50), 
  @Unit         NVARCHAR(50), 
  @UnitCost     DECIMAL(18,2), 
  @Discount     DECIMAL(18,2), 
  @Markup       DECIMAL(18,2), 
  @TaxMarkup    DECIMAL(18,2), 
  @TotalCost    DECIMAL(18,2), 
  @STProductRemarks Nvarchar(500), 
  @ShippingQty decimal(18,2), 
  @BackQty     decimal(18,2), 
  @ReferenceID nvarchar(50), 
  @Type nvarchar(50), 
  @AverageCost decimal(18,2) 
AS 
  BEGIN 
    -- SET NOCOUNT ON added to prevent extra result sets from 
    -- interfering with SELECT statements. 
    SET nocount ON; 
    insert INTO pkstproduct 
                ( 
                            stproductid, 
                            locationid, 
                            stid, 
                            productid, 
                            plu, 
                            barcode, 
                            productname1, 
                            productname2, 
                            pack, 
                            size, 
                            orderqty, 
                            weigh, 
                            unit, 
                            unitcost, 
                            discount, 
                            markup, 
                            taxmarkup, 
                            totalcost, 
                            stproductremarks, 
                            shippingqty, 
                            backqty, 
                            referenceid, 
                            type, 
                            averagecost 
                ) 
                VALUES 
                ( 
                            @STProductID, 
                            @LocationID, 
                            @STID, 
                            @ProductID, 
                            @PLU, 
                            @Barcode, 
                            @ProductName1, 
                            @ProductName2, 
                            @Pack, 
                            @Size, 
                            @OrderQty, 
                            @Weigh, 
                            @Unit, 
                            @UnitCost, 
                            @Discount, 
                            @Markup, 
                            @TaxMarkup, 
                            @TotalCost, 
                            @STProductRemarks, 
                            @ShippingQty, 
                            @BackQty, 
                            @ReferenceID, 
                            @Type, 
                            @AverageCost 
                ) ;
			
			BEGIN TRY
				update pkstproduct set seqOrder = seq where STProductID = @STProductID;		
			END TRY
			BEGIN CATCH
					
			END CATCH
				
  END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetSeparateByProdId]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetSeparateByProdId]
	@ProductId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @PLU varchar(50);
	declare @CategoryId varchar(50);

	declare @count int;
	select @count = count(*) from PKMapping where ProductID = @ProductId;

	if @count = 0
	begin
		set @PLU = ''
		set @CategoryId = ''

	end
	else
	begin
		select @PLU = plu, @CategoryId = CategoryID from PKProduct where id = @ProductId;
		select @count = count(*) from PKProduct where plu = @PLU and id <> @ProductId;
		if @count>0
		begin
			set @plu = dbo.PK_FuncGetNewPLUByCategoryID(@CategoryId);
			update PKProduct set plu = @plu where id = @ProductId;
		end
		delete from PKMapping where productid  = @ProductId;

	end

	select @plu as newPlu;

END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetSOProductUpDown]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetSOProductUpDown]
	@SoProductIdPara varchar(50),
	@UpDownPara varchar(10)
AS
BEGIN
	declare 	@SoProductId2ndTime varchar(50)
	declare 	@UpDown2ndTime varchar(10)
	declare @SOID varchar(50);
	declare @AlternateSOProductId varchar(50);
	declare @OldSeq int;
	declare @AlternateOldSeq int;


	set @SoProductId2ndTime = @SoProductIdPara;
	set @UpDown2ndTime = @UpDownPara;
	--Find out the limit area in whick to exchange the seq 
	select @SOID=soid, @OldSeq = seqOrder from PKSOProduct where SOProductID = @SoProductId2ndTime;

	update PKSOProduct  set seqOrder = seq where SOID = @SOID and isnull(seqOrder,'') = '';
	update PKSOProduct  set seqOrder = seq where SOID = @SOID and seqOrder=0 ;

	--Find out the item, which will be exchanged with the current one.
	if lower(@UpDown2ndTime) = 'up'
	begin
		--Get the item, whose seq is less than current one, it means the new one is above the current one on the page, if it exists.
		select top 1 @AlternateSOProductId = SOProductID, @AlternateOldSeq=ISNULL(seqOrder,0) from PKSOProduct where SOID = @SOID and seqOrder<@OldSeq and type='Item' order by seqOrder desc
	end
	else
	begin
		select top 1 @AlternateSOProductId = SOProductID, @AlternateOldSeq=ISNULL(seqOrder,0) from PKSOProduct where SOID = @SOID and seqOrder>@OldSeq and type='Item' order by seqorder asc

	end


	--If the item exists, do the following 
	if @AlternateOldSeq<>0 
	begin
		
		

		--Put the alternate product into a temper table, including its tax properties.
		select distinct SOProductID, seqOrder 
		into #tblAlternate
		from PKSOProduct 
		where SOProductID = @AlternateSOProductId 
		or ReferenceID = @AlternateSOProductId

		--Put the current product into a temper table, including its tax properties.
		select distinct SOProductID, seqOrder 
		into #tblOriginal
		from PKSOProduct 
		where SOProductID = @SoProductId2ndTime 
		or ReferenceID = @SoProductId2ndTime

		--select top 1 * into #tblSeq from #tblAlternate ;
		--delete from #tblSeq;
		select SOProductID, seqOrder, 'a' as flag, seqOrder as tempOrder into #tblSeq from #tblAlternate;
		insert into #tblSeq select SOProductID, seqOrder, 'o' as flag, seqOrder as tempOrder  from #tblOriginal ;

		declare @tempSoProductID varchar(50);
		declare @tempSeq int;

		select @tempSeq = min(seqOrder) from #tblSeq;

		if lower(@UpDown2ndTime) = 'up'
		begin
			declare t_cursor cursor for 
			select SOProductID from #tblSeq
			order by flag desc, seqOrder asc  --MOST IMPORTANT
			open t_cursor
			fetch next from t_cursor into @tempSoProductID
			while @@fetch_status = 0
			begin
				update #tblSeq set tempOrder = @tempSeq where SOProductID = @tempSoProductID;
				select @tempSeq = min(seqOrder) from #tblSeq where seqOrder> @tempSeq;
				fetch next from t_cursor into @tempSoProductID
			end
			close t_cursor
			deallocate t_cursor
		end
		else
		begin
			declare t_cursor cursor for 
			select SOProductID from #tblSeq
			order by flag asc, seqOrder asc  --MOST IMPORTANT
			open t_cursor
			fetch next from t_cursor into @tempSoProductID
			while @@fetch_status = 0
			begin
				update #tblSeq set tempOrder = @tempSeq where SOProductID = @tempSoProductID;
				select @tempSeq = min(seqOrder) from #tblSeq where seqOrder> @tempSeq;
				fetch next from t_cursor into @tempSoProductID
			end
			close t_cursor
			deallocate t_cursor
		end

		select * from #tblSeq
	    
		update PKSOProduct set seqOrder = tempOrder from #tblSeq where #tblSeq.SOProductID = PKSOProduct.SOProductID;

		drop table #tblAlternate
		drop table #tblOriginal
		drop table #tblSeq

	end

END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetSORemark]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_SetSORemark]
	@SOID varchar(50),
	@Remark varchar(500)
AS
BEGIN
	SET NOCOUNT ON;

	update PKSO set SORemarks = @Remark
	where SOID = @SOID;




END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetSTProductUpDown]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetSTProductUpDown]
	@StProductIdPara varchar(50),
	@UpDownPara varchar(10)
AS
BEGIN
	declare @StProductId2ndTime varchar(50)
	declare @UpDown2ndTime varchar(10)
	declare @STID varchar(50);
	declare @AlternateSTProductId varchar(50);
	declare @OldSeq int;
	declare @AlternateOldSeq int;

	set @StProductId2ndTime = @StProductIdPara;
	set @UpDown2ndTime = @UpDownPara;
	--Find out the limit area in whick to exchange the seq 
	select @STID=stid, @OldSeq = seqOrder from PKSTProduct where STProductID = @StProductId2ndTime;

	update PKSTProduct  set seqOrder = seq where STID = @STID and isnull(seqOrder,'') = '';
	update PKSTProduct  set seqOrder = seq where STID = @STID and seqOrder=0 ;

	--Find out the item, which will be exchanged with the current one.
	if lower(@UpDown2ndTime) = 'up'
	begin
		--Get the item, whose seq is less than current one, it means the new one is above the current one on the page, if it exists.
		select top 1 @AlternateSTProductId = STProductID, @AlternateOldSeq=ISNULL(seqOrder,0) from PKSTProduct where STID = @STID and seqOrder<@OldSeq and type='Item' order by seqOrder desc
	end
	else
	begin
		select top 1 @AlternateSTProductId = STProductID, @AlternateOldSeq=ISNULL(seqOrder,0) from PKSTProduct where STID = @STID and seqOrder>@OldSeq and type='Item' order by seqorder asc

	end

	--If the item exists, do the following 
	if @AlternateOldSeq<>0 
	begin
		--Put the alternate product into a temper table, including its tax properties.
		select distinct STProductID, seqOrder 
		into #tblAlternate
		from PKSTProduct 
		where STProductID = @AlternateSTProductId 
		or ReferenceID = @AlternateSTProductId

		--Put the current product into a temper table, including its tax properties.
		select distinct STProductID, seqOrder 
		into #tblOriginal
		from PKSTProduct 
		where STProductID = @StProductId2ndTime 
		or ReferenceID = @StProductId2ndTime

		--select top 1 * into #tblSeq from #tblAlternate ;
		--delete from #tblSeq;
		select STProductID, seqOrder, 'a' as flag, seqOrder as tempOrder into #tblSeq from #tblAlternate;
		insert into #tblSeq select STProductID, seqOrder, 'o' as flag, seqOrder as tempOrder  from #tblOriginal ;

		declare @tempStProductID varchar(50);
		declare @tempSeq int;

		select @tempSeq = min(seqOrder) from #tblSeq;

		if lower(@UpDown2ndTime) = 'up'
		begin
			declare t_cursor cursor for 
			select STProductID from #tblSeq
			order by flag desc, seqOrder asc  --MOST IMPORTANT
			open t_cursor
			fetch next from t_cursor into @tempStProductID
			while @@fetch_status = 0
			begin
				update #tblSeq set tempOrder = @tempSeq where STProductID = @tempStProductID;
				select @tempSeq = min(seqOrder) from #tblSeq where seqOrder> @tempSeq;
				fetch next from t_cursor into @tempStProductID
			end
			close t_cursor
			deallocate t_cursor
		end
		else
		begin
			declare t_cursor cursor for 
			select STProductID from #tblSeq
			order by flag asc, seqOrder asc  --MOST IMPORTANT
			open t_cursor
			fetch next from t_cursor into @tempStProductID
			while @@fetch_status = 0
			begin
				update #tblSeq set tempOrder = @tempSeq where STProductID = @tempStProductID;
				select @tempSeq = min(seqOrder) from #tblSeq where seqOrder> @tempSeq;
				fetch next from t_cursor into @tempStProductID
			end
			close t_cursor
			deallocate t_cursor
		end

		select * from #tblSeq
	    
		update PKSTProduct set seqOrder = tempOrder from #tblSeq where #tblSeq.STProductID = PKSTProduct.STProductID;

		drop table #tblAlternate
		drop table #tblOriginal
		drop table #tblSeq
	end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetTaxOnTax]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PK_SetTaxOnTax]
	@Id varchar(50),
	@TaxNameID varchar(50)
AS
BEGIN
	declare @s nvarchar(500);

	
	if(lower(@TaxNameID)='all')
	begin
		delete from PKProductTax where ProductID = @Id and len(ProductID) < 20;
			declare @taxName nvarchar(50);
			declare t_cursor cursor for 
			select id from PKTax 
			where LOWER(TaxType)='tax'
			open t_cursor
			fetch next from t_cursor into @taxName
			while @@fetch_status = 0
			begin
				set @s ='INSERT INTO PKProductTax(ProductID,TaxID,CreateTime)';
				set @s = @s + 'VALUES('''+ @Id +''', '''+@taxName +''', getdate())';
				exec(@s);
				fetch next from t_cursor into @taxName
			End
			close t_cursor
			deallocate t_cursor

	end
	else
	begin
		delete from PKProductTax where ProductID = @Id and len(ProductID) < 20;
		if len(@TaxNameID)>0 
		begin 
			INSERT INTO PKProductTax(ProductID,TaxID,CreateTime)
			VALUES(@Id, @TaxNameID, getdate())
		end 

		
	end

END


GO
/****** Object:  StoredProcedure [dbo].[PK_SettingGetBy]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SettingGetBy]
	@RoleId varchar(20),
	@FeatureGroupId varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	if @FeatureGroupId = ''
	begin
		SELECT 
			id,
			Feature,
			case featureGroup when 'ZZZZZZ' then 'Other' else featureGroup end as FeatureGroup,
			Remark,
			hasRole

			from(
			select 
			pf.id, 
			pf.feature, 
			isnull(pf.featureGroup,'ZZZZZZ') as featureGroup, 
			pf.remark ,
			isnull(PRF.id,0) as hasRole
			from pkfeature  pf
			left outer join PKRoleFeature PRF on prf.FeatureID = pf.ID and PRF.RoleID = @RoleId
			) a
			order by featureGroup, feature;
	end
	else
	begin
		
			select 
			pf.id, 
			pf.feature, 
			isnull(pf.featureGroup,'Other') as featureGroup, 
			pf.remark ,
			isnull(PRF.id,0) as hasRole
			from pkfeature  pf
			left outer join PKRoleFeature PRF on prf.FeatureID = pf.ID and PRF.RoleID = @RoleId
			where isnull(pf.featureGroup,'Other') = @FeatureGroupId
			order by pf.feature;
	end
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SettingGetByBooking]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SettingGetByBooking]
	@RoleId varchar(20),
	@FeatureGroupId varchar(50),
	@whichSystem varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	if @whichSystem = 'booking' 
	begin
		if @FeatureGroupId = ''
		begin
			SELECT 
				id,
				Feature,
				case featureGroup when 'ZZZZZZ' then 'Other' else featureGroup end as FeatureGroup,
				Remark,
				hasRole

				from(
				select 
				pf.id, 
				pf.feature, 
				isnull(pf.featureGroup,'ZZZZZZ') as featureGroup, 
				pf.remark ,
				isnull(PRF.id,0) as hasRole
				from pkfeatureBooking  pf
				left outer join PKRoleFeatureBooking PRF on prf.FeatureID = pf.ID and PRF.RoleID = @RoleId
				) a
				order by featureGroup, feature;
		end
		else
		begin
		
				select 
				pf.id, 
				pf.feature, 
				isnull(pf.featureGroup,'Other') as featureGroup, 
				pf.remark ,
				isnull(PRF.id,0) as hasRole
				from pkfeatureBooking  pf
				left outer join PKRoleFeatureBooking PRF on prf.FeatureID = pf.ID and PRF.RoleID = @RoleId
				where isnull(pf.featureGroup,'Other') = @FeatureGroupId
				order by pf.feature;
		end	
	end
	else
	begin
		if @FeatureGroupId = ''
		begin
			SELECT 
				id,
				Feature,
				case featureGroup when 'ZZZZZZ' then 'Other' else featureGroup end as FeatureGroup,
				Remark,
				hasRole

				from(
				select 
				pf.id, 
				pf.feature, 
				isnull(pf.featureGroup,'ZZZZZZ') as featureGroup, 
				pf.remark ,
				isnull(PRF.id,0) as hasRole
				from pkfeature  pf
				left outer join PKRoleFeature PRF on prf.FeatureID = pf.ID and PRF.RoleID = @RoleId
				) a
				order by featureGroup, feature;
		end
		else
		begin
		
				select 
				pf.id, 
				pf.feature, 
				isnull(pf.featureGroup,'Other') as featureGroup, 
				pf.remark ,
				isnull(PRF.id,0) as hasRole
				from pkfeature  pf
				left outer join PKRoleFeature PRF on prf.FeatureID = pf.ID and PRF.RoleID = @RoleId
				where isnull(pf.featureGroup,'Other') = @FeatureGroupId
				order by pf.feature;
		end
	end
END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetTransferBackByID]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetTransferBackByID]
	@transferId varchar(50)
AS
BEGIN
	declare @fromLocationId varchar(50);
	declare @toLocationId varchar(50);
	declare @ProductId varchar(50);
	declare @Qty decimal(18,2)
	declare @Id int

	select 
	@fromLocationId = FromLocationID,
	@toLocationId = ToLocationID
	from PKTransfer where ID  = @transferId;


	declare t_cursor cursor for 
	select
	ID, 
	ProductID,
	Qty
	from PKTransferProduct
	where TransferID = @transferId
	open t_cursor
	fetch next from t_cursor into @Id, @ProductId, @Qty
	while @@fetch_status = 0
	begin
		delete from PKTransferProduct where id = @Id;
		update PKInventory set qty = qty - @Qty,Updater = 'transferBack:' + cast(id as varchar(50)) where ProductID = @ProductId and LocationID  = @toLocationId;
		update PKInventory set qty = qty + @Qty,Updater = 'transferBack:' + cast(id as varchar(50)) where ProductID = @ProductId and LocationID  = @fromLocationId;
		
		fetch next from t_cursor into @Id, @ProductId, @Qty
	end
	
		
	close t_cursor
	deallocate t_cursor

	delete from PKTransfer where id = @transferId;




END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetUnpack]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetUnpack]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @BaseProductId varchar(50);
	declare @SubProductId varchar(50);
	------------------------------------
	declare @MaxStockQty decimal(18,2);
	declare @MinStockQty decimal(18,2);
	------------------------------------
	declare @BaseWeigh varchar(50);
	declare @BaseUnit varchar(50);
	declare @BaseNetWeightUnit varchar(50);
	declare @BaseNetWeight decimal(18,2);
	declare @BasePackL int;
	declare @BasePackM int;
	declare @BasePackS int;
	------------------------------------
	declare @SubWeigh varchar(50);
	declare @SubUnit varchar(50);
	declare @SubNetWeightUnit varchar(50);
	declare @SubNetWeight decimal(18,2);
	declare @SubPackL int;
	declare @SubPackM int;
	declare @SubPackS int;
	------------------------------------
	declare @LocationId varchar(50);
	------------------------------------
	declare @BaseQTY decimal(18,2);
	declare @BaseAverageCost decimal(18,2);
	declare @BaseLatestCost decimal(18,2);
	declare @BaseInventoryId varchar(50);

	declare @SubQTY decimal(18,2);
	declare @SubAverageCost decimal(18,2);
	declare @SubLatestCost decimal(18,2);
	declare @SubInventoryId varchar(50);
	------------------------------------
	declare @SubProdCapacityToBase decimal(18,4);
	------------------------------------
	declare @tempDecNumber decimal(18,4);
	

	execute dbo.PK_ToolInsertInventoryFromProduct;

	--return;
	declare t_cursor1 cursor for 
		select 
			PM.BaseProductID, 
			PM.ProductID,
			PM.MaxStockQty,
			PM.MinStockQty

			from PKMapping PM
			inner join PKProduct pB on pB.id = pm.BaseProductID
			inner join pkProduct PS on PS.id =  pm.ProductID

		open t_cursor1
		fetch next from t_cursor1 into 
		    @BaseProductId,
			@SubProductId,
			@MaxStockQty,
			@MinStockQty

		while @@fetch_status = 0
		begin
			---The 1st LOOP=====================================================================================
			select @SubProdCapacityToBase =  dbo.PK_FuncGetCapacityByProdID(@SubProductId);
			---------------------------------------------------------------------------------
			declare t_cursor2 cursor for 
				select 
				    LocationID
					from PKLocation
				open t_cursor2
				fetch next from t_cursor2 into @LocationId
				while @@fetch_status = 0
				begin
					---The 2nd LOOP=============================================================================
					declare @DiffQty decimal(18,4);
					declare @AddQty decimal(18,4);
					--------------------------------------------------------------------------------------------
					select 
						@BaseQTY = Qty,
						@BaseAverageCost  = AverageCost,
						@BaseLatestCost = LatestCost,
						@BaseInventoryId = ID
					from pkinventory 
					where productid = @BaseProductId and LocationID = @LocationId;

					select 
						@SubQTY = Qty,
						@SubAverageCost  = AverageCost,
						@SubLatestCost = LatestCost,
						@SubInventoryId = ID
					from pkinventory 
					where productid = @SubProductId and LocationID = @LocationId;
					--------------------------------------------------------------------------------------------
					set @MaxStockQty = isnull(@MaxStockQty, 0.00);
					set @MinStockQty = isnull(@MinStockQty, 0.00);
					
					if @MaxStockQty = 0 and @MinStockQty = 0
					begin
						--When both zero, it means no setting for this sub-product.
						if @SubQty < 0
						begin
							set @AddQty = abs(@SubQty) * @SubProdCapacityToBase;
							if @BaseQTY - @AddQty >0 
							begin
								update PKInventory set Qty = Qty - cast(@AddQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK1'  where id = @BaseInventoryId 
								update PKInventory set Qty = 0, UpdateTime=getdate(),Updater='UNPACK2'  where id = @SubInventoryId 
							end
						end
						
						if @BaseQTY <0 
						begin
							set @tempDecNumber =1.0000;

							select 
							pm.BaseProductID, 
							pm.ProductID,
							piv.Qty,
							@tempDecNumber as capacity,
							@tempDecNumber as QtyToBase
							into #tbl1
							from PKMapping pm
							inner join PKInventory  piv on pm.ProductID = piv.ProductID and piv.LocationID = @LocationId
							where pm.BaseProductID = @BaseProductId 
								and piv.Qty >0
								and pm.ProductID = @SubProductId
							;
							
							update #tbl1 set capacity  =  isnull(dbo.PK_FuncGetCapacityByProdID(ProductID), 1);

							update #tbl1 set QtyToBase  = qty * capacity;


							


							declare @Loop3ProductId varchar(50);
							declare @loop3Qty decimal(18,4);
							declare @loop3QtyToBase decimal(18,4);
							declare @loop3Capacity decimal(18,4);

							declare t_cursor3 cursor for 
							select  ProductID,Qty,  QtyToBase, capacity from #tbl1
							open t_cursor3
							fetch next from t_cursor3 into @Loop3ProductId, @loop3Qty, @loop3QtyToBase, @loop3Capacity
								

							while @@fetch_status = 0
							begin
								if @loop3QtyToBase - 0 > 0 - @BaseQTY
								begin
									if @loop3Capacity <=1
									begin
										set @DiffQty = @BaseQTY / @loop3Capacity;
										update PKInventory set Qty = 0, UpdateTime=getdate(),Updater='UNPACK3' where id = @BaseInventoryId 
										update PKInventory set Qty = Qty + cast(@DiffQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK4'  where id = @SubInventoryId 
										set @BaseQTY = 0;
									end
									else
									begin
										set @DiffQty = -1;
										update PKInventory set Qty = Qty - @loop3Capacity * 1, UpdateTime=getdate(),Updater='UNPACK3a' where id = @BaseInventoryId 
										update PKInventory set Qty = Qty + cast(@DiffQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK4a'  where id = @SubInventoryId 
										set @BaseQTY = 0;
									end
								end
								else
								begin
									set @DiffQty = @loop3Qty;
									set @AddQty = @loop3QtyToBase;
									update PKInventory set Qty = Qty + cast(@AddQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK5' where id = @BaseInventoryId 
									update PKInventory set Qty = Qty - cast(@DiffQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK6'  where id = @SubInventoryId 
									set @BaseQTY = @BaseQTY -@loop3QtyToBase;
								end
								fetch next from t_cursor3 into @Loop3ProductId, @loop3Qty, @loop3QtyToBase, @loop3Capacity
							end
							close t_cursor3
							deallocate t_cursor3

							drop table #tbl1;
						end

					end
					else
					begin
						-- When not both zero, it means real setting for this sub-product.
						if @subQty > @MaxStockQty
						begin
							set @DiffQty = @SubQTY - @MaxStockQty;
							set @AddQty = @DiffQty * @SubProdCapacityToBase;
							update PKInventory set Qty = Qty + cast(@AddQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK7' where id = @BaseInventoryId 
							update PKInventory set Qty = Qty - cast(@DiffQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK8'  where id = @SubInventoryId 

						end
						if @SubQTY < @MinStockQty
						begin 
							set @DiffQty = @MinStockQty -  @SubQTY;
							set @AddQty = @DiffQty * @SubProdCapacityToBase;
							if @BaseQTY > @AddQty  
							begin
								update PKInventory set Qty = Qty - cast(@AddQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK9'  where id = @BaseInventoryId 
								update PKInventory set Qty = Qty + cast(@DiffQty as decimal(18,2)), UpdateTime=getdate(),Updater='UNPACK10'  where id = @SubInventoryId 
							end
						end
					end				

					---The 2nd Loop End=========================================================================
					fetch next from t_cursor2 into @LocationId
				end
		
				close t_cursor2
				deallocate t_cursor2

			---The 1st Loop End=================================================================================
			fetch next from t_cursor1 into 
				@BaseProductId,
				@SubProductId,
				@MaxStockQty,
				@MinStockQty
		end
		
		close t_cursor1
		deallocate t_cursor1







END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetUpdateInventoryFromPKStockTakeProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_SetUpdateInventoryFromPKStockTakeProduct]
	@StockTakeProductId varchar(50),
	@StepIndex int,
	@KeepOriginalOrReplaceWith0 varchar(2),
	@RealQty decimal(18,2) out
AS
BEGIN
	set @RealQty = 0;
	--update PKInventory set Qty=" + qty + ", UpdateTime='" + updateTime + "', Updater='" + username + "'  WHERE (ID='" + id + "')
	declare @CurrentInventoryQty decimal(18,2);
	declare @CaptureQty decimal(18,2);
	declare @NewQty decimal(18,2);
	declare @DifferenceQty decimal(18,2);
	declare @StockTakeQty decimal(18,2);
	declare @StockTakeQty2 decimal(18,2);
	Select @CurrentInventoryQty = isnull(a.qty,0) 
		from PKInventory a 
		inner join PKStockTakeProduct b on b.InventoryID = a.ID
		where b.ID = @StockTakeProductId;
	Select @CaptureQty=isnull(InvCaptureQty,0) from PKStockTakeProduct where id = @StockTakeProductId;
	--Select @StockTakeQty = isnull(StockTakeQty,0), @StockTakeQty2 = StockTakeQty2 from PKStockTakeProduct where id = @StockTakeProductId;
	Select @StockTakeQty = StockTakeQty, @StockTakeQty2 = StockTakeQty2 from PKStockTakeProduct where id = @StockTakeProductId;
	--===IF the second stocktake qty is null, We need to take the first QTY.
	--===In order to judge it easily in the following step, we replace the value here. 
	If @StockTakeQty2 is null 
		Begin
			set @StockTakeQty2 = @StockTakeQty
		End
	declare @isUpdate bit;
	set @isUpdate = 0;
	--Set the proper value here, according to which step it is for now.
	Set @NewQty = 
		Case @StepIndex 
			when 2 then 
				@StockTakeQty2 
			else 
				@StockTakeQty
		End;
	Set @DifferenceQty = @CurrentInventoryQty - @CaptureQty;
	--If the newQty is null, it means both the first qty and the second one are null.
	If @NewQty is null 
		Begin
			if @KeepOriginalOrReplaceWith0 = 'o' --Keep the original one.
			begin
				set @RealQty = -10000
			end
			else if @KeepOriginalOrReplaceWith0='n' --Replace it with zero.
			begin
				set @RealQty = 0
			end
		End
	else
		begin
			set @RealQty = @NewQty + @DifferenceQty;
		end
	
	--What does it mean? perhaps useless.
	--update PKStockTakeProduct set invCaptureQty = @RealQty where id = @StockTakeProductId
	update PKStockTakeProduct set InventoryOldQTYNow = @CurrentInventoryQty where id = @StockTakeProductId
	update PKStockTakeProduct set InventoryNewQTYNow = case @RealQty when -10000 then @CurrentInventoryQty else @RealQty End where id = @StockTakeProductId
	update PKStockTake set NullWay = @KeepOriginalOrReplaceWith0 
	from PKStockTakeProduct b 
	where PKStockTake.ID = b.StockTakeID and b.ID = @StockTakeProductId; 
END

GO
/****** Object:  StoredProcedure [dbo].[PK_SetUupdate5Price]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_SetUupdate5Price]
	@ID NVarChar(50),                           
	@ProductID NVarChar(50),                    
	@Cost Decimal(18,2),                              
	@A Decimal(18,2),                                 
	@B Decimal(18,2),                                 
	@C Decimal(18,2),                                 
	@D Decimal(18,2),                                 
	@E Decimal(18,2),                                 
	@Special Decimal(18,2),                           
	@CreateTime DateTime,                       
	@UpdateTime DateTime,                       
	@Creater NVarChar(50),                      
	@Updater NVarChar(50),                      
	@AisFixed bit,                              
	@BisFixed bit,                              
	@CisFixed bit,                              
	@DisFixed bit,                              
	@EisFixed bit,                              
	@Online NVarChar(50)                       

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	update PKPrice set
		ID=@ID, ProductID=@ProductID, Cost=@Cost, A=@A, B=@B, C=@C, D=@D, E=@E,Special=@Special,
		CreateTime=@CreateTime, UpdateTime=@UpdateTime,
		Creater=@Creater, Updater=@Updater,
		AisFixed = @AisFixed,
		BisFixed = @BisFixed,
		CisFixed = @CisFixed,
		DisFixed = @DisFixed,
		EisFixed = @EisFixed,
		online = @Online
		WHERE (ID=@ID)

	if len(@Online)>0 
	begin
		update pkproduct set OnlineProduct = 'True' where id = @ProductID;
		update PKCategory set Online = 'True' where ID = (select top 1 CategoryID from PKProduct where id = @ProductID);
		update PKDepartment set Online = 'True' where id = (select top 1 DepartmentID from PKCategory pc inner join PKProduct PP on pc.ID = pp.CategoryID and pp.id = @ProductID);
	End
	

END


GO
/****** Object:  StoredProcedure [dbo].[PK_SetUupdate5PriceInPriceList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_SetUupdate5PriceInPriceList] 
	@ID  NVarChar(50),
	@ProductID NVarChar(50),
	@A Decimal(18,2),
	@B Decimal(18,2),
	@C Decimal(18,2),
	@D Decimal(18,2),
	@E Decimal(18,2),
	@Special Decimal(18,2),
	@UpdateTime DateTime,
	@Updater NVarChar(50),
	@Online NVarChar(50),
	@IsAPriceSpecial NVarChar(50)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    update PKPrice set
		ID=@ID, ProductID=@ProductID, A=@A, B=@B, C=@C, D=@D, E=@E, Special=@Special,
		IsAPriceSpecial = @IsAPriceSpecial,
		UpdateTime=@UpdateTime,Updater=@Updater,online=@Online
		WHERE (ID=@ID)

	if len(@Online)>0 
	begin
		update pkproduct set OnlineProduct = 'True' where id = @ProductID;
		update PKCategory set Online = 'True' where ID = (select top 1 CategoryID from PKProduct where id = @ProductID);
		update PKDepartment set Online = 'True' where id = (select top 1 DepartmentID from PKCategory pc inner join PKProduct PP on pc.ID = pp.CategoryID and pp.id = @ProductID);
	end
	

END



GO
/****** Object:  StoredProcedure [dbo].[Pk_setzeroinventoryfornewproduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Pk_setzeroinventoryfornewproduct] @ProductID VARCHAR(50), 
                                                  @Creater   VARCHAR(50) 
AS 
  BEGIN 
      -- SET NOCOUNT ON added to prevent extra result sets from  
      -- interfering with SELECT statements.  
      SET nocount ON; 

      DECLARE @locationID VARCHAR(50); 
      DECLARE @currentInventoryProdCount INT; 
      DECLARE @ProductUnit VARCHAR(50); 
	  declare @averageCost decimal(18,4);
	  declare @latestCost Decimal(18,4);

	  set @averageCost = dbo.PK_FuncGetAverageCostFromBaseProductByProdID(@productId,'a');
	  set @latestCost = dbo.PK_FuncGetAverageCostFromBaseProductByProdID(@productId,'l');



      SELECT @ProductUnit = unit 
      FROM   pkproduct 
      WHERE  id = @ProductID; 

      DECLARE c_locationids CURSOR FOR 
        SELECT locationid 
        FROM   pklocation 

      OPEN c_locationids 

      FETCH next FROM c_locationids INTO @locationID 

      WHILE @@fetch_status = 0 
        BEGIN 
            SELECT @currentInventoryProdCount = Count(*) 
            FROM   pkinventory 
            WHERE  locationid = @locationID 
                   AND productid = @ProductID 

            IF @currentInventoryProdCount = 0 
              BEGIN 
                  INSERT INTO pkinventory 
                              (id, 
                               locationid, 
                               productid, 
                               qty, 
                               unit, 
                               latestcost, 
                               averagecost, 
                               createtime, 
                               updatetime, 
                               creater, 
                               updater) 
                  VALUES      (Newid(), 
                               @locationID, 
                               @ProductID, 
                               0, 
                               @ProductUnit, 
                               @latestCost, 
                               @averageCost, 
                               Getdate(), 
                               Getdate(), 
                               @Creater, 
                               @Creater ) 
              END 

            FETCH next FROM c_locationids INTO @locationID 
        END 

      CLOSE c_locationids 

      DEALLOCATE c_locationids 
  END 



GO
/****** Object:  StoredProcedure [dbo].[PK_TempGetSOForSage]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create  PROCEDURE [dbo].[PK_TempGetSOForSage]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @datenow  datetime;
	set @datenow = getdate();

	SELECT distinct PKSO.*,isnull(pp.PaymentType,'') as paymentType,pp.PaymentDate,pp.PaymentAmount
	into #tbl1
	FROM PKSO 
	INNER JOIN 
		(select OrderID,SUM(PaymentAmount) As PayAmount From PKPayment 
		WHERE PayType <>'Credit' AND 
		PaymentDate>='2015-03-01 14:25:12.000' and 
		PaymentDate<=  @datenow
		group by OrderID) AS Payment 
	ON PKSO.SOID=Payment.OrderID 
	left outer join PKPayment PP on pp.OrderID = PKSO.SOID and isnull(pp.PaymentType,'')<>'' 

	WHERE Status='Shipped' AND TotalAmount = PayAmount AND Type != 'Contract'

	order by PKSO.OrderID;

	select distinct SOID, SoldToTitle, 
	OrderID,
	TotalAmount,
	OrderDate,
	ShipDate--,
	--PaymentDate
	into #tbl2
	 from #tbl1


	 select t1.SOID,
	 isnull(tax1.Amount,0) as GST,
	 isnull(tax2.Amount,0) as PST,
	 isnull(tax3.Amount,0) as HST
	 into #tbl4
	 from #tbl2 t1
	 left outer join PKSOTax Tax1 on Tax1.SOID = t1.SOID and tax1.TaxID = 'TAX100'
	 left outer join PKSOTax Tax2 on Tax2.SOID = t1.SOID and Tax2.TaxID = 'TAX200'
	 left outer join PKSOTax Tax3 on Tax3.SOID = t1.SOID and Tax3.TaxID = '1'

	 --select * from #tbl2  order by orderid ;


	 select OrderID, max(PaymentDate) as paymentDate
	 into #tbl3
	 from #tbl1
	 group by OrderID 

	 select OrderID, sum(PaymentAmount) as PaymentAmount
	 into #tbl5
	 from #tbl1
	 group by OrderID 



	 --select * from #tbl3 order by orderid ;
	 --select * from #tbl2 where not exists(select * from #tbl3 where #tbl2.OrderID = #tbl3.OrderID)

	 select t2.SOID, 
		
		t2.OrderID,
		t4.GST,
		t4.PST,
		t4.HST,
		t2.TotalAmount,
		t3.paymentDate,
		t5.PaymentAmount,
		t2.OrderDate,
		t2.ShipDate, 
		t2.SoldToTitle
	 from #tbl2 t2
	 inner join #tbl3 t3 on t3.OrderID = t2.OrderID
	 inner join #tbl4 t4 on t4.SOID = t2.SOID
	 inner join #tbl5 t5 on t5.OrderID = t2.OrderID
	 order by t2.OrderID

	drop table #tbl1;
	drop table #tbl2;
	drop table #tbl3;
	drop table #tbl4;
	drop table #tbl5;

END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolInputInventoryWithoutUnit]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolInputInventoryWithoutUnit]
	
AS
BEGIN
	update PKInventory set
	unit = (select top 1 unit from PKProduct where PKProduct.id = PKInventory.ProductID) where  len(isnull(unit,''))=0



END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolInsertInventoryFromProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_ToolInsertInventoryFromProduct]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @locationId varchar(50);
	declare @productId varchar(50);
	declare @unit varchar(50);

	
    declare t_cursor0 cursor for 
		SELECT DISTINCT LocationID  FROM   PKLocation 
		open t_cursor0
		fetch next from t_cursor0 into @locationId
		while @@fetch_status = 0
		begin
			
			 declare t_cursor cursor for 
				SELECT DISTINCT ID,Unit  FROM   PKProduct where 
					not exists(select * from PKInventory a where a.ProductID = PKProduct.ID and a.LocationID = @locationId) 
					and DATEADD(s,2,CreateDateTime)<getdate()
				open t_cursor
				fetch next from t_cursor into @productId, @unit
				while @@fetch_status = 0
				begin
					insert into PKInventory                               
                                (ID, LocationID, ProductID, Qty, Unit, LatestCost, AverageCost, UpdateTime, CreateTime, Creater, Updater)
                                values(NEWID(),@locationId,@productId,0,@unit,0,0,getdate(),getdate(),'AutoCreate','AutoCreate')


					fetch next from t_cursor into @productId, @unit
				end
		
				close t_cursor
				deallocate t_cursor

			fetch next from t_cursor0 into @locationId
		end
		
		close t_cursor0
		deallocate t_cursor0


   


END



GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsAuthorizeAllToManager]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolsAuthorizeAllToManager]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @managerRoleId int;
	declare @featureId int;
	declare @newRoleId int

	set @managerRoleId = 3

	delete from PKRoleFeature where RoleID = @managerRoleId;


	  DECLARE t_cursor CURSOR FOR 
        SELECT ID from PKFeature
      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @featureId 
      WHILE @@fetch_status = 0 
        BEGIN 
			SELECT @newRoleId = Max(ID) FROM PKRoleFeature ;
			set @newRoleId = isnull(@newroleId,0);
			set @newRoleId = @newRoleId + 1;
			insert into PKRoleFeature(id,RoleID,FeatureID)values(@newRoleId,@managerRoleId,@featureId);

           FETCH next FROM t_cursor INTO @featureId 
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 

	  DECLARE t_cursor CURSOR FOR 
        SELECT ID from PKFeatureBooking
      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @featureId 
      WHILE @@fetch_status = 0 
        BEGIN 
			SELECT @newRoleId = Max(ID) FROM PKRoleFeatureBooking ;
			set @newRoleId = isnull(@newroleId,0);
			set @newRoleId = @newRoleId + 1;
			insert into PKRoleFeatureBooking(id,RoleID,FeatureID)values(@newRoleId,@managerRoleId,@featureId);

           FETCH next FROM t_cursor INTO @featureId 
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 


    
END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsCalculateIncomeInMonth]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_ToolsCalculateIncomeInMonth]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
		   
		SELECT distinct --pkso.*, 
		soid,
		SubTotal,
		TotalTax,
		TotalAmount, 
		PKSO.OrderID,
			   --Isnull(pp.paymenttype, '') AS paymentType ,
			   paymentD.PaymentDate,
			   payment.PayAmount,
			   --case TotalAmount - payment.PayAmount when 0 then 'true' else 'False' end as Paid
			   pkso.ShipDate,
			   pkso.OrderDate,
			   pkso.SoldToTitle as customer
			   into #tbl1
		FROM   pkso 
			   INNER JOIN (SELECT orderid, 
								  Sum(paymentamount) AS PayAmount 
						   FROM   pkpayment 
						   WHERE  paytype <> 'Credit' 
								  AND paymentdate <= 
						  getdate()
						   GROUP  BY orderid) AS Payment 
					   ON pkso.soid = Payment.orderid 
			   INNER JOIN (SELECT orderid, 
								  Max(paymentdate) AS PaymentDate 
						   FROM   pkpayment 
						   WHERE  paytype <> 'Credit' 
						   GROUP  BY orderid) AS paymentD 
					   ON pkso.soid = paymentD.orderid 
						  AND paymentdate >= '2016-02-28 11:32:30.373' 
			   --LEFT OUTER JOIN pkpayment PP 
						--	ON pp.orderid = pkso.soid 
						--	   AND Isnull(pp.paymenttype, '') <> '' 
						--	   AND Isnull(pp.paymenttype, '') <> 'Credit' 
						--	   AND Isnull(pp.paymenttype, '') <> 'Store Credit' 
		WHERE  status = 'Shipped' 
			   AND totalamount = payamount 
			   AND type != 'Contract' 

		order by orderid 

		--select * from #tbl1 
		--where paymentdate between '2016-04-01 1:00:50.347' and '2016-05-01 1:00:50.347'
		--order by orderid

		--delete from #tbl1 where orderid in (
		--'S002125',
		--'S002954',
		--'S003108',
		--'S003150',
		--'S003261',
		--'S003167',
		--'S003283',
		--'S003563'

		--)  and paymentType <> 'Cheque'

		--select DATEDIFF(mm,'2015-12-28 12:36:07.890',PaymentDate) as c, PaymentDate as a, soid,SubTotal,TotalTax,TotalAmount, paymentType,PaymentDate from #tbl1 
		--order by SOID ;--where orderid in (
		--'S002125',
		--'S002954',
		--'S003108',
		--'S003150',
		--'S003261',
		--'S003167',
		--'S003283',
		--'S003563'

		--)


		--select orderid,count(orderid) from #tbl1
		--group by orderid 
		--order by count(orderid) desc;

		--====================================================================================================================

		select pkst.soid,pkst.TaxID,pkst.Amount 
		into #tbl5
		from PKSOTax Pkst
		 inner join #tbl1 t1 on t1.soid = pkst.soid


		-- select * from #tbl5

		 --select soid, taxid ,
		 --count(soid)
		 -- from #tbl5
		 --group by soid, taxid
		 --order by count(soid) desc
		--select soid,sum(amount) from #tbl5 
		--group by soid

		--order by soid;

		--select taxid , count(taxid)
		--from #tbl5
		--group by TaxID


		select * 
		into #tbl6
		from #tbl5 
		PIVOT(
			sum( Amount ) for TaxID in(
			TAX100, TAX200,TAX300
			)
		)as aaa;

		--select * from #tbl6 order by soid;
		--select soid, isnull(tax100,0) as tax100, isnull(tax200,0) as tax200 from #tbl6 order by soid

		select DATEDIFF(mm,'2015-12-28 12:36:07.890',PaymentDate) as monthNames, PaymentDate as a, isnull(t3.TAX100,0) as Gst , isnull(t3.TAX200,0) as pst, t1.* 
		into #tbl4
		from #tbl1 t1
		left outer join #tbl6 t3 on t3.SOID  = t1.SOID
		order by monthNames

		select t1.OrderID, isnull(t3.TAX100,0) as Gst ,isnull(t3.TAX200,0) as pst,isnull(t3.TAX300,0) as Hst, 
		--t1.SubTotal,
		t1.TotalAmount,t1.PayAmount,t1.PaymentDate as lastPaymentDate,
		t1.OrderDate, t1.ShipDate,t1.customer
		
		from #tbl1 t1
		left outer join #tbl6 t3 on t3.SOID  = t1.SOID
		where DATEDIFF(mm,'2015-12-28 12:36:07.890',PaymentDate) = 9
		order by lastPaymentDate

		--select * from #tbl4 where monthNames = 3 order by orderid 

		select 
		--monthNames, sum(SubTotal) as subtitle, sum(cast(gst as decimal(18,2))) as gst, sum(cast(pst as decimal(18,2))) as pst, sum(TotalAmount) as totalAmount 
		--monthNames, sum(SubTotal) as subtitle, sum(gst) as gst, sum(pst) as pst, sum(TotalAmount) as totalAmount 
		monthNames, sum(SubTotal) as subtitle, sum(gst) as gst, sum(pst) as pst, sum(TotalAmount) as totalAmount 

		from #tbl4 

		group by monthNames

		order by monthNames;


		drop table #tbl1;

		drop table #tbl4
		drop table #tbl5
		drop table #tbl6


END


GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsCheckAllProductsWithQtyZero]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolsCheckAllProductsWithQtyZero]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		SELECT DISTINCT productid 
		into #tbl1
		FROM   (
			SELECT DISTINCT PIT.productid 
				FROM   pkinventory PIT 
					   INNER JOIN pkmapping PM 
							   ON PM.BaseProductID = pit.productid 
				WHERE  Pit.latestcost = 0 
					   AND locationid = '190' 
				UNION 
				SELECT productid 
				FROM   pkinventory PIT 
				WHERE  NOT EXISTS (SELECT * 
								   FROM   pkmapping 
								   WHERE  baseproductid = PIT.productid 
										   OR pkmapping.productid = PIT.productid) 
					   AND latestcost = 0 
					   AND locationid = '190'
		) a 
		;

		select pib.id, PIB.ProductID,PIB.seq 
		into #tbl2
		from PKInboundProduct PIB 
		inner join #tbl1 t1 on t1.ProductID = pib.ProductID;

		--select ppp.POProductID, PPP.ProductID,PPP.seq 
		--into #tbl3
		--from PKPOProduct PPP 
		--inner join #tbl1 t1 on t1.ProductID = PPP.ProductID;

		select * from #tbl2;
		--select * from #tbl3;

		--select * from #tbl2 where not exists(select * from #tbl3 where #tbl3.ProductID = #tbl2.ProductID);
		--select * from #tbl3 where not exists(select * from #tbl2 where #tbl3.ProductID = #tbl2.ProductID);

		--select ProductID,count(productId) from #tbl2
		--group by ProductID
		--order by count(productId) desc

		--select * from PKProduct p inner join #tbl2 on #tbl2.ProductID  = p.ID
		select isnull(ppr.a,0)as a, p.* from PKProduct p inner join #tbl1 on #tbl1.ProductID  = p.ID and not exists(
			select * from #tbl2 where #tbl2.ProductID = #tbl1.ProductID
		)
		left outer join PKPrice ppr on ppr.ProductID = p.id 
		order by a desc;

		select isnull(ppr.a,0)as a, p.* from PKProduct p inner join #tbl1 on #tbl1.ProductID  = p.ID and  exists(
			select * from #tbl2 where #tbl2.ProductID = #tbl1.ProductID
		)
		left outer join PKPrice ppr on ppr.ProductID = p.id 
		order by a desc;

		select isnull(ppr.a,0)as a, p.* from PKProduct p inner join #tbl1 on #tbl1.ProductID  = p.ID 
		left outer join PKPrice ppr on ppr.ProductID = p.id 
		order by a desc;


		select productid, max(seq)as seq
		into #tbl4
		 from #tbl2
		group by ProductID
		order by productid 

		select * from #tbl4 t4 
		inner join PKInboundProduct PIP on pip.seq  = t4.seq;

		drop table #tbl1;
		drop table #tbl2;
		drop table #tbl4;
		--drop table #tbl3;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsCheckTheSize]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_ToolsCheckTheSize]

AS
BEGIN


	if not exists
	(
	   select * from dbo.sysobjects
	   where id = object_id(N'[dbo].[tablespaceinfo]')
	   and OBJECTPROPERTY(id, N'IsUserTable') = 1
	)
	create table tablespaceinfo
	(
	   nameinfo varchar(50) ,
	   rowsinfo int , reserved varchar(20) ,
	   datainfo varchar(20) ,
	   index_size varchar(20) ,
	   unused varchar(20)
	)
 
	delete from tablespaceinfo --清空原有数据表
 
	declare @tablename varchar(255) --表名称　变量
	declare @cmdsql varchar(500) --执行命令 变量
	--申明游标　取出库中所有表名 
	DECLARE Info_cursor CURSOR FOR  
	select o.name  
	from dbo.sysobjects o where OBJECTPROPERTY(o.id, N'IsTable') = 1  
	and o.name not like N'#%%' order by o.name
 
	OPEN Info_cursor
	FETCH NEXT FROM Info_cursor
	INTO @tablename
 
	WHILE @@FETCH_STATUS = 0
	BEGIN
	--如果是用户表 
	if exists  
	(
	   select * from dbo.sysobjects
	where id = object_id(@tablename) and OBJECTPROPERTY(id, N'IsUserTable') = 1
	)
 
	--说明：sp_executesql 执行可以多次重复使用或动态生成的Transact-SQL 语句或批处理
 
	-- sp_spaceused 显示行数、保留的磁盘空间以及当前数据库中的表、索引视图
 
	-- 或Service Broker 队列所使用的磁盘空间，或显示由整个数据库保留和使用的磁盘空间。
 
	execute sp_executesql
 
	N'insert into tablespaceinfo exec sp_spaceused @tbname',
 
	N'@tbname varchar(255)',
 
	@tbname = @tablename
 
	FETCH NEXT FROM Info_cursor
	INTO @tablename
	END
 
	CLOSE Info_cursor  --闭关游标
 
	DEALLOCATE Info_cursor;   --释放游标
 

 
	--显示数据库信息
	--sp_spaceused @updateusage = 'TRUE';
 
	--显示表信息
	select * from tablespaceinfo
	order by cast(left(ltrim(rtrim(reserved)) , len(ltrim(rtrim(reserved)))-2) as int) desc

End



GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsFixProductCostByBaseProduct]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolsFixProductCostByBaseProduct]
	@toFixProductsWithCostNotZero varchar(50)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @baseProductId varchar(50);
	declare @productId varchar(50);
    -- Insert statements for procedure here
	DECLARE t_cursor CURSOR FOR 
        select BaseProductID, ProductID from PKMapping 
      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @baseproductId, @productId
      WHILE @@fetch_status = 0 
        BEGIN 
			declare @BaseLatestCost decimal(18,2);
			declare @productLatestCost decimal(18,2);
			declare @BaseAveCost decimal(18,2);
			declare @productAveCost decimal(18,2);
			declare @Capacity decimal(18,4);

			declare @ProductOriginalLatestCost decimal(18,2);
			declare @productOriginalAveCost decimal(18,2);

			select @BaseLatestCost = LatestCost, @BaseAveCost = AverageCost  from PKInventory PKI
				inner join PKLocation  PL on pl.LocationID = pki.LocationID
				where pl.IsHeadquarter = '1' and pki.ProductID = @baseProductId;

			set @Capacity = dbo.PK_FuncGetCapacityByProdID(@productId);
			set @productLatestCost = @BaseLatestCost * @Capacity;
			set @productAveCost = @BaseAveCost * @Capacity;

			select @ProductOriginalLatestCost = LatestCost, @productOriginalAveCost = AverageCost  from PKInventory PKI
				inner join PKLocation  PL on pl.LocationID = pki.LocationID
				where pl.IsHeadquarter = '1' and pki.ProductID = @productId;

			if @BaseLatestCost>0 and  @ProductOriginalLatestCost = 0
			begin
				update PKInventory set LatestCost = @productLatestCost, Updater = 'FixProductCostByBaseProduct',UpdateTime = GETDATE() where ProductID = @productId;
			end

			if @BaseAveCost>0 and @productOriginalAveCost = 0
			begin
				update PKInventory set AverageCost = @productAveCost, Updater = 'FixProductCostByBaseProduct',UpdateTime = GETDATE() where ProductID = @productId;
			end

            FETCH next FROM t_cursor INTO @baseproductId, @productId
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 


	  DECLARE t_cursor CURSOR FOR 
        select productid , LatestCost,AverageCost  from PKInventory PKI 
				inner join PKLocation  PL on pl.LocationID = pki.LocationID
				where pl.IsHeadquarter = '1' ;
      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @productId, @ProductOriginalLatestCost,@productOriginalAveCost
      WHILE @@fetch_status = 0 
        BEGIN 
				
				update PKInventory set LatestCost = @ProductOriginalLatestCost, Updater = 'FixProductSameCostL',UpdateTime = GETDATE() 
				where ProductID = @productId and LatestCost=0;
				update PKInventory set AverageCost = @productOriginalAveCost, Updater = 'FixProductSameCostA',UpdateTime = GETDATE() 
				where ProductID = @productId and AverageCost=0;

            FETCH next FROM t_cursor INTO @productId, @ProductOriginalLatestCost,@productOriginalAveCost
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 

END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsFixStockTake]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolsFixStockTake]
	@stockTakeId varchar(50)
AS
BEGIN
	
	declare @InventoryId varchar(50);
	declare @stockTakeQty decimal(18,2);
	declare @diff decimal(18,2);


	DECLARE t_cursor CURSOR FOR 
			select  [InventoryID],isnull([StockTakeQty],0) as stockTakeQty
      
				from PKStockTakeProduct 
				where stocktakeid = @stockTakeId --'d3406e1d-0f6a-4c32-8654-83ff7ceaff85' --and (barcode = '1101122' or barcode = '055104001125')

	OPEN t_cursor 
	FETCH next FROM t_cursor INTO @InventoryId, @stockTakeQty
	WHILE @@fetch_status = 0 
	BEGIN 
		

		SELECT @diff = sum(newqty - oldqty) 
		  FROM [PKInventoryHistory]
			where InventoryId = @InventoryId
			and updatedBy = 'saleSync'
			and updateTime > '2016-01-04 1:01:00'

		--select @InventoryId as i, @stockTakeQty as s, isnull(@diff,0) as diff, @stockTakeQty +  isnull(@diff,0) as newQty;
		update PKInventory set qty = @stockTakeQty +  isnull(@diff,0), UpdateTime = getdate(),Updater='fixStockTake' where id = @InventoryId;
		

		FETCH next FROM t_cursor INTO @InventoryId, @stockTakeQty
	END 

	CLOSE t_cursor 
	DEALLOCATE t_cursor 

END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsFixStockTake_ChangeToZeroButCalculated]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_ToolsFixStockTake_ChangeToZeroButCalculated]
	@stockTakeId varchar(50)
AS
BEGIN
	
	declare @InventoryId varchar(50);
	declare @stockTakeQty decimal(18,2);
	declare @diff decimal(18,2);
	declare @InvCaptureQty decimal(18,2);
	declare @InventoryOldQtynow decimal(18,2);
	declare @inventoryNewQtyNow decimal(18,2);
	declare @InventoryCurrentQty Decimal(18,2);

	DECLARE t_cursor CURSOR FOR 
			select  [InventoryID], InvCaptureQty, InventoryNewQTYNow,InventoryOldQTYNow
				from PKStockTakeProduct 
				where stocktakeid = @stockTakeId and StockTakeQty is null and StockTakeQty2 is null

	OPEN t_cursor 
	FETCH next FROM t_cursor INTO @InventoryId, @InvCaptureQty,@inventoryNewQtyNow, @InventoryOldQtynow
	WHILE @@fetch_status = 0 
	BEGIN 
		select @InventoryCurrentQty from PKInventory where id = @InventoryId;

		set @diff = @InventoryOldQtynow - @InvCaptureQty + @InventoryCurrentQty - @inventoryNewQtyNow




		--select @InventoryId as i, @stockTakeQty as s, isnull(@diff,0) as diff, @stockTakeQty +  isnull(@diff,0) as newQty;
		update PKInventory set qty = @diff, UpdateTime = getdate(),Updater='_ChangeToZeroButCalculated' where id = @InventoryId;
		

		FETCH next FROM t_cursor INTO @InventoryId, @InvCaptureQty,@inventoryNewQtyNow, @InventoryOldQtynow
	END 

	CLOSE t_cursor 
	DEALLOCATE t_cursor 

END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsFixZeroFromOtherLocationInOneProd]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolsFixZeroFromOtherLocationInOneProd]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @baseProductId varchar(50);
	declare @productId varchar(50);
	declare @inventoryid varchar(50);
    -- Insert statements for procedure here
	declare @latestCost decimal(18,2);
	declare @aveCost decimal(18,2);

	declare @i int 

	DECLARE t_cursor CURSOR FOR 
        select productid, LatestCost,AverageCost  from pkinventory where LatestCost >0  
      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @baseproductId, @latestCost, @aveCost

      WHILE @@fetch_status = 0 
        BEGIN 

				set @i = 0;

				DECLARE t_cursor2 CURSOR FOR 
				select id  from pkinventory where productid = @baseProductId and LatestCost = 0
			  OPEN t_cursor2 
			  FETCH next FROM t_cursor2 INTO @inventoryid
			  WHILE @@fetch_status = 0 
				BEGIN 
						print @inventoryid 
						set @i = @i + 1;

					FETCH next FROM t_cursor2 INTO @inventoryid
				END 

			  CLOSE t_cursor2 
			  DEALLOCATE t_cursor2 
						update PKInventory set LatestCost = @latestCost, Updater = 'FixZeroFromOtherLocationInOneProd',UpdateTime = GETDATE() 
						where ProductID = @baseProductId and LatestCost=0;
						update PKInventory set AverageCost = @aveCost, Updater = 'FixZeroFromOtherLocationInOneProd',UpdateTime = GETDATE() 
						where ProductID = @baseProductId and AverageCost=0;
			  if @i >0 
			  begin
						print @latestcost
						print '-----------------------------'
			
			end
           FETCH next FROM t_cursor INTO @baseproductId, @latestCost, @aveCost
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 


	 
END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsGetAllWrongMappingProducts]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[PK_ToolsGetAllWrongMappingProducts]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @tempDecNumber DECIMAL(18, 4); 
	set @tempDecNumber = 1.0000;
	DECLARE @tempString NVARCHAR(100); 

    SET @tempString =  N'1234567891012345678910123456789101234567891012345678910' ; 

    select 
	BaseProductID,
	p.Weigh as baseWeigh,
	p.NetWeightUnit as baseNetWeightUnit,

	ProductID
	into #tbl1

	from PKMapping PM
	inner join PKProduct P on p.id = pm.BaseProductID 
	;

	select 
	t.BaseProductID,
	t.baseWeigh,
	t.baseNetWeightUnit,
	@tempString as BaseIsWeigh,
	t.ProductID,
	p.Weigh as productWeigh,
	p.NetWeightUnit as productNetWeightUnit,
	@tempString as productAsWeigh
	into #tbl2

	from #tbl1 t
	inner join PKProduct p on p.id = t.ProductID
	
	update #tbl2 set BaseIsWeigh = 'y' where LOWER(baseWeigh) = 'y' or (LOWER(baseWeigh) = 'n' and lower(baseNetWeightUnit)<>'ea');
	update #tbl2 set BaseIsWeigh = 'n' where LOWER(baseWeigh) = 'n'  and lower(baseNetWeightUnit)='ea';

	update #tbl2 set productAsWeigh = 'y' where LOWER(productWeigh) = 'y' or (LOWER(productWeigh) = 'n' and lower(productNetWeightUnit)<>'ea');
	update #tbl2 set productAsWeigh = 'n' where LOWER(productWeigh) = 'n' and lower(productNetWeightUnit)='ea';


	select t2.BaseProductID,
	t2.BaseIsWeigh,
	t2.ProductID,
	t2.productAsWeigh,
	p.Barcode
	
	from #tbl2 t2 
	inner join pkproduct p on p.id = t2.ProductID
	where t2.BaseIsWeigh <> t2.productAsWeigh


	drop table #tbl1;
	drop table #tbl2;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsGetMappingList]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolsGetMappingList]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @baseProductId varchar(50);
	declare @subProductId varchar(50);


	declare @barcodeBase varchar(50);
	declare @barcodeSub varchar(50);
	declare @NameBase Nvarchar(50);
	declare @NameSub nvarchar(50);

	DECLARE @tempString NVARCHAR(100); 

		  SET @tempString =  N'1234567891012345678910123456789101234567891012345678910' 
		  ; 
		  SET @tempString = @tempString + N'1234567891012345678910123456789101234567891012345678910'; 


	select @tempString as ParentBarcode, @tempString as ParentName, @tempString as barcode, @tempString as name1 into #tbl1;
	delete from #tbl1



	DECLARE t_cursor CURSOR FOR 
        select distinct BaseProductID from PKMapping

      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @baseProductId
      WHILE @@fetch_status = 0 
        BEGIN 
				select @barcodeBase = Barcode,@NameBase = Name1 from PKProduct where id = @baseProductId;



				DECLARE t_cursor2 CURSOR FOR 
				select distinct ProductID from PKMapping where BaseProductID = @baseProductId

				OPEN t_cursor2 
				FETCH next FROM t_cursor2 INTO @subProductId
				WHILE @@fetch_status = 0 
				BEGIN 
					select @barcodeSub = Barcode,@NameSub = Name1 from PKProduct where id = @subProductId;

					insert into #tbl1(ParentBarcode, ParentName, barcode, name1)values(@barcodeBase , @NameBase , @barcodeSub, @NameSub );

					FETCH next FROM t_cursor2 INTO @subProductId
				END 

				CLOSE t_cursor2 
				DEALLOCATE t_cursor2 


            FETCH next FROM t_cursor INTO @baseProductId
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 


	  select * from #tbl1 order by ParentBarcode,barcode;

	  drop table #tbl1
END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsMoveInforOFCategory1ToCategory2]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [dbo].[PK_ToolsMoveInforOFCategory1ToCategory2] 
	@CategoryFrom varchar(50),
	@CategoryTO varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @ProductId varchar(50);
	declare @oldProductPlu varchar(50);
	declare @newProductPlu varchar(50);
	declare @newCategoryPLU varchar(50);
	declare @newCategoryProductCounts int;

	select @newCategoryProductCounts = count(*) from PKProduct where CategoryID = @CategoryTO;

	declare t_cursor cursor for 
	select ID, plu from PKProduct 
		where CategoryID = @CategoryFrom;
		open t_cursor
		fetch next from t_cursor into @ProductId, @oldProductPlu
		while @@fetch_status = 0
		begin
			

			select @newCategoryPLU = PLU from PKCategory where ID = @CategoryTO;
			select @newCategoryProductCounts = @newCategoryProductCounts +1;

			set @newProductPlu = @newCategoryPLU + RIGHT('0000' + cast(@newCategoryProductCounts as varchar(50)), 3);
			--print @ProductId ;
			--print @newCategoryPLU ;
			--print @newCategoryProductCounts ;
			--print @newProductPlu ;
			--print '------'

			update PKInboundProduct set plu = @newProductPlu where ProductID = @ProductId;
			update PKOutboundProduct set plu = @newProductPlu where ProductID = @ProductId;
			update PKPOProduct set plu = @newProductPlu where ProductID = @ProductId;
			update PKPOReturnProduct set plu = @newProductPlu where ProductID = @ProductId;
			update PKProduct set plu = @newProductPlu where id = @ProductId;
			update PKReceiveProduct set plu = @newProductPlu where ProductID = @ProductId;
			update PKSOProduct set plu = @newProductPlu where ProductID = @ProductId;
			update PKPromotion set plu = @newProductPlu where plu = @oldProductPlu;
			update TransactionItem set plu = @newProductPlu where ProductID = @ProductId;

			
			fetch next from t_cursor into @ProductId, @oldProductPlu
		end
		
		close t_cursor
		deallocate t_cursor

	    update PKProduct set CategoryID = @CategoryTO where CategoryID = @CategoryFrom;
END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsRoleBackTransferById]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PK_ToolsRoleBackTransferById]
	@transferId int
AS
BEGIN
	declare @fromLocationId varchar(50);
	declare @toLocationId varchar(50);
	declare @ProductId varchar(50);
	declare @qty decimal(18,4);

	select @fromLocationId = FromLocationID, @toLocationId = ToLocationID from PKTransfer where id = @transferId;


	declare t_cursor cursor for 
	select ProductID,Qty from PKTransferProduct where TransferID = @transferId;
	open t_cursor
	fetch next from t_cursor into @productId, @Qty
	while @@fetch_status = 0
	begin
		update PKInventory set Qty = Qty + @qty, UpdateTime = getdate(),Updater='RolebackTransfer' where ProductID = @ProductId and LocationID = @fromLocationId;
		update PKInventory set Qty = Qty - @qty, UpdateTime = getdate(),Updater='RolebackTransfer' where ProductID = @ProductId and LocationID = @toLocationId;



		fetch next from t_cursor into @productId, @Qty
	end
	close t_cursor
	deallocate t_cursor


END

GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsTempFixLatesCost]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PK_ToolsTempFixLatesCost]
	
AS
BEGIN
	
		--select * 

		--from PKInventory PKI
		--inner join PKReceiveProduct PRP on pki.ProductID = pki.ProductID

		--where pki.LocationID = '10' 

		select distinct productid
		into #tbl1
		 from PKInventory

		 --where LatestCost = 0 --and productid = '0e77b40c-4e31-4030-b7af-c2bcd84bb5fb';

		  --select * from #tbl1 where productid = '0e77b40c-4e31-4030-b7af-c2bcd84bb5fb';

		 select PrP.ProductID, max(seq) as seq  
		  into #tbl2
		 from PKInboundProduct PRP
		  where 
		  prp.UnitCost <> 0 
		  --productid = '0e77b40c-4e31-4030-b7af-c2bcd84bb5fb'
		 group by prp.ProductID
 
		 --select * from #tbl2;



		select t1.ProductID, isnull(prp.UnitCost,0.0) as unitCost, pib.InboundDate, pib.ID,prp.OrderQty,prp.Unit,p.Unit as Punit,prp.UnitCost/case dbo.PK_FuncGetRatesBetween2Units(prp.Unit,p.Unit) when 0 then 1 else dbo.PK_FuncGetRatesBetween2Units(prp.Unit,p.Unit) end  as correctCost, dbo.PK_FuncGetRatesBetween2Units(prp.Unit,p.Unit) as rate
		into #tbl3
		from PKInventory t1
		inner join PKProduct p on p.id = t1.ProductID
		left outer join #tbl2 t2 on t1.ProductID = t2.ProductID
		left outer join PKInboundProduct PRP on  t2.seq = PRP.seq
		left outer join PKInbound PIB on pib.id = prp.InboundID
		where p.Status = 'Active'
		order by pib.InboundDate

		select distinct * from #tbl3
		where ProductID in (
		
		'6fa3464b-404f-49fa-8fd0-ecfa2783443e',
'42f6b847-d5d9-41f8-a7be-3b5f1dfe6f55',
'4668ed22-e02a-40e1-a25e-d19852c3dc23',
'ebab4fe0-9021-42e7-947a-2b348da00854',
'05ded1be-52c9-4941-9815-5d3c28bc3541',
'a90de629-c466-4ca3-8a7d-b47f92dea27b',
'444b1b8b-9f72-41a2-8050-b7614a01212b',
'8a657860-9d48-40df-b832-22a26fa8bf3a',
'6ecf9ad5-0db8-47d2-9395-db1fceb49cd0',
'9031ceea-ddd9-4c62-9e0d-3bec17137d44',
'332685d9-2952-4061-ab6c-0b6b7e97b901'
		
		)
		;

		--select abs(pki.LatestCost - t3.unitCost) as diff, 
		--pki.id,
		--pki.LocationID,
		--pki.ProductID,
		--pki.Qty,
		--pki.unit,
		--pki.LatestCost,
		--pki.AverageCost,
		--t3.unitCost,
		--p.Name1,
		--p.PLU,
		--p.Barcode,
		--t3.InboundDate,
		--t3.ID as inboundID,
		--t3.orderQty
		--into #tbl4

		--from PKInventory PKI

		--inner join #tbl3 t3 on t3.ProductID = pki.ProductID
		--inner join PKProduct P on p.ID = t3.ProductID
		----inner join PKInboundProduct
		--where pki.LocationID = '190' 
		----and t3.unitCost > 0
		--order by diff desc 

		--select * from #tbl4

		select distinct
		pki.latestCost,
		t3.inboundDate,
		t3.unit,
		t3.punit,
		t3.correctCost,
		t3.rate,
		'update pkinventory set latestCost = '+ cast(cast(t3.correctCost as decimal(18,4)) as varchar(50)) +', updatetime = getdate(), updater = ''fixZeroFromInbound'' where productid = '''+ t3.ProductID +''' and locationid = ''190'''
		,
		'select * from pkinventory  where productid = '''+ t3.ProductID +''' and locationid = ''190'''

		 from #tbl3 t3
		 inner join PKInventory pKI on pki.ProductID = t3.ProductID and pki.LocationID = '190'
		--where productid in (

		--and 
		where 
		--pki.LatestCost <> 0 and
		t3.unitcost >0 
		--and pki.LatestCost =0 
		--and t4.OrderQty > 0
		--and pki.latestCost <> t3.unitCost
		--and t3.unit <> t3.punit
		--order by t4.qty desc 
		order by t3.InboundDate 
		;



		 drop table #tbl1;
		 drop table #tbl2;
		 drop table #tbl3;
		 --drop table #tbl4;


		 --update pkinventory set latestCost = 8.17, updatetime = getdate(), updater = 'fixZeroFromInbound' where productid = '0e77b40c-4e31-4030-b7af-c2bcd84bb5fb' and locationid = '190'


END

GO
/****** Object:  StoredProcedure [dbo].[pK_ToolsTransferOneProByPoid]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pK_ToolsTransferOneProByPoid]
	@POID varchar(50)
AS
BEGIN
	-- This procedure is to transfer one PO which is received and inbounded in HeaderQuater already, 
	-- but it is not transfered to the shipping address yet.
	-- So, this procedure is not a common one who was used frequently.

	SET NOCOUNT ON;

	declare @ShippingLocationId varchar(50);
	declare @billingLocationId varchar(50);
	declare @OrderId varchar(50);

	select @ShippingLocationId = LocationID, @billingLocationId = BillingLocationID, @OrderId = OrderID from PKPO where POID = @POID;

	declare @productid varchar(50);
	declare @Qty decimal(18,4);
	declare @unit varchar(50);
	declare @UnitRate decimal(18,4);
	declare @OriginalProductUnit varchar(50);
	declare @OriginalProductUnitRate decimal(18,4);





	declare t_cursor cursor for 
	select ppp.ProductID,ppp.OrderQty,ppp.Unit from PKPOProduct ppp inner join pkpo pp on pp.POID = ppp.POID and pp.poid =  @POID
	open t_cursor
	fetch next from t_cursor into @productId, @Qty, @unit
	while @@fetch_status = 0
	begin
		
		select @OriginalProductUnit = unit from PKProduct where id = @productid;

		if LOWER(@unit)<> LOWER(@OriginalProductUnit)
		begin

			select @UnitRate = Rate from PKUnitNames where unit = @unit;
			select @OriginalProductUnitRate = Rate from PKUnitNames where unit = @OriginalProductUnit;

			set @qty = @Qty * @UnitRate/@OriginalProductUnitRate;

		end


		update PKInventory set Qty = Qty + @qty, UpdateTime = getdate(),Updater=@OrderId where ProductID = @ProductId and LocationID = @ShippingLocationId;
		update PKInventory set Qty = Qty - @qty, UpdateTime = getdate(),Updater=@OrderId where ProductID = @ProductId and LocationID = @billingLocationId;



		fetch next from t_cursor into @productId, @Qty, @unit
	end
	close t_cursor
	deallocate t_cursor

END


GO
/****** Object:  StoredProcedure [dbo].[PK_ToolsUpdateTransferProductCost]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 CREATE PROCEDURE [dbo].[PK_ToolsUpdateTransferProductCost]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

        DECLARE @tempDecNumber DECIMAL(18, 4); 
	set @tempDecNumber = 1.0000;
	declare @locationId varchar(50);
	set @locationId = dbo.pk_GetHeaderQuaterFieldValue('LocationID');


	select PTF.[ID]
      ,[TransferID]
      ,PTF.[ProductID]
      ,[Pack]
      ,[PackingQty]
      ,PTF.[Qty]
      ,PTF.[Unit]
      ,[TotalCost]
      ,[UnitPrice]
      ,[MSRP]
	  ,p.Unit as OriginalUnit
	  ,isnull(PIV.LatestCost,0 ) as originalLatestCost
	  ,isnull(pr.A, 0 ) as originalMSRP
	  ,@tempDecNumber as rate1
	  ,@tempDecNumber as rate2
	  ,@tempDecNumber as capacity

	  into #tblOriginal
	  from PKTransferProduct PTF
	  inner join PKTransfer PT on pt.id = ptf.TransferID and pt.Status = 'Draft'
	  inner join PKProduct P on p.id = ptf.ProductID
	   inner join PKPrice Pr on pr.ProductID = ptf.ProductID
	  left outer join PKInventory PIV on piv.ProductID = ptf.ProductID and LocationID = @locationId

	  update #tblOriginal 
	  set rate1 = PKUnitNames.Rate from PKUnitNames where #tblOriginal.unit = PKUnitNames.unit;
	  update #tblOriginal 
	  set rate2 = PKUnitNames.Rate from PKUnitNames where #tblOriginal.OriginalUnit = PKUnitNames.unit;

	  update #tblOriginal set capacity = rate1/rate2;
	  
	  select * from #tblOriginal where productid = 'ec0d9269-16a0-490b-aeb2-77ea0f1af373';
	  update #tblOriginal set UnitPrice = originalLatestCost * capacity;
	  update #tblOriginal set TotalCost = originalLatestCost * qty; 
	  update #tblOriginal set MSRP = originalMSRP ;--* capacity;


	  update PKTransferProduct 
	  set UnitPrice = #tblOriginal.UnitPrice , MSRP = #tblOriginal.MSRP
	  from #tblOriginal where #tblOriginal.id = PKTransferProduct.ID


	  select * from #tblOriginal where productid = 'ec0d9269-16a0-490b-aeb2-77ea0f1af373';
	  select * from PKTransferProduct where ProductID = 'ec0d9269-16a0-490b-aeb2-77ea0f1af373' and id = 26068;

	  drop table #tblOriginal;




END


GO
/****** Object:  StoredProcedure [dbo].[PK_ToolSyncDictionary]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PK_ToolSyncDictionary]
	
AS
BEGIN
	-- *****************************************************************
	-- * The Procedure is used by Kevin ONLY,							*
	-- * 																*
	-- * to Export dictionary from the development computer				*
	-- * and import dictionay to the cutomers computer					*
	-- * by building sql.												*
	-- * ****************************************************************
	SET NOCOUNT ON;

 --   SELECT 
	--	c.name 'Column Name',
	--	t.Name 'Data type',
	--	c.max_length 'Max Length',
	--	c.precision ,
	--	c.scale ,
	--	c.is_nullable,
 --   ISNULL(i.is_primary_key, 0) 'Primary Key'
	--FROM    
	--	sys.columns c
	--INNER JOIN 
	--	sys.types t ON c.user_type_id = t.user_type_id
	--LEFT OUTER JOIN 
	--	sys.index_columns ic ON ic.object_id = c.object_id AND ic.column_id = c.column_id
	--LEFT OUTER JOIN 
	--	sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
	--WHERE
	--	c.object_id = OBJECT_ID('PK_Dictionary')



	declare @sqlStr varchar(max);
	declare @columnName varchar(50);
	declare @selectStr varchar(max);

	declare @sqlUpdate varchar(max);
	declare @sqlUpdateWhere varchar(200);
	--insert into PK_Dictionary()values()
	set @sqlStr = 'insert into PK_Dictionary(';
	set @selectStr = '';

	set @sqlUpdate = 'update PK_Dictionary set '

	DECLARE t_cursor CURSOR FOR 
        SELECT 
		c.name
			FROM    
				sys.columns c
			WHERE
				c.object_id = OBJECT_ID('PK_Dictionary')

      OPEN t_cursor 
      FETCH next FROM t_cursor INTO @columnName 
      WHILE @@fetch_status = 0 
        BEGIN 
			if lower(@columnName)<>'id' 
			begin
				set @sqlStr = @sqlStr + @columnName + ','
				set @selectStr = @selectStr + '''N''''''+isnull(' + @columnName + ','''')+'''''',''+' 
				print @sqlstr 
				print @selectStr
				print '------'
				if lower(@columnName)<>'fieldName' 
				begin
					set @sqlUpdate = @sqlupdate + ' ' + @columnName + '='' + ''N''''''+isnull(' + @columnName + ','''')+'''''',' ;
				end
				else
				begin
					set @sqlUpdateWhere =   ' where ' + @columnName + '='' + ''N''''''+isnull(' + @columnName + ','''')+''''''' ;
				end
			end

            FETCH next FROM t_cursor INTO @columnName 
        END 

      CLOSE t_cursor 
      DEALLOCATE t_cursor 

	  --select @sqlStr;
	  --select @selectStr;
	  
	  	  set @sqlStr = SUBSTRING(@sqlStr,1,len(@sqlstr)-1);
	  set @selectStr = SUBSTRING(@selectStr,1,len(@selectStr)-3) + ');''';--GO;
	  	  set @sqlUpdate = SUBSTRING(@sqlUpdate,1,len(@sqlUpdate)-1);

	  set @sqlStr = @sqlStr + ')values('
	  set @selectStr = 'select ' + '''' + @sqlStr + ''' + ' + @selectStr + ' from pk_dictionary'
	  set @sqlUpdate = 'select ' + '''' + @sqlUpdate  + @sqlUpdateWhere + '''  from pk_dictionary'


	  --select @sqlStr;
	  exec(@selectStr);
	  exec(@sqlUpdate);
	  --select @selectStr;

END


GO
/****** Object:  StoredProcedure [dbo].[PKSavePayment]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[PKSavePayment]
 @OrderType varchar(50),
 @OrderID varchar(50),
 @InvoiceNo varchar(50), 
 @InvoiceAmount varchar(50),
 @PaymentType varchar(50),
 @CardID varchar(50),
 @PaymentAmount decimal(18,2),
 @Remarks varchar(50),
 @ALLPaid varchar(50), 
 @CreateBy varchar(50),
 @PaymentDate DateTime, 
 @CreateDate DateTime, 
 @PayType varchar(50),
 @Balance decimal(18,2)
AS
BEGIN
    if (SELECT count(*) FROM PKPayment WHERE OrderID= @OrderID AND PayType='Deposit') =0
      Begin
         insert into PKPayment
                                ( OrderType, OrderID, InvoiceNo, InvoiceAmount, PaymentType, CardID, PaymentAmount, Remarks, ALLPaid, CreateBy, PaymentDate, CreateDate,PayType,Balance) 
                                values 
                                ( @OrderType, @OrderID, @InvoiceNo, @InvoiceAmount, @PaymentType, @CardID, @PaymentAmount, @Remarks, @ALLPaid, @CreateBy, @PaymentDate, @CreateDate,@PayType,@Balance)
      End
	else
	  Begin 
	     Update PKPayment SET PaymentAmount=@PaymentAmount, CreateBy = @CreateBy, PaymentDate=@PaymentDate,Balance=@Balance WHERE  OrderID= @OrderID AND PayType='Deposit'
      End
END

GO
/****** Object:  StoredProcedure [dbo].[PKToolsFixInventoryAtTimepoint]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PKToolsFixInventoryAtTimepoint]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
		declare @timePoint smalldatetime;
		set @timePoint = cast ('2016-01-01 11:23:00' as smalldatetime);
		-----------------------------------------------------------------
		select InventoryId, min(Id) as id 
			into #tblNeedToBeCalculated

			from PKInventoryHistory
			where updateTime>@timePoint
			group by InventoryId
			order by id 

		select tc.InventoryId, tC.id, ph.ProductID,ph.LocationID,ph.qty as currentQty
			into #tblNeedToBeCalculated2
			from #tblNeedToBeCalculated TC
			inner join PKInventory PH on PH.id = tc.InventoryId
	
		-----------------------------------------------------------------
		select InventoryId, max(Id) as id 
			into #tblLastQty
			from PKInventoryHistory
			where updatetime < @timePoint
			group by InventoryId
			order by id 

		select TL.inventoryId, tL.id, ph.NewQty
		into #tblLastQty2
		from #tblLastQty TL 
		inner join PKInventoryHistory PH on PH.id = tl.id
		-----------------------------------------------------------------
		--History of outbound

		select distinct pop.*
		into #tblOutbound
		from #tblNeedToBeCalculated tc
		inner join PKInventory PIT on tc.InventoryId = pit.id
		inner join PKOutboundProduct POP on pit.productId = POP.ProductID and pit.LocationID = POP.LocationID
		inner join pkoutbound POB on poP.OutboundID  = POB.ID
		where POB.outboundDAte > @timePoint;


		select LocationID, productId,sum(OrderQty) as qty
		into #tblOutbound2
		from #tblOutbound
		group by locationId,ProductId
		-----------------------------------------------------------------
		--History of Inbound

		select distinct pop.*
		into #tblInbound
		from #tblNeedToBeCalculated tc
		inner join PKInventory PIT on tc.InventoryId = pit.id
		inner join PKInboundProduct POP on pit.productId = POP.ProductID and pit.LocationID = POP.LocationID
		inner join PKInbound POB on poP.InboundID  = POB.ID
		where POB.inboundDate > @timePoint;


		select LocationID, productId,sum(OrderQty) as qty
		into #tblInbound2
		from #tblInbound
		group by locationId,ProductId

		-----------------------------------------------------------------
		--History of transfer

		select distinct  Pob.FromLocationID,Pob.ToLocationID, pop.*
		into #tblTransfer
		from #tblNeedToBeCalculated tc
		inner join PKInventory PIT on tc.InventoryId = pit.id
		inner join PKtransferProduct POP on pit.productId = POP.ProductID 
		inner join PKTransfer POB on poP.TransferID  = POB.ID
		where POB.UpdateDate > @timePoint and pob.status = 'Post'; 



		select FromLocationID, productId,sum(qty) as qty
		into #transactionFrom
		from #tblTransfer
		group by FromLocationID,ProductId


		select ToLocationID, productId,sum(qty) as qty
		into #tblTransferTo
		from #tblTransfer
		group by ToLocationID,ProductId
		-----------------------------------------------------------------

		select tc.*, 
		isnull(tl.NewQty,0) as originalQty,
		isnull(to2.qty,0) as outQty,
		isnull(ti.qty, 0) as inQty,
		isnull(ttf.qty, 0) as transFromQty,
		isnull(ttt.qty, 0) as transToQty
		into #tblFinal
		from #tblNeedToBeCalculated2 tc
		left outer join #tblLastQty2 tl on tl.InventoryId = tc.InventoryId
		left outer join #tblOutbound2 to2 on to2.LocationID = tc.LocationId and to2.ProductID = tc.ProductID
		left outer join #tblTransferTo ttt on ttt.ToLocationID = tc.LocationId and ttt.ProductID = tc.ProductID
		left outer join #transactionFrom ttf on ttf.FromLocationID = tc.LocationId and ttf.ProductID = tc.ProductID
		left outer join #tblInbound2 ti on ti.LocationID = tc.LocationId and ti.ProductID = tc.ProductID
		---------------------------------------------------------------------

		select * ,
		originalQty - outQty - transFromQty + inQty + transToQty as FixQty
		into #tblFinal2
		from 
		#tblFinal
		-----------------------

		select * ,
		case currentQty-fixqty when 0 then 'Equal' else 'Need fix' end as Result
		from #tblFinal2
		order by abs(currentQty-fixqty) desc
		-----------------------

		select 'update pkinventory set qty = '+ cast(fixqty as varchar(50)) +' where id = '''+ inventoryId +'''' 

		from #tblFinal2

		where currentQty-fixqty<>0
		--------------------

			drop table #tblNeedToBeCalculated;
			drop table #tblNeedToBeCalculated2;
			drop table #tblLastQty;
			drop table #tblLastQty2;	
			drop table #tblOutbound;
			drop table #tblOutbound2;	
			drop table #tblInbound;
			drop table #tblInbound2;	
			drop table #tblTransfer;
			drop table #transactionFrom;
			drop table #tblTransferTo;
			drop table #tblFinal;	
			drop table #tblFinal2;		










END

GO
/****** Object:  StoredProcedure [dbo].[sp_dbcmptlevel]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 create procedure [dbo].[sp_dbcmptlevel]            -- 1997/04/15  
    @dbname sysname = NULL,                 -- database name to change  
    @new_cmptlevel tinyint = NULL OUTPUT    -- the new compatibility level to change to  
 as  
    set nocount    on  
   
    declare @exec_stmt nvarchar(max)  
    declare @returncode int  
    declare @comptlevel float(8)  
    declare @dbid int                   -- dbid of the database  
    declare @dbsid varbinary(85)        -- id of the owner of the database  
    declare @orig_cmptlevel tinyint     -- original compatibility level  
    declare @input_cmptlevel tinyint    -- compatibility level passed in by user  
        ,@cmptlvl80 tinyint             -- compatibility to SQL Server Version 8.0  
        ,@cmptlvl90 tinyint             -- compatibility to SQL Server Version 9.0  
        ,@cmptlvl100 tinyint                -- compatibility to SQL Server Version 10.0  
    select  @cmptlvl80 = 80,  
            @cmptlvl90 = 90,  
            @cmptlvl100 = 100  
   
    -- SP MUST BE CALLED AT ADHOC LEVEL --  
    if (@@nestlevel > 1)  
    begin  
        raiserror(15432,-1,-1,'sys.sp_dbcmptlevel')  
        return (1)  
    end  
   
    -- If no @dbname given, just list the valid compatibility level values.  
    if @dbname is null  
    begin  
       raiserror (15048, -1, -1, @cmptlvl80, @cmptlvl90, @cmptlvl100)  
       return (0)  
    end  
   
    --  Verify the database name and get info  
    select @dbid = dbid, @dbsid = sid ,@orig_cmptlevel = cmptlevel  
        from master.dbo.sysdatabases  
        where name = @dbname  
   
    --  If @dbname not found, say so and list the databases.  
    if @dbid is null  
    begin  
        raiserror(15010,-1,-1,@dbname)  
        print ' '  
        select name as 'Available databases:'  
            from master.dbo.sysdatabases  
        return (1)  
    end  
   
    -- Now save the input compatibility level and initialize the return clevel  
    -- to be the current clevel  
    select @input_cmptlevel = @new_cmptlevel  
    select @new_cmptlevel = @orig_cmptlevel  
   
    -- If no clevel was supplied, display and output current level.  
    if @input_cmptlevel is null  
    begin  
        raiserror(15054, -1, -1, @orig_cmptlevel)  
        return(0)  
    end  
   
    -- If invalid clevel given, print usage and return error code  
    -- 'usage: sp_dbcmptlevel [dbname [, compatibilitylevel]]'  
    if @input_cmptlevel not in (@cmptlvl80, @cmptlvl90, @cmptlvl100)  
    begin  
        raiserror(15416, -1, -1)  
        print ' '  
        raiserror (15048, -1, -1, @cmptlvl80, @cmptlvl90, @cmptlvl100)  
        return (1)  
    end  
   
    --  Only the SA or the dbo of @dbname can execute the update part  
    --  of this procedure sys.so check.  
    if (not (is_srvrolemember('sysadmin') = 1)) and suser_sid() <> @dbsid  
        -- ALSO ALLOW db_owner ONLY IF DB REQUESTED IS CURRENT DB  
        and (@dbid <> db_id() or is_member('db_owner') <> 1)  
    begin  
        raiserror(15418,-1,-1)  
        return (1)  
    end  
   
    -- If we're in a transaction, disallow this since it might make recovery impossible.  
    set implicit_transactions off  
    if @@trancount > 0  
    begin  
        raiserror(15002,-1,-1,'sys.sp_dbcmptlevel')  
        return (1)  
    end  
   
    set @exec_stmt = 'ALTER DATABASE ' + quotename(@dbname, '[') + ' SET COMPATIBILITY_LEVEL = ' + cast(@input_cmptlevel as nvarchar(128))  
   
    -- Note: database @dbname may not exist anymore  
    exec(@exec_stmt)  
   
    select @new_cmptlevel = @input_cmptlevel  
   
    return (0) -- sp_dbcmptlevel  

GO
/****** Object:  StoredProcedure [dbo].[sp_defragment_indexes]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[sp_defragment_indexes] 
  @maxfrag DECIMAL 
AS 
  --声明变量 
  SET nocount ON 
  DECLARE @tablename   VARCHAR (128) 
  DECLARE @execstr     VARCHAR (255) 
  DECLARE @objectid    INT 
  DECLARE @objectowner VARCHAR(255) 
  DECLARE @indexid     INT 
  DECLARE @frag        DECIMAL 
  DECLARE @indexname   CHAR(255) 
  DECLARE @dbname SYSNAME 
  DECLARE @tableid     INT 
  DECLARE @tableidchar VARCHAR(255) 
  --检查是否在用户数据库里运行 
  SELECT @dbname = Db_name() 
  IF @dbname IN ('master', 
                 'msdb', 
                 'model', 
                 'tempdb') 
  BEGIN 
    PRINT 'this PROCEDURE should NOT be run IN system databases.'
    RETURN 
  END 
  --第1阶段:检测碎片 
  --声明游标 
  DECLARE tables CURSOR FOR 
  SELECT CONVERT(VARCHAR,so.id) 
  FROM   sysobjects so 
  JOIN   sysindexes si 
  ON     so.id = si.id 
  WHERE  so.type ='u' 
  AND    si.indid < 2 
  AND    si.rows > 0 
  -- 创建一个临时表来存储碎片信息 
  CREATE TABLE #fraglist 
               ( 
                            objectname     CHAR (255), 
                            objectid       INT, 
                            indexname      CHAR (255), 
                            indexid        INT, 
                            lvl            INT, 
                            countpages     INT, 
                            countrows      INT, 
                            minrecsize     INT, 
                            maxrecsize     INT, 
                            avgrecsize     INT, 
                            forreccount    INT, 
                            extents        INT, 
                            extentswitches INT, 
                            avgfreebytes   INT, 
                            avgpagedensity INT, 
                            scandensity    DECIMAL, 
                            bestcount      INT, 
                            actualcount    INT, 
                            logicalfrag    DECIMAL, 
                            extentfrag     DECIMAL 
               ) 
  --打开游标 
  OPEN tables 
  -- 对数据库的所有表循环执行dbcc showcontig命令 
  FETCH next 
  FROM  tables 
  INTO  @tableidchar 
  WHILE @@FETCH_STATUS = 0 
  BEGIN 
    --对表的所有索引进行统计 
    INSERT INTO #fraglist 
    EXEC ('dbcc showcontig (' + @tableidchar + ') WITH fast, tableresults, all_indexes, no_infomsgs')
    FETCH next 
    FROM  tables 
    INTO  @tableidchar 
  END 
  -- 关闭释放游标 
  CLOSE tables 
  DEALLOCATE tables 
  -- 为了检查，报告统计结果 
  SELECT * 
  FROM   #fraglist 
  --第2阶段: (整理碎片) 为每一个要整理碎片的索引声明游标 
  DECLARE indexes CURSOR FOR 
  SELECT objectname, 
         objectowner = User_name(so.uid), 
         objectid, 
         indexname, 
         scandensity 
  FROM   #fraglist f 
  JOIN   sysobjects so 
  ON     f.objectid=so.id 
  WHERE  scandensity <= @maxfrag 
  AND    indexproperty (objectid, indexname, 'indexdepth') > 0 
  -- 输出开始时间 
  SELECT 'started defragmenting indexes at ' + CONVERT(varchar,getdate())
  --打开游标 
  OPEN indexes 
  --循环所有的索引 
  FETCH next 
  FROM  indexes 
  INTO  @tablename, 
        @objectowner, 
        @objectid, 
        @indexname, 
        @frag 
  WHILE @@FETCH_STATUS = 0 
  BEGIN 
    SET quoted_identifier ON 
    SELECT @execstr = 'DBCC dbreindex (' +''''+ rtrim(@objectowner) + '.' + rtrim(@tablename) +'''' + ', ''' + rtrim(@indexname) + ''') WITH no_infomsgs'
    SELECT 'now EXECUTING: ' 
    SELECT(@execstr) 
    EXEC (@execstr) 
    SET quoted_identifier OFF 
    FETCH next 
    FROM  indexes 
    INTO  @tablename, 
          @objectowner, 
          @objectid, 
          @indexname, 
          @frag 
  END 
  -- 关闭释放游标 
  CLOSE indexes 
  DEALLOCATE indexes 
  -- 报告结束时间 
  SELECT 'finished defragmenting indexes at ' + CONVERT(varchar,getdate())
  -- 删除临时表 
  DROP TABLE #fraglist

GO
/****** Object:  StoredProcedure [dbo].[VipReport]    Script Date: 2023/2/10 14:13:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[VipReport]
	@rptId int,
	@timeFrom datetime,
	@timeTo datetime
AS
BEGIN
	declare @frequency varchar(50);
	declare @cardfrom varchar(50);
	declare @cardTo varchar(50);


	--set @rptId=6;

	select 
			@frequency=rptFrequency,
			@cardfrom=rptCardFrom,
			@cardTo=rptCardTo 
		from CustomerVipReport 
		where rptid=@rptId

	--select @frequency as f,@cardfrom as cf, @cardTo as ct;

	--**Ignore frequency for now

	--


	SELECT 
	   
		   c.CustomerNo as IDCardNo,
		   c.FirstName + ' ' + c.LastName as cardOwner,
		   ct.TransactionID as OriginalTransactionId,
		   pt.TransactionNo as TransactionID,
		   pt.Cashier,
		   pt.SubTotalAmount,
		   abs(pt.SubTotalDiscount) as SubTotalDiscount,
		   pt.TotalAmount,
		   pt.AllTaxTotalAmount,
		   ti.Name1 + case isnull(ti.Name2,'') when '' then '' else '  [' + ti.Name2 + ']' end  as productName,
		   ti.Qty,
		   ti.UnitPrice,
		   ti.ItemTaxTotalAmount,
		   ti.ItemSubTotal
		   ,pt.StatusDateTime

	  into #tbl1
	  FROM Customer c
	  left join CustomerTransaction ct 
		on c.ID = ct.CustomerID
	  left join POSTransaction PT
		on ct.TransactionID = PT.ID
	  left join TransactionItem TI
		on ti.TransactionID = ct.TransactionID


	  where 
	  c.CustomerNo >=@cardfrom and 
	  c.CustomerNo<=@cardTo   
	  and PT.StatusDateTime >= @timeFrom and
	  pt.StatusDateTime <= @timeTo

	  --group by c.IDCardNo,ct.TransactionID

	  order by IDCardNo,TransactionID

	  SELECT distinct IDCardNo,
		   TransactionID,
		   SubTotalAmount,
		   SubTotalDiscount,
		   AllTaxTotalAmount,
		   TotalAmount
	  into #tbl2
	  from #tbl1

	  --select * from #tbl2;
	  
	  select 
		IDCardNo,
		sum(subTotalAmount) as sumSubAmount,
		sum(subTotalDiscount) as sumSubDiscount,
		sum(allTaxTotalAmount) as sumTax,
		sum (totalAmount) as sumAmount,
		count(idcardNo) as transCount,
		sum (totalAmount)/count(idcardNo) as transAveAmount
	  into #tbl3
	  from #tbl2
	  group by idcardNo;

	  select 
		sum(subTotalAmount) as allSubAmount,
		sum(subTotalDiscount) as allSubDiscount,
		sum(totalAmount) as allAmount,
		count(idcardNo) as allTransCount,
		sum(allTaxTotalAmount) as allTax,
		sum(totalAmount)/count(idcardNo) as AllAveAmount
	  into #tbl4
	  from #tbl2

	  SELECT 
		   t1.IDCardNo,
		   t1.cardOwner,
		   t1.TransactionID,
		   t1.Cashier,
		   t1.SubTotalAmount,
		   t1.SubTotalDiscount,
		   t1.AllTaxTotalAmount,
		   t1.TotalAmount,
		   t1.productName,
		   t1.Qty,
		   t1.UnitPrice,
		   t1.ItemTaxTotalAmount,
		   t1.ItemSubTotal,
		   t1.StatusDateTime,
		   t3.sumSubAmount,
		   t3.sumSubDiscount,
		   t3.sumTax,
		   t3.sumAmount,
		   t3.transCount,
		   t3.transAveAmount,
		   t4.allSubAmount,
		   t4.allSubDiscount,
		   t4.allTax,
		   t4.allAmount,
		   t4.allTransCount,
		   t4.AllAveAmount
		from #tbl1 t1
		left join #tbl3 t3 on t3.IDCardNo = t1.IDCardNo
		left join #tbl4 t4 on 1=1




  drop table #tbl4; 
  drop table #tbl3;  
  drop table #tbl2;  
  drop table #tbl1;

END





GO
