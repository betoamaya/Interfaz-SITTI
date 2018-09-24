SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_cxcCancelacionDeAplicacionDeIngresos]
	@CxcID		int,
	@Usuario	char(10)
As

	set nocount on
	
	-- *************************************************************************
	-- Variables
	-- *************************************************************************
	
	Declare @LogParametrosXml Xml;
	Set @LogParametrosXml = 
		(select 
			@CxcID			as 'CxcID',
			@Usuario		as 'Usuario'
		For Xml Path('Parametros'));
	
	Exec Interfaz_LogsInsertar 'Interfaz_cxcCancelacionDeAplicacionDeIngresos','Ejecución','',@Usuario,@LogParametrosXml;
	
	Declare @VentaID	int
	Declare @cxcMov		varchar(20)
	Declare @cxcMovID	varchar(20)
	
	Declare @aID		int
	Declare @intCont	int
	
	Select 
		@VentaID	= max(oID)
	From
		MovFlujo
	Where
		dID			=  @CxcID and
		dModulo		= 'CXC' and
		oModulo		= 'VTAS' and
		Cancelado	= 0
	
	-- *************************************************************************
	-- Validaciones
	-- *************************************************************************
			
	-- Si la venta no esta concluida no hay necesidad de hacer algo.
	If not exists (select * from venta where ID = @VentaID and Estatus = 'CONCLUIDO')
	Begin
		Exec Interfaz_LogsInsertar 'Interfaz_cxcCancelacionDeAplicacionDeIngresos','Error de Validación','Registro ya concluido, se termina sin ejecutar operaciones.',@Usuario,@LogParametrosXml;
		return;		
	End	
	
	-- *************************************************************************
	-- Proceso
	-- *************************************************************************
	
	Select 
		--@cxcID		= max(dID),
		@cxcMov		= max(dMov),
		@cxcMovID	= max(dMovID)
	From
		MovFlujo
	Where
		oID			=  @VentaID and
		oModulo		= 'VTAS' and
		dModulo		= 'CXC' and
		Cancelado	= 0
	
	Create Table #tmp_anticipos
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
		Insert Into #tmp_anticipos
			Select
				ID	= cxcd.ID
			From
				cxcd
			Where
				Aplica		= @cxcMov and
				AplicaID	= @cxcMovID
	End
		
	-- Se cancelan Aplicación de Anticipos
	Set @intCont = 1
	while @intCont <= (Select count(*) from #tmp_anticipos)
	Begin
		
		Set @aID = (Select aID From #tmp_anticipos Where Consecutivo = @intCont);

		Begin Try
			Exec spAfectar 	'CXC', @aID, 'CANCELAR', 'Todo', null, @Usuario;
		End Try
		Begin Catch
		End Catch
								
		Set @intCont = @intCont + 1;
	End
	
	
	-- Se cancela el movimiento en venta
	Begin Try
		Exec spAfectar 	'VTAS', @VentaID, 'CANCELAR', 'Todo', null, @Usuario;
	End Try
	Begin Catch
	End Catch
	
	
	-- *************************************************************************
	-- Información de Retorno
	-- *************************************************************************

	Select
		Estatus
	From
		cxc
	Where
		ID = @CxcID
GO
GRANT EXECUTE ON  [dbo].[Interfaz_cxcCancelacionDeAplicacionDeIngresos] TO [Linked_Svam_Pruebas]
GO
