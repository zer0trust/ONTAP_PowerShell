Describe "NetApp Networking Tests" -Tags @('comprehensive', 'NetApp') {
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
	Context "Testing Cluster NTP Server Settings" {
		(Get-NcNtpServer -ServerName $Config.Cluster.NTP.ServerName1).ForEach{
			It "1st NTP server is configured correctly" -test {
				$_.ServerName | Should -Be $basic_config.Cluster.NTP.ServerName1
				$_.ServerName | Should -Not -Be $Null
			} # It
			(Get-NcNtpServer -ServerName $Config.Cluster.NTP.ServerName2).ForEach{
				It "2nd NTP server is configured correctly" -test {
					$_.ServerName | Should -Be $Config.Cluster.NTP.ServerName2
					$_.ServerName | Should -Not -Be $Null
				} # It
			} # Get-NcNtpServer-1
		} # Get-NcNtpServer-0
	} # Context
	Context "Testing DNS Server settings for each SVM" {
		(Get-NcNetDNS).ForEach{
			It "DNS state is enabled for $($_.Vserver)" -test {
				$_.DNSState | Should -Be enabled
			} # It
			It "More than one name server is configured for $($_.Vserver)" -test {
				$_.NameServers.Count | Should -BeGreaterThan 1
			} # It
			It "Nameserver values are well-defined" -test {
				$_.NameServers | Should -Be $Config.Cluster.Nameservers
			} # It
		} # Get-NcNetDNS
	} # Context
	Context "Testing NIS Server settings for each SVM" {
		(Get-NcNis).ForEach{
			It "NIS servers are active for $($_.Vserver)" -test {
				$_.IsActive | Should -Be True
			} # It
			It "NIS server values are well-defined" -test {
				$_.NisServers | Should -Be $Config.Cluster.NisServers
			} # It
		} # Get-NcNis
	} # Context
	Context "Testing cluster networking and SnapMirror components" {
		$sp = (Get-NcServiceProcessor | Where-Object { $_.Status -eq "offline" })
		It "Service Processors for all nodes are online" -test {
			$sp | Should -BeNullOrEmpty
		} # It
		$autoupdate = (Get-NcServiceProcessor | Where-Object { $_.IsAutoUpdateEnabled -eq "False" })
		It "Service Processor auto update is enabled for all nodes" -test {
			$autoupdate | Should -BeNullOrEmpty
		} # It
		$dataping = Get-NcClusterPeerHealth | Where-Object { $_.DataPing -match "unreachable" }
		It "All nodes have data connectivity to peered nodes" -test {
			$dataping | Should -BeNullOrEmpty
		} # It
		$sm = Get-NcSnapMirror | Where-Object { $_.IsHealthy -match "false" }
		It "All SnapMirror relationships are healthy" -test {
			$sm | Should -BeNullOrEmpty
		} # It
		$ports = Get-NcNetPort | Where-Object { $_.Role -ne "data" } | Where-Object { $_.LinkStatus -match "down" }
		It "All cluster and node management ports are up" -test {
			$ports | Should -BeNullorEmpty
		} # It
		$int = Get-NcNetInterface | Where-Object { $_.IsHome -match "false" }
		It "All interfaces are at their home ports" -test {
			$int | Should -BeNullOrEmpty
		} # It
	}  # Context
} # Describe