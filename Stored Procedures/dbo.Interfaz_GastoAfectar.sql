SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	11/04/2018
-- Descripción:		Afecta los movimientos de Gasto.
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_GastoAfectar]
    @Usuario CHAR(10) ,
    @Id INT ,
    @NumErr INT = NULL OUTPUT ,
    @Descripcion VARCHAR(255) = NULL OUTPUT
AS
    SET NOCOUNT ON
    SET DATEFORMAT YMD

	-- ******************************************************
	--		VARIABLES
	-- ******************************************************

    DECLARE @LogParametrosXML XML;
    SET @LogParametrosXML = ( SELECT @Usuario AS 'Usuario', @Id AS 'Id'
                            FOR
                              XML PATH('Parametros')
                            );

    EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Ejecución', '', @Usuario, @LogParametrosXML;

    DECLARE @MensajeError AS VARCHAR(MAX) ,
        @Error AS INT ,
        @Mensaje AS VARCHAR(512) ,
        @Estatus VARCHAR(20);

	-- ******************************************************
	--		VALIDACIONES
	-- ******************************************************
    PRINT 'Validaciones Generales';
    IF @Usuario <> 'SITTI'
        BEGIN
            SET @MensajeError = 'Usuario no valido. Por favor, indique un Usuario valido para la ejecución de este proceso.';
            SELECT  @NumErr = 0 ,
                    @Descripcion = @MensajeError;
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Error de Validación', @MensajeError, @Usuario,
                @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF @Id IS NULL
        OR @Id = 0
        BEGIN
            SET @MensajeError = 'Id de movimiento nulo o igual a cero. Por favor, indique un Id de movimiento valido para la ejecución de este proceso.';
            SELECT  @NumErr = 0 ,
                    @Descripcion = @MensajeError;
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Error de Validación', @MensajeError, @Usuario,
                @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF NOT EXISTS ( SELECT  g.ID
                    FROM    dbo.Gasto g
                    WHERE   g.ID = @Id )
        BEGIN
            SET @MensajeError = 'El Id de movimiento indicado no es valido. El Id ' + RTRIM(CONVERT(VARCHAR, @Id))
                + ' no existe en Gasto, por favor indique Id valido.';
            SELECT  @NumErr = 0 ,
                    @Descripcion = @MensajeError;
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Error de Validación', @MensajeError, @Usuario,
                @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

    IF EXISTS ( SELECT  g.Estatus
                FROM    dbo.Gasto g
                WHERE   g.ID = @Id
                        AND g.Estatus = 'CANCELADO' )
        BEGIN
            SET @MensajeError = 'El Id de movimiento indicado esta cancelado. El Id ' + RTRIM(CONVERT(VARCHAR, @Id))
                + ' esta cancelado en Gasto, por favor verifique Id.';
            SELECT  @NumErr = 0 ,
                    @Descripcion = @MensajeError;
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Error de Validación', @MensajeError, @Usuario,
                @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END

	-- ******************************************************
	--		Proceso
	-- ******************************************************

    IF ( SELECT g.Estatus FROM dbo.Gasto g WHERE g.ID = @Id
       ) IN ( 'SINAFECTAR' ) /*Se Agrego esta validación, para que no se concluyeran los movimientos.*/
        BEGIN
            BEGIN TRY
                PRINT 'Afectando el Gasto ' + RTRIM(@Id);
                EXEC dbo.spAfectar @Modulo = 'GAS', @ID = @Id, @Accion = 'AFECTAR', @Base = 'Todo', @GenerarMov = NULL,
                    @Usuario = @Usuario, @SincroFinal = NULL, @EnSilencio = 1, @Ok = @Error OUTPUT,
                    @OkRef = @Mensaje OUTPUT;

                IF @Error IN ( 20900, 20901 )
                    BEGIN
                        SELECT  @Estatus = g.Estatus
                        FROM    dbo.Gasto AS g
                        WHERE   g.ID = @Id;

                        PRINT 'El Gasto ' + RTRIM(@Id) + ' tiene estatus ' + RTRIM(@Estatus);

                        PRINT 'El Gasto ' + RTRIM(@Id) + ' Requiere Autorización / '
                            + RTRIM(CAST(ISNULL(@Error, -1) AS VARCHAR(255))) + ', ' + RTRIM(ISNULL(@Mensaje, ''));;
                        IF ( SELECT g.Estatus FROM dbo.Gasto AS g WHERE g.ID = @Id
                           ) = 'SINAFECTAR'
                            BEGIN
                                PRINT 'Autorizando Gasto ' + RTRIM(@Id) + ' con usuario EYCRUZ'
                                EXEC dbo.spAfectar @Modulo = 'GAS', @ID = @Id, @Accion = 'AUTORIZAR', @Base = 'Todo',
                                    @GenerarMov = NULL, @Usuario = 'EYCRUZ', @SincroFinal = NULL, @EnSilencio = 1,
                                    @Ok = @Error OUTPUT, @OkRef = @Mensaje OUTPUT;
                            END
                    END
            END TRY

            BEGIN CATCH
                SELECT  @Error = ERROR_NUMBER() ,
                        @Mensaje = RTRIM(CONVERT(VARCHAR(20), @Id)) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(), '')
                        + ', ln ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(), '');

                PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE ' + RTRIM(@Mensaje);
            END CATCH
        END
    SELECT  @Estatus = g.Estatus
    FROM    dbo.Gasto AS g
    WHERE   g.ID = @Id;

    PRINT 'El Gasto ' + RTRIM(@Id) + ' tiene estatus ' + RTRIM(@Estatus);
    IF ( SELECT RTRIM(g.Estatus)
         FROM   dbo.Gasto g
         WHERE  g.ID = @Id
       ) = 'SINAFECTAR'
        BEGIN
            SET @MensajeError = 'Ocurrio un error al aplicar el movimiento ' + RTRIM(CONVERT(VARCHAR, @Id))
                + ' / Error = ' + RTRIM(CAST(ISNULL(@Error, -1) AS VARCHAR(255))) + ', Mensaje = '
                + RTRIM(ISNULL(@Mensaje, ''));
            SELECT  @NumErr = 0 ,
                    @Descripcion = @MensajeError;
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Error', @MensajeError, @Usuario, @LogParametrosXML;
            RAISERROR(@MensajeError, 16, 1);
            RETURN;
        END
    IF ( SELECT RTRIM(ISNULL(g.Situacion, ''))
         FROM   dbo.Gasto g
         WHERE  g.ID = @Id
       ) <> 'Autorizado'
        BEGIN
            PRINT 'El Gasto ' + RTRIM(@Id) + ' tiene situación diferente a Autorizado';
            IF ( SELECT RTRIM(g.Estatus)
                 FROM   dbo.Gasto g
                 WHERE  g.ID = @Id
                        AND g.Mov = 'Comprobante'
               ) = 'BORRADOR'
                BEGIN
                    BEGIN TRY
                        PRINT 'Cambiando situación de Gasto ' + RTRIM(@Id) + ' a Autorizado';	
                        EXEC dbo.spCambiarSituacion @Modulo = 'GAS', @ID = @Id, @Situacion = 'Autorizado',
                            @SituacionFecha = NULL, @Usuario = 'EYCRUZ', @SituacionUsuario = 'EYCRUZ',
                            @SituacionNota = NULL;
                    END TRY
                    BEGIN CATCH
                        SELECT  @Error = ERROR_NUMBER() ,
                                @Mensaje = RTRIM(CONVERT(VARCHAR(20), @Id)) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(), '')
                                + ', ln ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(),
                                                                                                      '');
                        PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE ' + RTRIM(@Mensaje);
                    END CATCH
                    IF ( SELECT RTRIM(g.Situacion)
                         FROM   dbo.Gasto g
                         WHERE  g.ID = @Id
                       ) <> 'Autorizado'
                        BEGIN
                            SET @MensajeError = 'Ocurrio un error al cambiar la situación del movimiento '
                                + RTRIM(CONVERT(VARCHAR, @Id)) + ' / Error = '
                                + RTRIM(CAST(ISNULL(@Error, -1) AS VARCHAR(255))) + ', Mensaje = '
                                + RTRIM(ISNULL(@Mensaje, ''));
                            SELECT  @NumErr = 0 ,
                                    @Descripcion = @MensajeError;
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Error', @MensajeError, @Usuario,
                                @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END
                END

            IF ( SELECT g.Estatus
                 FROM   dbo.Gasto g
                 WHERE  g.ID = @Id
                        AND g.Mov <> 'Comprobante'
               ) = 'PENDIENTE'
                BEGIN
                    BEGIN TRY
                        PRINT 'Cambiando situación de Gasto ' + RTRIM(@Id) + ' a Autorizado';	
                        EXEC dbo.spCambiarSituacion @Modulo = 'GAS', @ID = @Id, @Situacion = 'Autorizado',
                            @SituacionFecha = NULL, @Usuario = 'EYCRUZ', @SituacionUsuario = 'EYCRUZ',
                            @SituacionNota = NULL;
                    END TRY
                    BEGIN CATCH
                        SELECT  @Error = ERROR_NUMBER() ,
                                @Mensaje = RTRIM(CONVERT(VARCHAR(20), @Id)) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(), '')
                                + ', ln ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(),
                                                                                                      '');
                        PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@Error) + ' ERROR_LINE ' + RTRIM(@Mensaje);
                    END CATCH
                    IF ( SELECT RTRIM(g.Situacion)
                         FROM   dbo.Gasto g
                         WHERE  g.ID = @Id
                       ) <> 'Autorizado'
                        BEGIN
                            SET @MensajeError = 'Ocurrio un error al cambiar la situación del movimiento '
                                + RTRIM(CONVERT(VARCHAR, @Id)) + ' / Error = '
                                + RTRIM(CAST(ISNULL(@Error, -1) AS VARCHAR(255))) + ', Mensaje = '
                                + RTRIM(ISNULL(@Mensaje, ''));
                            SELECT  @NumErr = 0 ,
                                    @Descripcion = @MensajeError;
                            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoAfectar', 'Error', @MensajeError, @Usuario,
                                @LogParametrosXML;
                            RAISERROR(@MensajeError, 16, 1);
                            RETURN;
                        END
                END
        END
	
	-- ******************************************************
	--		Parametros de Retorno
	-- ******************************************************

    SELECT  @NumErr = 1 ,
            @Descripcion = 'Se afecto correctamente el movimiento.';

    SELECT  @NumErr AS 'NumErr' ,
            @Descripcion AS 'Descripcion';
GO
GRANT EXECUTE ON  [dbo].[Interfaz_GastoAfectar] TO [Linked_Svam_Pruebas]
GO
