Set-StrictMode -Version Latest


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
        $SerialNumber,

        #Lenovo Product Code for device being queried
        [Parameter(Mandatory = $false,
        ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $true,
        Position = 1,
        ParameterSetName = "BySerialNumber")]
        $Product,

        [Parameter(Mandatory = $false,
        ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $true,
        Position = 0,
        ParameterSetName = "ByComputerName")]
        $ComputerName,

        [Parameter(Mandatory = $false)]
        $Credential
        
    )

    $url = "https://ibase.lenovo.com/POIRequest.aspx"
    $verb = "POST"

    $header = @{ "Content-Type" = "application/x-www-form-urlencoded" }

    $body = [xml]"<wiInputForm source='ibase'><id>LSC3</id><pw>IBA4LSC3</pw><product></product><serial></serial><wiOptions><machine/><parts/><service/><upma/><entitle/></wiOptions></wiInputForm>"

    switch($PsCmdlet.ParameterSetName)
    {
        "BySerialNumber"
        {
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
        }
        "ByComputerName"
        {
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
            }
        }


    }



    $SerialNumber
    $Product
    $ComputerName
    $Manufacturer

    break

   




    $webresponse = Invoke-RestMethod -Method $verb -Uri $url -Body $body -Headers $header

    $properties = @{}

    $properties.Add("LastUpdate", (get-date))

    if ($webresponse.wiOutputForm.warrantyInfo.serviceInfo) {

        $properties.Add("ShipDate", $webresponse.wiOutputForm.warrantyInfo.serviceInfo.shipDate[0])
        $properties.Add("WarrantyStartDate", $webresponse.wiOutputForm.warrantyInfo.serviceInfo.warstart[0])
        $properties.Add("WarrantyEndDate", $webresponse.wiOutputForm.warrantyInfo.serviceInfo.wed[0])
    } else {
        $properties.Add("ShipDate", $null)
        $properties.Add("WarrantyStartDate", $null)
        $properties.Add("WarrantyEndDate", $null)
    }


    if ($webresponse.wiOutputForm.warrantyInfo.machineinfo) {

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

    $WarrantyInfo = New-Object –TypeName PSObject –Prop $properties


    $WarrantyInfo    

}

Export-ModuleMember Get-LenovoWarrantyInfo












