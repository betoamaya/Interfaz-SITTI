SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_ventasCancelar]
	@VentaID	int,
	@Usuario	char(10)
As

	set nocount on
	
	-- *************************************************************************
	-- Variables
	-- *************************************************************************
	
	Declare @LogParametrosXml Xml;
	Set @LogParametrosXml = 
		(select 
			@VentaID	as 'VentaID',
			@Usuario	as 'Usuario'
		For Xml Path('Parametros'));
	
	Exec Interfaz_LogsInsertar 'Interfaz_ventasCancelar','Ejecución','',@Usuario,@LogParametrosXml;
	
	Declare @cxcID		int
	Declare @cxcMov		varchar(20)
	Declare @cxcMovID	varchar(20)
	
	Declare @cID		int
	Declare @intCont	int
		
	-- *************************************************************************
	-- Validaciones
	-- *************************************************************************
			
	---- Si la venta esta concluida no hay necesidad de hacer algo.
	--If exists (select * from venta where ID = @VentaID and Estatus = 'CONCLUIDO')
	--Begin
	--	Exec Interfaz_LogsInsertar 'Interfaz_ventasCancelar','Error de Validación','Registro ya concluido, se termina sin ejecutar operaciones.',@Usuario,@LogParametrosXml;
	--	return;
	--End	
	
	-- *************************************************************************
	-- Proceso
	-- *************************************************************************
	
	Select 
		@cxcID		= max(dID),
		@cxcMov		= max(dMov),
		@cxcMovID	= max(dMovID)
	From
		MovFlujo
	Where
		oID			=  @VentaID and
		oModulo		= 'VTAS' and
		dModulo		= 'CXC' and
		Cancelado	= 0
	
	Create Table #cobros
	(
		Consecutivo	int identity(1,1) not null,
		ID			int
	)
	
	If exists (Select
				ID
			   From
				cxcd
			   Where
				Aplica		= @cxcMov and
				AplicaID	= @cxcMovID)
	Begin
		Insert Into #cobros
			Select
				ID	= cxcd.ID
			From
				cxcd
			Where
				Aplica		= @cxcMov and
				AplicaID	= @cxcMovID
	End
		
	-- Se cancelan cobros
	Set @intCont = 1
	while @intCont <= (Select count(*) from #cobros)
	Begin
		
		Set @cID = (Select ID From #cobros Where Consecutivo = @intCont);

		Begin Try
			Exec spAfectar 	'CXC', @cID, 'CANCELAR', 'Todo', null, @Usuario, NULL, 1;
		End Try
		Begin Catch
		End Catch
								
		Set @intCont = @intCont + 1;
	End
	
	
	-- Se cancela el movimiento en venta
	Begin Try
		Exec spAfectar 	'VTAS', @VentaID, 'CANCELAR', 'Todo', null, @Usuario, NULL, 1;
	End Try
	Begin Catch
	End Catch
	
	
	-- *************************************************************************
	-- Información de Retorno
	-- *************************************************************************

	Select
		Estatus
	From
		venta
	Where
		ID = @VentaID
GO
GRANT EXECUTE ON  [dbo].[Interfaz_ventasCancelar] TO [Linked_Svam_Pruebas]
GO
