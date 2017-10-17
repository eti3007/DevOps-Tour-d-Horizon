<#
    .DESCRIPTION
        An runbook which add NSG for VM and encrypt storage blob

    .NOTES
        AUTHOR: Etienne L.
        LASTEDIT: Oct 06, 2017
#>


$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}


#Get "Demo-Automation" resource groups
$ResourceGroup = Get-AzureRmResourceGroup -Name Demo-Automation
if ($ResourceGroup){
    Write-Output ("Update security settings in resource group " + $ResourceGroup.ResourceGroupName + " for resource with tag SECURITYRULE: ")

    $Resources = Find-AzureRmResource -ResourceGroupNameContains $ResourceGroup.ResourceGroupName | Select ResourceName, ResourceType
    ForEach ($Resource in $Resources){
        if ($Resource.ResourceType.ToString() -eq "Microsoft.Storage/storageAccounts"){
            $sto = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $Resource.ResourceName
            if ($sto.Tags['securityRule'] -eq "encryption") {
                $blob = ($sto | select Encryption).Encryption.Services.Blob.Enabled
                if (-not $blob) {
                    Set-AzureRmStorageAccount -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $Resource.ResourceName -EnableEncryptionService "Blob"
                    
                    Write-Output ($Resource.ResourceName + " Blob encryption succeed !")
                }
            }
        }
        if ($Resource.ResourceType.ToString() -eq "Microsoft.Compute/virtualMachines"){
            $vm = Get-AzureRmVM -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $Resource.ResourceName
            if ($vm.Tags['securityRule'] -eq "networkgroup") {
                $nsgName = $Resource.ResourceName + "nsg"

                $rule1 = New-AzureRmNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" `
                    -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix `
                    Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
                
                $rule2 = New-AzureRmNetworkSecurityRuleConfig -Name web-rule -Description "Allow HTTP" `
                    -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix `
                    Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80
                
                $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $ResourceGroup.Location -Name $nsgName -SecurityRules $rule1,$rule2
                Write-Output ($Resource.ResourceName + " NSG creation succeed !")

                $vnetName = (Get-AzureRmResourceGroup -Name $ResourceGroup.ResourceGroupName | Get-AzureRmResource -ResourceType "Microsoft.Network/virtualNetworks").Name
                $subnet = (Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $ResourceGroup.ResourceGroupName).Subnets[0]

                $vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $ResourceGroup.ResourceGroupName | `
                Set-AzureRmVirtualNetworkSubnetConfig -Name $subnet.Name -AddressPrefix $subnet.AddressPrefix -NetworkSecurityGroup $nsg

                Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

                Write-Output ("NSG associated to subnet: " + $subnet.Name)
            }
        }
    }
}
