SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	19/12/2017
-- Descripción:		Inserción de log de interfaces
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_LogsInsertar]
    @SP AS VARCHAR(255) ,
    @Tipo AS VARCHAR(255) ,
    @DetalleError AS VARCHAR(MAX) ,
    @Usuario AS VARCHAR(10) ,
    @Parametros AS XML
AS
    SET NOCOUNT ON;
	
    INSERT  INTO Interfaz_Logs
            ( Fecha ,
              SP ,
              Parametros ,
              Tipo ,
              DetalleError ,
              Usuario ,
              SqlUser ,
              SqlHost
	        )
    VALUES  ( GETDATE() ,
              @SP ,
              @Parametros ,
              @Tipo ,
              @DetalleError ,
              @Usuario ,
              SYSTEM_USER ,
              HOST_NAME()
            );
/*ENVIO DE CORREO*/
    IF @SP IN ( 'Interfaz_VentasInsertar', 'Interfaz_cxcInsertar', 'Interfaz_CxcAplicacionDeIngresos' )
        AND @DetalleError <> ' '
        AND @Tipo NOT IN ( 'Timbrado CFDI' )
        BEGIN
            DECLARE @FROM AS VARCHAR(100) ,
                @TO AS VARCHAR(100) ,
                @SUBJECT AS VARCHAR(100) ,
                @BODY AS VARCHAR(8000) ,
                @ServerBase AS VARCHAR(50);
            SET @FROM = 'trackingtpe@transpais.com.mx';
            SET @TO = 'roberto.amaya@transpais.com.mx';
            SET @SUBJECT = 'Mensaje de error al ejecutar ' + @SP;
            SET @ServerBase = ( SELECT  @@SERVERNAME
                              );
            SET @ServerBase = @ServerBase + '\'
            SET @ServerBase = @ServerBase + ( SELECT    DB_NAME()
                                            );
            SET @BODY = '<html>
<head>
	<meta http-equiv="content-type" content="text/html; charset=windows-1252">
	<title></title>
	<meta name="generator" content="LibreOffice 4.2.5.2 (Windows)">
	<meta name="created" content="20141020;152826795000000">
	<meta name="changed" content="20141020;154157365000000">
	<style type="text/css">
	<!--
		@page { margin: 2cm }
		p { margin-bottom: 0.25cm; line-height: 120% }
		td p { margin-bottom: 0cm }
	-->
	</style>
</head>
<body lang="es-MX" dir="ltr">
<table width="665" cellpadding="4" cellspacing="0">
	<col width="146">
	<col width="501">
	<tr>
		<td colspan="2" width="655" valign="top" bgcolor="#3465a4" style="border: 1px solid #ffffff; padding: 0.1cm">
			<p align="center" style="background: #3465a4"><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt"><b>'
                + @SP
                + '</b></font></font></font></p>
		</td>
	</tr>
	<tr valign="top">
		<td width="146" bgcolor="#3465a4" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: none; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0cm">
			<p><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt"><b>Base
			de Datos:</b></font></font></font></p>
		</td>
		<td width="501" bgcolor="#729fcf" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: 1px solid #ffffff; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0.1cm">
			<p style="font-weight: normal"><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt">'
                + @ServerBase
                + '</font></font></font></p>
		</td>
	</tr>
	<tr valign="top">
		<td width="146" bgcolor="#3465a4" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: none; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0cm">
			<p><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt"><b>Fecha:</b></font></font></font></p>
		</td>
		<td width="501" bgcolor="#729fcf" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: 1px solid #ffffff; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0.1cm">
			<p style="font-weight: normal"><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt">'
                + CONVERT(VARCHAR, GETDATE(), 126)
                + '</font></font></font></p>
		</td>
	</tr>
	<tr valign="top">
		<td width="146" bgcolor="#3465a4" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: none; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0cm">
			<p><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt"><b>Tipo de Mensaje:</b></font></font></font></p>
		</td>
		<td width="501" bgcolor="#729fcf" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: 1px solid #ffffff; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0.1cm">
			<p style="font-weight: normal"><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt">'
                + @Tipo
                + '</font></font></font></p>
		</td>
	</tr>
	<tr valign="top">
		<td width="146" bgcolor="#3465a4" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: none; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0cm">
			<p><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt"><b>Mensaje:</b></font></font></font></p>
		</td>
		<td width="501" bgcolor="#729fcf" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: 1px solid #ffffff; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0.1cm">
			<p style="font-weight: normal"><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt">'
                + @DetalleError
                + '</font></font></font></p>
		</td>
	</tr>
	<tr valign="top">
		<td width="146" bgcolor="#3465a4" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: none; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0cm">
			<p><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt"><b>Par&aacute;metros:</b></font></font></font></p>
		</td>
		<td width="501" bgcolor="#729fcf" style="border-top: none; border-bottom: 1px solid #ffffff; border-left: 1px solid #ffffff; border-right: 1px solid #ffffff; padding-top: 0cm; padding-bottom: 0.1cm; padding-left: 0.1cm; padding-right: 0.1cm">
			<p style="font-weight: normal"><font color="#ffffff"><font face="Microsoft Sans Serif, sans-serif"><font size="2" style="font-size: 10pt">'
                + RTRIM(CONVERT(VARCHAR(MAX), @Parametros, 1)) + '</font></font></font></p>
		</td>
	</tr>
</table>
<p style="margin-bottom: 0cm; line-height: 100%"><br>
</p>
</body>
</html>'
		
            DECLARE @iMsg AS INT ,
                @hr AS INT ,
                @source AS VARCHAR(255) ,
                @description AS VARCHAR(500) ,
                @output AS VARCHAR(1000);
		--************* Create the CDO.Message Object ************************ 
            EXEC @hr = sp_OACreate 'CDO.Message', @iMsg OUT;
		--***************Configuring the Message Object ****************** 
		
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusing").Value', '2';
		-- This is to configure the Server Name or IP address. 
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpserver").Value',
                'smtp.gmail.com';
		
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpserverport").Value', '465';
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpusessl").Value', '1';
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpconnectiontimeout").Value',
                '60';
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate").Value', '1';
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusername").Value',
                'trackingtpe@transpais.com.mx';
            EXEC @hr = sp_OASetProperty @iMsg,
                'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendpassword").Value',
                'transpais2315';

		-- Guardar las configuraciones del objeto de mensaje. 
            EXEC @hr = sp_OAMethod @iMsg, 'Configuration.Fields.Update', NULL;
		-- Establecer los parámetros de correo electrónico. 
            EXEC @hr = sp_OASetProperty @iMsg, 'To', @TO;
            EXEC @hr = sp_OASetProperty @iMsg, 'From', @FROM;
		--EXEC @hr = sp_OASetProperty @iMsg, 'CC', @CopyTo
            EXEC @hr = sp_OASetProperty @iMsg, 'Subject', @SUBJECT;
            EXEC @hr = sp_OASetProperty @iMsg, 'HTMLBody', @BODY
		---
            EXEC @hr = sp_OAMethod @iMsg, 'Send', NULL;
            EXEC @hr = sp_OADestroy @iMsg;
			
        END
GO
