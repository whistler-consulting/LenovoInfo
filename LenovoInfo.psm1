Set-StrictMode -Version Latest

Function Invoke-LenovoWarrantyRESTAPI {
[CmdletBinding()]

    param
    (
        $Serial,
        $Product
    )

    $url = "https://ibase.lenovo.com/POIRequest.aspx"
    $verb = "POST"

    $header = @{ "Content-Type" = "application/x-www-form-urlencoded" }

    $body = [xml]"<wiInputForm source='ibase'><id>LSC3</id><pw>IBA4LSC3</pw><product></product><serial></serial><wiOptions><machine/><parts/><service/><upma/><entitle/></wiOptions></wiInputForm>"

    if (!([string]::IsNullOrEmpty($Product)))
    {
        #product parameter was provided

        $node = $body.SelectSingleNode("//product")
        $node.InnerText = $Product
    }

    if (!([string]::IsNullOrEmpty($SerialNumber)))
    {
        #model parameter was provided

        $node = $body.SelectSingleNode("//serial")
        $node.InnerText = $SerialNumber
    }

    $response = Invoke-RestMethod -Method $verb -Uri $url -Body ("xml=$($body.InnerXml))") -Headers $header

    return $response
}


Function Get-LenovoWarrantyInfo {
[CmdletBinding(DefaultParameterSetName="ByComputerName")]

    param (

        #Specifies the Lenovo serial number
        [Parameter(Mandatory = $true,
        ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $true,
        Position = 0,
        ParameterSetName="BySerialNumber")]
        [Alias('SN')]
        [string]$SerialNumber,

        #Lenovo Product Code for device being queried
        [Parameter(Mandatory = $false,
        ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $true,
        Position = 1,
        ParameterSetName = "BySerialNumber")]
        [string]$Product,

        [Parameter(Mandatory = $false,
        ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $true,
        Position = 0,
        ParameterSetName = "ByComputerName")]
        [string]$ComputerName,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.CredentialAttribute()]$Credential
        
    )

    switch($PsCmdlet.ParameterSetName)
    {
        "BySerialNumber"
        {
            #don't need anything extra because we already have serial number and possibly product code
        }
        }
        "ByComputerName"
        {
            # need to use WMI to lookup serial number and model number of device
            
            $args = @{ namespace = "root\cimv2"
                        class = "Win32_SystemEnclosure"
                        ErrorAction = "SilentlyContinue"}

            if (!([string]::IsNullOrEmpty($ComputerName)))
            {
                $args.Add("ComputerName", $ComputerName)
            }

            if (!([string]::IsNullOrEmpty($Credential)))
            {
                $args.Add("Credential", $Credential)
            }

            $result = Get-WmiObject @args

            if ($result -eq $null)
            {
                Write-Error "Unable to retrieve Serial Number from computer '$computername'"
                Exit
            } 
            else 
            {

                $SerialNumber = $result | Select-Object -ExpandProperty SerialNumber

                $args["Class"] = "Win32_ComputerSystem"

                $result = Get-WmiObject @args

                $Product = $result | Select-Object -ExpandProperty Model

                $Manufacturer = $result | Select-Object -ExpandProperty Manufacturer

                if ($Manufacturer -notmatch "Lenovo")
                {
                    Write-Warning "Possibly not a Lenovo device"
                }
            }
        }

    $args = @{}
    $args.Add("Serial", $SerialNumber)

    if ($null -ne $Product) { $args.Add("Product", $Product) }

    $webresponse = Invoke-LenovoWarrantyRESTAPI @args

    if ($null -eq $webresponse) 
    {
        Write-Error "REST API returned NULL"
    }
    else
    {
        #REST API returned data

        $properties = @{}

        if ($webresponse.SelectSingleNode("serviceInfo")) {

            $properties.Add("ShipDate", $webresponse.wiOutputForm.warrantyInfo.serviceInfo.shipDate[0])
            $properties.Add("WarrantyStartDate", $webresponse.wiOutputForm.warrantyInfo.serviceInfo.warstart[0])
            $properties.Add("WarrantyEndDate", $webresponse.wiOutputForm.warrantyInfo.serviceInfo.wed[0])
        } else {
            $properties.Add("ShipDate", $null)
            $properties.Add("WarrantyStartDate", $null)
            $properties.Add("WarrantyEndDate", $null)
        }


        if ($webresponse.SelectSingleNode("machineInfo")) {

            $properties.Add("Model", $webresponse.wiOutputForm.warrantyInfo.machineinfo.model)
            $properties.Add("Type", $webresponse.wiOutputForm.warrantyInfo.machineinfo.type)
            $properties.Add("Product", $webresponse.wiOutputForm.warrantyInfo.machineinfo.product)
            $properties.Add("SerialNumber", $webresponse.wiOutputForm.warrantyInfo.machineinfo.serial)
        }

        $errorMessage = $webresponse.wiInputForm.xmlMessages.xmlMessage | Where-Object {$_.type -eq "error"}

        if ( $errorMessage -ne $null  ) {
            $properties.Add("ErrorNumber",($errorMessage.num))
            $properties.Add("ErrorText", ($errorMessage.InnerText))

        }
    }

    $WarrantyInfo = New-Object –TypeName PSObject –Prop $properties

    $WarrantyInfo    
}

Export-ModuleMember Get-LenovoWarrantyInfo












