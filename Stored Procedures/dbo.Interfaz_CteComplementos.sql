SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	21/08/2018
-- Descrición:		Actualización de Datos de Adenda y Complementos
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_CteComplementos]
    @Usuario AS VARCHAR(10),
    @Cliente AS VARCHAR(10),
    @Sucursal AS INT,
    @Tipo AS INT,
    @Parametros AS XML,
    @iError AS INT = -1 OUTPUT,
    @sDescr AS VARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- =============================================
    -- Variables
    -- =============================================

    DECLARE @LogParametrosXML AS XML;
    SET @LogParametrosXML =
    (
        SELECT @Usuario AS 'Usuario',
               @Cliente AS 'Cliente',
               @Sucursal AS 'Sucursal',
               @Tipo AS 'Tipo',
               @Parametros AS 'Parametros'
        FOR XML PATH('Parametros')
    );
    EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                   @Tipo = 'Actualización',          -- varchar(255)
                                   @DetalleError = '',               -- varchar(max)
                                   @Usuario = @Usuario,              -- varchar(10)
                                   @Parametros = @LogParametrosXML;  -- xml

    DECLARE @T_Parametros TABLE
    (
        Cliente VARCHAR(10),
        Sucursal INT,
        Dato01 VARCHAR(50),
        Dato02 VARCHAR(50),
        Dato03 VARCHAR(50),
        Dato04 VARCHAR(50),
        Dato05 VARCHAR(50),
        Dato06 VARCHAR(50),
        Dato07 VARCHAR(50),
        Dato08 VARCHAR(50),
        Dato09 VARCHAR(50),
        Dato10 VARCHAR(50),
        Dato11 VARCHAR(50),
        Dato12 VARCHAR(50),
        Dato13 VARCHAR(50),
        Dato14 VARCHAR(50),
        Dato15 VARCHAR(50),
        Dato16 VARCHAR(50),
        Dato17 VARCHAR(50)
    );

    DECLARE @X_Parametros AS XML;
    SET @X_Parametros = CAST(@Parametros AS XML);

    --********************************************************************
    --		VALIDACIONES 
    --********************************************************************
    IF @Usuario IS NULL
       OR NOT EXISTS
    (
        SELECT u.Usuario
        FROM dbo.Usuario AS u
        WHERE u.Usuario = RTRIM(@Usuario)
    )
    BEGIN
        SELECT @iError = -1,
               @sDescr = 'Usuario no indicado o No existe. Por favor, indique Usuario validó.';
        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                       @Tipo = 'Error de Validación',    -- varchar(255)
                                       @DetalleError = @sDescr,          -- varchar(max)
                                       @Usuario = @Usuario,              -- varchar(10)
                                       @Parametros = @LogParametrosXML;  -- xml
        RETURN;
    END;

    IF @Cliente IS NULL
       OR NOT EXISTS
    (
        SELECT *
        FROM dbo.Cte AS c
        WHERE c.Cliente = RTRIM(@Cliente)
    )
    BEGIN
        SELECT @iError = -1,
               @sDescr = 'Cliente no indicado o No existe. Por favor, indique Cliente validó.';
        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                       @Tipo = 'Error de Validación',    -- varchar(255)
                                       @DetalleError = @sDescr,          -- varchar(max)
                                       @Usuario = @Usuario,              -- varchar(10)
                                       @Parametros = @LogParametrosXML;  -- xml
        RETURN;
    END;
    IF ISNULL(@Sucursal, 0) <> 0
    BEGIN
        IF NOT EXISTS
        (
            SELECT cea.Cliente,
                   cea.ID
            FROM dbo.CteEnviarA AS cea
            WHERE cea.Cliente = @Cliente
                  AND cea.ID = @Sucursal
        )
        BEGIN
            SELECT @iError = -1,
                   @sDescr
                       = 'La sucursal indicada no existe para el cliente ' + RTRIM(@Cliente)
                         + '. Por favor, indique Cliente y Sucursal validas.';
            EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                           @Tipo = 'Error de Validación',    -- varchar(255)
                                           @DetalleError = @sDescr,          -- varchar(max)
                                           @Usuario = @Usuario,              -- varchar(10)
                                           @Parametros = @LogParametrosXML;  -- xml
            RETURN;
        END;
    END;
    /*Llenar tabla*/
    IF @Parametros IS NOT NULL
    BEGIN
        IF @Tipo = 1 /* A D E N D A --- F E M S A*/
        BEGIN
            INSERT INTO @T_Parametros
            (
                Cliente,
                Sucursal,
                Dato01,
                Dato02,
                Dato03,
                Dato04,
                Dato05,
                Dato06,
                Dato07,
                Dato08,
                Dato09,
                Dato10,
                Dato11,
                Dato12,
                Dato13,
                Dato14,
                Dato15,
                Dato16
            )
            SELECT @Cliente,
                   @Sucursal,
                   T.LOC.value('@Version', 'VARCHAR(50)') AS [Version],
                   T.LOC.value('@TipoDocumento', 'VARCHAR(50)') AS [TipoDocumento],
                   T.LOC.value('@Documento', 'VARCHAR(50)') AS [Documento],
                   T.LOC.value('@NoSociedad', 'VARCHAR(50)') AS [NoSociedad],
                   T.LOC.value('@NoProveedor', 'VARCHAR(50)') AS [NoProveedor],
                   T.LOC.value('@NoPedido', 'VARCHAR(50)') AS [NoPedido],
                   T.LOC.value('@Moneda', 'VARCHAR(50)') AS [Moneda],
                   T.LOC.value('@NoEntrada', 'VARCHAR(50)') AS [NoEntrada],
                   T.LOC.value('@NoRemision', 'VARCHAR(50)') AS [NoRemision],
                   T.LOC.value('@NoSocio', 'VARCHAR(50)') AS [NoSocio],
                   T.LOC.value('@CentroCostos', 'VARCHAR(50)') AS [CentroCostos],
                   T.LOC.value('@InicioPeriodo', 'VARCHAR(50)') AS [InicioPeriodo],
                   T.LOC.value('@FinPeriodo', 'VARCHAR(50)') AS [FinPeriodo],
                   T.LOC.value('@Retencion1', 'VARCHAR(50)') AS [Retencion1],
                   T.LOC.value('@Retencion2', 'VARCHAR(50)') AS [Retencion2],
                   T.LOC.value('@Email', 'VARCHAR(50)') AS [Email]
            FROM @X_Parametros.nodes('//row/fila') AS T(LOC);
        END;
        ELSE
        BEGIN
            IF @Tipo = 2 /* C O M P L E M E N T O --- I N E*/
            BEGIN
                INSERT INTO @T_Parametros
                (
                    Cliente,
                    Sucursal,
                    Dato01,
                    Dato02,
                    Dato03,
                    Dato04,
                    Dato05,
                    Dato06
                )
                SELECT @Cliente,
                       @Sucursal,
                       T.LOC.value('@TipoProceso', 'VARCHAR(50)') AS [TipoProceso],
                       T.LOC.value('@TipoComite', 'VARCHAR(50)') AS [TipoComite],
                       T.LOC.value('@IdContabilidad', 'VARCHAR(50)') AS [IdContabilidad],
                       T.LOC.value('@ClaveEntidad', 'VARCHAR(50)') AS [ClaveEntidad],
                       T.LOC.value('@Ambito', 'VARCHAR(50)') AS [Ambito],
                       T.LOC.value('@EntidadIdContabilidad', 'VARCHAR(50)') AS [EntidadIdContabilidad]
                FROM @X_Parametros.nodes('//row/fila') AS T(LOC);

                IF
                (
                    SELECT ISNULL(tp.Dato01, '') AS 'TipoProceso'
                    FROM @T_Parametros AS tp
                    WHERE tp.Cliente = @Cliente
                          AND tp.Sucursal = @Sucursal
                ) = ''
                BEGIN
                    SELECT @iError = -1,
                           @sDescr
                               = 'Complemento INE - Tipo de Proceso Invalido. Por favor, indique Tipo de Proceso validó.';
                    EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                                   @Tipo = 'Error de Validación',    -- varchar(255)
                                                   @DetalleError = @sDescr,          -- varchar(max)
                                                   @Usuario = @Usuario,              -- varchar(10)
                                                   @Parametros = @LogParametrosXML;  -- xml
                    RETURN;
                END;
            END;
        END;
    END;

    ELSE
    BEGIN
        SELECT @iError = -1,
               @sDescr = 'Parámetros no indicado. Por favor, indique Parámetros';
        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                       @Tipo = 'Error de Validación',    -- varchar(255)
                                       @DetalleError = @sDescr,          -- varchar(max)
                                       @Usuario = @Usuario,              -- varchar(10)
                                       @Parametros = @LogParametrosXML;  -- xml
        RETURN;
    END;

    --********************************************************************
    --		PROCESO
    --********************************************************************

    IF @Tipo = 1 /* A D E N D A --- F E M S A*/
    BEGIN
        IF NOT EXISTS
        (
            SELECT cod.Cliente
            FROM dbo.CteOtrosDatos AS cod
            WHERE cod.Cliente = @Cliente
        )
        BEGIN
            PRINT 'Se crea Registro del cliente ' + RTRIM(@Cliente) + ' en CteOtrosDatos';
            INSERT INTO dbo.CteOtrosDatos
            (
                Cliente
            )
            VALUES (@Cliente);
        END;
        BEGIN TRY
            PRINT 'Actualizando Cliente ' + RTRIM(@Cliente) + ' con datos de Adenda FEMSA...';
            UPDATE c
            SET c.Descripcion11 = RTRIM(Dato01), --[Version]
                c.Descripcion12 = RTRIM(Dato02), --[TipoDocumento]
                c.Descripcion20 = RTRIM(Dato03), --[Documento]
                c.Descripcion13 = RTRIM(Dato04), --[NoSociedad]
                c.Descripcion14 = RTRIM(Dato05), --[NoProveedor]
                c.Descripcion15 = RTRIM(Dato06), --[NoPedido]
                c.Descripcion16 = RTRIM(Dato07), --[Moneda]
                c.Descripcion17 = RTRIM(Dato08), --[NoEntrada]
                c.Descripcion18 = RTRIM(Dato09), --[NoRemision]
                c.Descripcion19 = RTRIM(Dato16)  --[Email]
            FROM dbo.Cte AS c
                INNER JOIN @T_Parametros AS tp
                    ON tp.Cliente = c.Cliente
            WHERE c.Cliente = @Cliente;

            PRINT 'Actualizando CteOtrosDatos del Cliente ' + RTRIM(@Cliente) + ' con datos de Adenda FEMSA...';
            UPDATE cod
            SET cod.Descripcion21 = RTRIM(Dato10), --[NoSocio]
                cod.Descripcion22 = RTRIM(Dato11), --[CentroCostos]
                cod.Descripcion23 = RTRIM(Dato12), --[InicioPeriodo]
                cod.Descripcion24 = RTRIM(Dato13), --[FinPeriodo]
                cod.Descripcion25 = RTRIM(Dato14), --[Retencion1]
                cod.Descripcion26 = RTRIM(Dato15)  --[Retencion1]
            FROM dbo.CteOtrosDatos AS cod
                INNER JOIN @T_Parametros AS tp
                    ON tp.Cliente = cod.Cliente
            WHERE cod.Cliente = @Cliente;
        END TRY
        BEGIN CATCH
            PRINT 'Error Actualizando Cliente ' + RTRIM(@Cliente) + ' con datos de Adenda FEMSA...';
            SELECT @iError = ISNULL(ERROR_NUMBER(), -1),
                   @sDescr = 'Error: ' + RTRIM(ISNULL(ERROR_MESSAGE(), ''));
            EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                           @Tipo = 'Error',                  -- varchar(255)
                                           @DetalleError = @sDescr,          -- varchar(max)
                                           @Usuario = @Usuario,              -- varchar(10)
                                           @Parametros = @LogParametrosXML;  -- xml
            RETURN;
        END CATCH;
    END;

    IF @Tipo = 2 /* C O M P L E M E N T O --- I N E*/
    BEGIN
        IF ISNULL(@Sucursal, 0) = 0
        BEGIN
            BEGIN TRY
                PRINT 'Actualizando Cliente ' + RTRIM(@Cliente) + ' con datos de Complemento INE...';
                UPDATE cc
                SET cc.TipoProceso = RTRIM(tp.Dato01),          -- [TipoProceso] 
                    cc.TipoComite = RTRIM(tp.Dato02),           -- [TipoComite]
                    cc.IdContabilidad = RTRIM(tp.Dato03),       -- [IdContabilidad] 
                    cc.ClaveEntidad = RTRIM(tp.Dato04),         -- [ClaveEntidad] 
                    cc.Ambito = RTRIM(tp.Dato05),               -- [Ambito] 
                    cc.EntidadIdContabilidad = RTRIM(tp.Dato06) -- [EntidadIdContabilidad]
                FROM dbo.CteCFD AS cc
                    INNER JOIN @T_Parametros AS tp
                        ON tp.Cliente = cc.Cliente
                WHERE cc.Cliente = @Cliente;
            END TRY
            BEGIN CATCH
                PRINT 'Error Actualizando Cliente ' + RTRIM(@Cliente) + ' con datos de Complemento INE...';
                SELECT @iError = ISNULL(ERROR_NUMBER(), -1),
                       @sDescr = 'Error: ' + RTRIM(ISNULL(ERROR_MESSAGE(), ''));
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                               @Tipo = 'Error',                  -- varchar(255)
                                               @DetalleError = @sDescr,          -- varchar(max)
                                               @Usuario = @Usuario,              -- varchar(10)
                                               @Parametros = @LogParametrosXML;  -- xml
                RETURN;
            END CATCH;
        END;
        ELSE
        BEGIN
            BEGIN TRY
                PRINT 'Actualizando Cliente ' + RTRIM(@Cliente) + ' Sucursal ' + RTRIM(ISNULL(@Sucursal, 0))
                      + ' con datos de Complemento INE...';
                UPDATE cea
                SET cea.TipoProceso = RTRIM(tp.Dato01),          -- [TipoProceso] 
                    cea.TipoComite = RTRIM(tp.Dato02),           -- [TipoComite]
                    cea.IdContabilidad = RTRIM(tp.Dato03),       -- [IdContabilidad] 
                    cea.ClaveEntidad = RTRIM(tp.Dato04),         -- [ClaveEntidad] 
                    cea.Ambito = RTRIM(tp.Dato05),               -- [Ambito] 
                    cea.EntidadIdContabilidad = RTRIM(tp.Dato06) -- [EntidadIdContabilidad]
                FROM dbo.CteEnviarA AS cea
                    INNER JOIN @T_Parametros AS tp
                        ON tp.Cliente = cea.Cliente
                WHERE cea.Cliente = @Cliente
                      AND cea.ID = @Sucursal;
            END TRY
            BEGIN CATCH
                PRINT 'Error Actualizando Cliente ' + RTRIM(@Cliente) + ' con datos de Complemento INE...';
                SELECT @iError = ISNULL(ERROR_NUMBER(), -1),
                       @sDescr = 'Error: ' + RTRIM(ISNULL(ERROR_MESSAGE(), ''));
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteComplementos', -- varchar(255)
                                               @Tipo = 'Error',                  -- varchar(255)
                                               @DetalleError = @sDescr,          -- varchar(max)
                                               @Usuario = @Usuario,              -- varchar(10)
                                               @Parametros = @LogParametrosXML;  -- xml
                RETURN;
            END CATCH;
        END;
    END;

    SELECT @iError = 0,
           @sDescr = 'El cliente fue actualizado con éxito.';

END;

GO
