SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	27/04/2018
-- Descripción:		Insersión y afectación de facturas de credito y venta.
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_VentasInsertar]
    @Empresa AS CHAR(5) ,
    @Mov AS CHAR(20) ,
    @FechaEmision AS SMALLDATETIME ,
    @Concepto AS VARCHAR(50) ,
    @Moneda AS CHAR(10) ,
    @TipoCambio AS FLOAT ,
    @Usuario AS CHAR(10) ,
    @Referencia AS VARCHAR(50) ,
    @Codigo AS VARCHAR(30) ,
    @Cliente AS CHAR(10) ,
    @Sucursal AS INT ,
    @Vencimiento AS SMALLDATETIME ,
    @Importe AS MONEY ,
    @Impuestos AS MONEY ,
    @CentroDeCostos AS VARCHAR(20) ,
    @TipoPago AS VARCHAR(50) ,
    @Observaciones AS VARCHAR(100) ,
    @Comentarios AS VARCHAR(MAX) ,
    @PartidasVtas VARCHAR(MAX) = NULL ,
    @MovRelacionados VARCHAR(MAX) = NULL ,
    @ID AS INT = NULL OUTPUT ,
    @MovID AS VARCHAR(MAX) = NULL OUTPUT ,
    @Estatus AS CHAR(15) = NULL OUTPUT ,
    @CFDFlexEstatus AS VARCHAR(15) = NULL OUTPUT ,
    @CFDxml AS VARCHAR(MAX) = NULL OUTPUT ,
    @noCertificado AS VARCHAR(MAX) = NULL OUTPUT ,
    @Sello AS VARCHAR(MAX) = NULL OUTPUT ,
    @SelloSAT AS VARCHAR(MAX) = NULL OUTPUT ,
    @TFDCadenaOriginal VARCHAR(MAX) = NULL OUTPUT ,
    @UUID AS VARCHAR(MAX) = NULL OUTPUT ,
    @FechaTimbrado AS VARCHAR(MAX) = NULL OUTPUT ,
    @noCertificadoSAT AS VARCHAR(MAX) = NULL OUTPUT
AS
    BEGIN
        SET NOCOUNT ON;
	--********************************************************************
    --        VARIABLES 
    --********************************************************************
	-- Se crea y se genera Xml con los parametros para tabla Interfaz_Logs
        DECLARE @LogParametrosXml XML;
        SET @LogParametrosXml = ( SELECT    @Empresa AS 'Empresa' ,
                                            @Mov AS 'Mov' ,
                                            @FechaEmision AS 'FechaEmision' ,
                                            @Concepto AS 'Concepto' ,
                                            @Moneda AS 'Moneda' ,
                                            @TipoCambio AS 'TipoCambio' ,
                                            @Usuario AS 'Usuario' ,
                                            @Referencia AS 'Referencia' ,
                                            @Codigo AS 'Codigo' ,
                                            @Cliente AS 'Cliente' ,
                                            @Sucursal AS 'Sucursal' ,
                                            @Vencimiento AS 'Vencimiento' ,
                                            @Importe AS 'Importe' ,
                                            @Impuestos AS 'Impuestos' ,
                                            @CentroDeCostos AS 'CentroDeCostos' ,
                                            @TipoPago AS 'TipoPago' ,
                                            @Observaciones AS 'Observaciones' ,
                                            @Comentarios AS 'Comentarios' ,
                                            @PartidasVtas AS 'PartidasVtas' ,
                                            @MovRelacionados AS 'MovRelacionados'
                                FOR
                                  XML PATH('Parametros')
                                );
        EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Inserción', '', @Usuario, @LogParametrosXml;

		/* Tipo de Pago segun catalogo de Intelisis*/
        PRINT 'Tipo de pago recibida: ' + RTRIM(@TipoPago);
        SELECT  @TipoPago = ( CASE WHEN @TipoPago = 'Tarjeta de Credito' THEN 'Tarjetas de Crédito'
                                   WHEN @TipoPago = 'Tarjeta de Debito' THEN 'Tarjeta de débito'
                                   WHEN @TipoPago = 'Deposito Cheque' THEN 'Cheque'
                                   WHEN @TipoPago = 'Deposito Efectivo' THEN 'Efectivo'
                                   WHEN @TipoPago = 'PayPal' THEN 'Tarjeta de débito'
                                   WHEN @TipoPago = 'Transferencia' THEN 'Transferencia Electronica'
                                   WHEN @TipoPago = 'NO IDENTIFICADO' THEN 'NA'
                                   ELSE @TipoPago
                              END );
        PRINT 'Tipo de pago a insertar: ' + RTRIM(@TipoPago);
   	
	-- VARIABLES DE LOS MOVIMIENTOS
        DECLARE @RegresoID AS INT ,
            @DescripcionExtra AS VARCHAR(255) ,
            @sreferencia AS VARCHAR(255) ,
            @TasaImpuesto AS MONEY ,
            @Precio AS FLOAT ,
            @Almacen AS CHAR(10) ,
            @Unidad AS CHAR(20) ,
            @Articulo AS VARCHAR(20) ,
            @Condicion AS VARCHAR(20) ,
            @Impuesto1 AS FLOAT;

	-- VARIBLES PARA MENSAJES DE ERROR
        DECLARE @iError AS INT ,
            @sError AS VARCHAR(MAX) ,
            @bMovValido AS BIT;

        DECLARE @T_PartidasVtas TABLE
            (
              Consecutivo INT IDENTITY(1, 1) ,
              Articulo VARCHAR(20) ,
              Precio FLOAT ,
              TasaImpuesto MONEY
            )
		
        DECLARE @T_MovRelacionados AS TABLE
            (
              ID INT NOT NULL ,
              Importe MONEY
            )

        DECLARE @T_ComparacionAnticipos TABLE
            (
              Consecutivo INT IDENTITY(1, 1)
                              NOT NULL ,
              aID INT ,
              aImporte MONEY ,
              CxcID INT ,
              Diferencia MONEY ,
              Mov VARCHAR(20) ,
              MovID VARCHAR(20) ,
              Cliente CHAR(10) ,
              Estatus CHAR(15)
            )
            
        DECLARE @X_PartidasVtas XML
        SET @X_PartidasVtas = CAST(@PartidasVtas AS XML);

        DECLARE @X_MovRelacionados XML
        SET @X_MovRelacionados = CAST(@MovRelacionados AS XML);

        SELECT  @Condicion = 'Credito';

        IF ISNULL(@PartidasVtas, '') = ''
            BEGIN
                SELECT  @TasaImpuesto = 16;
                DECLARE @xctag1 FLOAT ,
                    @xctag2 FLOAT;
                SET @xctag1 = @TasaImpuesto / 100;
                SET @xctag2 = @xctag1 + 1;
                SELECT  @Precio = ( ( @Importe + @Impuestos ) / @xctag2 )
                INSERT  INTO @T_PartidasVtas
                        ( Articulo ,
                          Precio ,
                          TasaImpuesto
                        )
                VALUES  ( 'V.ESP.GRAVADO' ,
                          @Precio ,
                          @TasaImpuesto
                        );
            END
        ELSE
            BEGIN
                INSERT  INTO @T_PartidasVtas
                        SELECT  T.LOC.value('@Articulo', 'VARCHAR(20)') AS ARTICULO ,  ---- SECOPA-10,SECOPA-15 RENTA UNIDADES
                                T.LOC.value('@Precio', 'FLOAT') AS Precio ,
                                T.LOC.value('@TasaImpuesto', 'MONEY') AS TasaImpuesto  --Tasa 11,16,0
                        FROM    @X_PartidasVtas.nodes('//row/fila') AS T ( LOC );
            END
        IF @MovRelacionados IS NOT NULL
            BEGIN
                INSERT  INTO @T_MovRelacionados
                        SELECT  T.LOC.value('@ID', 'INT') AS ID ,
                                T.LOC.value('@Importe', 'MONEY') AS Importe
                        FROM    @X_MovRelacionados.nodes('//row/fila') AS T ( LOC );
            END
        SELECT  @Unidad = 'Servicio'


        -- *************************************************************************
		--        Validaciones
		-- *************************************************************************

        SELECT  @sError = VE.fn_ValidaInterfaz(@Empresa, @Mov, @FechaEmision, @Concepto, @Moneda, @TipoCambio, @Usuario,
                                               @Cliente, @Sucursal, @Vencimiento, @Importe, @Impuestos, @CentroDeCostos,
                                               @TipoPago);
        											   	
        SELECT  @Almacen = ( CASE WHEN RTRIM(@Empresa) = 'TUN' THEN 'TUN_VE'
                                  WHEN RTRIM(@Empresa) = 'TSL' THEN 'TSL_VE'
                                  ELSE NULL
                             END );
        PRINT 'Resultado de validación General: ' + RTRIM(@sError);
        --********************************************************************
		--        VALIDACIONES POR MOVIMIENTO
		--********************************************************************
        SET @bMovValido = 0;
		/*   ***'CFDI SIN VIAJE GRAV'***   */
        IF ( @Mov IN  ('CFDI SIN VIAJE GRAV', 'INE SIN VIAJE GRAV') )
            BEGIN
                SET @bMovValido = 1;
                --SET @DescripcionExtra = 'SERVICIO DE TRANSPORTE PÚBLICO DE PERSONAS';
                SET @DescripcionExtra = '';
                IF ( @Concepto <> 'VIAJE ESPECIAL GRAVADO' )
                    BEGIN
                        SET @sError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                            + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                    END
            END
        
		/*   ***'Fact Otros Ing Cont***   */
        IF ( @Mov = 'Fact Otros Ing Cont' )
            BEGIN
                SET @bMovValido = 1;
                IF ( @Concepto <> 'ENTRADAS A PARQUES'
                     AND @Concepto <> 'EXTRA PAQUETES'
                   )
                    BEGIN
                        SET @sError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                            + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                    END
                IF ( @Concepto = 'ENTRADAS A PARQUES' )
                    BEGIN
                        SELECT  @Condicion = 'Contado' ,
                                @TasaImpuesto = 16;
                        UPDATE  @T_PartidasVtas
                        SET     Articulo = 'SECOPA-15' ,
                                TasaImpuesto = 16;

                    END
                ELSE
                    BEGIN
                        IF ( @Concepto = 'EXTRA PAQUETES' )
                            BEGIN
                                SELECT  @Condicion = 'Contado' ,
                                        @TasaImpuesto = 16;
                                UPDATE  @T_PartidasVtas
                                SET     Articulo = 'SECOPA-15' ,
                                        TasaImpuesto = 16;
                            END
                    END
            END
          
		/*   ***'FACT.VE.GRAVADO'***   */
        IF ( @Mov IN ( 'FACT.VE.GRAVADO', 'INE VE GRAVADO' ) )
            BEGIN
                SET @bMovValido = 1;
                --SET @DescripcionExtra = 'SERVICIO DE TRANSPORTE PÚBLICO DE PERSONAS';
                SET @DescripcionExtra = '';
                IF ( @Concepto <> 'VIAJE ESPECIAL GRAVADO'
                     AND @Concepto <> 'VIAJES ESPECIALES'
                   )
                    BEGIN
                        SET @sError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                            + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                                        
                    END
            END
        
		/*   ***'FACT.VE.GRAVADO'***   */
        IF ( @Mov = 'Factura TranspInd' )
            BEGIN
                SET @bMovValido = 1;
                --SET @DescripcionExtra = 'TI  SERVICIO DE TRANSPORTE DE PERSONAL';
                SET @DescripcionExtra = '';
                IF ( @Concepto <> 'T.INDUSTRIAL 10%'
                     AND @Concepto <> 'T.INDUSTRIAL 15%'
                   )
                    BEGIN
                        SET @sError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                            + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                                                
                    END
                IF ( @Concepto = 'T.INDUSTRIAL 10%' )
                    BEGIN
                        SELECT  @Condicion = 'Credito' ,
                                @Impuesto1 = 11;
                        UPDATE  @T_PartidasVtas
                        SET     Articulo = 'TI-10' ,
                                TasaImpuesto = 11;
                    END
                ELSE
                    IF ( @Concepto = 'T.INDUSTRIAL 15%' )
                        BEGIN
                            SELECT  @Condicion = 'Credito' ,
                                    @Impuesto1 = 16;
                            UPDATE  @T_PartidasVtas
                            SET     Articulo = 'TI-15' ,
                                    TasaImpuesto = 16;
                        END
            END
			
		/*   ***'Devolucion Turismo'***   */
        IF ( @Mov = 'Devolucion Turismo' )
            BEGIN
                SET @bMovValido = 1;
                SELECT  @Condicion = 'Contado';
                --SET @DescripcionExtra = 'SERVICIO DE TRANSPORTE PÚBLICO DE PERSONAS';
                SET @DescripcionExtra = '';
                IF ( @Concepto <> 'DEV/SOBRE VENTAS DE VIAJES ESPECIALES' )
                    BEGIN
                        SET @sError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                            + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                                        
                    END
            END

		/*   ***FACTURA DE VENTA GENERAL***   */
        IF ( @Mov IN ( 'Factura VE Total', 'Ingreso Paquetes', 'INE VE TOTAL' ) )
            BEGIN
                SET @bMovValido = 1;
                IF ( @Mov IN ( 'Factura VE Total', 'INE VE TOTAL' )
                     AND @Concepto <> 'VIAJES ESPECIALES'
                   )
                    OR ( @Mov = 'Ingreso Paquetes'
                         AND @Concepto NOT IN ( 'PAQUETE PROMOCION GRAVADA' )
                       )
                    BEGIN
                        SET @sError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                            + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                                        
                    END

                SET @DescripcionExtra = '';
                IF NOT EXISTS ( SELECT  ID
                                FROM    @T_MovRelacionados )
                    BEGIN
                        SET @sError = 'No indico ningún anticipo. Por favor, indique al menos un anticipo valido.';
                    END
                ELSE
                    BEGIN
						/* Tabla para validar anticipos*/
                        INSERT  INTO @T_ComparacionAnticipos
                                SELECT  aID = B.ID ,
                                        aimporte = B.Importe ,
                                        CxcID = C.ID ,
                                        Diferencia = ISNULL(C.Saldo, 0) - B.Importe ,
                                        Mov = C.Mov ,
                                        MovID = C.MovID ,
                                        Cliente = C.Cliente ,
                                        Estatus = C.Estatus
                                FROM    @T_MovRelacionados AS B
                                        LEFT JOIN Cxc AS C ON B.ID = C.ID;
                        IF EXISTS ( SELECT  CxcID
                                    FROM    @T_ComparacionAnticipos
                                    WHERE   CxcID IS NULL )
                            BEGIN
                                SET @sError = 'Uno o mas identificadores de anticipos indicados, no fueron encontrados (IDs no encontrados ';
                                SET @sError = @sError + ( SELECT TOP 1
                                                                    ( SELECT    CAST(T2.aID AS VARCHAR) + ', '
                                                                      FROM      @T_ComparacionAnticipos AS T2
                                                                      WHERE     T2.CxcID IS NULL
                                                                      ORDER BY  T2.aID
                                                                    FOR
                                                                      XML PATH('')
                                                                    ) AS IDs
                                                          FROM      @T_ComparacionAnticipos AS T1
                                                        );
                                SET @sError = SUBSTRING(@sError, 1, LEN(@sError) - 1);
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlos.';
                            END
                        IF EXISTS ( SELECT  A.Cliente
                                    FROM    @T_ComparacionAnticipos AS A
                                    WHERE   A.Cliente <> @Cliente )
                            BEGIN
                                SET @sError = 'Uno o mas anticipos, no le corresponden al cliente indicado (IDs que no corresponden ';
                                SET @sError = @sError + ( SELECT TOP 1
                                                                    ( SELECT    CAST(T2.aID AS VARCHAR) + ', '
                                                                      FROM      @T_ComparacionAnticipos AS T2
                                                                      WHERE     T2.Cliente <> @Cliente
                                                                      ORDER BY  T2.aID
                                                                    FOR
                                                                      XML PATH('')
                                                                    ) AS IDs
                                                          FROM      @T_ComparacionAnticipos AS T1
                                                        );
                                SET @sError = SUBSTRING(@sError, 1, LEN(@sError) - 1);
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlos.';
                            END
                        IF EXISTS ( SELECT  A.Estatus
                                    FROM    @T_ComparacionAnticipos AS A
                                    WHERE   A.Estatus <> 'PENDIENTE' )
                            BEGIN
                                SET @sError = 'Uno o mas anticipos, ya no estan en Estatus PENDIENTE (IDs que no estan pendientes ';
                                SET @sError = @sError + ( SELECT TOP 1
                                                                    ( SELECT    CAST(T2.aID AS VARCHAR) + ', '
                                                                      FROM      @T_ComparacionAnticipos AS T2
                                                                      WHERE     T2.Estatus <> 'PENDIENTE'
                                                                      ORDER BY  T2.aID
                                                                    FOR
                                                                      XML PATH('')
                                                                    ) AS IDs
                                                          FROM      @T_ComparacionAnticipos AS T1
                                                        );
                                SET @sError = SUBSTRING(@sError, 1, LEN(@sError) - 1);
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlos.';
			
                            END
		
                        IF EXISTS ( SELECT  A.Diferencia
                                    FROM    @T_ComparacionAnticipos AS A
                                    WHERE   A.Diferencia < 0 )
                            BEGIN
                                SET @sError = 'El importe de uno o mas anticipos, no corresponde con los saldos (IDs que no coinciden ';
                                SET @sError = @sError + ( SELECT TOP 1
                                                                    ( SELECT    CAST(T2.aID AS VARCHAR) + ', '
                                                                      FROM      @T_ComparacionAnticipos AS T2
                                                                      WHERE     T2.Diferencia < 0
                                                                      ORDER BY  T2.aID
                                                                    FOR
                                                                      XML PATH('')
                                                                    ) AS IDs
                                                          FROM      @T_ComparacionAnticipos AS T1
                                                        );
                                SET @sError = SUBSTRING(@sError, 1, LEN(@sError) - 1);
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlos.';
                            END

                    END
				
            END
         
         --    ***    'NO HAY UN MOV VALIDO' ***
        IF @bMovValido = 0
            BEGIN
                SET @sError = 'Mov no valido. El movimiento no se encuentra entre los movimientos esperados. '
                    + 'Por favor, indique un Movimiento valido.';
            END
        PRINT 'Resultado de validación por movimiento: ' + RTRIM(@sError);
        IF @sError <> 'Ok'
            BEGIN
                EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error de Validación', @sError, @Usuario,
                    @LogParametrosXml;
                RAISERROR(@sError,16,1);
                RETURN;
            END
        IF NOT EXISTS ( SELECT  ClaveUsoCFDI
                        FROM    dbo.CteCFD
                        WHERE   Cliente = @Cliente )
            BEGIN
                PRINT 'Insertar registro de Clave Uso CFDI';
                INSERT  INTO dbo.CteCFD
                        ( Cliente, ClaveUsoCFDI )
                VALUES  ( @Cliente, -- Cliente - char(10)
                          'G03'  -- ClaveUsoCFDI - varchar(3)
                          );	
            END
        ELSE
            BEGIN
                IF ( SELECT ClaveUsoCFDI
                     FROM   dbo.CteCFD
                     WHERE  Cliente = @Cliente
                   ) IS NULL
                    BEGIN
                        PRINT 'Actualizando registro de Clave Uso CFDI'
                        UPDATE  CteCFD
                        SET     ClaveUsoCFDI = 'G03'
                        WHERE   Cliente = @Cliente;	
                    END
            END
        --********************************************************************
		--        PROCESO
		--********************************************************************

        IF ( @Condicion = 'Contado' )
            BEGIN
                PRINT 'Se ajusta la fecha de vencimiento, cuando este es de contado';
                SELECT  @Vencimiento = @FechaEmision;
            END
		--********************************************************************
		--        Cambiar Metodo de Pago en casos especiales
		--********************************************************************
		
        SELECT TOP 1
                @TipoPago = ISNULL(ccf.sTipoPago, @TipoPago) ,
                @sreferencia = ccf.sReferencia ,
                @Unidad = ISNULL(ccf.sUnidad, @Unidad)
        FROM    VE.cnfCteFacturas ccf
        WHERE   ccf.sCliente = RTRIM(@Cliente)
                AND ccf.iSucursal = ISNULL(@Sucursal, 0)
                AND ccf.isActivo = 1
                AND ccf.sRama = 'VTA'
                AND ccf.dInicio <= @FechaEmision
                AND ccf.dFin >= @FechaEmision
        ORDER BY ccf.dAlta DESC;
		
		/* Validación de CODIGO*/
        IF NOT EXISTS ( SELECT  v.Codigo
                        FROM    dbo.Venta v
                        WHERE   v.Codigo = @Codigo
                                AND v.Mov = @Mov
                                AND v.Estatus IN ( 'CONCLUIDO', 'SINAFECTAR' ) )
            OR @Codigo IS NULL
            BEGIN
                PRINT 'Se inserta registro nuevo en Vtas';
		/* INSERTAR REGISTRO EN VENTA*/
                INSERT  INTO dbo.Venta
                        ( Empresa ,
                          Mov ,
                          FechaEmision ,
                          UltimoCambio ,
                          Concepto ,
                          Moneda ,
                          TipoCambio ,
                          Usuario ,
                          Sucursal ,
                          Referencia ,
                          Observaciones ,
                          Estatus ,
                          Prioridad ,
                          RenglonID ,
                          Cliente ,
                          EnviarA ,
                          Almacen ,
                          FechaRequerida ,
                          Condicion ,
                          Vencimiento ,
                          Importe ,
                          Impuestos ,
                          ContUso ,
                          Comentarios ,
                          FormaPagoTipo ,
                          Codigo
		                )
                VALUES  ( @Empresa , -- Empresa - char(5)
                          @Mov , -- Mov - char(20)
                          dbo.Fn_QuitarHrsMin(@FechaEmision) , -- FechaEmision - datetime
                          GETDATE() , -- UltimoCambio - datetime
                          @Concepto , -- Concepto - varchar(50)
                          @Moneda , -- Moneda - char(10)
                          @TipoCambio , -- TipoCambio - float
                          @Usuario , -- Usuario - char(10)
                          0 , --TUN y TSL sucursal 0 
                          @Referencia , -- Referencia - varchar(50)
                          @Observaciones , -- Observaciones - varchar(100)
                          'SINAFECTAR' , -- Estatus - char(15)
                          'Normal' , -- Prioridad - char(10)
                          1 , -- RenglonID - int
                          @Cliente , -- Cliente - char(10)
                          @Sucursal , -- EnviarA - int
                          @Almacen , -- Almacen - char(10)
                          @FechaEmision , -- FechaRequerida - datetime
                          @Condicion ,
                          @Vencimiento ,
                          @Importe , -- Importe - money
                          @Impuestos , -- Impuestos - money
                          @CentroDeCostos , -- ContUso - varchar(20)
                          @Comentarios ,
                          @TipoPago ,
                          @Codigo
		                );
                SET @RegresoID = SCOPE_IDENTITY();

		/* INSERTAR DETALLE VENTAD*/
                PRINT 'Se inserta detalle de VTAS ID= ' + CAST(@RegresoID AS VARCHAR) + ' Mov= ' + RTRIM(@Mov);

                INSERT  INTO dbo.VentaD
                        ( ID ,
                          Renglon ,
                          RenglonSub ,
                          RenglonID ,
                          RenglonTipo ,
                          Cantidad ,
                          Almacen ,
                          Articulo ,
                          SubCuenta ,
                          Precio ,
                          PrecioSugerido ,
                          Impuesto1 ,
                          Impuesto2 ,
                          Impuesto3 ,
                          DescripcionExtra ,
                          Costo ,
                          ContUso ,
                          Unidad ,
                          Factor ,
                          FechaRequerida ,
                          Sucursal ,
                          SucursalOrigen ,
                          PrecioMoneda ,
                          PrecioTipoCambio
				        )
                        SELECT  @RegresoID , -- ID - int
                                2048 * tpv.Consecutivo , -- Renglon - float
                                0 , -- RenglonSub - int
                                1 , -- RenglonID - int
                                'N' , -- RenglonTipo - char(1)
                                1.0 , -- Cantidad - float
                                @Almacen , -- Almacen - char(10)
                                tpv.Articulo , -- Articulo - char(20)
                                NULL , -- SubCuenta - varchar(50)
                                tpv.Precio , -- Precio - float
                                0.0 , -- PrecioSugerido - float
                                tpv.TasaImpuesto , -- Impuesto1 - float
                                0.0 , -- Impuesto2 - float
                                0.0 , -- Impuesto3 - float
                                @DescripcionExtra , -- DescripcionExtra - varchar(100)
                                0 , -- Costo - money
                                @CentroDeCostos , -- ContUso - varchar(20)
                                @Unidad , -- Unidad - varchar(50)
                                1.0 , -- Factor - float
                                @FechaEmision , -- FechaRequerida - datetime
                                0 , -- Sucursal - int
                                0 , -- SucursalOrigen - int
                                @Moneda , -- PrecioMoneda - varchar(10)
                                @TipoCambio  -- PrecioTipoCambio - float
                        FROM    @T_PartidasVtas tpv;
				 
                IF @Condicion = 'Contado'
                    BEGIN
                        INSERT  INTO VentaCobro
                                ( ID ,
                                  Importe1 ,
                                  Vencimiento ,
                                  SucursalOrigen ,
                                  FormaCobro1
                                )
                                SELECT  @RegresoID ,
                                        @Importe + @Impuestos ,
                                        @Vencimiento ,
                                        0 , -- SucursalOrigen'
                                        @TipoPago;
                    END
                IF ( @sreferencia IS NOT NULL
                     AND @Condicion = 'Credito'
                   )
                    BEGIN
                        INSERT  INTO VentaCobro
                                ( ID ,
                                  Importe1 ,
                                  Vencimiento ,
                                  SucursalOrigen ,
                                  FormaCobro1 ,
                                  Referencia1
						        )
                                SELECT  @RegresoID ,
                                        @Importe + @Impuestos ,
                                        @Vencimiento ,
                                        0 , -- SucursalOrigen'
                                        @TipoPago ,
                                        @sreferencia;
                    END
                IF @Mov IN ( 'Factura VE Total', 'Ingreso Paquetes', 'INE VE TOTAL' )
                    BEGIN
                        PRINT 'Relacionando las facturas de anticipo'
                        INSERT  INTO dbo.VentaOrigenDevolucion
                                ( Empresa ,
                                  Modulo ,
                                  Id ,
                                  ModuloOrigen ,
                                  IdOrigen ,
                                  MovOrigen ,
                                  MovIDOrigen ,
                                  ClaveTipoRelacion
						        )
                                SELECT  @Empresa ,
                                        'VTAS' ,
                                        @RegresoID ,
                                        'CXC' ,
                                        c.ID ,
                                        c.Mov ,
                                        c.MovID ,
                                        '07' --Tipo Relación
                                FROM    dbo.Cxc c
                                        INNER JOIN @T_MovRelacionados ta ON ta.ID = c.ID
                    END
                IF @Mov IN ( 'Devolucion Turismo' )
                    BEGIN
                        PRINT 'Relacionando la factura de venta'
                        DECLARE @RamaMov AS CHAR(5);
                        IF @Codigo IN ( '7546-698-DEVO' )
                            BEGIN
                                SET @RamaMov = 'CXC';
                            END
                        ELSE
                            BEGIN
                                SET @RamaMov = 'VTAS';
                            END
                        INSERT  INTO dbo.VentaOrigenDevolucion
                                ( Empresa ,
                                  Modulo ,
                                  Id ,
                                  ModuloOrigen ,
                                  IdOrigen ,
                                  MovOrigen ,
                                  MovIDOrigen
						        )
                                SELECT  @Empresa ,
                                        'VTAS' ,
                                        @RegresoID ,
                                        @RamaMov ,
                                        v.ID ,
                                        v.Mov ,
                                        v.MovID
                                FROM    dbo.Venta v
                                        INNER JOIN @T_MovRelacionados ta ON ta.ID = v.ID
                    END
            END
        ELSE
            BEGIN
                SELECT TOP 1
                        @RegresoID = v.ID
                FROM    dbo.Venta v
                WHERE   v.Codigo = @Codigo
                        AND v.Mov = @Mov
                        AND v.Estatus IN ( 'CONCLUIDO', 'SINAFECTAR' )
                ORDER BY v.FechaRegistro DESC

                PRINT 'Ya existe en VTAS ID= ' + CAST(@RegresoID AS VARCHAR) + ' ' + RTRIM(@Mov);
            END
        
	--********************************************************************
    --        AFECTAR
    --********************************************************************
        IF EXISTS ( SELECT  v.Codigo
                    FROM    dbo.Venta v
                    WHERE   v.Codigo = @Codigo
                            AND v.Mov = @Mov
                            AND v.Estatus = 'SINAFECTAR' )
            OR @Codigo IS NULL
            BEGIN
    
                BEGIN TRY
                    PRINT 'Afectando VTAS ID= ' + CAST(@RegresoID AS VARCHAR) + ' ' + RTRIM(@Mov);
                    EXEC spAfectar 'VTAS', @RegresoID, 'AFECTAR', 'Todo', NULL, @Usuario, NULL, 1, @iError OUTPUT,
                        @sError OUTPUT;

                    PRINT 'Retorno SPAfectar: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));

                    SELECT  @sError = ml.Descripcion
                    FROM    dbo.MensajeLista ml
                    WHERE   ml.Mensaje = @iError;

                    PRINT 'Codigo de Resultado: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));

                END TRY
            
                BEGIN CATCH
                    SELECT  --@iError = ERROR_NUMBER() ,
                            @sError = '(sp ' + ISNULL(ERROR_PROCEDURE(), '') + ', ln '
                            + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(), '');
                END CATCH
            
                IF EXISTS ( SELECT  Estatus
                            FROM    Venta
                            WHERE   ID = @RegresoID
                                    AND Estatus = 'SINAFECTAR' )
                    BEGIN
                        SET @sError = 'Error al aplicar el movimiento de Intelisis: ' + 'Error = '
                            + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ISNULL(( SELECT   ' - ' + RTRIM(Descripcion)
                                                                                   FROM     dbo.MensajeLista
                                                                                   WHERE    Mensaje = @iError
                                                                                 ), '') + ', Mensaje = '
                            + ISNULL(@sError, '') + ',Movimiento SIN AFECTAR, intente nuevamente';
                        EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error', @sError, @Usuario,
                            @LogParametrosXml;
                        RAISERROR(@sError,16,1);
                        RETURN;
                    END
            END
        SET @sError = NULL;
        IF EXISTS ( SELECT  v.CFDFlexEstatus
                    FROM    MovTipo mt
                            JOIN dbo.Venta v ON v.Mov = mt.Mov
                                                AND v.Estatus = mt.eDocEstatus
                    WHERE   mt.CFDFlex = 1
                            AND mt.Modulo = 'VTAS'
                            AND v.CFDFlexEstatus <> 'CONCLUIDO'
                            AND v.Estatus = 'CONCLUIDO'
                            AND v.ID = @RegresoID )
            BEGIN
                BEGIN TRY
                    PRINT 'Generando CFDI de VTAS ID= ' + CAST(@RegresoID AS VARCHAR) + ' ' + RTRIM(@Mov);
                
                    EXEC dbo.spCFDFlex @Estacion = 881, @Empresa = @Empresa, @Modulo = 'VTAS', @ID = @RegresoID,
                        @Estatus = 'CONCLUIDO', @Ok = @iError OUTPUT, @OkRef = @sError OUTPUT;

                    SET @sError = 'Resultado de Timbrado :' + RTRIM(ISNULL(CAST(@iError AS INT), 0)) + ' '
                        + RTRIM(ISNULL(@sError, 'CONCLUIDO'));
                    PRINT @sError;

                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Timbrado CFDI', @sError, @Usuario,
                        @LogParametrosXml;
                END TRY
                BEGIN CATCH
                    SELECT  @iError = ERROR_NUMBER() ,
                            @sError = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') '
                            + ERROR_MESSAGE();
                END CATCH
                IF ( SELECT ISNULL(CFDFlexEstatus, '')
                     FROM   dbo.Venta
                     WHERE  ID = @RegresoID
                   ) <> 'CONCLUIDO'
                    BEGIN
                        SET @sError = 'Error al timbrar el movimiento de Intelisis: ' + 'Error = '
                            + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                            + '. Intente nuevamente.';
                        EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error', @sError, @Usuario, @LogParametrosXml;
                        RAISERROR(@sError,16,1);
                        --RETURN;
                    END
                ELSE
                    BEGIN
                        SET @sError = NULL;
                    END
            END
        
	--********************************************************************
    --        INFORMACION DE RETORNO
    --********************************************************************
        SELECT  v.ID ,
                v.MovID ,
                v.Estatus ,
                CASE WHEN c.UUID = NULL THEN RTRIM(ISNULL(@sError, ''))
                     ELSE RTRIM(v.CFDFlexEstatus)
                END AS CFDFlexEstatus ,
                CAST(c.Documento AS VARCHAR(MAX)) AS CFDxml ,
                c.noCertificado ,
                c.Sello ,
                c.SelloSAT ,
                c.TFDCadenaOriginal ,
                c.UUID ,
                c.FechaTimbrado ,
                c.noCertificadoSAT
        FROM    dbo.Venta v
                LEFT JOIN dbo.CFD c ON c.Modulo = 'VTAS'
                                       AND c.ModuloID = v.ID
        WHERE   v.ID = @RegresoID;
        
        SELECT  @ID = v.ID ,
                @MovID = v.MovID ,
                @Estatus = v.Estatus ,
                @CFDFlexEstatus = CASE WHEN c.UUID = NULL THEN RTRIM(ISNULL(@sError, ''))
                                       ELSE RTRIM(v.CFDFlexEstatus)
                                  END ,
                @CFDxml = CAST(c.Documento AS VARCHAR(MAX)) ,
                @noCertificado = c.noCertificado ,
                @Sello = c.Sello ,
                @SelloSAT = c.SelloSAT ,
                @TFDCadenaOriginal = c.TFDCadenaOriginal ,
                @UUID = c.UUID ,
                @FechaTimbrado = c.FechaTimbrado ,
                @noCertificadoSAT = c.noCertificadoSAT
        FROM    dbo.Venta v
                LEFT JOIN dbo.CFD c ON c.Modulo = 'VTAS'
                                       AND c.ModuloID = v.ID
        WHERE   v.ID = @RegresoID;	
    END

GO
GRANT EXECUTE ON  [dbo].[Interfaz_VentasInsertar] TO [Linked_Svam_Pruebas]
GO
