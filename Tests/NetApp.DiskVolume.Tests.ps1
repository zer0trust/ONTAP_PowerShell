Describe "NetApp disk, volume and snapshot tests" -Tags @('comprehensive', 'NetApp') {
$configfile = Get-Content ".\ontap-general-config.json" -raw
$basic_config = ConvertFrom-Json $configfile

if ($null -eq $currentnccontroller) {
  $controller = Read-Host -Prompt 'Target controller'
  $credential = Get-Credential 
  Connect-NcController -Name $controller -Credential $credential
}
else {
  Write-Host -Object ("Running tests against " + $currentnccontroller.Name + "...")
  }
	Context "Disks and volumes are healthy" {
		$broken_disks = Get-NcDisk | Where-Object { $_.DiskRaidInfo.ContainerType -eq "broken" }
		It "There are no broken disks present" -test {
			$broken_disks | Should -BeNullOrEmpty
		} # It
		$unassigned_disks = Get-NcDisk | Where-Object { $_.DiskRaidInfo.ContainerType -eq "unassigned" }
		It "There are no unassigned disks present" -test {
			$unassigned_disks | Should -BeNullOrEmpty
		} # It
		Get-NcVol | Where-Object { $_.State -eq "offline" }
		It "There are no offline volumes" -test {
			$_.State | Should -BeNullOrEmpty
		} # It
		$180days = (get-date).adddays(-180)
		$oldsnaps = (Get-NcSnapshot | Where-Object { ($_.Created -lt $180days -and $_.Total -ge 10GB -and $_.Dependency -eq $null) })
		$cv_snaps = (Get-NcSnapshot | Where-Object { ($_.Created -lt $180days -and $_.Total -ge 10GB -and $_.Dependency -eq $null -and $_.Name -like "SP_2_*") })
		It "There are no large snapshots older than 180 days (over 10GB and with no dependencies)" -test {
			$oldsnaps | Should -BeNullOrEmpty
		} # It-snaps
		It "There are no large CommVault snapshots older than 180 days" -test {
			$cv_snaps | Should -BeNullOrEmpty
		} # It-cv_snaps
	} # Context
} # Describe