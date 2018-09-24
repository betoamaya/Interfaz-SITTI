SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	16/04/2018
-- Descripción:		Aplicación de Anticipos
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_CxcAplicacionDeIngresos]
    @Empresa CHAR(5) ,
    @Mov CHAR(20) ,
    @FechaEmision SMALLDATETIME ,
    @Concepto VARCHAR(50) ,
    @Moneda CHAR(10) ,
    @TipoCambio FLOAT ,
    @Usuario CHAR(10) ,
    @Codigo AS VARCHAR(30) ,
    @Referencia VARCHAR(50) ,
    @Cliente CHAR(10) ,
    @Sucursal INT = NULL ,
    @Importe MONEY ,
    @Impuestos MONEY ,
    @CentroDeCostos VARCHAR(20) ,
    @Observaciones VARCHAR(100) ,
    @Comentarios VARCHAR(MAX) ,
    @Anticipos VARCHAR(MAX) = NULL ,
    @PartidasVtas VARCHAR(MAX) = NULL ,
    @ID AS INT = NULL OUTPUT ,
    @MovID AS VARCHAR(MAX) = NULL OUTPUT ,
    @Estatus AS CHAR(15) = NULL OUTPUT ,
    @CFDFlexEstatus AS VARCHAR(15) = NULL OUTPUT ,
    @CFDXml AS VARCHAR(MAX) = NULL OUTPUT ,
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
--		VARIABLES 
--********************************************************************

	-- Se crea y se genera Xml con los parametros para tabla Interfaz_Logs 
        DECLARE @iError AS INT ,
            @sError AS VARCHAR(MAX) ,
            @Aplica AS CHAR(20) ,
            @AplicaMovID AS VARCHAR(20) ,
            @AplicaID AS INT ,
            @RegresoID INT ,				--ID creado
            @RegresoMov VARCHAR(20) ,	--Tipo Mov
            @RegresoMovID VARCHAR(20) ,
            @CxcID AS INT ,
            @sEstatus AS VARCHAR(15) ,
            @LogParametrosXml AS XML;

        SET @LogParametrosXml = ( SELECT    @Empresa AS 'Empresa' ,
                                            @Mov AS 'Mov' ,
                                            @FechaEmision AS 'FechaEmision' ,
                                            @Concepto AS 'Concepto' ,
                                            @Moneda AS 'Moneda' ,
                                            @TipoCambio AS 'TipoCambio' ,
                                            @Usuario AS 'Usuario' ,
                                            @Codigo AS 'Codigo' ,
                                            @Referencia AS 'Referencia' ,
                                            @Cliente AS 'Cliente' ,
                                            @Sucursal AS 'Sucursal' ,
                                            @Importe AS 'Importe' ,
                                            @Impuestos AS 'Impuestos' ,
                                            @CentroDeCostos AS 'CentroDeCostos' ,
                                            @Observaciones AS 'Observaciones' ,
                                            @Comentarios AS 'Comentarios' ,
                                            @Anticipos AS 'Anticipos' ,
                                            @PartidasVtas AS 'PartidasVtas'
                                FOR
                                  XML PATH('Parametros')
                                );
	-- Se carga Interfaz_Logs
        EXEC Interfaz_LogsInsertar 'Interfaz_CxcAplicacionDeIngresos', 'Ejecución', '', @Usuario, @LogParametrosXml;

        DECLARE @T_Anticipos AS TABLE
            (
              ID INT NOT NULL ,
              Importe MONEY
            )

        DECLARE @T_Partidas TABLE
            (
              Consecutivo INT IDENTITY(1, 1)
                              NOT NULL ,
              --Importe MONEY ,
              Aplica CHAR(20) ,
              AplicaMovID VARCHAR(20) ,
              AplicaID INT
            );

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

        DECLARE @X_Anticipos XML
        SET @X_Anticipos = CAST(@Anticipos AS XML);

        DECLARE @X_PartidasVtas XML
        SET @X_PartidasVtas = CAST(@PartidasVtas AS XML);

        IF NOT @Anticipos IS NULL
            BEGIN
                INSERT  INTO @T_Anticipos
                        SELECT  T.LOC.value('@ID', 'INT') AS ID ,
                                T.LOC.value('@Importe', 'MONEY') AS Importe
                        FROM    @X_Anticipos.nodes('//row/fila') AS T ( LOC );
            END
	
        IF NOT @PartidasVtas IS NULL
            BEGIN
                INSERT  INTO @T_Partidas
                        SELECT  --T.LOC.value('@Importe', 'MONEY') AS Importe ,
                                T.LOC.value('@Aplica', 'CHAR(20)') AS Aplica ,
                                T.LOC.value('@AplicaMovID', 'VARCHAR(20)') AS AplicaMovID ,
                                T.LOC.value('@AplicaID', 'INT') AS AplicaMovID
                        FROM    @X_PartidasVtas.nodes('//row/fila') AS T ( LOC );
                SELECT TOP 1
                        @Aplica = Aplica ,
                        @AplicaMovID = @AplicaMovID ,
                        @AplicaID = AplicaID
                FROM    @T_Partidas;
            END;

--********************************************************************
--		VALIDACIONES 
--********************************************************************
		/* Validaciones Comunes*/
        IF NOT EXISTS ( SELECT  c.ID
                        FROM    dbo.Cxc c
                        WHERE   c.Codigo = @Codigo
                                AND c.Mov = @Mov
                                AND c.Estatus IN ( 'CONCLUIDO', 'SINAFECTAR', 'PENDIENTE' ) )
            BEGIN
                SELECT  @sError = VE.fn_ValidaInterfaz(@Empresa, @Mov, @FechaEmision, @Concepto, @Moneda, @TipoCambio,
                                                       @Usuario, @Cliente, @Sucursal, GETDATE(), @Importe, @Impuestos,
                                                       @CentroDeCostos, 'Hard');
                PRINT 'Resultado de validación General: ' + RTRIM(@sError);
                IF @Mov <> 'CFDi APLIC GRAVADA'
                    BEGIN
                        SET @sError = 'Movimiento no valido. El movimiento no se encuentra entre los movimientos esperados. ';
                    END
                IF @Concepto NOT IN ( 'VIAJE ESPECIAL GRAVADO', 'ANTICIPO CFDI GRAVADO VE', 'CFD VIAJES COBRADOS X ANT.',
                                      'VIAJES COBRADOS POR ANTICIPADO' )
                    OR @Usuario <> 'SITTI'
                    BEGIN
                        SET @sError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                            + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                    END
                IF NOT EXISTS ( SELECT  *
                                FROM    @T_Partidas )
                    BEGIN
                        SET @sError = 'No indico ningún partida. Por favor, indique una partida valida.';
                    END
                ELSE
                    BEGIN
                        IF NOT EXISTS ( SELECT  v.ID
                                        FROM    dbo.Venta v
                                                INNER JOIN @T_Partidas ta ON ta.AplicaID = v.ID
                                                                             AND ta.Aplica = v.Mov
                                                                             AND ta.AplicaMovID = v.MovID )
                            BEGIN
                                SET @sError = 'El factura a aplicar no fue encontrado. Por favor, indique una factura valida.';
                            END
                        IF NOT EXISTS ( SELECT  c.Saldo
                                        FROM    dbo.Cxc c
                                                INNER JOIN @T_Partidas ta ON ta.Aplica = c.Mov
                                                                             AND ta.AplicaMovID = c.MovID )
                            BEGIN
                                SET @sError = 'El saldo de la factura a aplicar no corresponde al importe dle movimeinto. Por favor, indique una factura valida.';
                            END
                    END

                IF NOT EXISTS ( SELECT  *
                                FROM    @T_Anticipos )
                    BEGIN
                        SET @sError = 'No indico ningún anticipo. Por favor, indique un anticipo valido.';
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
                                FROM    @T_Anticipos AS B
                                        LEFT JOIN Cxc AS C ON B.ID = C.ID;
                        IF ( SELECT COUNT (*) FROM @T_Anticipos
                           ) > 1
                            BEGIN
                                SET @sError = 'Solo se puede indicar un anticipos. Favor de verificar.';
                            END
                        IF ( SELECT c.Saldo
                             FROM   dbo.Cxc c
                                    INNER JOIN @T_Anticipos ta ON ta.ID = c.ID
                           ) < @Importe
                            --OR ( SELECT pv.Importe
                            --     FROM   @T_Partidas pv
                            --   ) <> @Importe
                            BEGIN
                                SET @sError = 'El importe a aplicar es mayor al saldo del Movimiento. Intente nuevamente.'
                            END
                        IF EXISTS ( SELECT  CxcID
                                    FROM    @T_ComparacionAnticipos
                                    WHERE   CxcID IS NULL )
                            BEGIN
                                SET @sError = 'El anticipo indicado, no fue encontrado (ID ';
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
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlo.';
                            END
                        IF EXISTS ( SELECT  A.Cliente
                                    FROM    @T_ComparacionAnticipos AS A
                                    WHERE   A.Cliente <> @Cliente )
                            BEGIN
                                SET @sError = 'El anticipo no le corresponden al cliente indicado (ID que no corresponde ';
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
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlo.';
                            END
                        IF EXISTS ( SELECT  A.Estatus
                                    FROM    @T_ComparacionAnticipos AS A
                                    WHERE   A.Estatus <> 'PENDIENTE' )
                            BEGIN
                                SET @sError = 'El anticipo, ya no esta en Estatus PENDIENTE (ID que no esta pendiente ';
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
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlo.';
			
                            END
		
                        IF EXISTS ( SELECT  A.Diferencia
                                    FROM    @T_ComparacionAnticipos AS A
                                    WHERE   A.Diferencia < 0 )
                            BEGIN
                                SET @sError = 'El importe del anticipo, no corresponde con el saldo (ID que no coincide ';
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
                                SET @sError = RTRIM(@sError) + '). Favor de verificarlo.';
                            END

                    END
                PRINT 'Resultado de validación por movimiento: ' + RTRIM(@sError);
                IF @sError <> 'Ok'
                    BEGIN
                        EXEC Interfaz_LogsInsertar 'Interfaz_CxcAplicacionDeIngresos', 'Error de Validación', @sError,
                            @Usuario, @LogParametrosXml;
                        RAISERROR(@sError,16,1);
                        RETURN;
                    END
                --SELECT  *
                --FROM    @T_ComparacionAnticipos
                --SELECT  *
                --FROM    @T_Partidas;
                --RAISERROR(@sError,16,1);
                --RETURN;
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
--		PROCESO 
--********************************************************************
		--Se obtiene el movimiento de CXC de la factura de Anticipos
                SELECT  @RegresoID = MAX(T1.DID) ,
                        @RegresoMov = MAX(T1.DMov) ,
                        @RegresoMovID = MAX(T1.OMovID)
                FROM    MovFlujo AS T1
                WHERE   T1.OID = @AplicaID
                        AND T1.OModulo = 'VTAS'
                        AND T1.DModulo = 'CXC'
                        AND T1.Cancelado = 0;

                PRINT 'Flujo del movimiento en Cxc ' + RTRIM(CAST(@RegresoID AS VARCHAR)) + ' ' + RTRIM(@RegresoMov)
                    + ' ' + RTRIM(@RegresoMovID);

		--Se inserta el nuevo registro
                INSERT  INTO Cxc
                        ( Empresa ,
                          Mov ,
                          FechaEmision ,
                          UltimoCambio ,
                          Concepto ,
                          Moneda ,
                          TipoCambio ,
                          Usuario ,
                          Referencia ,
                          Estatus ,
                          Cliente ,
                          ClienteEnviarA ,
                          Vencimiento ,
                          FormaCobro ,
                          Importe ,
                          Impuestos ,
                          AplicaManual ,
                          ConDesglose ,
                          ContUso ,
                          Observaciones ,
                          Comentarios ,
                          ClienteMoneda ,
                          ClienteTipoCambio ,
                          MovAplica ,
                          MovAplicaID ,
                          Codigo
				        )
                        SELECT TOP 1
                                @Empresa ,
                                @Mov ,
                                dbo.Fn_QuitarHrsMin(@FechaEmision) ,
                                GETDATE() ,
                                @Concepto ,
                                @Moneda ,
                                @TipoCambio ,
                                @Usuario ,
                                @Referencia ,
                                'SINAFECTAR' ,
                                @Cliente ,
                                @Sucursal ,
                                NULL ,
                                'Efectivo' ,
                                @Importe ,
                                @Impuestos ,
                                1 ,
                                0 ,
                                @CentroDeCostos ,
                                @Observaciones ,
                                @Comentarios ,
                                @Moneda ,
                                @TipoCambio ,
                                c.Mov ,
                                c.MovID ,
                                @Codigo
                        FROM    @T_Anticipos ta
                                INNER JOIN dbo.Cxc c ON c.ID = ta.ID

                SET @CxcID = SCOPE_IDENTITY();

                PRINT 'Registro Insertado en Cxc ID= ' + RTRIM(CAST(@CxcID AS VARCHAR));

                INSERT  INTO CxcD
                        ( ID ,
                          Renglon ,
                          RenglonSub ,
                          Importe ,
                          Aplica ,
                          AplicaID
				        )
                VALUES  ( @CxcID ,
                          2048 ,
                          0 ,
                          @Importe ,
                          @RegresoMov ,
                          @RegresoMovID
				        );
            END
        ELSE
            BEGIN
                SELECT TOP 1
                        @CxcID = c.ID
                FROM    dbo.Cxc c
                WHERE   c.Codigo = @Codigo
                        AND c.Mov = @Mov
                        AND c.Estatus IN ( 'CONCLUIDO', 'SINAFECTAR', 'PENDIENTE' )
                ORDER BY c.FechaRegistro DESC

                PRINT 'Ya existe en Cxc ID= ' + CAST(@CxcID AS VARCHAR) + ' ' + RTRIM(@Mov) + ' con el codigo '
                    + RTRIM(@Codigo);
            END
		        


--********************************************************************
--		AFECTAR
--********************************************************************
        IF EXISTS ( SELECT  c.Codigo
                    FROM    dbo.Cxc c
                    WHERE   c.Codigo = @Codigo
                            AND c.Mov = @Mov
                            AND c.Estatus = 'SINAFECTAR' )
            BEGIN
                BEGIN TRY
                    PRINT 'Afectando Cxc ID= ' + CAST(@CxcID AS VARCHAR) + ' ' + RTRIM(@Mov);

                    EXEC spAfectar 'CXC', @CxcID, 'AFECTAR', 'Todo', NULL, @Usuario, NULL, 1, @iError OUTPUT,
                        @sError OUTPUT;

                    PRINT 'Retorno SPAfectar: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));

                    SELECT  @sError = ml.Descripcion
                    FROM    dbo.MensajeLista ml
                    WHERE   ml.Mensaje = @iError;

                    PRINT 'Codigo de Resultado: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));
                END TRY
	
                BEGIN CATCH
                    SELECT  @iError = ERROR_NUMBER() ,
                            @sError = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') '
                            + ERROR_MESSAGE();
                END CATCH
                IF ( SELECT A.Estatus FROM Cxc AS A WHERE A.ID = @CxcID
                   ) = 'SINAFECTAR'
                    BEGIN
                        IF ( ISNULL(@sError, '') = '' )
                            BEGIN
                                SELECT  @sError = RTRIM(ISNULL(ml.Descripcion, ''))
                                FROM    dbo.MensajeLista AS ml
                                WHERE   ml.Mensaje = @iError;
                            END
                        SET @sError = 'Error al aplicar el movimiento de Intelisis: ' + 'Error = '
                            + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                            + '. Intente nuevamente.';
                        EXEC Interfaz_LogsInsertar 'Interfaz_CxcAplicacionDeIngresos', 'Error', @sError, @Usuario,
                            @LogParametrosXml;
                        RAISERROR(@sError,16,1);
                        RETURN;
                    END
            END
        SET @sError = NULL;

        SELECT  @sEstatus = c.Estatus
        FROM    dbo.Cxc c
        WHERE   c.ID = @CxcID;

        --IF EXISTS ( SELECT  c.CFDFlexEstatus
        --            FROM    MovTipo mt
        --                    JOIN Cxc c ON c.Mov = mt.Mov
        --            WHERE   mt.CFDFlex = 1
        --                    AND mt.Modulo = 'CXC'
        --                    AND c.CFDFlexEstatus <> 'CONCLUIDO'
        --                    AND c.Mov = @Mov
        --                    AND c.ID = @CxcID )
        --    BEGIN
				
        --        SELECT  @sEstatus = c.Estatus
        --        FROM    dbo.Cxc c
        --        WHERE   c.ID = @RegresoID;

        --        PRINT 'Regenerando CFDI de CXC ID= ' + CAST(@CxcID AS VARCHAR) + ' ' + RTRIM(@Mov) + ' '
        --            + RTRIM(ISNULL(@RegresoMovID, '0'));

        --        EXEC dbo.spCFDFlex @Estacion = 881, -- int --TURISMO
        --            @Empresa = @Empresa, -- varchar(5)
        --            @Modulo = 'CXC', -- varchar(5)
        --            @ID = @CxcID, -- int
        --            @Estatus = @sEstatus, -- varchar(15)
        --            @Ok = @iError OUTPUT, -- int
        --            @OkRef = @sError OUTPUT;

        --        SET @sError = 'Resultado Regeneración CFDI :' + RTRIM(ISNULL(CAST(@iError AS INT), 0)) + ' '
        --            + RTRIM(ISNULL(@sError, 'CONCLUIDO'));
        --        PRINT @sError;
        --        EXEC Interfaz_LogsInsertar 'Interfaz_CxcAplicacionDeIngresos', 'Regenerar CFDI', @sError, @Usuario,
        --            @LogParametrosXml;
        --    END

        SET @sError = NULL;
        
        IF EXISTS ( SELECT  c.CFDFlexEstatus
                    FROM    MovTipo mt
                            JOIN Cxc c ON c.Mov = mt.Mov
                    WHERE   mt.CFDFlex = 1
                            AND mt.Modulo = 'CXC'
                            AND c.CFDFlexEstatus <> 'CONCLUIDO'
                            AND c.Mov = @Mov
                            AND c.ID = @CxcID )
            BEGIN
				
                SELECT  @sEstatus = c.Estatus
                FROM    dbo.Cxc c
                WHERE   c.ID = @RegresoID;

                BEGIN TRY

                    PRINT 'Generando CFDI de CXC ID= ' + CAST(@CxcID AS VARCHAR) + ' ' + RTRIM(@Mov) + ' '
                        + RTRIM(ISNULL(@RegresoMovID, '0'));

                    EXEC dbo.spCFDFlex @Estacion = 881, -- int --TURISMO
                        @Empresa = @Empresa, -- varchar(5)
                        @Modulo = 'CXC', -- varchar(5)
                        @ID = @CxcID, -- int
                        @Estatus = @sEstatus, -- varchar(15)
                        @Ok = @iError OUTPUT, -- int
                        @OkRef = @sError OUTPUT;

                    SET @sError = 'Resultado Timbrado :' + RTRIM(ISNULL(CAST(@iError AS INT), 0)) + ' '
                        + RTRIM(ISNULL(@sError, 'CONCLUIDO'));
                    PRINT @sError;

                    EXEC Interfaz_LogsInsertar 'Interfaz_CxcAplicacionDeIngresos', 'Timbrado CFDI', @sError, @Usuario,
                        @LogParametrosXml;
                END TRY
                BEGIN CATCH
                    SELECT  @iError = ERROR_NUMBER() ,
                            @sError = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') '
                            + ERROR_MESSAGE();
                END CATCH

                IF ( SELECT ISNULL(CFDFlexEstatus, '')
                     FROM   dbo.Cxc
                     WHERE  ID = @CxcID
                   ) <> 'CONCLUIDO'
                    BEGIN
                        SET @sError = 'Error al timbrar el movimiento de Intelisis: ' + 'Error = '
                            + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                            + '. Intente nuevamente.';
                        EXEC Interfaz_LogsInsertar 'Interfaz_CxcAplicacionDeIngresos', 'Error', @sError, @Usuario,
                            @LogParametrosXml;
                        RAISERROR(@sError,16,1);
                        --RETURN;
                    END
            END
--********************************************************************
--		INFORMACION DE RETORNO
--********************************************************************
        SELECT  ID = @CxcID ,
                T2.MovID ,
                T2.Estatus ,
                CASE WHEN T1.UUID = NULL THEN RTRIM(ISNULL(@sError, ''))
                     ELSE RTRIM(T2.CFDFlexEstatus)
                END AS CFDFlexEstatus ,
                CFDXML = CAST(T1.Documento AS VARCHAR(MAX)) ,
                T1.noCertificado ,
                T1.Sello ,
                T1.SelloSAT ,
                T1.TFDCadenaOriginal ,
                T1.UUID ,
                T1.FechaTimbrado ,
                T1.noCertificadoSAT
        FROM    CFD AS T1
                INNER JOIN dbo.Cxc T2 ON T2.ID = T1.ModuloID
                                         AND T2.MovID = T1.MovID
        WHERE   T1.ModuloID = @CxcID
                AND T1.Modulo = 'CXC';
			
        SELECT  @ID = T2.ID ,
                @MovID = T2.MovID ,
                @Estatus = T2.Estatus ,
                @CFDFlexEstatus = CASE WHEN T1.UUID = NULL THEN RTRIM(ISNULL(@sError, ''))
                                       ELSE RTRIM(T2.CFDFlexEstatus)
                                  END ,
                @CFDXml = CAST(T1.Documento AS VARCHAR(MAX)) ,
                @noCertificado = T1.noCertificado ,
                @Sello = T1.Sello ,
                @SelloSAT = T1.SelloSAT ,
                @TFDCadenaOriginal = T1.TFDCadenaOriginal ,
                @UUID = T1.UUID ,
                @FechaTimbrado = T1.FechaTimbrado ,
                @noCertificadoSAT = T1.noCertificadoSAT
        FROM    CFD AS T1
                INNER JOIN dbo.Cxc T2 ON T2.ID = T1.ModuloID
                                         AND T2.MovID = T1.MovID
        WHERE   T1.ModuloID = @CxcID
                AND T1.Modulo = 'CXC';
    END
        
GO
GRANT EXECUTE ON  [dbo].[Interfaz_CxcAplicacionDeIngresos] TO [Linked_Svam_Pruebas]
GO
