Function Remove-SANHost {
	<#
		.Description
		Function to remove igroups from LUNs, offline/delete boot LUNs and then delete igroups. Useful when decommissioning hosts.
		.Synopsis
		This function assumes you are already connected to a NetApp controller, and will fail if you do not have a current connection.
		.Example
		Remove-SANHost -ComputerName lab-esx-mgmt-001
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$ComputerName
	)
	Process {
		if ($null -eq $CurrentNcController) {
			throw("Please connect to a NetApp controller before running this command")
		} # if connected
		$igroup = Get-NcIgroup -Name $ComputerName.ToLower()
		if ( $null -eq $igroup) {
			throw( "Unable to locate igroup")
		}
		#Find all Luns that are mapped to the igroup

		$MappedLuns = Get-NcLunMap -Vserver $igroup.Vserver | Where-Object InitiatorGroup -eq $igroup

		#Loop through the Luns and remove the mapping
		#Remove-NcLunMap supports -whatif so no need to wrap it in $pscmdlet

		Foreach ($Path in $MappedLuns) {
			Remove-NcLunMap -Path $Path.Path -InitiatorGroup $igroup.Name -VserverContext $igroup.Vserver
		} # Foreach

		#Of the mapped luns, LUN 0 is our boot LUN and needs to go along with the rest

		$BootLun = $MappedLuns | Where-Object LunId -eq 0
		if ( $null -eq $BootLun) {
			Write-Warning -Message "Unable to find Boot LUN"
		}
		else {
			Set-NcLun -Path $BootLun.Path -Offline -VserverContext $igroup.Vserver
			Remove-NcLun -Path $BootLun.Path -VserverContext $igroup.Vserver
		}
		Foreach ( $Initiator in $igroup.Initiators) {

			#It is possible that our initiators are part of a different igroup, so we should just check and pull them there too.
			$NcIgroups = Get-NcIgroup -Initiator $Initiator -Vserver $igroup.Vserver

			Foreach ($Group in $NcIgroups) {
				Remove-NcIgroupInitiator -Name $Group -Initiator $Initiator -VserverContext $igroup.Vserver
			} # Foreach
		} # Foreach

		#Now that we feel good about things, we can delete the igroup.

		Remove-NcIgroup -Name $igroup -VserverContext $igroup.Vserver

	} # Process
} # function