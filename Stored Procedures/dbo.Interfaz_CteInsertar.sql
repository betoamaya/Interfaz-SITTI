SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	11/01/2018
-- Descripción:		Alta de Usuarios
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_CteInsertar]
    @Usuario VARCHAR(10) ,
    @Grupo VARCHAR(50) ,
    @RFC VARCHAR(20) ,
    @Nombre VARCHAR(255) ,
    @Direccion VARCHAR(100) ,
    @DireccionNumero VARCHAR(20) ,
    @DireccionNumeroInt VARCHAR(20) ,
    @EntreCalles VARCHAR(100) ,
    @Colonia VARCHAR(100) ,
    @Poblacion VARCHAR(100) ,
    @Estado VARCHAR(30) ,
    @Pais VARCHAR(30) ,
    @CodigoPostal VARCHAR(15) ,
    @Telefonos VARCHAR(100) ,
    @Extencion VARCHAR(10) ,
    @Fax VARCHAR(50) ,
    @Contacto VARCHAR(50) ,
    @Email VARCHAR(50)
AS
    BEGIN
        SET NOCOUNT ON;
        SET DATEFORMAT DMY;
-- =============================================
-- Variables
-- =============================================
        DECLARE @UltimoId AS INT ,
            @sCliente AS VARCHAR(10) ,
            @iError AS INT ,
            @sDescripcion AS VARCHAR(MAX) ,
            @LogParametrosXML AS XML;
        SET @RFC = UPPER(@RFC);
        SET @LogParametrosXML = ( SELECT    @Usuario AS 'sUsuario' ,
                                            @Grupo AS 'sGrupo' ,
                                            @RFC AS 'sRFC' ,
                                            @Nombre AS 'sNombre' ,
                                            @Direccion AS 'sDireccion' ,
                                            @DireccionNumero AS 'sDireccionNumero' ,
                                            @DireccionNumeroInt AS 'sDireccionNumeroInt' ,
                                            @EntreCalles AS 'sEntreCalles' ,
                                            @Colonia AS 'sColonia' ,
                                            @Poblacion AS 'sPoblacion' ,
                                            @Estado AS 'sEstado' ,
                                            @Pais AS 'sPais' ,
                                            @CodigoPostal AS 'sCodigoPostal' ,
                                            @Telefonos AS 'sTelefonos' ,
                                            @Extencion AS 'sExtencion' ,
                                            @Fax AS 'sFax' ,
                                            @Contacto AS 'sContacto' ,
                                            @Email AS 'sEmail'
                                FOR
                                  XML PATH('Parametros')
                                );
        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
            @Tipo = 'Inserción', -- varchar(255)
            @DetalleError = '', -- varchar(max)
            @Usuario = @Usuario, -- varchar(10)
            @Parametros = @LogParametrosXML; -- xml
-- =============================================
-- Validaciones
-- =============================================
        
        IF NOT EXISTS ( SELECT  u.Usuario
                        FROM    dbo.Usuario u
                        WHERE   RTRIM(LTRIM(u.Usuario)) = RTRIM(LTRIM(@Usuario)) )
            BEGIN
                SET @sDescripcion = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @RFC IS NULL
             OR RTRIM(LTRIM(@RFC)) = ''
           )
            BEGIN
                SET @sDescripcion = 'RFC no encontrado. Por favor, indique un RFC valido.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF EXISTS ( SELECT  c.RFC
                    FROM    dbo.Cte c
                    WHERE   c.RFC = @RFC
                            AND @RFC NOT LIKE 'XAX%' )
            BEGIN
                SET @sDescripcion = 'Ya existe un cliente con este R.F.C. (' + @RFC + '). Favor de verificarlo.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Nombre IS NULL
             OR RTRIM(LTRIM(@Nombre)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Nombre no indicado. Por favor, indique un Nombre.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Direccion IS NULL
             OR RTRIM(LTRIM(@Direccion)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Dirección no indicada. Por favor, indique una Dirección.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @DireccionNumero IS NULL
             OR RTRIM(LTRIM(@DireccionNumero)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Número de Dirección no indicado. Por favor, indique un Número de Dirección.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Colonia IS NULL
             OR RTRIM(LTRIM(@Colonia)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Colonia no indicada. Por favor, indique una Colonia.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Poblacion IS NULL
             OR RTRIM(LTRIM(@Poblacion)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Población no indicada. Por favor, indique una Población.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Estado IS NULL
             OR RTRIM(LTRIM(@Estado)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Estado no indicado. Por favor, indique un Estado.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Pais IS NULL
             OR RTRIM(LTRIM(@Pais)) = ''
           )
            BEGIN
                SET @sDescripcion = 'País no indicado. Por favor, indique un País.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Pais IS NULL
             OR RTRIM(LTRIM(@Pais)) = ''
           )
            BEGIN
                SET @sDescripcion = 'País no indicado. Por favor, indique un País.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @CodigoPostal IS NULL
             OR RTRIM(LTRIM(@CodigoPostal)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Código Postal no indicado. Por favor, indique un Código Postal.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Grupo IS NULL
             OR RTRIM(LTRIM(@Grupo)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Grupo no indicado. Por favor, indique su Grupo.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END

-- =============================================
-- Proceso
-- =============================================
		/*Obtener el #Consecutivo de cliente*/
        SELECT  @UltimoId = cons.Consecutivo
        FROM    dbo.Consecutivo cons
        WHERE   cons.Tipo = 'Cte';

        SET @sCliente = CAST(@UltimoId + 1 AS VARCHAR);

        BEGIN TRY
            INSERT  INTO dbo.Cte
                    ( Cliente ,
                      Rama ,
                      Nombre ,
                      Direccion ,
                      DireccionNumero ,
                      EntreCalles ,
                      Colonia ,
                      Poblacion ,
                      Estado ,
                      Pais ,
                      CodigoPostal ,
                      RFC ,
                      Telefonos ,
                      Fax ,
                      Contacto1 ,
                      Extencion1 ,
                      eMail1 ,
                      Categoria ,
                      Grupo ,
                      Estatus ,
                      CreditoEspecial ,
                      Usuario ,
                      DireccionNumeroInt
			          --CtaBanco ,
			          --ClaveBanco
			        )
            VALUES  ( @sCliente , -- Cliente - char(10)
                      'CLIENTES' , -- Rama - char(10)
                      @Nombre , -- Nombre - varchar(255)
                      @Direccion , -- Direccion - varchar(100)
                      @DireccionNumero , -- DireccionNumero - varchar(20)
                      @EntreCalles , -- EntreCalles - varchar(100)
                      @Colonia , -- Colonia - varchar(100)
                      @Poblacion , -- Poblacion - varchar(100)
                      @Estado , -- Estado - varchar(30)
                      @Pais , -- Pais - varchar(30)
                      @CodigoPostal , -- CodigoPostal - varchar(15)
                      @RFC , -- RFC - varchar(15)
                      @Telefonos , -- Telefonos - varchar(100)
                      @Fax , -- Fax - varchar(50)
                      @Contacto , -- Contacto1 - varchar(50)
                      @Extencion , -- Extencion1 - varchar(10)
                      @Email , -- eMail1 - varchar(50)
                      'CLIENTES' , -- Categoria - varchar(50)
                      @Grupo , -- Grupo - varchar(50)
                      'ALTA' , -- Estatus - char(15)
                      1 , -- CreditoEspecial - bit
                      @Usuario , -- Usuario - varchar(10)
                      @DireccionNumeroInt  -- DireccionNumeroInt - varchar(20)--
			          --'' , -- CtaBanco - varchar(50)
			         -- 0  -- ClaveBanco - int
			        );	
        END TRY
        BEGIN CATCH
            SELECT  @sDescripcion = CAST(ERROR_NUMBER() AS VARCHAR) + ' ' + ERROR_MESSAGE();
            EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteInsertar', -- varchar(255)
                @Tipo = 'Error', -- varchar(255)
                @DetalleError = @sDescripcion, -- varchar(max)
                @Usuario = @Usuario, -- varchar(10)
                @Parametros = @LogParametrosXML; -- xml
            RAISERROR (@sDescripcion, 16, 1);
            RETURN;
        END CATCH

        SET @UltimoId = @UltimoId + 1

        UPDATE  dbo.Consecutivo
        SET     Consecutivo = @UltimoId
        WHERE   Tipo = 'Cte';

		/* Se Agrega la cave de uso por defaul para Turismo*/
        INSERT  INTO dbo.CteCFD
                ( Cliente, ClaveUsoCFDI )
        VALUES  ( @sCliente, -- Cliente - char(10)
                  'G03'  -- ClaveUsoCFDI - varchar(3)
                  );

-- =============================================
-- Información de Retorno
-- =============================================
        SELECT  c.Cliente ,
                ccfd.ClaveUsoCFDI
        FROM    dbo.Cte c
                LEFT JOIN dbo.CteCFD ccfd ON ccfd.Cliente = c.Cliente
        WHERE   c.Cliente = @sCliente;	
    END
GO
GRANT EXECUTE ON  [dbo].[Interfaz_CteInsertar] TO [Linked_Svam_Pruebas]
GO
