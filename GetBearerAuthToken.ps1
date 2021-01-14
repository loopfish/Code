[int]$global:RetryCnt = 0
[string]$global:subscription = "76a230a7-16a7-40fd-9da5-23228cbd2bb0"
[string]$global:Failure = ""

function getBearer([string]$TenantID, [string]$ClientID, [string]$ClientSecret)
{
  $TokenEndpoint = {https://login.windows.net/{0}/oauth2/token} -f $TenantID 
  $ARMResource = "https://management.core.windows.net/";

  $Body = @{
          'resource'= $ARMResource
          'client_id' = $ClientID
          'grant_type' = 'client_credentials'
          'client_secret' = $ClientSecret
  }

  $params = @{
      ContentType = 'application/x-www-form-urlencoded'
      Headers = @{'accept'='application/json'}
      Body = $Body
      Method = 'Post'
      URI = $TokenEndpoint
  }

  $token = Invoke-RestMethod @params

  Return "Bearer " + ($token.access_token).ToString()
}

function GetVMMetrics ([string]$Bearer, [string] $resourcegroup, [string]$VM, [string]$metric, [ref]$score)
{

  $Endpoint = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/virtualMachines/{2}/providers/microsoft.insights/metrics?api-version=2019-07-01&metricnames={3}&interval=PT1H&aggregation=average" -f $global:subscription, $resourcegroup, $VM, $metric 

  try
  {
     $note = ""
          $params = @{
              ContentType = 'application/x-www-form-urlencoded'
              Headers = @{Authorization = "$Bearer"}
    
              Method = 'Get'
              URI = $Endpoint
          }

            $Result = Invoke-RestMethod @params