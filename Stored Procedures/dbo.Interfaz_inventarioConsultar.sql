SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_inventarioConsultar] --'TUN', '20110601', 'VIAJESESP'
	@Empresa		char(5),
	@FechaEmision	smalldatetime,
	@Usuario		char(10)
As

	-- *************************************************************************
	-- Variables
	-- *************************************************************************

	Declare @LogParametrosXml Xml;
	Set @LogParametrosXml = 
		(select 
			@Empresa			as 'Empresa',
			@FechaEmision		as 'FechaEmision',
			@Usuario			as 'Usuario'
		For Xml Path('Parametros'));
	
	Exec Interfaz_LogsInsertar 'Interfaz_inventarioConsultar','Consulta','',@Usuario,@LogParametrosXml;
	
	Declare @mensajeError varchar(max)
	
	-- *************************************************************************
	-- Validaciones
	-- *************************************************************************
	
	If(@Empresa Is Null Or rtrim(ltrim(@Empresa)) = '') 
	Begin
		Set @MensajeError = 'Empresa no indicada. Por favor, indique una Empresa.';
		Exec Interfaz_LogsInsertar 'Interfaz_inventarioConsultar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	If(@FechaEmision Is Null) 
	Begin
		Set @MensajeError = 'Fecha de emisión no indicada. Por favor, indique una Fecha de emisión.';
		Exec Interfaz_LogsInsertar 'Interfaz_inventarioConsultar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	If(@Usuario Is Null Or rtrim(ltrim(@Usuario)) = '') 
	Begin
		Set @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
		Exec Interfaz_LogsInsertar 'Interfaz_inventarioConsultar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	
	If Not Exists(select * from Usuario where rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario))) 
	Begin
		Set @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
		Exec Interfaz_LogsInsertar 'Interfaz_inventarioConsultar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	-- *************************************************************************
	-- Proceso
	-- *************************************************************************
	
	-- *************************************************************************
	-- Información de Retorno
	-- *************************************************************************

	--llantas en inventario --
	SELECT 
		UnidadNegocio= CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						END ,
		Autobus		= b.espacio,
		Importe		= SUM(cantidad*costo) 
	FROM inv a JOIN invd b ON a.id=b.id JOIN ESPACIO es ON b.Espacio =es.Espacio
	JOIN autorol ar ON es.Rol=ar.Rol JOIN CentroCostos c ON ar.CentroCostosTRANSPAIS=c.CentroCostos 
	WHERE a.estatus='concluido' AND FechaEmision >=@FechaEmision
	AND mov='consumo llant y cam' AND a.empresa=@Empresa
	GROUP BY b.Espacio ,CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						END

	-- llantas en venta ---
	SELECT UnidadNegocio = CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						   END ,
		   Autobus		= b.espacio, 
		   Importe		= SUM(cantidad*costo) FROM venta a JOIN ventad b ON a.id=b.id JOIN ESPACIO es ON b.Espacio =es.Espacio
	JOIN autorol ar ON es.Rol=ar.Rol JOIN CentroCostos c ON ar.CentroCostosTRANSPAIS=c.CentroCostos 
	WHERE a.estatus='concluido' AND FechaEmision >=@FechaEmision
	AND mov='Salida vta llant-cam' AND a.empresa=@Empresa
	GROUP BY b.Espacio ,CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						END
	                    

	--- aceite y grasa 
	SELECT UnidadNegocio=CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						END ,
		   Autobus		= b.espacio, 
		   Importe		= SUM(cantidad*costo) FROM inv a JOIN invd b ON a.id=b.id JOIN ESPACIO es ON b.Espacio =es.Espacio
	JOIN autorol ar ON es.Rol=ar.Rol JOIN CentroCostos c ON ar.CentroCostosTRANSPAIS=c.CentroCostos 
	WHERE 
		a.estatus		= 'concluido' AND 
		FechaEmision	>= @FechaEmision AND 
		mov				= (CASE WHEN @Empresa = 'TUN' THEN 'consumo Aceite grasa' ELSE 'Salida vta ac-grasa' END) AND 
		a.empresa		= @Empresa
	GROUP BY b.Espacio,CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						END 
	




	---refacciones 
	SELECT UnidadNegocio=CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						END ,
		   Autobus		= b.espacio,mov,
		   Importe		= SUM(cantidad*costo) FROM inv a JOIN invd b ON a.id=b.id JOIN ESPACIO es ON b.Espacio =es.Espacio
	JOIN autorol ar ON es.Rol=ar.Rol JOIN CentroCostos c ON ar.CentroCostosTRANSPAIS=c.CentroCostos 
	WHERE a.estatus='concluido' AND FechaEmision >=@FechaEmision
	AND mov IN ('salida Por accidente','Salida por acond','Salida por mantto')
	AND a.empresa=@Empresa
	GROUP BY mov, b.Espacio ,CASE 
							WHEN LEFT(ar.CentroCostosTRANSPAIS,1) = 'K' THEN 'Paqueteria'
							WHEN RIGHT(ltrim(RTRIM(c.descripcion)),4) = '(VE)' THEN 'Viajes especiales '
							ELSE  es.Empresa
						END

	
GO
