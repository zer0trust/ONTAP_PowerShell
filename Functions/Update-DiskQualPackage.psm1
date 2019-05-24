<#
.SYNOPSIS
   Downloads a Disk Qualification Package on a NetApp controller. The CredentialManager module is required.
.DESCRIPTION
   Disk Qualification Package is uploaded using this function.
.PARAMETER Controller
	Controller to connect to.
.PARAMETER StoredCredential
	Name of the stored credential object in the Windows Credential Manager.
.EXAMPLE
   Update-DiskQualPackage -Controller lab-clst-01 -StoredCredential LAB_ONTAP
#>
Function Update-DiskQualPackage {
	[CmdletBinding(SupportsShouldProcess = $true)]

	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Controller,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$StoredCredential
	)
	# Check DataONTAP PowerShell module

	Process {

		if (Get-Module -ListAvailable DataONTAP) {
			Import-Module DataONTAP
		}
		else {
			Throw "Required Module 'DataONTAP' is missing."
		}
		# Log into NetApp Support site and download latest DQP to local directory

		$PathDQP = "C:\web\qual_devices.zip"
		$c = Get-StoredCredential -Target "netapp_support"
		$r = Invoke-WebRequest 'https://mysupport.netapp.com/NOW/download/tools/diskqual/' -SessionVariable my_session
		$form = $r.Forms[0]
		$form.fields['user'] = $c.UserName
		$form.fields['password'] = $c.GetNetworkCredential().Password
		$r = Invoke-WebRequest -Uri ('https://mysupport.netapp.com/NOW/download/tools/diskqual/qual_devices.zip') -WebSession $my_session -Method $form.Method -Body $form.Fields -OutFile $PathDQP

		# Check for existence of DQP .zip file

		if ($PathDQP) {
			if (Test-Path -Path $PathDQP) {
			}
		}
		else {
			Throw "DQP does not exist at the specified file path."
		}

		# Check that localhost web server is listening on port 80

		if (Test-NetConnection -ComputerName localhost -CommonTCPPort HTTP -InformationLevel Quiet) {
		}
		else {
			Throw "Web server is not listening on port 80 on localhost."
		}

		# Check controller connection

		if ($null -eq $currentnccontroller) {
			$credentials = Get-StoredCredential -Target $StoredCredential
			Connect-NcController $Controller -Credential $credentials
		}
		# Download firmware from local web server to controller

		Invoke-NcSsh -Command "storage firmware download -node * -package-url http://1.1.1.1/qual_devices.zip"

	} # Process
} # Function