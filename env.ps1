# Change me!
$thumbprint = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$tenantid = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" 
$clientsecret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$clientid = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$vaultname = "vaultname"

# Set env variables
$password = ConvertTo-SecureString $clientsecret -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential($clientid, $password)
Set-Item -path env:thumbprint -Value $thumbprint
Set-Item -path env:tenantid -value $tenantid
Set-Item -path env:creds -value $creds
Set-Item -path env:clientid -Value $clientid
Set-Item -path env:clientsecret -Value $clientsecret
Set-Item -path env:vaultname -value $vaultname

