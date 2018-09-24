SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_cxcBuscar]
	@Empresa		char(5),
	@Mov			char(20),
	@Cliente		char(10),
	@Saldo			money,
	@Usuario		char(10),
	@Referencia		varchar(50)
As

	set nocount on
	
	-- *************************************************************************
	-- Variables
	-- *************************************************************************
	Declare @LogParametrosXml Xml;
	Set @LogParametrosXml = 
		(select 
			@Empresa	as 'Empresa',
			@Mov		as 'Mov',
			@Cliente	as 'Cliente',
			@Saldo		as 'Saldo',
			@Usuario	as 'Usuario',
			@Referencia	as 'Referencia'
		For Xml Path('Parametros'));
	
	Exec Interfaz_LogsInsertar 'Interfaz_cxcBuscar','Consulta','',@Usuario,@LogParametrosXml;
	
	-- *************************************************************************
	-- Validaciones
	-- *************************************************************************
	
	-- *************************************************************************
	-- Proceso
	-- *************************************************************************
	
	-- *************************************************************************
	-- Información de Retorno
	-- *************************************************************************
	
	Select 
		ID,
		Mov,
		MovID,
		FechaEmision,
		Concepto,
		Importe,
		Saldo,
		Referencia,
		Estatus
	From
		cxc
	Where
		Empresa		= @Empresa and
		Mov			= @Mov and
		Usuario		= @Usuario and
		(Cliente	= @Cliente or @Cliente = '') and
		(Saldo		= @Saldo or @Saldo Is Null) and
		(Referencia	= @Referencia or @Referencia = '')
		
GO
GRANT EXECUTE ON  [dbo].[Interfaz_cxcBuscar] TO [Linked_Svam_Pruebas]
GO
