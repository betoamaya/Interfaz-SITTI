SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_cteBuscar]  
	@Cliente	varchar(10)		= '',  
	@Sucursal	int				= -1,  
	@RFC		varchar(20)		= '',  
	@Nombre		varchar(255)	= '',  
	@Usuario	char(10)   
As  
  
 set nocount on  
 Set dateformat DMY  
   
	-- *************************************************************************  
	-- Variables  
	-- *************************************************************************  
	Declare @LogParametrosXml Xml;  
	Set @LogParametrosXml =   
		(select   
			@Cliente as 'Cliente',  
			@Sucursal as 'Sucursal',  
			@RFC  as 'RFC',  
			@Nombre  as 'Nombre',  
			@Usuario as 'Usuario'  
		 For Xml Path('Parametros'));  
   
 Exec Interfaz_LogsInsertar 'Interfaz_cteBuscar','Consulta','',@Usuario,@LogParametrosXml;  
   
 Declare @Error varchar(max)  
   
 -- *************************************************************************  
 -- Validaciones  
 -- *************************************************************************  
   
 if @RFC <> '' and @Nombre <> ''  
 Begin  
   
  Set @Error = 'No puede indicar el R.F.C. y el Nombre al mismo tiempo. Por favor, indique solo uno de los dos.';  
  Exec Interfaz_LogsInsertar 'Interfaz_cteBuscar','Error de Validación',@Error,@Usuario,@LogParametrosXml;   
  raiserror(@Error,16,1);  
  return;  
  
 End  
   
 if (@RFC <> '' Or @Nombre <> '') and @Cliente <> ''  
 Begin  
  Set @Error = 'Puede buscar por cliente y sucursal o por R.F.C. o por Nombre. Si busca por cliente y sucursal no puede indicar R.F.C o Nombre. Por favor, indique solo una de las busquedas.';  
  Exec Interfaz_LogsInsertar 'Interfaz_cteBuscar','Error de Validación',@Error,@Usuario,@LogParametrosXml;  
  raiserror(@Error,16,1);  
  return;  
 End  
   
 if @RFC = '' and @Nombre = '' and @Cliente = ''  
 Begin  
  Set @Error = 'No ha indicado ningún para criterio de busqueda. Por favor, indique un R.F.C. o un Nombre o un Cliente y Sucursal.';  
  Exec Interfaz_LogsInsertar 'Interfaz_cteBuscar','Error de Validación',@Error,@Usuario,@LogParametrosXml;  
  raiserror(@Error,16,1);  
  return;  
 End  
 
 if @RFC = 'XAXX010101000'
 Begin  
    SELECT * FROM dbo.Cte c WHERE c.Cliente = '0';
  return;  
 End  
   
 -- *************************************************************************  
 -- Proceso  
 -- *************************************************************************  
   
 Create Table #tmp  
 (  
  Cliente   varchar(10),  
  Sucursal  int,  
  RFC    varchar(20),  
  Nombre   varchar(100),  
  Direccion  varchar(100),  
  DireccionNumero varchar(20),  
  Colonia   varchar(100),  
  Poblacion  varchar(100),  
  Estado   varchar(30),  
  Pais   varchar(30),  
  CodigoPostal varchar(15),  
  Telefonos  varchar(100),  
  Fax    varchar(50),  
  Contacto1  varchar(50),  
  Extencion1  varchar(10),  
  eMail1   varchar(50),  
  Grupo   varchar(50),  
  EntreCalles  varchar(100)  
 )  
 
 
   
 insert into #tmp  
  Select distinct   
   c.Cliente,  
   Sucursal   = 0,  
   c.RFC,  
   c.Nombre,  
   c.Direccion,  
   c.DireccionNumero,  
   c.Colonia,  
   C.Poblacion,  
   c.Estado,  
   c.Pais,  
   c.CodigoPostal,  
   c.Telefonos,  
   c.Fax,  
   c.Contacto1,  
   c.Extencion1,  
   c.eMail1,  
   c.Grupo,  
   c.EntreCalles  
  From   
   cte c  
   
   left join cteEnviarA s on --@JGTO-21/03/2013: Se agrega busqueda del nombre también en la sucursal.
		s.cliente = c.cliente
   
  Where   
   (
	   (c.RFC Like '%' + @RFC + '%' and @RFC <> '') Or  
	   (c.Nombre Like '%' + @Nombre + '%' and @Nombre <> '') Or  
	   (s.Nombre Like '%' + @Nombre + '%' and @Nombre <> '')
   ) Or  
   (c.Cliente = @Cliente)  
   
 Insert Into #tmp  
  Select   
   c.Cliente,  
   Sucursal   = c.ID,  
   t.RFC,  
   c.Nombre,  
   c.Direccion,  
   c.DireccionNumero,  
   c.Colonia,  
   C.Poblacion,  
   c.Estado,  
   c.Pais,  
   c.CodigoPostal,  
   c.Telefonos,  
   c.Fax,  
   c.Contacto1,  
   c.Extencion1,  
   c.eMail1,  
   c.Grupo,  
   c.EntreCalles  
  From  
   cteEnviarA c  
     
   inner join #tmp t on  
    t.Cliente = c.Cliente  
  
 If(@Cliente <>'')  
 Begin  
  Delete From #tmp where Sucursal <> @Sucursal  
 End   
   
 -- *************************************************************************  
 -- Información de Retorno  
 -- *************************************************************************  
   
 select   
  Cliente   = IsNull(Cliente,''),  
  Sucursal,  
  RFC    = IsNull(RFC,''),  
  Nombre   = IsNull(Nombre,''),  
  Direccion  = IsNull(Direccion,''),  
  DireccionNumero = IsNull(DireccionNumero,''),  
  Colonia   = IsNull(Colonia, ''),  
  Poblacion  = IsNull(Poblacion, ''),  
  Estado   = IsNull(Estado, ''),  
  Pais   = IsNull(Pais, ''),  
  CodigoPostal = IsNull(CodigoPostal, ''),  
  Telefonos  = IsNull(Telefonos, ''),  
  Fax    = IsNull(Fax, ''),  
  Contacto1  = IsNull(Contacto1,''),  
  Extencion1  = IsNull(Extencion1,''),  
  eMail1   = IsNull(eMail1, ''),  
  Grupo   = IsNull(Grupo, ''),  
  EntreCalles  = IsNull(EntreCalles, '')  
 from   
  #tmp 
where  LEN(RFC) >11   --solo regresa RFc´s válidos
 Order by   
  Cliente,   
  Sucursal  
GO
GRANT EXECUTE ON  [dbo].[Interfaz_cteBuscar] TO [Linked_Svam_Pruebas]
GO
