param (
    [Parameter(Mandatory=$true, 
        HelpMessage="Azure application client ID and secret in a PSCredential object")]
    [System.Management.Automation.PSCredential]$Credentials,

    [Parameter(Mandatory=$true,
        HelpMessage="Azure/M365 tenantID")]
    [String]$TenantID,

    [Parameter(Mandatory=$false,
        HelpMessage="Certificate thumbprint for local certificate that has access to your keyvault")]
    [String]$Thumbprint,

    [Parameter(Mandatory=$false,
        HelpMessage="Name of your Azure key vault")]
    [String]$VaultName,

    [Parameter(Mandatory=$false,
        HelpMessage="Name of secret to store refresh token in")]
    [String]$SecretName
)

$uri = "https://login.microsoftonline.com/{$($TenantId)}/oauth2/token"
$clientSecret = ConvertFrom-SecureString $Credentials.Password -AsPlainText
$body = @{
    resource = "https://graph.windows.net"
    client_id = $Credentials.UserName
    client_secret = $clientSecret
    grant_type = "client_credentials"
}


function Get-AuthCode($clientId, $port)
{
    # Start an HTTP listener to catch a redirect from the web browser with the users auth code
    Write-Output "Starting http listener on port $port"
    $httpListener = New-Object System.Net.HttpListener
    $httpListener.Prefixes.Add("http://localhost:$port/")
    $httpListener.Start()

    # Opens AAD sign-in in the default browser
    Start-Process "https://login.microsoftonline.com/common/oauth2/authorize?&client_id=$($clientId)&response_type=code&redirect_url=https://localhost:55485"
    Write-Host -ForegroundColor Green "Sign in with your service account in the browser that opened..."

    # HTTP listener blocks until user completes login in browser and redirects to the listener
    $context = $httpListener.GetContext()

    # Parse the web browser redirect request to grab auth code
    $context.Request.RawUrl -match '(?<=code=)[^&]+'
    $authCode = $matches.0
    if($null -eq $authCode)
    {
        Write-Error "Something went wrong, unable to grab auth code from browser, aborting"
        exit
    }

    # Send the browser a success message
    $context.Response.StatusCode = 200
    $context.Response.ContentType = "text/HTML"
    $HTML = "<!doctype html>
        <title>Success</title>
        Sucessfully grabbed authentication code. You can close this window
        "
    $encodedHTML = [Text.Encoding]::UTF8.GetBytes($HTML)
    $context.Response.OutputStream.Write($encodedHTML, 0, $encodedHTML.Length)

    $httpListener.Close()
    return $authCode
}

function Get-RefreshToken($TenantID, $clientId, $clientSecret, $authCode)
{
    $uri = "https://login.microsoftonline.com/{$($TenantId)}/oauth2/token"
    $clientSecret = ConvertFrom-SecureString $Credentials.Password -AsPlainText
    $body = @{
        resource = "https://graph.microsoft.com"
        client_id = $clientId
        code = $authCode
        grant_type = "authorization_code"
    }
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body

    if($null -eq $response.refresh_token)
    {
        Write-Error "Failed to get refresh token with auth code, aborting"
        exit
    }
    return $response.refresh_token
}

function Set-KeyVaultRefreshToken($clientId, $TenantID, $Thumbprint, $vaultName, $secretName, $refreshToken)
{
    Write-Output "Connection to Azure"
    $params = @{
        CertificateThumbprint = $cert.Thumbprint
        ApplicationId = $clientId
        Tenant = $TenantId
        ServicePrincipal = $true
    }
    Connect-AzAccount @params

    Write-Output "Adding refresh token to $vaultName with key name $secretName"
    Set-AzKeyVaultSecret -VaultName $vaultName -secretName $secretName -SecretValue $refreshToken
}


$clientId = $Credentials.UserName
$clientSecret = ConvertFrom-SecureString $Credentials.Password -AsPlainText
$port = "55485"

$authCode = Get-AuthCode($clientId, $port)
$refreshToken = Get-RefreshToken($TenantID, $clientId, $clientSecret, $authCode)
Set-KeyVaultRefreshToken($clientId, $TenantID, $Thumbprint, $VaultName, $secretName, $refreshToken)

Write-Ouput "Updated refresh token, exiting..."
