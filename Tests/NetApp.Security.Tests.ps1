Describe "NetApp Security Tests" -Tags @('comprehensive', 'NetApp') {
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
	Context "Testing Fpolicy (Native and Varonis) components" {
		(Get-NcFpolicyStatus).ForEach{
			It "Fpolicy is enabled and connected for $($_.PolicyName) in $($_.Vserver)" -test {
				$_.Enabled | Should -Be True
			} # It
		} # Get-NcFpolicyStatus
		(Get-NcFpolicyEvent | Where-Object { $_.EventName -eq "evt_ransomware" }).ForEach{
			It "Native Fpolicy events are well-defined for $($_.Vserver)" -test {
				$_.Protocol | Should -Be "cifs"
				$_.FileOperations | Should -Be @("create", "rename")
			} # It
		} # Get-NcFpolicyEvent
		(Get-NcFpolicyPolicy | Where-Object { $_.EngineName -eq "native" }).ForEach{
			It "Native Fpolicy policies are well-defined for $($_.Vserver)" -test {
				$_.PolicyName | Should -Be "pol_ransomware"
				$_.Events | Should -Be "evt_ransomware"
				$_.IsMandatory | Should -Be True
			} # It
		} # Get-NcFpolicyPolicy
		(Get-NcFpolicyScope | Where-Object { $_.PolicyName -eq "pol_ransomware" }).ForEach{
			It "Native Fpolicy scope is well-defined for $($_.Vserver)" -test {
				$_.SharesToInclude | Should -Be "*"
				$_.FileExtensionsToInclude | Should -Contain @('_crypt', '0x0', '1999', 'aaa', 'bleep', 'ccc', 'crinf', 'crjoker', 'crypt', 'crypto', 'ctb2ctbl', 'ecc', 'EnCiPhErEd', 'encoderpass', 'encrypted', 'encryptedRSA', 'exx', 'ezz',
					'good', 'ha3', 'k', 'keybtc@inbox_com', 'LeChiffre', 'locked', 'locky', 'lol', 'lol!', 'magic', 'micro', 'mp3', 'omg!', 'pzdc', 'r16M01D05', 'r5a', 'rdm', 'rokku', 'rrk', 'supercrypt', 'surprise', 'toxcrypt', 'ttt', 'vault',
					'vvv', 'xrtn', 'xtbl', 'xxx', 'xyz', 'zepto', 'zzz')
			} # It
		} # Get-NcFpolicyScope
		$varonis_event = (Get-NcFpolicyEvent | Where-Object { $_.EventName -eq "fp_event_varonis_cifs" })
		It "Varonis Fpolicy events are well-defined for $($varonis_event.Vserver)" -test {
			$varonis_event.Protocol | Should -Be "cifs"
			$varonis_event.FileOperations | Should -Contain @('create', 'create_dir', 'open', 'delete', 'delete_dir', 'read', 'write', 'rename', 'rename_dir', 'setattr')
			$varonis_event.FilterString | Should -Be "open_with_delete_intent"
		} # It
		(Get-NcFpolicyPolicy | Where-Object { $_.PolicyName -eq "Varonis" }).ForEach{
			It "Varonis Fpolicy policy is well-defined for $($_.Vserver)" -test {
				$_.EngineName | Should -BeLike "*-dsm-col-00*"
				$_.Events | Should -Be "fp_event_varonis_cifs"
				$_.IsMandatory | Should -Be False
			} # It
		} # Get-NcFpolicyPolicy
		(Get-NcFpolicyScope | Where-Object { $_.PolicyName -eq "Varonis" }).ForEach{
			It "Varonis Fpolicy scope is well-defined for $($_.Vserver)" -test {
				$_.PolicyName | Should -Not -Be $Null
				$_.ExportPoliciesToInclude | Should -Be "*"
				$_.VolumesToInclude | Should -Be "*"
			} # It
		} # Get-NcFpolicyScope
		(Get-NcFpolicyExternalEngine | Where-Object { $_.EngineName -eq "fp_ex_eng" }).ForEach{
			It "Varonis external engine configuration is well-defined for $($_.Vserver)" -test {
				$_.EngineName | Should -Not -Be $Null
				$_.PortNumber | Should -Be "2002"
				$_.SslOption | Should -Be "no_auth"
			} # It
		} # Get-NcFpolicyExternalEngine
	} # Context
	Context "Testing Vscan components" {
		(Get-NcVscanStatus | Where-Object { $_.Vserver -Like "*nas*" }).ForEach{
			It "Vscan is enabled for $($_.Vserver)" -test {
				$_.Vserver | Should -Not -Be $Null
				$_.Enabled | Should -Be True
			} # It
		} # Get-NcVscanStatus
		(Get-NcRole -RoleName vscanners -AccessLevel readonly).ForEach{
			It "Vscanners role exists and is well-defined" -test {
				$_.RoleName | Should -Not -Be $Null
				$_.CommandDirectoryName | Should Be "network interface"
			} # It
		} # Get-NcRole
		(Get-NcUser | Where-Object { $_.UserName -Like "NA\srvcNetAppAV*" }).ForEach{
			It "Vscanner service account exists and is well-defined" -test {
				$_.UserName | Should -Not -Be $Null
				$_.Application | Should -Be "ontapi"
				$_.AuthMethod | Should -Be "domain"
				$_.RoleName | Should -Be "vscanners"
				$_.IsLocked | Should -Be $Null
			} # It
		} # Get-NcUser
		(Get-NcVscanScannerPool | Where-Object { $_.Vserver -Like "*nas*" }).ForEach{
			It "Vscan scanner pools exist and are well-defined for NAS-enabled SVM $($_.Vserver)" -test {
				$_.Vserver | Should -Not -Be $Null
				$_.ScannerPolicy | Should -Be "primary"
				$_.Active | Should -Be True
			} # It
		} # Get-NcVscanScannerPool
		(Get-NcVscanOnAccessPolicy | Where-Object { ($_.Vserver -Like "*nas*" -and $_.PolicyName -NotLike "*default_CIFS*") }).ForEach{
			It "Vscan on-access policies exist and are well-defined for NAS-enabled SVM $($_.Vserver)" -test {
				$_.Protocol | Should -Be "cifs"
				$_.IsPolicyEnabled | Should -Be True
			} # It
		} # Get-NcVscanOnAccessPolicy
		(Get-NcVscanConnection | Where-Object { $_.Server -eq $Config.Cluster.Vscan.Primary }).ForEach{
			It "Primary Vscan server is well-defined" -test {
				$_.ServerStatus | Should -Be "connected"
				$_.Servers | Should -Be "10.221.64.42"
			} # It
		} # Get-NcVscanConnection
		(Get-NcVscanConnection | Where-Object { $_.Server -eq $Config.Cluster.Vscan.Secondary }).ForEach{
			It "Secondary Vscan server is well-defined" -test {
				$_.ServerStatus | Should -Be "connected"
				$_.Servers | Should -Be "10.221.64.43"
			} # It
		} # Get-NcVscanConnection
	} # Context
} # Describe