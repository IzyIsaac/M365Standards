param (
    [Parameter(Mandatory=$true, 
        HelpMessage="The friendly name of the app registration.")]
    [String]$AppName,

    [Parameter(Mandatory=$true,
        HelpMessage="List of Claims your application requires. Only supports adding Microsoft Graph claims. Other Microsoft resource claims will need to be added in the Entra portal.")]
    [String[]]$Claims
)

Import-Module Az.Resources
Import-Module Microsoft.Graph.Authentication

Write-Output "Connecting to azure, please sign in on your web browser..."
Connect-AzAccount


if ($null -ne (Get-AzADApplication -DisplayName $AppName))
{
    Write-Error "An application with the name `"$AppName`" already exists, aborting" -Category ResourceExists
    return
}

# Graph API Permissions
$graphScopes = @()
$Claims | Find-MgGraphPermission -ExactMatch -PermissionType Application | ForEach-Object  {
    $graphScopes += @{Id = $_.Id; Type = "Role"}
}
$graphResourceAccess = @{
    ResourceAppId = "00000003-0000-0000-c000-000000000000"
    ResourceAccess = $graphScopes
}

# Partner Center API permissions
$partnerResourceAccess = @{
    ResourceAppId = "fa3d9a0c-3fb0-42cc-9193-47c7ecd2edbd"
    ResourceAccess = @{
        Id = "1cebfa2a-fb4d-419e-b5f9-839b4383e05a"
        Type = "Scope"
    }
}

# Client secret
$passwordCredentials = @{
    KeyId = "$AppName-Secret"
}

Write-Output "Creating new aad application registration..."
$params = @{
    AvailableToOtherTenants = $true
    DisplayName = $AppName
    RequiredResourceAccess = $graphResourceAccess, $partnerResourceAccess
    PasswordCredentials = $passwordCredentials
    Web = @{ RedirectUris=@("http://localhost","https://localhost") }
}
$application = New-AzADApplication @params
