param (
    [Parameter(Mandatory=$true, 
    HelpMessage="The friendly name of the app registration.")]
    [String]$AppName,

    [Parameter(Mandatory=$true,
    HelpMessage="List of Claims your application requires. Only supports adding Microsoft Graph claims. Other Microsoft resource claims will need to be added in the Entra portal.")]
    [String[]]$Claims,

    [Parameter(Mandatory=$false,
    HelpMessage="Azure Subscription ID for creating a new key vault")]
    [String]$SubscriptionID
)

Import-Module Microsoft.Graph.Applications

Write-Host("Connecting to MSGraph...")
Connect-MgGraph -Scopes "Application.ReadWrite.All"

$context = Get-MgContext

if ($null -ne (Get-MgApplication |  Where-Object DisplayName -eq $AppName)) {
    $confirm = Read-Host "An application with the name $AppName already exists. Use existing application or abort? (y/n(abort))"
    if ($confirm -ne "y") { 
        return 
    }
    else {
        Write-Host "Grabbing existing application..."
        $application = Get-MgApplication -Filter "DisplayName eq '$AppName'"
        if($application.getType().Name -eq "Object[]") {
                Write-Host "More than one application with specified name exists, aborting"
                return
        }
    }
}

# Password authentication
$PasswordCredentials = @(
    @{
        EndDateTime = 
    }
)

# GraphAPI permissions
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

# Create or update the AAD application
if($null -eq $application) {
    $application = New-MgApplication -AvailableToOtherTenants $true -DisplayName $AppName -RequiredResourceAccess $requiredResourceAccess, $partnerResourceAccess -KeyCredentials $KeyCredentials -Web @{ RedirectUris="http://localhost" }
    Write-Host "Created new application with AppId: $($application.AppId)"
    }
else {
    Update-MgApplication -AvailableToOtherTenants $true -ApplicationId $application.Id -RequiredResourceAccess $requiredResourceAccess, $partnerResourceAccess -KeyCredentials $KeyCredentials -Web @{ RedirectUris="http://localhost" }
    Write-Host "Updated existing application with AppId: $($application.AppId)"
    }

# Create a service principal for our new app


Write-Host "Generating admin consent URL..."
$adminConsentUrl = "https://login.microsoftonline.com/" + $context.TenantId + "/adminconsent?client_id=" `
 + $application.AppId
Write-Host "Please go to the following URL in your browser to provide admin consent:"
Write-Host -ForegroundColor Yellow $adminConsentUrl
Write-Host

$connectGraph = "Connect-MgGraph -ClientId """ + $application.AppId + """ -TenantId """`
 + $context.TenantId + """ -CertificateThumbprint """ + $Thumbprint + """"
Write-Host "After providing admin consent, you can use the following command to connect to Graph in your application:"
Write-Host -ForegroundColor Yellow $connectGraph
Write-Host
Write-Host "Disconnecting from Microsoft Graph"
Disconnect-MgGraph
