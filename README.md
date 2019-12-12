# Introducción

Crea y configura la autentificación de O365 (AAD) en Dynamics Business Central On-Prem

Este scrtipt genera la aplicación necesaria en el Azure Active Directory con los permisos necesarios  para poder configurar un servicio de Business Central con la autentificación de O365 (AAD).

# Requisitos

- Cuenta de administrador del tenant de Azure
- Cuenta de administrador local de la máquina
- Instancia de BC configurada con certificado válido

# Instrucciones

Descargar el proyecto a un directorio local y ejecutar desde la consola de PowerShell (admin) el fichero **ConfO365BCAuth.ps1**
Una vez iniciado el script nos solicitará la siguiente información:

- Indica la version de Business Central (130,140 o 150)
- Nombre DNS público de la máquina (Ejemplo: demo001.cloudapp.northeurope.com)
- Nombre de la instancia de BC (Ejemplo: BC140)

Una vez terminada la ejecución del script se reiniciará la instancia de Business Central.

Más información en [++Authenticating Business Central Users with Azure Active Directory++] (https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/authenticating-users-with-azure-active-directory)

# Acerca de 

- [**www.robertoameijeiras.com**](https://www.robertoameijeiras.com)
- [**robertoameijeiras@gmail.com**](mailto:robertoameijeiras@gmail.com)
- [**@r_ameijeiras**](https://twitter.com/r_ameijeiras)



