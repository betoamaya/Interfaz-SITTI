SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_cxcActualizar]
	@ID				int,
	@Usuario		char(10),
	@Referencia		varchar(50),
	@Cliente		char(10)
As

	set nocount on
	
	-- *************************************************************************
	-- Variables
	-- *************************************************************************
	
	Declare @LogParametrosXml Xml;
	Set @LogParametrosXml = 
		(select 
			@ID				as 'ID',
			@Usuario		as 'Usuario',
			@Referencia		as 'Referencia',
			@Cliente		as 'Cliente'
		For Xml Path('Parametros'));
	
	Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Actualización','',@Usuario,@LogParametrosXml;
	
	Declare @mensajeError			varchar(max)
	
	-- *************************************************************************
	-- Validaciones
	-- *************************************************************************
	
	If(@ID Is Null) 
	Begin
		Set @MensajeError = 'ID no indicado. Por favor, indique un ID.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
		
	If Not Exists(select * from cxc where ID = @ID) 
	Begin
		Set @MensajeError = 'ID no encontrado. Por favor, indique un ID valido de Intelisis.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	If (select Estatus from cxc where ID = @ID) = 'CONCLUIDO'
	Begin
		Set @MensajeError = 'ID indicado ya se encuentra concluido. Por favor, indique un ID que no este concluido.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	If(@Usuario Is Null Or rtrim(ltrim(@Usuario)) = '') 
	Begin
		Set @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
		
	If Not Exists(select * from Usuario where rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario))) 
	Begin
		Set @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	If Not Exists(select * from cxc where ID = @ID and rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario))) 
	Begin
		Set @MensajeError = 'Usuario indicado no corresponde al ID. Por favor, indique un Usuario valido para este ID, o indique un ID que pertenezca a este usuario.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
		
	If(@Cliente Is Null Or rtrim(ltrim(@Cliente)) = '') 
	Begin
		Set @MensajeError = 'Cliente no indicado. Por favor, indique un Cliente.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
	
	If Not Exists(select * from cxc where ID = @ID and rtrim(ltrim(Cliente)) = rtrim(ltrim(@Cliente))) 
	Begin
		Set @MensajeError = 'Cliente indicado no corresponde al ID. Por favor, indique un Cliente valido para este ID, o indique un ID que pertenezca a este cliente.';
		Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		raiserror(@MensajeError,16,1);
		return;
	End
			
	-- *************************************************************************
	-- Proceso
	-- *************************************************************************
	
	Update cxc Set
		Referencia	= @Referencia
	Where
		ID = @ID
	
	-- *************************************************************************
	-- Información de Retorno
	-- *************************************************************************
GO
GRANT EXECUTE ON  [dbo].[Interfaz_cxcActualizar] TO [Linked_Svam_Pruebas]
GO
