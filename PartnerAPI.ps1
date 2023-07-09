
function Connect-MSPartnerCenter

   $requestBody = @{ 
       Uri = "https://login.microsoftonline.com/{$tenantId}/oauth2/token"
       } 
