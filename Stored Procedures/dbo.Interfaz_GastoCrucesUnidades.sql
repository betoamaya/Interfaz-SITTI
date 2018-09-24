SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	25/06/2018
-- Descripción:		Complementa Gastos de Casetas
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_GastoCrucesUnidades]
    @Empresa AS VARCHAR(5) ,
    @Id AS INT ,
    @MovID AS VARCHAR(20) ,
    @Usuario VARCHAR(10) ,
    @Observaciones VARCHAR(100) ,
    @Comentarios VARCHAR(MAX) ,
    @Partidas VARCHAR(MAX) = NULL ,
    @NumErr INT = NULL OUTPUT ,
    @Descripcion VARCHAR(255) = NULL OUTPUT
AS
    BEGIN
        SET NOCOUNT ON;
	-- ******************************************************
	--		VARIABLES
	-- ******************************************************
        DECLARE @LogParametrosXML AS XML ,
            @sQuery AS VARCHAR(MAX) ,
            @MensajeError AS VARCHAR(MAX) ,
            @Error AS INT ,
            @Mensaje AS VARCHAR(512) ,
            @Estatus VARCHAR(20) ,
            @PathCFDIXml AS VARCHAR(255) ,
            @xml AS XML ,
            @sRFC AS VARCHAR(20) ,
            @sReferencia AS VARCHAR(50) ,
            @sVersion AS VARCHAR(20);

        DECLARE @TMPXML TABLE
            (
              Reg INT IDENTITY ,
              Moneda VARCHAR(20) NULL ,
              FechaTimbrado DATETIME NULL ,
              RfcReceptor VARCHAR(50) NULL ,
              Total MONEY DEFAULT ( 0 ) ,
              UUID VARCHAR(MAX) NULL ,
              RfcEmisor VARCHAR(50) NULL ,
              Folio VARCHAR(40) NULL ,
              subTotal MONEY DEFAULT ( 0 )
            );

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
              FolioConv VARCHAR(10) ,
              Cliente VARCHAR(10) ,
              Sucursal INT ,
              Personal VARCHAR(10) ,
              Fecha DATETIME
            );

        SET @LogParametrosXML = ( SELECT    @Empresa AS 'Empresa' ,
                                            @Id AS 'Id' ,
                                            @MovID AS 'MovID' ,
                                            @Usuario AS 'Usuario' ,
                                            @Observaciones AS 'Observaciones' ,
                                            @Comentarios AS 'Comentarios' ,
                                            @Partidas AS 'Partidas'
                                FOR
                                  XML PATH('Parametros')
                                );

        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_GastoCrucesUnidades', @Tipo = 'Inserción', @DetalleError = '',
            @Usuario = @Usuario, @Parametros = @LogParametrosXML;

        SET @xml = CAST(@Partidas AS XML)
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
	-- ******************************************************
	--		VALIDACIONES
	-- ******************************************************
        PRINT 'Validaciones Generales';
        IF @Usuario <> 'SITTI'
            BEGIN
                SET @MensajeError = 'Usuario no valido. Por favor, indique un Usuario valido para la ejecución de este proceso.';
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación', @MensajeError,
                    @Usuario, @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        IF @Id IS NULL
            OR @Id = 0
            BEGIN
                SET @MensajeError = 'Id de movimiento nulo o igual a cero. Por favor, indique un Id de movimiento valido para la ejecución de este proceso.';
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación', @MensajeError,
                    @Usuario, @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        IF @MovID IS NULL
            OR LEN(@MovID) = '0'
            OR CAST(@MovID AS INT) = 0
            BEGIN
                SET @MensajeError = 'MovId de movimiento nulo o igual a cero. Por favor, indique un MovId de movimiento valido para la ejecución de este proceso.';
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación', @MensajeError,
                    @Usuario, @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        IF NOT EXISTS ( SELECT  g.ID
                        FROM    dbo.Gasto g
                        WHERE   g.MovID = @MovID
                                AND g.ID = @Id
                                AND g.Empresa = @Empresa )
            BEGIN
                SET @MensajeError = 'El Gasto indicado no es valido. No se encontro el gasto '
                    + RTRIM(CONVERT(VARCHAR, @MovID)) + ', por favor indique Gasto valido.';
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación', @MensajeError,
                    @Usuario, @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        IF EXISTS ( SELECT  g.Estatus
                    FROM    dbo.Gasto g
                    WHERE   g.MovID = @MovID
                            AND g.ID = @Id
                            AND g.Estatus NOT IN ( 'SINAFECTAR', 'BORRADOR' )
                            AND g.Empresa = @Empresa )
            BEGIN
                SET @MensajeError = 'El Gasto ' + RTRIM(CONVERT(VARCHAR, @MovID))
                    + ' no puede ser editado, debido a que su estatus es diferente a BORRADOR, por favor verifique en Intelisis.';
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación', @MensajeError,
                    @Usuario, @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
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

        IF EXISTS ( SELECT  tp.Concepto
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
                        EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                        EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                        EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                        EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                        EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                        EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                                    + RTRIM(CONVERT(VARCHAR, @Min)) + ' con el concepto: ' + RTRIM(( SELECT
                                                                                                        tp.Concepto
                                                                                                     FROM
                                                                                                        @tPartidas tp
                                                                                                     WHERE
                                                                                                        tp.ID = @Min
                                                                                                   ))
                                    + ' no tiene Unidad.' + ' Por favor, indique Unidad, para este Concepto.';
                                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
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
                        --IF ( RTRIM(@Mov) IN ( 'Solicitud SIVE', 'Comprobante' ) )
                        --    BEGIN
                        --        SET @MensajeError = 'Folio Convenio no indicado. La partida: '
                        --            + RTRIM(CONVERT(VARCHAR, @Min)) + ' con el concepto: ' + RTRIM(( SELECT
                        --                                                                                tp.Concepto
                        --                                                                             FROM
                        --                                                                                @tPartidas tp
                        --                                                                             WHERE
                        --                                                                                tp.ID = @Min
                        --                                                                           ))
                        --            + ' no tiene Folio Convenio.'
                        --            + ' Por favor, indique Folio Convenio, para este Concepto.';
                        --        EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error de Validación',
                        --            @MensajeError, @Usuario, @LogParametrosXML;
                        --        RAISERROR(@MensajeError, 16, 1);
                        --        RETURN;
                        --    END
                    END

			-- Se incrementa el ciclo
                SELECT  @Min = MIN(tp.ID)
                FROM    @tPartidas tp
                WHERE   tp.ID > @Min;
            END

	-- ******************************************************
	--		Proceso
	-- ******************************************************
        --SELECT  @IdGasto = g.ID
        --FROM    dbo.Gasto g
        --WHERE   g.MovID = @MovID
        --        AND g.Mov = @Mov
        --        AND g.Empresa = @Empresa;
		
        SELECT TOP 1
                @PathCFDIXml = am.Direccion
        FROM    dbo.AnexoMov AS am
        WHERE   am.ID = @Id
                AND am.Rama = 'GAS'
                AND am.Icono = 3
        ORDER BY am.Alta ASC

        PRINT @PathCFDIXml;

        IF ISNULL(@PathCFDIXml, '') = ''
            BEGIN
                SET @MensajeError = 'Error al consultar el archivo. No se encontro el archivo XML del Gasto'
                    + RTRIM(CONVERT(VARCHAR, @MovID)) + '.'
                
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error', @MensajeError, @Usuario,
                    @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        IF OBJECT_ID('TempDB..#GastoCFDI', 'U') IS NOT NULL
            BEGIN
                DROP TABLE #GastoCFDI;
            END

        CREATE TABLE #GastoCFDI ( Data XML );
        BEGIN TRY
            SELECT  @sQuery = 'INSERT INTO #GastoCFDI SELECT * FROM OPENROWSET (BULK ''' + @PathCFDIXml
                    + ''', SINGLE_BLOB) AS DATA';

            EXEC sp_sqlexec @sQuery;
        END TRY
        BEGIN CATCH
            SELECT  @Error = ERROR_NUMBER() ,
                    @Mensaje = RTRIM(CONVERT(VARCHAR(20), @Id)) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(), '') + ', ln '
                    + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(), '');

            PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE ' + RTRIM(@Mensaje);
            SET @MensajeError = 'Error al Consultar Archivo Xml: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE '
                + RTRIM(@Mensaje);
            SELECT  @NumErr = 1 ,
                    @Descripcion = @MensajeError;
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error', @MensajeError, @Usuario,
                @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END CATCH

        IF ( SELECT COUNT (*) FROM #GastoCFDI
           ) = 0
            BEGIN
                SET @MensajeError = 'Error al leer el archivo ' + RTRIM(@PathCFDIXml) + ' . ';
                
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error', @MensajeError, @Usuario,
                    @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        SELECT  @xml = Data
        FROM    #GastoCFDI;

        WITH XMLNAMESPACES('http://www.sat.gob.mx/cfd/3' AS cfdi) SELECT @sVersion = a.b.value('@Version','varchar(100)') FROM @XML.nodes('cfdi:Comprobante') a(b);
        IF @sVersion IS NULL
            BEGIN
                WITH XMLNAMESPACES('http://www.sat.gob.mx/cfd/3' AS cfdi) SELECT @sVersion = a.b.value('@version','varchar(100)') FROM @XML.nodes('cfdi:Comprobante') a(b);
            END

        PRINT 'Version de XML ' + RTRIM(@sVersion);

        IF @sVersion = '3.3'
            BEGIN
                WITH XMLNAMESPACES('http://www.sat.gob.mx/cfd/3' AS cfdi,'http://www.sat.gob.mx/TimbreFiscalDigital' AS tfd)
				INSERT INTO @TMPXML
					(Moneda,Folio,subTotal,Total,RfcEmisor,RfcReceptor, FechaTimbrado,UUID)
				SELECT
					a.b.value('@Moneda','varchar(100)') Moneda,
					a.b.value('@Folio','varchar(100)') Folio,
					a.b.value('@SubTotal','varchar(100)') subTotal,
					a.b.value('@Total','varchar(100)') Total,
					c.d.value('@Rfc','varchar(100)') RfcEmisor,
					e.f.value('@Rfc','varchar(100)') RfcReceptor,
					g.h.value('@FechaTimbrado','datetime') FechaTimbrado,
					g.h.value('@UUID','varchar(100)') UUID
				FROM @XML.nodes('cfdi:Comprobante') a(b)
					,@XML.nodes('cfdi:Comprobante/cfdi:Emisor') c(d)
					,@XML.nodes('cfdi:Comprobante/cfdi:Receptor') e(f)
					,@XML.nodes('cfdi:Comprobante/cfdi:Complemento/tfd:TimbreFiscalDigital') g(h)
            END
        ELSE
            BEGIN
                SET @MensajeError = 'Error al Consultar Archivo Xml: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE '
                    + RTRIM(@Mensaje);
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error', @MensajeError, @Usuario,
                    @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        IF ( SELECT COUNT (*) FROM @TMPXML
           ) > 0
            BEGIN
                SELECT TOP 1
                        @sReferencia = t.Folio ,
                        @sRFC = t.RfcEmisor
                FROM    @TMPXML AS t;
                UPDATE  @tPartidas
                SET     RFC = @sRFC ,
                        Referencia = @sReferencia;
            END
        ELSE
            BEGIN
                SET @MensajeError = 'Error: obtener los datos del XML asignado al gasto.' + RTRIM(@Mensaje);
                SELECT  @NumErr = 1 ,
                        @Descripcion = @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error', @MensajeError, @Usuario,
                    @LogParametrosXML;
                RAISERROR(@MensajeError, 16, 1);
                RETURN;
            END

        BEGIN TRY
            UPDATE  dbo.Gasto
            SET     Comentarios = @Comentarios ,
                    Observaciones = @Observaciones
            WHERE   ID = @Id;
-- ******************************************************
--		Depuración tabla de GastoD
-- ******************************************************
            DELETE  dbo.GastoD
            WHERE   ID = @Id;
-- ******************************************************
--		Inserción de Datos
-- ******************************************************
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
                    SELECT  ID = @Id ,
                            Renglon = 2048 * tp.ID ,
                            RenglonSub = 0 ,
                            Concepto = tp.Concepto ,
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
                    FROM    @tPartidas tp;

        END TRY
        BEGIN CATCH
            SELECT  @Error = ERROR_NUMBER() ,
                    @Mensaje = RTRIM(CONVERT(VARCHAR(20), @Id)) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(), '') + ', ln '
                    + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(), '');

            PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE ' + RTRIM(@Mensaje);
            SET @MensajeError = 'Error al registrar los conceptos: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE '
                + RTRIM(@Mensaje);
            SELECT  @NumErr = 1 ,
                    @Descripcion = @MensajeError;
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCrucesUnidades', 'Error', @MensajeError, @Usuario,
                @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END CATCH
        SELECT  @NumErr = 0 ,
                @Descripcion = 'Proceso Concluido.'; 
    END

GO
