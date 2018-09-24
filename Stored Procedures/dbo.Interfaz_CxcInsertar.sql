SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	21/08/2018
-- Descripción:		Insersión y afectación de facturas de Anticipo y Otros Movimientos CXC.
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_CxcInsertar]
    @Empresa CHAR(5),
    @Mov CHAR(20),
    @FechaEmision SMALLDATETIME,
    @Concepto VARCHAR(50),
    @Moneda CHAR(10),
    @TipoCambio FLOAT,
    @Usuario CHAR(10),
    @Codigo AS VARCHAR(30),
    @Referencia VARCHAR(50),
    @Cliente CHAR(10),
    @Sucursal INT = NULL,
    @Vencimiento SMALLDATETIME,
    @Importe MONEY,
    @Impuestos MONEY,
    @CentroDeCostos VARCHAR(20),
    @TipoPago VARCHAR(50),
    @CtaDinero CHAR(10),
    @Observaciones VARCHAR(100),
    @Comentarios VARCHAR(MAX),
    @Partidas VARCHAR(MAX) = NULL,
    @ID AS INT = NULL OUTPUT,
    @MovID AS VARCHAR(MAX) = NULL OUTPUT,
    @Estatus AS CHAR(15) = NULL OUTPUT,
    @CFDFlexEstatus AS VARCHAR(15) = NULL OUTPUT,
    @CFDXml AS VARCHAR(MAX) = NULL OUTPUT,
    @noCertificado AS VARCHAR(MAX) = NULL OUTPUT,
    @Sello AS VARCHAR(MAX) = NULL OUTPUT,
    @SelloSAT AS VARCHAR(MAX) = NULL OUTPUT,
    @TFDCadenaOriginal VARCHAR(MAX) = NULL OUTPUT,
    @UUID AS VARCHAR(MAX) = NULL OUTPUT,
    @FechaTimbrado AS VARCHAR(MAX) = NULL OUTPUT,
    @noCertificadoSAT AS VARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    --********************************************************************
    --		VARIABLES 
    --********************************************************************

    -- Se crea y se genera Xml con los parametros para tabla Interfaz_Logs
    DECLARE @LogParametrosXml XML;
    SET @LogParametrosXml =
    (
        SELECT @Empresa AS 'Empresa',
               @Mov AS 'Mov',
               @FechaEmision AS 'FechaEmision',
               @Concepto AS 'Concepto',
               @Moneda AS 'Moneda',
               @TipoCambio AS 'TipoCambio',
               @Usuario AS 'Usuario',
               @Codigo AS 'Codigo',
               @Referencia AS 'Referencia',
               @Cliente AS 'Cliente',
               @Sucursal AS 'Sucursal',
               @Vencimiento AS 'Vencimiento',
               @Importe AS 'Importe',
               @Impuestos AS 'Impuestos',
               @CentroDeCostos AS 'CentroDeCostos',
               @TipoPago AS 'TipoPago',
               @CtaDinero AS 'CtaDinero',
               @Observaciones AS 'Observaciones',
               @Comentarios AS 'Comentarios',
               @Partidas AS 'Partidas'
        FOR XML PATH('Parametros')
    );
    -- Se Registra Evento
    EXEC Interfaz_LogsInsertar 'Interfaz_CxcInsertar',
                               'Inserción',
                               '',
                               @Usuario,
                               @LogParametrosXml;
    /* Tipo de Pago segun catalogo de Intelisis*/
    PRINT 'Tipo de pago recibida: ' + RTRIM(@TipoPago);
    SELECT @TipoPago = (CASE
                            WHEN @TipoPago = 'Tarjeta de Credito' THEN
                                'Tarjetas de Crédito'
                            WHEN @TipoPago = 'Tarjeta de Debito' THEN
                                'Tarjeta de débito'
                            WHEN @TipoPago = 'Deposito Cheque' THEN
                                'Cheque'
                            WHEN @TipoPago = 'Deposito Efectivo' THEN
                                'Efectivo'
                            WHEN @TipoPago = 'PayPal' THEN
                                'Tarjeta de débito'
                            WHEN @TipoPago = 'Transferencia' THEN
                                'Transferencia Electronica'
                            WHEN @TipoPago = 'NO IDENTIFICADO' THEN
                                'NA'
                            ELSE
                                @TipoPago
                        END
                       );
    PRINT 'Tipo de pago a insertar: ' + RTRIM(@TipoPago);
    -- VARIBLES PARA MENSAJES DE ERROR
    DECLARE @iError AS INT,
            @sError AS VARCHAR(MAX),
            @bMovValido AS BIT;
    -- VARIABLES DE RETORNO
    DECLARE @RegresoID AS INT,
            @RegresoMovID AS VARCHAR(20),
            @sEstatus AS VARCHAR(15);
    -- VARIABLES DEL MOVIMIENTO
    DECLARE @Condicion AS VARCHAR(10),
            @Aplica AS CHAR(20),
            @AplicaID AS VARCHAR(20),
            @a2ID AS INT,
            @AplManual AS INT,
            @Origen AS CHAR(20),
            @PathImagen VARCHAR(100),
            @RefApli2 AS VARCHAR(50),
            @SumApli2 AS MONEY,
            @sReferencia VARCHAR(10),
            @iConsecutivo AS INT;
    -- Referencia de 250 Caracteres
    --DECLARE @Ref0 AS CHAR(50) = '' ,	--Referencia
    --    @Ref1 AS CHAR(50) = '' ,	--Referencia1
    --    @Ref2 AS CHAR(50) = '' ,	--Referencia2
    --    @Ref3 AS CHAR(50) = '' ,	--Referencia3
    --    @Ref4 AS CHAR(50) = '';		--Referencia4

    --Tabla de Partidas para movimientos con Aplicación 2
    DECLARE @T_Partidas TABLE
    (
        Consecutivo INT IDENTITY(1, 1) NOT NULL,
        Importe MONEY,
        Aplica CHAR(20),
        AplicaID VARCHAR(20)
    );

    DECLARE @X_Partidas XML;
    SET @X_Partidas = CAST(@Partidas AS XML);
    /* Llenar tabla de partidas*/
    IF NOT @Partidas IS NULL
    BEGIN
        INSERT INTO @T_Partidas
        SELECT T.LOC.value('@Importe', 'MONEY') AS Importe,
               T.LOC.value('@Aplica', 'CHAR(20)') AS Aplica,
               T.LOC.value('@AplicaID', 'VARCHAR(20)') AS AplicaID
        FROM @X_Partidas.nodes('//row/fila') AS T(LOC);
        SELECT TOP 1
            @Aplica = Aplica,
            @AplicaID = AplicaID
        FROM @T_Partidas;
    END;

    --IF ( @AplicaID IN ( 'TVE104921', 'TVE104232', 'TVE104231' ) )
    --    BEGIN
    --        SELECT  @Aplica = 'CFD Anticipo ServCom';
    --    END
    /* Validación de CODIGO*/
    IF NOT EXISTS
    (
        SELECT c.Codigo
        FROM dbo.Cxc c
        WHERE c.Codigo = @Codigo
              AND c.Mov = @Mov
              AND c.Estatus IN ( 'CONCLUIDO', 'PENDIENTE', 'SINAFECTAR' )
    )
       OR @Codigo IS NULL
    BEGIN

        --********************************************************************
        --		VALIDACIONES 
        --********************************************************************
        /* Validaciones Comunes*/
        SELECT @sError
            = VE.fn_ValidaInterfaz(
                                      @Empresa,
                                      @Mov,
                                      @FechaEmision,
                                      @Concepto,
                                      @Moneda,
                                      @TipoCambio,
                                      @Usuario,
                                      @Cliente,
                                      @Sucursal,
                                      @Vencimiento,
                                      @Importe,
                                      @Impuestos,
                                      @CentroDeCostos,
                                      @TipoPago
                                  );

        IF NOT EXISTS
        (
            SELECT ctad.CtaDinero
            FROM dbo.CtaDinero ctad
            WHERE ctad.CtaDinero = RTRIM(@CtaDinero)
        )
           AND @Mov IN ( 'Cobro VE Gravado', 'Cobro TransInd' )
        BEGIN
            SET @sError
                = 'La cuenta indicada ( ' + ISNULL(@CtaDinero, 'No Indicada')
                  + ' ), no es valida. Por favor, indique un cuenta valida.';
        END;

        IF NOT EXISTS (SELECT * FROM @T_Partidas)
           AND @Mov <> 'CFD Anticipo'
        BEGIN
            SET @sError = 'No indico ninguna partida. Por favor, indique al menos una partida valida.';
        END;

        IF EXISTS (SELECT * FROM @T_Partidas AS A WHERE A.AplicaID IS NULL)
        BEGIN
            SET @sError = 'Uno o mas AplicaID de partidas no fueron indicados. Favor de verificarlos.';
        END;
        --Evaluar Retirarlo
        IF EXISTS
        (
            SELECT *
            FROM @T_Partidas AS A
            WHERE A.Aplica = 'CFD FactVia Credito'
        )
           AND @Mov = 'Nota Credito TransIn'
        BEGIN
            SET @Mov = 'Nota Credito SIVE';
            SET @Concepto = 'CANC. ING. VE CFD';
        END;
        IF (@Mov IN ( 'Cobro SIVE', 'Cobro TransInd', 'Cobro VE Gravado', 'Cobro Paquete', 'Bonificación TI',
                      'Bonificación SIVE', 'BONIFICACION VE GRAV', 'Devolucion Paquete', 'Devolucion Gravada',
                      'Devolucion', 'Nota Credito SIVE', 'Nota Credito TransIn', 'NOTA CREDITO VE GRAV',
                      'CANCELACION TURISMO'
                    )
           )
        BEGIN
            IF (@Aplica IS NULL OR RTRIM(LTRIM(@Aplica)) = '')
            BEGIN
                SET @sError
                    = 'Aplica no indicado. En Movimientos de ' + RTRIM(@Mov) + ' debe indicar un movimiento Aplica. '
                      + 'Por favor, indique un Aplica.';
            END;

            IF (@AplicaID IS NULL OR RTRIM(LTRIM(@AplicaID)) = '')
            BEGIN
                SET @sError
                    = 'AplicaID no indicado. En movimientos de ' + RTRIM(@Mov) + ' debe indicar un AplicaID. '
                      + 'Por favor, indique un AplicaID.';
            END;

            IF
            (
                SELECT COUNT(*) FROM @T_Partidas
            ) <> 1
            BEGIN
                SET @sError
                    = 'De acuerdo al movimiento indicado, solo puede indicar una partida. Por favor, indique solo una partida valida.';
            END;

            IF NOT EXISTS
            (
                SELECT *
                FROM Cxc AS A
                WHERE A.Mov = @Aplica
                      AND A.MovID = @AplicaID
                      AND A.Empresa = @Empresa
            )
            BEGIN
                SET @sError
                    = 'Factura no encontrada. Los parámetros Aplica = "' + RTRIM(@Aplica) + '" y AplicaID = "'
                      + RTRIM(@AplicaID) + '" hacen referencia a una factura que no fue encontrada. '
                      + 'Por favor, indique una factura valida.';
            END;

            IF (
               (
                   SELECT TOP 1
                       A.Estatus
                   FROM Cxc AS A
                   WHERE A.Mov = @Aplica
                         AND A.MovID = @AplicaID
                         AND A.Empresa = @Empresa
               ) <> 'PENDIENTE'
               )
            BEGIN
                SET @sError
                    = 'Factura no se encuentra "PENDIENTE". Los parámetros Aplica = "' + RTRIM(@Aplica)
                      + '" y AplicaID = "' + RTRIM(@AplicaID)
                      + '" hacen referencia a una factura que no se encuentra en estado "PENDIENTE". '
                      + 'Por favor, indique una factura valida.';
            END;

            IF (
               (
                   SELECT TOP 1
                       A.Cliente
                   FROM Cxc AS A
                   WHERE A.Mov = @Aplica
                         AND A.MovID = @AplicaID
                         AND A.Empresa = @Empresa
               ) <> RTRIM(@Cliente)
               )
            BEGIN
                SET @sError
                    = 'La factura no corresponde al cliente indicado. Los parámetros Aplica = "' + RTRIM(@Aplica)
                      + '" y AplicaID = "' + RTRIM(@AplicaID)
                      + '" hacen referencia a una factura que no corresponde al Cliente indicado. '
                      + 'Por favor, indique una factura valida.';
            END;

            IF (
               (
                   SELECT TOP 1
                       A.Saldo
                   FROM Cxc AS A
                   WHERE A.Mov = @Aplica
                         AND A.MovID = @AplicaID
                         AND A.Estatus = 'PENDIENTE'
                         AND A.Empresa = @Empresa
               ) < @Importe
               )
            BEGIN
                SET @sError
                    = 'El Importe es superior al Saldo de la factura (Saldo igual a '
                      + CAST(
                        (
                            SELECT TOP 1
                                A.Saldo
                            FROM Cxc AS A
                            WHERE A.Mov = @Aplica
                                  AND A.MovID = @AplicaID
                                  AND A.Estatus = 'PENDIENTE'
                        ) AS VARCHAR) + '). Por favor, indique un Importe valido.';
            END;
            IF
            (
                SELECT CAST(SUM(Importe) AS MONEY)FROM @T_Partidas
            ) <> (@Importe + @Impuestos)
            BEGIN
                SET @sError
                    = 'Importe de aplicación no valido. El importe de aplicación indicado es diferente al importe del movimiento. '
                      + 'Por favor, indique un Importe de aplicación.';
            END;
        END;

        IF EXISTS
        (
            SELECT *
            FROM @T_Partidas AS T1
                LEFT JOIN Cxc AS T2
                    ON T1.AplicaID = T2.MovID
            WHERE T2.Mov IS NULL
        )
        BEGIN
            SET @sError = 'Una o mas partidas indicadas, no fueron encontradas (AplicaIDs no encontrados ';
            SET @sError = @sError +
                          (
                              SELECT TOP 1
                                  (
                                      SELECT CAST(T2.AplicaID AS VARCHAR) + ','
                                      FROM @T_Partidas AS T2
                                          LEFT JOIN Cxc AS T3
                                              ON T2.AplicaID = T3.MovID
                                      WHERE T3.MovID IS NULL
                                      ORDER BY T2.AplicaID
                                      FOR XML PATH('')
                                  ) AS IDS
                              FROM @T_Partidas AS T1
                          );
            SET @sError = SUBSTRING(@sError, 1, LEN(@sError) - 1);
            SET @sError = @sError + '). Favor de verificarlos.';
        END;

        PRINT 'Resultado de validación General: ' + RTRIM(ISNULL(@sError, 'Ok'));
        --********************************************************************
        --		VALIDACIONES POR MOVIMIENTO
        --********************************************************************
        SET @bMovValido = 0;
        --  ***	'Bonificación TI' ***
        IF (@Mov = 'Bonificación TI')
        BEGIN
            SET @bMovValido = 1;
            IF (@Usuario = 'SITTI')
            BEGIN
                IF (@Concepto NOT IN ( 'CANC. INGRESO T.IND. 15%' ))
                BEGIN
                    SET @sError
                        = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
                IF (@Aplica <> 'Factura TranspInd')
                BEGIN
                    SET @sError
                        = 'Aplica no valido. El movimiento Aplica se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Aplica valido para esta combinación de movimiento y usuario.';
                    RETURN;
                END;
            END;
            ELSE
            BEGIN
                SET @sError
                    = 'Usuario no valido. El usuario que indico existe en Intelisis, '
                      + 'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
            END;
        END;
        --	***	'BONIFICACION VE GRAV' ***
        IF (@Mov = 'BONIFICACION VE GRAV')
        BEGIN
            SET @bMovValido = 1;
            IF (@Usuario = 'SITTI')
            BEGIN
                IF (@Concepto NOT IN ( 'CANCELACION VE GRAVADO' ))
                BEGIN
                    SET @sError
                        = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
                IF (@Aplica NOT IN ( 'FACT.VE.GRAVADO', 'FACTURA VE TOTAL', 'Ingreso Paquetes', 'INE VE GRAVADO' ))
                BEGIN
                    SET @sError
                        = 'Aplica no valido. El movimiento Aplica se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Aplica valido para esta combinación de movimiento y usuario.';
                END;
            END;
            ELSE
            BEGIN
                SET @sError
                    = 'Usuario no valido. El usuario que indico existe en Intelisis, '
                      + 'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
            END;
        END;
        --	***	'CFD Anticipo' ***
        IF (@Mov = 'CFD Anticipo')
        BEGIN
            SET @bMovValido = 1;
            IF (@Usuario = 'SITTI')
            BEGIN
                IF (@Concepto NOT IN ( 'ANTICIPO CFDI GRAVADO VE' ))
                BEGIN
                    SET @sError
                        = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
            END;
            ELSE
            BEGIN
                SET @sError
                    = 'Usuario no valido. El usuario que indico existe en Intelisis, '
                      + 'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
            END;
        END;
        --	***	 'Cobro TransInd' ***
        IF (@Mov = 'Cobro TransInd')
        BEGIN
            SET @bMovValido = 1;
            IF (@Usuario = 'SITTI')
            BEGIN
                IF (@Concepto NOT IN ( 'T.INDUSTRIAL 10%', 'T.INDUSTRIAL 15%' ))
                BEGIN
                    SET @sError
                        = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
                IF (@Aplica NOT IN ( 'Factura TranspInd', 'Nota Cargo SIVE', 'Endoso' ))
                BEGIN
                    SET @sError
                        = 'Aplica no valido. El movimiento Aplica se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Aplica valido para esta combinación de movimiento y usuario.';
                END;
            END;
            ELSE
            BEGIN
                SET @sError
                    = 'Usuario no valido. El usuario que indico existe en Intelisis, '
                      + 'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
            END;
        END;
        --	***	'Cobro VE Gravado' ***
        IF (@Mov = 'Cobro VE Gravado')
        BEGIN
            SET @bMovValido = 1;
            IF (@Usuario = 'SITTI')
            BEGIN
                IF (@Concepto NOT IN ( 'VIAJE ESPECIAL GRAVADO', 'T.INDUSTRIAL 15%' ))
                BEGIN
                    SET @sError
                        = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
                IF (@Aplica NOT IN ( 'FACT.VE.GRAVADO', 'CFDI SIN VIAJE GRAV', 'Nota Cargo SIVE',
                                     'CFD FactVia Credito', 'CFD Sin Viaje', 'Factura TraspInd', 'Factura INE',
                                     'Endoso', 'Factura VE TOTAL', 'INE VE GRAVADO'
                                   )
                   )
                BEGIN
                    SET @sError
                        = 'Aplica no valido. El movimiento Aplica se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Aplica valido para esta combinación de movimiento y usuario.';
                END;
            END;
            ELSE
            BEGIN
                SET @sError
                    = 'Usuario no valido. El usuario que indico existe en Intelisis, '
                      + 'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
            END;
        END;

        -- ***	'Devolucion Gravada' ***
        IF (@Mov = 'Devolucion Gravada')
        BEGIN
            SET @bMovValido = 1;
            IF (@Usuario = 'SITTI')
            BEGIN
                IF (@Concepto NOT IN ( 'DEVOLUCION ANTICIPO' ))
                BEGIN
                    SET @sError
                        = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
                IF (@Aplica NOT IN ( 'CFD Anticipo', 'CFD Anticipo ServCom' ))
                BEGIN
                    SET @sError
                        = 'Aplica no valido. El movimiento Aplica se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Aplica valido para esta combinación de movimiento y usuario.';
                END;
                IF (@Impuestos <> 0)
                BEGIN
                    SET @sError
                        = 'Este movimiento no debe tener Impuestos. El movimiento Devolución Gravada debe indicar Impuestos 0 '
                          + 'en el encabezado. Por favor, indique un valor de Impuestos valido para este movimiento.';
                END;
                SET @Condicion = 'Contado'; -- se implemento por solicitud de Juan Gabina
            END;
            ELSE
            BEGIN
                SET @sError
                    = 'Usuario no valido. El usuario que indico existe en Intelisis, '
                      + 'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
            END;
        END;

        --	***	'CANCELACION TURISMO' ***
        IF (@Mov IN ( 'CANCELACION TURISMO' ))
        BEGIN
            SET @bMovValido = 1;
            IF (@Usuario = 'SITTI')
            BEGIN
                IF (@Concepto NOT IN ( 'CANCELACION VE GRAVADO', 'CANC. INGRESO T.IND. 15%', 'T.INDUSTRIAL 16%' ))
                BEGIN
                    SET @sError
                        = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
                IF
                (
                    SELECT TOP 1 CAST(Importe AS MONEY)FROM @T_Partidas
                ) < (@Importe + @Impuestos)
                BEGIN
                    SET @sError
                        = 'Importe de aplicación no valido. El importe de aplicación indicado es menor al importe del movimiento. '
                          + 'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                END;
            END;
            ELSE
            BEGIN
                SET @sError
                    = 'Usuario no valido. El usuario que indico existe en Intelisis, '
                      + 'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
            END;
        END;
        IF @bMovValido = 0
        BEGIN
            SET @sError
                = 'Mov no valido. El movimiento no se encuentra entre los movimientos esperados. '
                  + 'Por favor, indique un Movimiento valido.';
        END;
        PRINT 'Resultado de validación por movimiento: ' + RTRIM(ISNULL(@sError, 'Ok'));
        IF @sError <> 'Ok'
        BEGIN
            EXEC Interfaz_LogsInsertar 'Interfaz_CxcInsertar',
                                       'Error de Validación',
                                       @sError,
                                       @Usuario,
                                       @LogParametrosXml;
            RAISERROR(@sError, 16, 1);
            RETURN;
        END;
        IF NOT EXISTS
        (
            SELECT ClaveUsoCFDI
            FROM dbo.CteCFD
            WHERE Cliente = @Cliente
        )
        BEGIN
            PRINT 'Insertar registro de Clave Uso CFDI';
            INSERT INTO dbo.CteCFD
            (
                Cliente,
                ClaveUsoCFDI
            )
            VALUES
            (   @Cliente, -- Cliente - char(10)
                'G03'     -- ClaveUsoCFDI - varchar(3)
            );
        END;
        ELSE
        BEGIN
            IF
            (
                SELECT ClaveUsoCFDI FROM dbo.CteCFD WHERE Cliente = @Cliente
            ) IS NULL
            BEGIN
                PRINT 'Actualizando registro de Clave Uso CFDI';
                UPDATE CteCFD
                SET ClaveUsoCFDI = 'G03'
                WHERE Cliente = @Cliente;
            END;
        END;
        --********************************************************************
        --		PROCESO
        --********************************************************************

        SELECT TOP 1
            @TipoPago = ISNULL(ccf.sTipoPago, @TipoPago),
            @sReferencia = ISNULL(ccf.sReferencia, NULL)
        FROM VE.cnfCteFacturas ccf
        WHERE ccf.sCliente = RTRIM(@Cliente)
              AND ccf.iSucursal = ISNULL(@Sucursal, 0)
              AND ccf.isActivo = 1
              AND ccf.sRama = 'CXC'
              AND ccf.dInicio <= @FechaEmision
              AND ccf.dFin >= @FechaEmision
        ORDER BY ccf.dAlta DESC;

        PRINT 'Condición: ' + ISNULL(@Condicion, '');
        --	*****	SE INSERTAN LOS REGISTROS EN CXC	*****
        PRINT 'Se inserta registro nuevo en CXC';

        IF (@Mov NOT IN ( 'DEV.SALDO', 'Devolucion', 'Devolucion Gravada', 'Devolucion Saldo', 'Devolucion Paquete',
                          'Cobro SIVE', 'Cobro Paquete', 'Cobro TransInd', 'Cobro VE Gravado', 'CANCELACION TURISMO',
                          'Bonificación TI', 'BONIFICACION VE GRAV'
                        )
           )
        BEGIN
            SET @AplManual = 0;
            SET @Origen = NULL;
        END;
        ELSE
        BEGIN
            PRINT 'Aplicación manual';
            SET @AplManual = 1; -- APLICACION MANUAL
            SET @Origen = @Aplica;
        END;

        IF @Mov IN ( 'Cobro VE Gravado', 'Cobro TransInd' )
        BEGIN
            PRINT 'Se genera consecutivo del Cobro';
            SELECT @iConsecutivo = cc.Consecutivo + 1
            FROM CxcC cc
            WHERE cc.Mov = 'Cobro VE Gravado'
                  AND cc.Serie = 'TVC';
            SET @MovID = 'TVC' + CAST(@iConsecutivo AS VARCHAR);
            PRINT 'TVC' + CAST(@iConsecutivo AS VARCHAR);
        END;
        ELSE
        BEGIN
            SET @iConsecutivo = NULL;
            SET @MovID = NULL;
        END;

        INSERT INTO dbo.Cxc
        (
            Empresa,
            Mov,
            MovID,
            FechaEmision,
            UltimoCambio,
            Concepto,
            Moneda,
            TipoCambio,
            Usuario,
            Referencia,
            Observaciones,
            Estatus,
            Cliente,
            ClienteEnviarA,
            ClienteMoneda,
            ClienteTipoCambio,
            Condicion,
            Vencimiento,
            FormaCobro,
            Importe,
            Impuestos,
            AplicaManual,
            ConDesglose,
            Referencia1,
            --Referencia2 ,
            --Referencia3 ,
            --Referencia4 ,
            Origen,
            Sucursal,
            ContUso,
            Codigo,
            FormaCobro1,
            CtaDinero
        )
        VALUES
        (   @Empresa,                           -- Empresa - char(5)
            @Mov,                               -- Mov - char(20)
            @MovID,
            dbo.Fn_QuitarHrsMin(@FechaEmision), -- FechaEmision - datetime
            GETDATE(),                          -- UltimoCambio - datetime
            @Concepto,                          -- Concepto - varchar(50)
            @Moneda,                            -- Moneda - char(10)
            @TipoCambio,                        -- TipoCambio - float
            @Usuario,                           -- Usuario - char(10)
            @Referencia,                        -- Referencia - varchar(50)
            @Observaciones,                     -- Observaciones - varchar(100)
            'SINAFECTAR',                       -- Estatus - char(15)
            @Cliente,                           -- Cliente - char(10)
            @Sucursal,                          -- ClienteEnviarA - int
            @Moneda,                            -- ClienteMoneda - char(10)
            @TipoCambio,                        -- ClienteTipoCambio - float
            @Condicion,                         -- Condicion - varchar(50)
            @Vencimiento,                       -- Vencimiento - datetime
            @TipoPago,                          -- FormaCobro - varchar(50)
            @Importe,                           -- Importe - money
            @Impuestos,                         -- Impuestos - money
            @AplManual,                         -- AplicaManual - bit
            0,                                  -- ConDesglose - bit
            @sReferencia,                       -- Referencia1 - varchar(50)
                                                --@Ref2 , -- Referencia2 - varchar(50)
                                                --@Ref3 , -- Referencia3 - varchar(50)
                                                --@Ref4 , -- Referencia4 - varchar(50)
            @Origen,                            -- Origen - varchar(20)
            0,                                  -- Sucursal - int
            @CentroDeCostos,                    -- ContUso - varchar(20)
            @Codigo,                            -- Codigo - varchar(30)
            @TipoPago,
            @CtaDinero
        );

        SET @RegresoID = SCOPE_IDENTITY();

        IF @Mov IN ( 'Cobro VE Gravado', 'Cobro TransInd' )
        BEGIN
            PRINT 'Se actualiza consecutivo del Cobro';
            UPDATE dbo.CxcC
            SET Consecutivo = @iConsecutivo
            WHERE Mov = 'Cobro VE Gravado'
                  AND Serie = 'TVC';
        END;

        PRINT 'Se inserta detalle de CXC ID= ' + CAST(@RegresoID AS VARCHAR) + ' Mov= ' + RTRIM(@Mov);

        --	*****	SE INSERTAN EL DETALLE EN CXCD	*****
        IF @Mov IN ( 'Bonificación TI', 'BONIFICACION VE GRAV', 'Cobro SIVE', 'Cobro TransInd', 'Cobro Paquete',
                     'Cobro VE Gravado', 'Devolucion', 'Devolucion Gravada', 'Devolucion Paquete', 'DEV.SALDO',
                     'CANCELACION TURISMO'
                   )
        BEGIN
            PRINT 'Caso Cobros Bonificaciones y Cancelaciones';
            INSERT INTO CxcD
            (
                ID,
                Renglon,
                RenglonSub,
                Importe,
                Aplica,
                AplicaID
            )
            VALUES
            (@RegresoID, 2048, 0, @Importe + @Impuestos, @Aplica, @AplicaID);
        END;
        ELSE
        BEGIN

            IF @Mov IN ( 'Bonificación SIVE', 'Nota Credito TransIn', 'Nota Credito SIVE' )
            BEGIN
                PRINT 'Caso Nota de Credito';
                INSERT INTO CxcD
                (
                    ID,
                    Renglon,
                    RenglonSub,
                    Importe,
                    Aplica,
                    AplicaID
                )
                SELECT @RegresoID,
                       Renglon = 2048 * T1.Consecutivo,
                       0,
                       Importe = T1.Importe,
                       Aplica = T1.Aplica,
                       AplicaID = T1.AplicaID
                FROM @T_Partidas AS T1;
            END;
        END;
    END;
    ELSE
    BEGIN

        SELECT TOP 1
            @RegresoID = c.ID,
            @RegresoMovID = c.MovID
        FROM dbo.Cxc c
        WHERE c.Codigo = @Codigo
              AND c.Mov = @Mov
              AND c.Estatus IN ( 'CONCLUIDO', 'PENDIENTE', 'SINAFECTAR' )
        ORDER BY c.FechaRegistro DESC;
        PRINT 'Ya existe en CXC ID= ' + CAST(@RegresoID AS VARCHAR) + ' ' + RTRIM(@Mov) + ' '
              + RTRIM(ISNULL(@RegresoMovID, '0'));
    END;
    --********************************************************************
    --		AFECTAR
    --********************************************************************
    IF EXISTS
    (
        SELECT c.Codigo
        FROM dbo.Cxc c
        WHERE c.Codigo = @Codigo
              AND c.ID = @RegresoID
              AND c.Estatus = 'SINAFECTAR'
    )
       OR @Codigo IS NULL
    BEGIN
        BEGIN TRY
            WAITFOR DELAY '00:00:20';
            PRINT 'Afectando CXC ID= ' + CAST(@RegresoID AS VARCHAR) + ' ' + RTRIM(@Mov) + ' '
                  + RTRIM(ISNULL(@RegresoMovID, '0'));

            --IF OBJECT_ID('TempDB..#Afectar', 'U') IS NOT NULL
            --    BEGIN
            --        DROP TABLE #Afectar;
            --    END
            --CREATE TABLE #afectar
            --    (
            --      error INT NULL ,
            --      texto CHAR(250) NULL ,
            --      var3 CHAR(250) NULL ,
            --      var4 CHAR(250) NULL ,
            --      var5 CHAR(250) NULL
            --    )

            --INSERT  INTO #afectar
            EXEC spAfectar 'CXC',
                           @RegresoID,
                           'AFECTAR',
                           'Todo',
                           NULL,
                           @Usuario,
                           NULL,
                           1,
                           @iError OUTPUT,
                           @sError OUTPUT;

            PRINT 'Retorno SPAfectar: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));

            SELECT @sError = ml.Descripcion
            FROM dbo.MensajeLista ml
            WHERE ml.Mensaje = @iError;

            PRINT 'Codigo de Resultado: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));

        END TRY
        BEGIN CATCH
            SELECT @iError = ERROR_NUMBER(),
                   @sError
                       = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') ' + ERROR_MESSAGE();
        END CATCH;

        IF
        (
            SELECT A.Estatus FROM Cxc AS A WHERE A.ID = @RegresoID
        ) = 'SINAFECTAR'
        BEGIN
            SET @sError
                = 'Error al aplicar el movimiento de Intelisis: ' + 'Error = '
                  + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                  + '. Intente nuevamente.';
            EXEC Interfaz_LogsInsertar 'Interfaz_CxcInsertar',
                                       'Error',
                                       @sError,
                                       @Usuario,
                                       @LogParametrosXml;
            RAISERROR(@sError, 16, 1);
            RETURN;
        END;
    END;

    SET @RegresoMovID =
    (
        SELECT A.MovID FROM Cxc AS A WHERE A.ID = @RegresoID
    );
    SET @sError = NULL;

    IF EXISTS
    (
        SELECT c.CFDFlexEstatus
        FROM MovTipo mt
            JOIN Cxc c
                ON c.Mov = mt.Mov
        --AND c.Estatus = mt.eDocEstatus
        WHERE mt.CFDFlex = 1
              AND mt.Modulo = 'CXC'
              AND ISNULL(c.CFDFlexEstatus, 'Error') <> 'CONCLUIDO'
              AND c.Mov NOT IN ( 'Cobro VE Gravado', 'Cobro TransInd' )
              AND c.ID = @RegresoID
    )
    BEGIN

        SELECT @sEstatus = c.Estatus
        FROM dbo.Cxc c
        WHERE c.ID = @RegresoID;

        BEGIN TRY

            PRINT 'Generando CFDI de CXC ID= ' + CAST(@RegresoID AS VARCHAR) + ' ' + RTRIM(@Mov) + ' '
                  + RTRIM(ISNULL(@RegresoMovID, '0'));

            EXEC dbo.spCFDFlex @Estacion = 881,      -- int --TURISMO
                               @Empresa = @Empresa,  -- varchar(5)
                               @Modulo = 'CXC',      -- varchar(5)
                               @ID = @RegresoID,     -- int
                               @Estatus = @sEstatus, -- varchar(15)
                               @Ok = @iError OUTPUT, -- int
                               @OkRef = @sError OUTPUT;

            SET @sError
                = 'Resultado Timbrado :' + RTRIM(ISNULL(CAST(@iError AS INT), 0)) + ' ' + RTRIM(ISNULL(@sError, ''));
            PRINT @sError;

            EXEC Interfaz_LogsInsertar 'Interfaz_CxcInsertar',
                                       'Timbrado CFDI',
                                       @sError,
                                       @Usuario,
                                       @LogParametrosXml;
        END TRY
        BEGIN CATCH
            SELECT @iError = ERROR_NUMBER(),
                   @sError
                       = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') ' + ERROR_MESSAGE();
        END CATCH;

        IF
        (
            SELECT ISNULL(CFDFlexEstatus, '') FROM dbo.Cxc WHERE ID = @RegresoID
        ) <> 'CONCLUIDO'
        BEGIN
            SET @sError
                = 'Error al timbrar el movimiento de Intelisis: ' + 'Error = '
                  + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                  + '. Intente nuevamente.';
            EXEC Interfaz_LogsInsertar 'Interfaz_CxcInsertar',
                                       'Error',
                                       @sError,
                                       @Usuario,
                                       @LogParametrosXml;
            RAISERROR(@sError, 16, 1);
        --RETURN;
        END;
    END;

    --********************************************************************
    --		Aplicación2 que concluye los movimientos de Bonificación y Nota de crédito 
    --********************************************************************
    /*Revisar casos */
    IF (@Mov IN ( 'Nota Credito TransIn', 'Nota Credito SIVE', 'NOTA CREDITO VE GRAV' ))
    BEGIN
        IF @Mov = 'NOTA CREDITO VE GRAV'
        BEGIN
            SET @RefApli2 = LTRIM(RTRIM(@Mov)) + ' ' + LTRIM(RTRIM(@RegresoMovID));
            SET @SumApli2 = @Importe + @Impuestos;
        END;
        ELSE
        BEGIN
            SET @RefApli2 = @AplicaID;
            SET @SumApli2 = @Importe + @Impuestos;
        END;
        IF NOT EXISTS
        (
            SELECT c.Codigo
            FROM dbo.Cxc c
            WHERE c.Codigo = @Codigo
                  AND c.Mov = 'Aplicacion2'
                  AND c.Estatus IN ( 'CONCLUIDO', 'PENDIENTE', 'SINAFECTAR' )
        )
           OR @Codigo IS NULL
        BEGIN

            INSERT INTO dbo.Cxc
            (
                Empresa,
                Mov,
                FechaEmision,
                UltimoCambio,
                Concepto,
                Moneda,
                TipoCambio,
                Usuario,
                Referencia,
                Observaciones,
                Estatus,
                Cliente,
                ClienteEnviarA,
                ClienteMoneda,
                ClienteTipoCambio,
                Vencimiento,
                FormaCobro,
                Importe,
                Impuestos,
                AplicaManual,
                ConDesglose,
                MovAplica,
                MovAplicaID,
                Comentarios,
                ContUso,
                Codigo
            )
            VALUES
            (   @Empresa,                           -- Empresa - char(5)
                'Aplicacion2',                      -- Mov - char(20)
                dbo.Fn_QuitarHrsMin(@FechaEmision), -- FechaEmision - datetime
                GETDATE(),                          -- UltimoCambio - datetime
                @Concepto,                          -- Concepto - varchar(50)
                @Moneda,                            -- Moneda - char(10)
                @TipoCambio,                        -- TipoCambio - float
                @Usuario,                           -- Usuario - char(10)
                @RefApli2,                          -- Referencia - varchar(50)
                @Observaciones,                     -- Observaciones - varchar(100)
                'SINAFECTAR',                       -- Estatus - char(15)
                @Cliente,                           -- Cliente - char(10)
                @Sucursal,                          -- ClienteEnviarA - int
                @Moneda,                            -- ClienteMoneda - char(10)
                @TipoCambio,                        -- ClienteTipoCambio - float
                NULL,                               -- Vencimiento - datetime
                NULL,                               -- FormaCobro - varchar(50)
                @SumApli2,                          -- Importe - money
                0,                                  -- Impuestos - money
                1,                                  -- AplicaManual - bit
                0,                                  -- ConDesglose - bit
                @Mov,                               -- MovAplica - varchar(20)
                @RegresoMovID,                      -- MovAplicaID - varchar(20)
                @Comentarios,                       -- Comentarios - text
                @CentroDeCostos,                    -- ContUso - varchar(20)
                @Codigo
            );
            SET @a2ID = SCOPE_IDENTITY();
            INSERT INTO CxcD
            (
                ID,
                Renglon,
                RenglonSub,
                Importe,
                Aplica,
                AplicaID
            )
            VALUES
            (@a2ID, 2048, 0, @SumApli2, @Aplica, @AplicaID);
        END;
        ELSE
        BEGIN
            SELECT TOP 1
                @a2ID = c.ID
            FROM dbo.Cxc c
            WHERE c.Codigo = @Codigo
                  AND c.Mov = 'Aplicacion2'
                  AND c.Estatus IN ( 'CONCLUIDO', 'PENDIENTE', 'SINAFECTAR' )
            ORDER BY c.FechaRegistro DESC;
        END;

        --********************************************************************
        --		AFECTAR Aplicacion 2
        --********************************************************************
        IF EXISTS
        (
            SELECT c.Codigo
            FROM dbo.Cxc c
            WHERE c.Codigo = @Codigo
                  AND c.ID = @a2ID
                  AND c.Estatus = 'SINAFECTAR'
        )
           OR @Codigo IS NULL
        BEGIN
            BEGIN TRY
                EXEC spAfectar 'CXC',
                               @a2ID,
                               'AFECTAR',
                               'Todo',
                               NULL,
                               @Usuario,
                               NULL,
                               1,
                               @iError OUTPUT,
                               @sError OUTPUT;
                SELECT @sError = ml.Descripcion
                FROM dbo.MensajeLista ml
                WHERE ml.Mensaje = @iError;
            END TRY
            BEGIN CATCH
                SELECT @iError = ERROR_NUMBER(),
                       @sError
                           = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') '
                             + ERROR_MESSAGE();
            END CATCH;

            IF
            (
                SELECT A.Estatus FROM Cxc AS A WHERE A.ID = @a2ID
            ) = 'SINAFECTAR'
            BEGIN
                SET @sError
                    = 'Error al aplicar el movimiento de aplicación 2 de Intelisis: ' + 'Error = '
                      + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                      + ', el movimiento fue cancelado. Intente nuevamente.';
                EXEC Interfaz_LogsInsertar 'Interfaz_cxcInsertar',
                                           'Error',
                                           @sError,
                                           @Usuario,
                                           @LogParametrosXml;
                RAISERROR(@sError, 16, 1);
                RETURN;
            END;
        END;
    END;

    IF
    (
        SELECT c.Estatus FROM dbo.Cxc c WHERE c.ID = @RegresoID
    ) = 'CONCLUIDO'
    AND @Mov IN ( 'Cobro VE Gravado', 'Cobro TransInd' )
    AND NOT EXISTS
    (
        SELECT Documento
        FROM dbo.CFDICobroParcialTimbrado
        WHERE IDModulo = @RegresoID
    )
    BEGIN
        BEGIN TRY

            PRINT 'Generando CFDI de Cxc ID= ' + CAST(@RegresoID AS VARCHAR) + ' ' + RTRIM(@Mov) + ' '
                  + RTRIM(ISNULL(@RegresoMovID, '0'));

            /*Se crea la información para el CFDI Cobro Parcial*/
            EXEC dbo.spCFDICobroParcialMovimientosCxc @Estacion = @RegresoID, -- int -- Estación Turismo
                                                      @Empresa = 'TUN',       -- varchar(5)
                                                      @cID = @RegresoID;      -- int

            EXEC dbo.spCFDICobroParcialLimpiarCte @Estacion = @RegresoID;

            DELETE ListaID
            WHERE Estacion = @RegresoID; -- Elimina movimientos pendientes de esta estación
            /*Inserta nuevos movimiento para afectar*/
            INSERT dbo.ListaID
            (
                Estacion,
                ID
            )
            VALUES
            (   @RegresoID, -- Estacion - int
                @RegresoID  -- ID - int
            );
            /*Afecta y Genera el CFDI*/
            /*Afecta y Genera el CFDI*/
            EXEC dbo.spXMLPagosParciales @Estacion = @RegresoID, -- int
                                         @Empresa = @Empresa;    -- varchar(5)

            SELECT @sError = ISNULL(lg.Error, '')
            FROM dbo.CFDICobroParcialLog lg
            WHERE lg.IDCobro = @RegresoID;

            --                EXEC VE.TimbrarCobros @Estacion = @RegresoID, -- int
            --                    @Empresa = 'TUN', -- varchar(5)
            --                    @OkRef = @sError OUTPUT; -- varchar(max)
            ----EXEC dbo.spXMLPagosParciales @Estacion = @RegresoID, @Empresa = 'TUN';

            DELETE ListaID
            WHERE Estacion = @RegresoID; -- Elimina movimientos pendientes de esta estación

            SET @sError = 'Resultado Timbrado :' + RTRIM(ISNULL(@sError, 'CONCLUIDO'));
            PRINT @sError;

            EXEC Interfaz_LogsInsertar 'Interfaz_CxcInsertar',
                                       'Timbrado CFDI',
                                       @sError,
                                       @Usuario,
                                       @LogParametrosXml;
        END TRY
        BEGIN CATCH
            SELECT @iError = ERROR_NUMBER(),
                   @sError
                       = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') ' + ERROR_MESSAGE();
        END CATCH;

        IF NOT EXISTS
        (
            SELECT cpt.Documento
            FROM CFDICobroParcialTimbrado cpt
            WHERE cpt.IDModulo = @RegresoID
                  AND cpt.MovID = @RegresoMovID
        )
        BEGIN
            SET @sError
                = 'Error al timbrar el movimiento de Intelisis: ' + 'Error = '
                  + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                  + '. Intente nuevamente.';
            EXEC Interfaz_LogsInsertar 'Interfaz_CxcInsertar',
                                       'Error',
                                       @sError,
                                       @Usuario,
                                       @LogParametrosXml;
            RAISERROR(@sError, 16, 1);
        --RETURN;
        END;
    END;

    --********************************************************************
    --		INFORMACION DE RETORNO
    --********************************************************************
    IF EXISTS
    (
        SELECT *
        FROM CFD AS A
        WHERE A.ModuloID = @RegresoID
              AND A.MovID = @RegresoMovID
    )
       AND @Mov NOT IN ( 'Cobro VE Gravado', 'Cobro TransInd' )
    BEGIN
        SELECT ID = @RegresoID,
               MovID = @RegresoMovID,
               T2.Estatus,
               CASE
                   WHEN T1.UUID = NULL THEN
                       RTRIM(ISNULL(@sError, ''))
                   ELSE
                       RTRIM(T2.CFDFlexEstatus)
               END AS CFDFlexEstatus,
               CFDXML = CAST(T1.Documento AS VARCHAR(MAX)),
               T1.noCertificado,
               T1.Sello,
               T1.SelloSAT,
               T1.TFDCadenaOriginal,
               T1.UUID,
               T1.FechaTimbrado,
               T1.noCertificadoSAT
        FROM CFD AS T1
            INNER JOIN dbo.Cxc T2
                ON T2.ID = T1.ModuloID
                   AND T2.MovID = T1.MovID
        WHERE T1.ModuloID = @RegresoID
              AND T1.MovID = @RegresoMovID;

        SELECT @ID = @RegresoID,
               @MovID = @RegresoMovID,
               @Estatus = T2.Estatus,
               @CFDFlexEstatus = CASE
                                     WHEN T1.UUID = NULL THEN
                                         RTRIM(ISNULL(@sError, ''))
                                     ELSE
                                         RTRIM(T2.CFDFlexEstatus)
                                 END,
               @CFDXml = CAST(T1.Documento AS VARCHAR(MAX)),
               @noCertificado = T1.noCertificado,
               @Sello = T1.Sello,
               @SelloSAT = T1.SelloSAT,
               @TFDCadenaOriginal = T1.TFDCadenaOriginal,
               @UUID = T1.UUID,
               @FechaTimbrado = T1.FechaTimbrado,
               @noCertificadoSAT = T1.noCertificadoSAT
        FROM CFD AS T1
            INNER JOIN dbo.Cxc T2
                ON T2.ID = T1.ModuloID
                   AND T2.MovID = T1.MovID
        WHERE T1.ModuloID = @RegresoID
              AND T1.MovID = @RegresoMovID;
    END;
    ELSE
    BEGIN
        IF @Mov IN ( 'Cobro VE Gravado', 'Cobro TransInd' )
        BEGIN
            PRINT 'Resultado de ' + RTRIM(@Mov);
            SELECT ID = @RegresoID,
                   T2.MovID,
                   T2.Estatus,
                   (CASE
                        WHEN T1.Documento IS NOT NULL THEN
                            'CONCLUIDO'
                        ELSE
                            ISNULL(@sError, 'Error')
                    END
                   ) AS CFDFlexEstatus,
                   CFDXML = CAST(T1.Documento AS VARCHAR(MAX)),
                   T1.noCertificado,
                   T1.Sello,
                   T1.SelloSAT,
                   T1.TFDCadenaOriginal,
                   T1.UUID,
                   T1.FechaTimbrado,
                   T1.noCertificadoSAT
            FROM dbo.CFDICobroParcialTimbrado AS T1
                RIGHT JOIN dbo.Cxc T2
                    ON T2.ID = T1.IDModulo
                       AND T2.MovID = T1.MovID
            WHERE T2.ID = @RegresoID;

            SELECT @ID = @RegresoID,
                   @MovID = @RegresoMovID,
                   @Estatus = T2.Estatus,
                   @CFDFlexEstatus = (CASE
                                          WHEN T1.Documento IS NOT NULL THEN
                                              'CONCLUIDO'
                                          ELSE
                                              ISNULL(@sError, 'Error')
                                      END
                                     ),
                   @CFDXml = CAST(T1.Documento AS VARCHAR(MAX)),
                   @noCertificado = T1.noCertificado,
                   @Sello = T1.Sello,
                   @SelloSAT = T1.SelloSAT,
                   @TFDCadenaOriginal = T1.TFDCadenaOriginal,
                   @UUID = T1.UUID,
                   @FechaTimbrado = T1.FechaTimbrado,
                   @noCertificadoSAT = T1.noCertificadoSAT
            FROM dbo.CFDICobroParcialTimbrado AS T1
                RIGHT JOIN dbo.Cxc T2
                    ON T2.ID = T1.IDModulo
                       AND T2.MovID = T1.MovID
            WHERE T2.ID = @RegresoID;
        END;
        ELSE
        BEGIN
            SELECT ID = c.ID,
                   MovID = c.MovID,
                   Estatus = c.Estatus,
                   CFDFlexEstatus = c.CFDFlexEstatus,
                   CFDXML = NULL,
                   noCertificado = NULL,
                   Sello = NULL,
                   SelloSAT = NULL,
                   TFDCadenaOriginal = NULL,
                   UUID = NULL,
                   FechaTimbrado = NULL,
                   noCertificadoSAT = NULL
            FROM dbo.Cxc c
            WHERE c.ID = @RegresoID;

            SELECT @ID = c.ID,
                   @MovID = c.MovID,
                   @Estatus = c.Estatus,
                   @CFDFlexEstatus = c.CFDFlexEstatus,
                   @CFDXml = NULL,
                   @noCertificado = NULL,
                   @Sello = NULL,
                   @SelloSAT = NULL,
                   @TFDCadenaOriginal = NULL,
                   @UUID = NULL,
                   @FechaTimbrado = NULL,
                   @noCertificadoSAT = NULL
            FROM dbo.Cxc c
            WHERE c.ID = @RegresoID;
        END;
    END;
END;


GO
