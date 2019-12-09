<#  
.SYNOPSIS  
    Crea y configura la autentificación de O365 en Dynamics Business Central On-Prem
.DESCRIPTION  
    Este scrtipt genera la aplicación necesaria en el Azure Active Directory con los permisos necesarios 
    para poder configurar un servicio de Bsuiness Central con la autentificación de O365 (AAD).
    Es necesario disponer de una cuenta con permisos de administración en el tenant.
.NOTES  
    Fichero   : ConfO365BCAuth.ps1  
    Autor     : Roberto Ameijeiras - robertoameijeiras@gmail.com 
    Fecha     : 01-12-2019
.LINK  
#>



$Version = Read-Host -Prompt "Indica la version de NAV (130,140,150)" -
$RutaNavAdminTool = 'C:\Program Files\Microsoft Dynamics 365 Business Central\'+ $Version +'\Service\NavAdminTool.ps1'
Import-Module $RutaNavAdminTool


$NombreDNSPublico = Read-Host -Prompt "Introduce DNS público de la máquina (Ejemplo: arbdemo001.cloudapp.northeurope.com) "
$BCInstance = Read-Host -Prompt "Nombre de la instancia de BC (Ejemplo: BC140) "
$URLWeb = "https://$NombreDNSPublico/$BCInstance/"
$PublicODataURL = "https://" + $NombreDNSPublico + ":7048/$BCInstance/Odata"


$TipoAutentificacion = Get-NAVServerConfiguration -ServerInstance BC140 -KeyName ClientServicesCredentialType

if ($TipoAutentificacion -ne "NavUserPassword") {
    write-host "Es necesario tener configurada la instancia como NavUserPassword y su correspondiente certificado." -ForegroundColor red
    break
}

$Office365AdminCredenciales = Get-Credential

Write-Host "Creando aplicación en Azure AD" -ForegroundColor Yellow
Write-Host

if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
    Write-Host "Instalando NuGet Package Provider"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -WarningAction Ignore | Out-Null
}

if (!(Get-Package -Name AzureAD -ErrorAction Ignore)) {
    Write-Host "Instalando AzureAD PowerShell package"
    Install-Package AzureAD -Force -WarningAction Ignore | Out-Null
}

$ConexAAD = Connect-AzureAD -Credential $Office365AdminCredenciales

#Se eliminan apps si ya existen
Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($URLWeb) } | Remove-AzureADApplication

$aesManaged = New-Object "System.Security.Cryptography.AesManaged"
$aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
$aesManaged.BlockSize = 128
$aesManaged.KeySize = 256
$aesManaged.GenerateKey()
$SsoAdAppKeyValue = [System.Convert]::ToBase64String($aesManaged.Key)

Write-Host "Creando AAD App para WebClient"
$ssoAdApp = New-AzureADApplication -DisplayName "WebClient $URLWeb" `
                                   -Homepage $URLWeb `
                                   -IdentifierUris $URLWeb `
                                   -ReplyUrls @($URLWeb, ($URLWeb.ToLowerInvariant()+"SignIn"))

$startDate = Get-Date
New-AzureADApplicationPasswordCredential -ObjectId $ssoAdApp.ObjectId `
                                         -Value $SsoAdAppKeyValue `
                                         -StartDate $startDate `
                                         -EndDate $startDate.AddYears(10) | Out-Null

# Windows Azure Active Directory -> Permisos delegados (User.Read)
$req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
$req1.ResourceAppId = "00000002-0000-0000-c000-000000000000"
$req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"

# Dynamics 365 Business Central -> Permisos delegados (Financials.ReadWrite.All)
$req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
$req2.ResourceAppId = "996def3d-b36c-4153-8607-a6fd3c01b89f"
$req2.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "2fb13c28-9d89-417f-9af2-ec3065bc16e6","Scope"

Set-AzureADApplication -ObjectId $ssoAdApp.ObjectId -RequiredResourceAccess @($req1, $req2)

Write-Host "Configurando instancia de BC" -ForegroundColor Yellow
Write-Host
Set-NAVServerConfiguration -ServerInstance $BCInstance -KeyName "ClientServicesCredentialType" -KeyValue "NavUserPassword" -WarningAction Ignore
Set-NAVServerConfiguration -ServerInstance $BCInstance -KeyName "ValidAudiences" -KeyValue $ssoAdApp.AppId.ToString() -WarningAction Ignore -ErrorAction Ignore
Set-NAVServerConfiguration -ServerInstance $BCInstance -KeyName "AppIdUri" -KeyValue $URLWeb -WarningAction Ignore
Set-NAVServerConfiguration -ServerInstance $BCInstance -KeyName "WSFederationLoginEndpoint" -KeyValue "https://login.windows.net/Common/wsfed?wa=wsignin1.0%26wtrealm=$URLWeb" -WarningAction Ignore
Set-NAVServerConfiguration -ServerInstance $BCInstance -KeyName "ClientServicesFederationMetadataLocation" -KeyValue "https://login.windows.net/Common/FederationMetadata/2007-06/FederationMetadata.xml" -WarningAction Ignore
Set-NAVServerConfiguration -ServerInstance $BCInstance -KeyName "PublicODataBaseUrl" -KeyValue $PublicODataURL -WarningAction Ignore

Write-Host "Reiniciando instancia de BC..." -ForegroundColor Yellow
Write-Host

Restart-NAVServerInstance $BCInstance

Write-Host "Proceso finalizado" -ForegroundColor Green
Write-Host
