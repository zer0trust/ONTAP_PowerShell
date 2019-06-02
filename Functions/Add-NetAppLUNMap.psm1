Function Add-NetAppLUNMap {
	[CmdletBinding(SupportsShouldProcess = $true)]
	<#
		.Description
		Function to add igroups to list of LUNs
		.Synopsis
		This function assumes you are already connected to a NetApp controller, and will fail if you do not have a current connection.
		.Example
			Add-NetAppLUNMap -ComputerName lab-esx-mgmt-001 -Config -FilePath \path\to\file -SVM lab_svm
	#>
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$ComputerName,
		[Parameter(Mandatory = $true, ParameterSetName = "File")]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( {
				if ( $_ -like "*.json" ) {
					if ( Test-Path $_) {
						$True
					} # Test-Path True
					else {
						Throw "Unable to locate $_"
					} #Test-Path false
				} # if match json true
				else {
					Throw "$_ must be a valid JSON file"
				} # if match json false
			}
		)]
		[string]$FilePath,
		[Parameter(Mandatory = $true, ParameterSetName = "Config")]
		[ValidateNotNullOrEmpty()]
		[hashtable]$Config
	)
	Process {
		if ($null -eq $currentnccontroller) {
			throw("Please connect to a NetApp controller before running this command")
		}
		if ( $FilePath ) {
			$Config = Get-Content -Path $FilePath | ConvertFrom-Json | ConvertTo-Hashtable
		} # if filepath
		if ( $Config.About.NetApp -ne $CurrentNcController) {
			throw( "Please connect to " + $Config.About.NetApp + " currently connected to " + $CurrentNcController)
		}

		Foreach ($LunPath in $Config.Storage) {
			Add-NcLunMap -Path /vol/$LunPath -InitiatorGroup $ComputerName -Vserver $Config.SVM
			#Write-Output "$ComputerName has been added to $LunPath"
		} # Foreach
	} # Process
} # function

