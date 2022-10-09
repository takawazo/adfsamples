
<#
# MIT License

# Copyright (c) 2022 Takahiro Kawazoe

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#>

<#
.SYNOPSIS
Update pipeline's settings in specified Data Factory. In this script, we update concurrency of pipeline

.DESCRIPTION
.EXAMPLE
.\AdfPipelineUpdate.ps1
This will show the existing pipeline count
.EXAMPLE
.\AdfPipelineUpdate.ps1 -List
This will list up the existing pipeline names and count
.EXAMPLE
.\AdfPipelineUpdate.ps1 -Update
This will list up the existing pipeline names and count. Also it will update the pipeline settings.
.EXAMPLE
.\AdfPipelineUpdate.ps1 -Verbose
This will show verbose message and can be used with other parameters (List, Update)
.EXAMPLE
.\AdfPipelineUpdate.ps1 -Verbose -List -Update
This will List and Update with verbose message
#>

Param(
   [Parameter(Mandatory=$false, HelpMessage="Will update the pipelines")]
   [Switch]$Update,
   [Parameter(Mandatory=$false, HelpMessage="Will list the pipelines")]
   [Switch]$List
)


# URL for single pipeline resource
# https://management.azure.com/subscriptions/<subscriptionId>/resourceGroups/<resourceGroup>/providers/Microsoft.DataFactory/factories/<dataFactoryName>/pipelines/<pipelineName>?api-version=2018-06-01

# Prerequisite: Create a service principal and grant the permission
# Replace clientId, secret, tenant and subscriptionId
$appId = "<appId>";
$password = "<client secret>";
$tenant = "<tenant Id>";
$subscriptionId = "<subscription Id>";

# Replace resource Group, data Factory
$resourceGroup = "<resource Group>";
$dataFactory = "<data Factory>";


# 1. Receive access token
# Get an access token
$body = @{grant_type='client_credentials'
client_id=$appId
client_secret=$password
resource='https://management.azure.com/'}
$contentType = 'application/x-www-form-urlencoded'
$tokenEndpointUri = "https://login.microsoftonline.com/"+$tenant+"/oauth2/token"
$loginRequest = Invoke-WebRequest  -Method Post -Uri $tokenEndpointUri -body $body -ContentType $contentType
$accesstoken = (ConvertFrom-Json -InputObject $loginRequest.Content).access_token

# Set the header
$headers = @{"Authorization"="Bearer "+$accesstoken};

# 2. Get the list of pipelines
# Set the rest URL and issue REST request
$pipelineListUrl = "https://management.azure.com/subscriptions/"+$subscriptionId+"/resourceGroups/"+$resourceGroup+"/providers/Microsoft.DataFactory/factories/"+$dataFactory+"/pipelines?api-version=2018-06-01"
$restCall = (Invoke-WebRequest -Uri $pipelineListUrl -Method Get -Headers $headers).Content
$pipelineJSON=  ConvertFrom-Json -InputObject $restCall

Write-Host "The number of pipelines:" $pipelineJSON.value.count -ForegroundColor Cyan


#Loop pipelines and issue rest request
ForEach($pipeline in $pipelineJSON.value)
{
    $pipelineName = $pipeline.name
    $pipelineId = $pipeline.id

    #List pipeline and resource URI
    if($List)
    {
        Write-Host "Pipeline : $pipelineName" 
        Write-Verbose "Pipeline ID : $pipelineId"
    }

    #Update pipeline property
    if($Update)
    {
        # Set the REST API URL for individual pipeline:
        $pipelineListUrl = "https://management.azure.com/subscriptions/"+$subscriptionId+"/resourceGroups/"+$resourceGroup+"/providers/Microsoft.DataFactory/factories/"+$dataFactory+"/pipelines/"+$pipeline.name+"?api-version=2018-06-01"
        
        # Issue REST Requet to get pipeline json
        Write-Verbose "Issuing request to $pipelineName" 
        $restCall = (Invoke-WebRequest -Uri $pipelineListUrl -Method Get -Headers $headers).Content
        
        # Json in PUT shouldn't include elements except for priperties. See details below
        # https://learn.microsoft.com/en-us/rest/api/datafactory/pipelines/create-or-update?tabs=HTTP
        $jsonBody =  ConvertFrom-Json -InputObject $restCall | select-Object -ExcludeProperty id, etag, type, name

        # For instance, let's set concurrency to 2
        # If no concurrency is set, add member to PSCustomObject
        if($NULL -ne $jsonBody.properties.concurrency){
            $jsonBody.properties.concurrency = 2
        }else{
            $jsonBody.properties | Add-Member -MemberType NoteProperty -Name concurrency -value 2
        }
        $jsonBodyForPUT = $jsonBody | ConvertTo-Json -Depth 10

        # Issue REST Requet to update pipeline with json
        Write-Verbose "Issuing request to $pipelineName to update" 
        $restCall = Invoke-WebRequest -Method Put -Uri $pipelineListUrl  -Headers $headers -Body $jsonBodyForPUT
    }
}
