SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	30/04/2018
-- Descripción:		Insersión de movimientos de Gasto
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_GastoInsertarMovimiento]
    @Empresa VARCHAR(5) ,
    @Mov VARCHAR(20) ,
    @FechaEmision SMALLDATETIME ,
    @Moneda VARCHAR(10) ,
    @TipoCambio FLOAT ,
    @Usuario VARCHAR(10) ,
    @Referencia VARCHAR(50) ,
    @Proveedor VARCHAR(10) ,
    @FechaRequerida SMALLDATETIME ,
    @Observaciones VARCHAR(100) ,
    @Comentarios VARCHAR(MAX) ,
    @Antecedente VARCHAR(20) = NULL ,
    @AntecendenteId VARCHAR(20) = NULL ,
    @Clasificacion VARCHAR(50) = NULL ,
    @Partidas VARCHAR(MAX) = NULL
AS
    SET NOCOUNT ON
    SET DATEFORMAT YMD
	
	-- ******************************************************
	--		VARIABLES
	-- ******************************************************

	--Claudia
    IF @Proveedor = 'E034748'
        BEGIN
            SET @Proveedor = 'E0034748'
        END

    DECLARE @LogParametrosXML XML;
    SET @LogParametrosXML = ( SELECT    @Empresa AS 'Empresa' ,
                                        @Mov AS 'Mov' ,
                                        @FechaEmision AS 'FechaEmision' ,
                                        @Moneda AS 'Moneda' ,
                                        @TipoCambio AS 'TipoCambio' ,
                                        @Usuario AS 'Usuario' ,
                                        @Referencia AS 'Referencia' ,
                                        @Proveedor AS 'Proveedor' ,
                                        @FechaRequerida AS 'FechaRequerida' ,
                                        @Observaciones AS 'Observaciones' ,
                                        @Comentarios AS 'Comentarios' ,
                                        @Antecedente AS 'Antecedente' ,
                                        @AntecendenteId AS 'AntecedenteId' ,
                                        @Clasificacion AS 'Clasificiacion' ,
                                        @Partidas AS 'Partidas'
                            FOR
                              XML PATH('Parametros')
                            );

    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Inserción', '', @Usuario, @LogParametrosXML;

    DECLARE @Clase AS VARCHAR(50) ,
        @Importe AS MONEY ,
        @Impuestos AS MONEY ,
        @MensajeError AS VARCHAR(MAX) ,
        @MensajeCompleto AS VARCHAR(MAX) ,
        @RegresoId AS INT ,
        @RegresoMovId AS INT ,
        @Error AS INT ,
        @Mensaje AS VARCHAR(512) ,
        @SubClase AS VARCHAR(50) ,
        @PathDestino AS VARCHAR(300);
	
    DECLARE @tPartidas AS TABLE
        (
          ID INT IDENTITY(1, 1)
                 NOT NULL ,
          Cantidad INT ,
          Precio MONEY ,
          Impuestos MONEY ,
          CentroDeCosto VARCHAR(20) ,
          Referencia VARCHAR(50) ,
          Concepto VARCHAR(50) ,
          RFC VARCHAR(20) ,
          Espacio VARCHAR(20) ,
          FolioConv VARCHAR(10) , -- Rentabilidad
          Cliente VARCHAR(10) , --Rentabilidad
          Sucursal INT , -- Rentabilidad
          Personal VARCHAR(10) , --Agregado por solicitud de Contabilidad 16/09/2016
          Fecha DATETIME --Agregado por solicitud de Contabilidad 16/09/2016
		);

    DECLARE @XML XML;
    SET @XML = CAST(@Partidas AS XML)
    IF NOT @Partidas IS NULL
        BEGIN
            INSERT  INTO @tPartidas
                    SELECT  T.Loc.value('@Cantidad', 'int') AS Cantidad ,
                            T.Loc.value('@Precio', 'money') AS Precio ,
                            T.Loc.value('@Impuestos', 'money') AS Impuestos ,
                            T.Loc.value('@CentroDeCosto', 'varchar(20)') AS CentroDeCosto ,
                            T.Loc.value('@Referencia', 'varchar(50)') AS Referencia ,
                            T.Loc.value('@Concepto', 'varchar(50)') AS Concepto ,
                            T.Loc.value('@RFC', 'varchar(20)') AS RFC ,
                            T.Loc.value('@Espacio', 'varchar(20)') AS Espacio ,
                            T.Loc.value('@FolioConv', 'varchar(10)') AS FolioConv ,
                            T.Loc.value('@Cliente', 'varchar(10)') AS Cliente ,
                            T.Loc.value('@Sucursal', 'int') AS Sucursal ,
                            T.Loc.value('@Personal', 'varchar(10)') AS Personal , --Agregado por solicitud de Contabilidad 16/09/2016
                            T.Loc.value('@Fecha', 'datetime') AS Fecha --Agregado por solicitud de Contabilidad 16/09/2016
                    FROM    @xml.nodes('//row/fila') AS T ( Loc )
        END

	--SELECT * FROM @tPartidas;

    DECLARE @Result_SP TABLE
        (
          ID INT IDENTITY(1, 1)
                 NOT NULL ,
          Empresa VARCHAR(5) ,
          Mov VARCHAR(20) ,
          MovId VARCHAR(20) ,
          EMPD VARCHAR(10) ,
          PROVD VARCHAR(20) ,
          EJERD VARCHAR(10) ,
          MESD VARCHAR(10) ,
          IDD VARCHAR(20) ,
          PathOrig VARCHAR(300) ,
          PathDest VARCHAR(300)
        );
	
	-- ******************************************************
	--		VALIDACIONES
	-- ******************************************************

    IF ( @Empresa IS NULL
         OR RTRIM(LTRIM(@Empresa)) = ''
       )
        BEGIN
            SET @MensajeError = 'Empresa no indicada. Por favor, indique una Empresa';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF ( @Mov IS NULL
         OR RTRIM(LTRIM(@Mov)) = ''
       )
        BEGIN
            SET @MensajeError = 'Movimiento no indicado. Por favor, indique un Movimiento.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF ( @FechaEmision IS NULL )
        BEGIN
            SET @MensajeError = 'Fecha de Emisión no indicada. Por favor, indique una Fecha de Emisión.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF ( @Moneda IS NULL
         OR RTRIM(LTRIM(@Moneda)) = ''
       )
        BEGIN
            SET @MensajeError = 'Moneda no indicada. Por favor, indique una Moneda.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF ( RTRIM(LTRIM(@Moneda)) <> 'Pesos'
         AND RTRIM(LTRIM(@Moneda)) <> 'Dolares'
       )
        BEGIN
            SET @MensajeError = 'La Moneda indicada no es ni "Pesos" ni "Dolares" (Moneda indicada "'
                + RTRIM(LTRIM(@Moneda)) + '"). Por favor, indique una Moneda valida.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF ( @TipoCambio IS NULL
         OR @TipoCambio <= 0
       )
        BEGIN
            SET @MensajeError = 'Tipo de cambio no indicado o menor o igual que cero. Por favor, indique un Tipo de cambio mayor que cero.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF ( @Usuario IS NULL
         OR RTRIM(LTRIM(@Usuario)) = ''
       )
        BEGIN
            SET @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF NOT EXISTS ( SELECT  *
                    FROM    dbo.Usuario u
                    WHERE   RTRIM(LTRIM(u.Usuario)) = RTRIM(LTRIM(@Usuario)) )
        BEGIN
            SET @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END
    IF ( @Proveedor IS NULL
         OR RTRIM(LTRIM(@Proveedor)) = ''
       )
        BEGIN
            SET @MensajeError = 'Proveedor no indicado. Por favor, indique un Proveedor.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF ( @FechaRequerida IS NULL )
        BEGIN
            SET @MensajeError = 'Fecha requerida no indicada. Por favor, indique una Fecha requerida.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END
	
	-- Según Movimiento
    IF @Mov = 'Comprobante'
        BEGIN
            IF @Usuario = 'SITTI'
                BEGIN
                    IF ( @Antecedente IS NULL
                         OR @AntecendenteId IS NULL
                         OR RTRIM(LTRIM(@Antecedente)) = ''
                         OR RTRIM(LTRIM(@AntecendenteId)) = ''
                       )
                        BEGIN
                            SET @MensajeError = 'No se especificaron los origenes del comprobante, favor de indicar Antecedente y Atecedente ID';
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                                @MensajeError, @Usuario, @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END
					
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END
        END
    ELSE
        BEGIN
            IF @Mov IN ( 'Solicitud Gasto', 'Solicitud SIVE' )
                BEGIN
                    IF @Usuario <> 'SITTI'
                        BEGIN
                            SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                                @MensajeError, @Usuario, @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Movimiento no valido. El Movimiento que indico no es uno de los movimientos esperados. Por favor, indique un Movimiento valido.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END
        END

    IF @Partidas IS NULL
        OR RTRIM(LTRIM(@Partidas)) = ''
        BEGIN
            SET @MensajeError = 'Partidas no indicadas. Por favor, indique Partidas.';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF EXISTS ( SELECT  *
                FROM    @tPartidas tp
                WHERE   ISNULL(tp.Concepto, '') = '' )
        BEGIN
            SET @MensajeError = 'Uno o mas conceptos, no fueron indicados';
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación', @MensajeError,
                @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    DECLARE @Min INT ,
        @Max INT;
    SELECT  @Min = MIN(tp.ID)
    FROM    @tPartidas tp;
    SELECT  @Max = MAX(tp.ID)
    FROM    @tPartidas tp;

    WHILE @Min <= @Max
        BEGIN
            IF NOT EXISTS ( SELECT  tp.Concepto
                            FROM    @tPartidas tp
                                    INNER JOIN dbo.Concepto c ON tp.Concepto = c.Concepto
                                                                 AND c.Modulo = 'GAS'
                            WHERE   tp.ID = @Min )
                BEGIN
                    SET @MensajeError = 'Concepto no valido. La partida: ' + RTRIM(CONVERT(VARCHAR, @Min))
                        + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                         FROM   @tPartidas tp
                                                         WHERE  tp.ID = @Min
                                                       )) + ' no es valido. Por favor, indique un Concepto valido.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END

            IF ( SELECT tp.Cantidad
                 FROM   @tPartidas tp
                 WHERE  tp.ID = @Min
               ) <= 0
                BEGIN
                    SET @MensajeError = 'Cantidad menor o igual a cero. La partida: ' + RTRIM(CONVERT(VARCHAR, @Min))
                        + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                         FROM   @tPartidas tp
                                                         WHERE  tp.ID = @Min
                                                       )) + ' con Cantidad asignada menor o igual a cero.'
                        + ' Por favor, indique un Cantidad valida, para este Concepto.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END

            IF ( SELECT tp.Precio FROM @tPartidas tp WHERE tp.ID = @Min
               ) <= 0
                BEGIN
                    SET @MensajeError = 'Precio menor o igual a cero. La partida: ' + RTRIM(CONVERT(VARCHAR, @Min))
                        + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                         FROM   @tPartidas tp
                                                         WHERE  tp.ID = @Min
                                                       )) + ' con Precio capturado menor o igual a cero.'
                        + ' Por favor, indique un Precio valido, para este Concepto.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END

            IF ( SELECT tp.CentroDeCosto
                 FROM   @tPartidas tp
                 WHERE  tp.ID = @Min
               ) = ''
                BEGIN
                    SET @MensajeError = 'Centro de Costos no indicado. La partida: ' + RTRIM(CONVERT(VARCHAR, @Min))
                        + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                         FROM   @tPartidas tp
                                                         WHERE  tp.ID = @Min
                                                       )) + ' no tiene Centro de Costos indicado.'
                        + ' Por favor, indique Centro de Costos, para este Concepto.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END

            IF NOT EXISTS ( SELECT  tp.CentroDeCosto
                            FROM    @tPartidas tp
                                    INNER JOIN dbo.CentroCostos cc ON cc.CentroCostos = tp.CentroDeCosto
                            WHERE   tp.ID = @Min )
                BEGIN
                    SET @MensajeError = 'Centro de Costos indicado no es Valido. La partida: '
                        + RTRIM(CONVERT(VARCHAR, @Min)) + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                                                         FROM   @tPartidas tp
                                                                                         WHERE  tp.ID = @Min
                                                                                       ))
                        + ' indica Centro de Costos que no se encuentra en Intelisis.'
                        + ' Por favor, indique Centro de Costos valido, para este Concepto.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END

            IF ( SELECT LEN(tp.Espacio)
                 FROM   @tPartidas tp
                 WHERE  tp.ID = @Min
               ) > 0
                AND ( SELECT    LEN(tp.Espacio)
                      FROM      @tPartidas tp
                      WHERE     tp.ID = @Min
                    ) < 5
                BEGIN
                    SET @MensajeError = 'Unidad (Espacio) indicado con un numero de caracteres diferente a 5. La partida: '
                        + RTRIM(CONVERT(VARCHAR, @Min)) + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                                                         FROM   @tPartidas tp
                                                                                         WHERE  tp.ID = @Min
                                                                                       ))
                        + ' indica una Unidad con un numero de caracteres diferente a 5.'
                        + ' Por favor, indique Unidad correcta, para este Concepto.';
                    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                        @MensajeError, @Usuario, @LogParametrosXML;
                    RAISERROR(@MensajeError, 16, 1);
                    RETURN;
                END

            IF ( SELECT RTRIM(ISNULL(tp.FolioConv, ''))
                 FROM   @tPartidas tp
                 WHERE  tp.ID = @Min
               ) <> ''
                BEGIN
                    IF ( SELECT RTRIM(ISNULL(tp.Espacio, ''))
                         FROM   @tPartidas tp
                         WHERE  tp.ID = @Min
                       ) = ''
                        BEGIN
                            SET @MensajeError = 'Unidad (Espacio) no indicado. La partida: '
                                + RTRIM(CONVERT(VARCHAR, @Min)) + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                                                                 FROM   @tPartidas tp
                                                                                                 WHERE  tp.ID = @Min
                                                                                               )) + ' no tiene Unidad.'
                                + ' Por favor, indique Unidad, para este Concepto.';
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                                @MensajeError, @Usuario, @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END
			
                    IF ( SELECT RTRIM(ISNULL(tp.Cliente, ''))
                         FROM   @tPartidas tp
                         WHERE  tp.ID = @Min
                       ) = ''
                        BEGIN
                            SET @MensajeError = 'Cliente no indicado. La partida: ' + RTRIM(CONVERT(VARCHAR, @Min))
                                + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                                 FROM   @tPartidas tp
                                                                 WHERE  tp.ID = @Min
                                                               )) + ' no tiene Cliente.'
                                + ' Por favor, Cliente, para este Concepto.';
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                                @MensajeError, @Usuario, @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END

                    IF ( SELECT RTRIM(ISNULL(tp.Sucursal, ''))
                         FROM   @tPartidas tp
                         WHERE  tp.ID = @Min
                       ) = ''
                        BEGIN
                            SET @MensajeError = 'Sucursal no indicada. La partida: ' + RTRIM(CONVERT(VARCHAR, @Min))
                                + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                                 FROM   @tPartidas tp
                                                                 WHERE  tp.ID = @Min
                                                               )) + ' no tiene Sucursal.'
                                + ' Por favor, indique Sucursal, para este Concepto.';
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                                @MensajeError, @Usuario, @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    UPDATE  @tPartidas
                    SET     Sucursal = ''
                    WHERE   ID = @Min;
                    IF ( RTRIM(@Mov) IN ( 'Solicitud SIVE', 'Comprobante' ) )
                        BEGIN
                            SET @MensajeError = 'Folio Convenio no indicado. La partida: ' + RTRIM(CONVERT(VARCHAR, @Min))
                                + ' con el concepto: ' + RTRIM(( SELECT tp.Concepto
                                                                 FROM   @tPartidas tp
                                                                 WHERE  tp.ID = @Min
                                                               )) + ' no tiene Folio Convenio.'
                                + ' Por favor, indique Folio Convenio, para este Concepto.';
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error de Validación',
                                @MensajeError, @Usuario, @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END
                END

			-- Se incrementa el ciclo
            SELECT  @Min = MIN(tp.ID)
            FROM    @tPartidas tp
            WHERE   tp.ID > @Min;
        END

	-- ******************************************************
	--		Inserción del Movimiento
	-- ******************************************************
	
    SELECT  @Importe = SUM(tp.Cantidad * tp.Precio) ,
            @Impuestos = SUM(tp.Impuestos)
    FROM    @tPartidas tp;

    INSERT  INTO dbo.Gasto
            ( dbo.Gasto.Empresa ,
              dbo.Gasto.Mov ,
              dbo.Gasto.FechaEmision ,
              dbo.Gasto.Moneda ,
              dbo.Gasto.TipoCambio ,
              dbo.Gasto.Usuario ,
              dbo.Gasto.Observaciones ,
              dbo.Gasto.Estatus ,
              dbo.Gasto.Acreedor ,
              dbo.Gasto.Vencimiento ,
              dbo.Gasto.FechaRegistro ,
              dbo.Gasto.FechaRequerida ,
              dbo.Gasto.Comentarios ,
              dbo.Gasto.Clase ,
              dbo.Gasto.Subclase ,
              dbo.Gasto.Importe ,
              dbo.Gasto.Impuestos ,
              dbo.Gasto.MovAplica ,
              dbo.Gasto.MovAplicaID
	        )
    VALUES  ( @Empresa , -- Empresa - char
              @Mov , -- Mov - char
              dbo.Fn_QuitarHrsMin(@FechaEmision) , -- FechaEmision - datetime
              @Moneda , -- Moneda - char
              @TipoCambio , -- TipoCambio - float
              @Usuario , -- Usuario - char
              @Observaciones , -- Observaciones - varchar
              'SINAFECTAR' , -- Estatus - char
              @Proveedor , -- Acreedor - char
              DATEADD(DAY, 5, @FechaEmision) , -- Vencimiento - datetime
              GETDATE() , -- FechaRegistro - datetime
              @FechaRequerida , -- FechaRequerida - datetime
              @Comentarios , -- Comentarios - text
              @Clase , -- Clase - varchar
              @SubClase , -- Subclase - varchar
              @Importe , -- Importe - money
              @Impuestos , -- Impuestos - money
              @Antecedente , -- MovAplica - char
              @AntecendenteId -- MovAplicaID - varchar
	        )
    SET @RegresoId = SCOPE_IDENTITY();

    INSERT  INTO dbo.GastoD
            ( ID ,
              Renglon ,
              RenglonSub ,
              Concepto ,
		--dbo.GastoD.Fecha,
              Referencia ,
              Cantidad ,
              Precio ,
              Importe ,
              Impuestos ,
              ContUso ,
              Espacio ,
			  /*Cambio Solicitado por Marco el 30/04/2018*/
              DescripcionExtra ,
              ABC ,
              Recurso ,
              --dbo.GastoD.DescripcionExtra , --FolioConv
              --dbo.GastoD.ContUso2 ,-- IdCliente
              --dbo.GastoD.ContUso3 , -- sucursal
              RFCComprobante ,
              Personal , --Agregado por solicitud de Contabilidad 16/09/2016
              Fecha --Agregado por solicitud de Contabilidad 16/09/2016
	        )
            SELECT  ID = @RegresoId ,
                    Renglon = 2048 * tp.ID ,
                    RenglonSub = 0 ,
                    Concepto = tp.Concepto ,
		--Fecha = @FechaEmision,
                    Referencia = CASE WHEN RTRIM(LTRIM(tp.Referencia)) = '' THEN NULL
                                      ELSE tp.Referencia
                                 END ,
                    Cantidad = tp.Cantidad ,
                    Precio = tp.Precio ,
                    Importe = tp.Cantidad * tp.Precio ,
                    Impuestos = tp.Impuestos ,
                    ContUso = tp.CentroDeCosto ,
                    Espacio = tp.Espacio ,
                    tp.FolioConv ,
                    tp.Cliente ,
                    tp.Sucursal ,
                    RfCComprobante = tp.RFC ,
                    Personal = ( CASE WHEN tp.Personal = '' THEN NULL
                                      ELSE CONVERT(INT, tp.Personal)
                                 END ) , --Agregado por solicitud de Contabilidad 16/09/2016
                    Fecha = tp.Fecha --Agregado por solicitud de Contabilidad 16/09/2016
            FROM    @tPartidas tp

	--SELECT * FROM dbo.GastoD WHERE ID = @RegresoId;
	

	-- ******************************************************
	--		GENERAR CONSECUTIVO
	-- ******************************************************

    BEGIN TRY
        EXEC dbo.spAfectar @Modulo = 'GAS', @ID = @RegresoId, @Accion = 'Consecutivo', @Base = 'Todo',
            @GenerarMov = NULL, @Usuario = @Usuario, @SincroFinal = NULL, @EnSilencio = 1, @Ok = @Error OUTPUT,
            @OkRef = @Mensaje OUTPUT
    END TRY

    BEGIN CATCH
        SELECT  @Error = ERROR_NUMBER() ,
                @Mensaje = CONVERT(VARCHAR(20), @RegresoId) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(), '') + ', ln '
                + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(), '');
    END CATCH

    SELECT  @RegresoMovId = g.MovID
    FROM    dbo.Gasto g
    WHERE   g.ID = @RegresoId;

	-- SI NO SE GENERA CONSECUTIVO
    IF @RegresoMovId IS NULL
        BEGIN
            SET @MensajeError = RTRIM(CONVERT(VARCHAR(20), @RegresoId)) + '/ Error = '
                + RTRIM(CAST(ISNULL(@Error, -1) AS VARCHAR(255))) + ', Mensaje = ' + RTRIM(ISNULL(@Mensaje, ''));
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoInsertarMovimiento', 'Error', @MensajeError, @Usuario,
                @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

	-- ******************************************************
	--		OBTENER RUTA DESTINO
	-- ******************************************************

    INSERT  @Result_SP
            EXEC dbo.spSelUbicDestXmlyPdf_Macv @ID = @RegresoId, @Mod = 'gas';

    SELECT TOP 1
            @PathDestino = rs.PathDest
    FROM    @Result_SP rs 

	-- ******************************************************
	--		RESULTADOS
	-- ******************************************************

    SELECT  ID = @RegresoId ,
            MovID = @RegresoMovId ,
            PathDestino = @PathDestino;
GO
GRANT EXECUTE ON  [dbo].[Interfaz_GastoInsertarMovimiento] TO [Linked_Svam_Pruebas]
GO
