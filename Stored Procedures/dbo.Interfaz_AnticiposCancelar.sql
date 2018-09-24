SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	23/02/2018
-- Descripción:		Cancelación de Anticipos.
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_AnticiposCancelar]
    @IDIntelisis AS INT ,
    @MovIdIntelisis AS VARCHAR(20) ,
    @Usuario AS CHAR(10) ,
    @Id AS INT = NULL OUTPUT ,
    @MovId AS VARCHAR(20) = NULL OUTPUT ,
    @Estatus AS VARCHAR(15) = NULL OUTPUT ,
    @Importe AS MONEY = NULL OUTPUT
AS
    SET NOCOUNT ON
-- *************************************************************************
--	Variables
-- *************************************************************************
	
    DECLARE @LogParametrosXml AS XML ,
        @sError AS VARCHAR(MAX) ,
        @iError AS INT;
    SET @LogParametrosXml = ( SELECT    @IDIntelisis AS 'ID' ,
                                        @MovIdIntelisis AS 'MovID' ,
                                        @Usuario AS 'Usuario'
                            FOR
                              XML PATH('Parametros')
                            );
	
    EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_AnticiposCancelar', -- varchar(255)
        @Tipo = 'Ejecución', -- varchar(255)
        @DetalleError = '', -- varchar(max)
        @Usuario = @Usuario, -- varchar(10)
        @Parametros = @LogParametrosXml -- xml
	                          
-- *************************************************************************
--	Validaciones
-- *************************************************************************
    SET @sError = NULL;
    IF ( @Usuario IS NULL
         OR RTRIM(LTRIM(@Usuario)) = ''
       )
        BEGIN
            SET @sError = 'Usuario no indicado. Por favor, indique un Usuario.';
        END
	
    IF NOT EXISTS ( SELECT  *
                    FROM    Usuario
                    WHERE   RTRIM(LTRIM(Usuario)) = RTRIM(LTRIM(@Usuario)) )
        BEGIN
            SET @sError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
        END

    IF ( SELECT Mov
         FROM   dbo.Cxc
         WHERE  ID = @IDIntelisis
                AND MovID = @MovIdIntelisis
       ) NOT IN ('CFD Anticipo', 'Cobro TransInd', 'Cobro VE Gravado')
        BEGIN
            SET @sError = 'El tipo de Movimiento, no se encuentra en el catalogo de movimientos validos para cancelar.';
        END

    IF NOT EXISTS ( SELECT  Mov
                    FROM    dbo.Cxc
                    WHERE   ID = @IDIntelisis
                            AND MovID = @MovIdIntelisis )
        BEGIN
            SET @sError = 'Movimiento no encontrado. Por favor, indique un Movimento valido.';
        END

    PRINT 'Resultado de Validacion General: ' + RTRIM(ISNULL(@sError, ' '));
    IF @sError IS NOT NULL
        BEGIN
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_AnticiposCancelar', -- varchar(255)
                @Tipo = 'Error', -- varchar(255)
                @DetalleError = @sError, -- varchar(max)
                @Usuario = @Usuario, -- varchar(10)
                @Parametros = @LogParametrosXml -- xml
            RAISERROR(@sError,16,1);
            RETURN;
        END

	
-- *************************************************************************
--	Validaciones
-- *************************************************************************
	
    BEGIN TRY
        PRINT 'Cancelando el movimiento: ' + RTRIM(@IDIntelisis);
        EXEC dbo.spAfectar @Modulo = 'CXC', -- char(5)
            @ID = @IDIntelisis, -- int
            @Accion = 'CANCELAR', -- char(20)
            @Base = 'Todo', -- char(20)
            @GenerarMov = NULL, -- char(20)
            @Usuario = @Usuario, -- char(10)
            @SincroFinal = NULL, -- bit
            @EnSilencio = 1, -- bit
            @Ok = @iError OUTPUT, -- int
            @OkRef = @sError OUTPUT; -- varchar(255)
		    
        PRINT 'Retorno SPAfectar: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));

        SELECT  @sError = ml.Descripcion + ' ' + RTRIM(ISNULL(@sError, ''))
        FROM    dbo.MensajeLista ml
        WHERE   ml.Mensaje = @iError;

        PRINT 'Codigo de Resultado: ' + CAST(ISNULL(@iError, 0) AS VARCHAR) + ' ' + RTRIM(ISNULL(@sError, ''));
    END TRY
	
    BEGIN CATCH
        SELECT  @iError = ERROR_NUMBER() ,
                @sError = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') ' + ERROR_MESSAGE();
    END CATCH
	
    IF EXISTS ( SELECT  *
                FROM    Cxc AS A
                WHERE   A.Estatus <> 'CANCELADO'
                        AND A.ID = @IDIntelisis )
        BEGIN
            SET @sError = 'Error al aplicar el movimiento de Intelisis: ' + 'Error = '
                + CAST(ISNULL(@iError, -1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@sError, '')
                + ', el movimiento no fue cancelado. Intente nuevamente.';
            
            EXEC dbo.Interfaz_LogsInsertar 'Interfaz_AnticiposCancelar', -- varchar(255)
                @Tipo = 'Error', -- varchar(255)
                @DetalleError = @sError, -- varchar(max)
                @Usuario = @Usuario, -- varchar(10)
                @Parametros = @LogParametrosXml -- xml
            RAISERROR(@sError,16,1);
            RETURN;
        END
	
-- *************************************************************************
--		INFORMACION DE RETORNO
-- *************************************************************************
   
    SELECT  A.ID ,
            A.MovID ,
            A.Estatus ,
            A.Importe
    FROM    Cxc AS A
    WHERE   A.ID = @IDIntelisis

    SELECT  @Id = A.ID ,
            @MovId = A.MovID ,
            @Estatus = A.Estatus ,
            @Importe = A.Importe
    FROM    Cxc AS A
    WHERE   A.ID = @IDIntelisis
GO
GRANT EXECUTE ON  [dbo].[Interfaz_AnticiposCancelar] TO [Linked_Svam_Pruebas]
GO
