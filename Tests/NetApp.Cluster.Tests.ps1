Describe "NetApp Cluster tests" -Tags @('comprehensive', 'NetApp') {
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
	It "Check Cluster ONTAP version" {
		$version = Get-NcSystemVersion
		$version | Should -Match 'NetApp Release 9.3P8'
	} # It
	(Get-NcNode).ForEach{
		Context "Testing AutoSupport Settings on $($_)" {
			(Get-NcAutoSupportConfig -Node $_.Node).ForEach{
				It "AutoSupport settings are well-defined" -test {
					$_.IsEnabled | Should -Be $Config.Cluster.AutoSupport.IsEnabled
					$_.Transport | Should -Be $Config.Cluster.AutoSupport.Transport
					$_.MailHosts | Should -Be $Config.Cluster.Autosupport.MailHost
					$_.SupportAddress | Should -Be $Config.Cluster.Autosupport.SupportAddress
					$_.To | Should -Be $Config.Cluster.Autosupport.To
				} # It
			} # Get-NcAutoSupportConfig
		} # Context
	} # Get-NcNode
	Context "Testing cluster-level health settings" {
		(Get-NcClusterHaInfo).ForEach{
			It "Node state is connected for $($_.Node)" -test {
				$_.NodeState | Should -Be connected
			} # It
			It "Takeover of $($_.Node) is possible" -test {
				$_.TakeOverEnabled | Should -Be True
			} # It
	 } # Get-NcClusterHaInfo
		$autogb = Invoke-NcSsh -Command "storage failover show -fields auto-giveback"
		It "Auto-giveback is enabled for all nodes" -test {
			$autogb | Should -Not -Contain false
		} # It
		(Get-NcClusterNode).ForEach{
			It "$($_.NodeName) is healthy and eligible for cluster participation" -test {
				$_.IsNodeHealthy | Should -Be True
				$_.IsNodeEligible | Should -Be True
			} # It
		} # Get-NcClusterNode
	} # Context
} # Describe