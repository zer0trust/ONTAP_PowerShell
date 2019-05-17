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
Describe -Name 'NetApp Configuration Tests' {
  It "Check Cluster ONTAP version" {
    $version = Get-NcSystemVersion  
    $version | Should -Match 'NetApp Release 9.3P8'
  } # It 
  (Get-NcNode).ForEach{    
    Context "Testing AutoSupport Settings on $($_)" {
      (Get-NcAutoSupportConfig -Node $_.Node).ForEach{ 
        It "AutoSupport is enabled" -test {
          $_.IsEnabled | Should -Be $basic_config.Cluster.AutoSupport.IsEnabled
        } # It
        It "Autosupport transport method is HTTPS" -test {  
          $_.Transport | Should -Be $basic_config.Cluster.AutoSupport.Transport
        } # It
        It "Mail host value is well-defined" -test {
          $_.MailHosts | Should -Be $basic_config.Cluster.Autosupport.MailHost
        } # It
        It "Support address is well-defined" -test {
          $_.SupportAddress | Should -Be $basic_config.Cluster.Autosupport.SupportAddress
        } # It
        It "AutoSupport notification destination email is well-defined" -test {
          $_.To | Should -Be $basic_config.Cluster.Autosupport.To
        } # It            
      } # Get-NcAutoSupportConfig
    } # Context    
   } # Get-NcNode
     Context "Testing Cluster NTP Server Settings" {
       (Get-NcNtpServer -ServerName $basic_config.Cluster.NTP.ServerName1).ForEach{
         It "1st NTP server is configured correctly" -test {
          $_.ServerName | Should -Be $basic_config.Cluster.NTP.ServerName1
          $_.ServerName | Should -Not -Be $null
         } # It
        (Get-NcNtpServer -ServerName $basic_config.Cluster.NTP.ServerName2).ForEach{
          It "2nd NTP server is configured correctly" -test {
            $_.ServerName | Should -Be $basic_config.Cluster.NTP.ServerName2
            $_.ServerName | Should -Not -Be $null
        } # It
      } # Get-NcNtpServer-1
    } # Get-NcNtpServer-0
  } # Context
       Context "Testing DNS Server Settings for each SVM" {
        (Get-NcNetDNS).ForEach{
         It "DNS state is enabled for $($_.Vserver)" -test {
          $_.DNSState | Should -Be enabled
        } # It
          It "More than one name server is configured for $($_.Vserver)" -test {
           $_.NameServers.Count | Should -BeGreaterThan 1
        } # It
    } # Get-NcNetDNS
  } # Context
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
       Context "Testing cluster networking and SnapMirror components" {
        $sp = (Get-NcServiceProcessor | Where-Object {$_.Status -eq "offline"})
          It "Service Processors for all nodes are online" -test {
           $sp | Should -BeNullOrEmpty
        } # It
        $autoupdate = (Get-NcServiceProcessor | Where-Object {$_.IsAutoUpdateEnabled -eq "False"})
          It "Service Processor auto update is enabled for all nodes" -test {
            $autoupdate | Should -BeNullOrEmpty 
        } # It
        $dataping = Get-NcClusterPeerHealth | Where-Object {$_.DataPing -match "unreachable"}
          It "All nodes have data connectivity to peered nodes" -test {
           $dataping | Should -BeNullOrEmpty
        } # It
        $sm = Get-NcSnapMirror | Where-Object {$_.IsHealthy -match "false"}
         It "All SnapMirror relationships are healthy" -test {
          $sm | Should -BeNullOrEmpty
        } # It
         $ports = Get-NcNetPort | Where-Object {$_.Role -ne "data"} | Where-Object {$_.LinkStatus -match "down"}
          It "All cluster and node management ports are up" -test {
           $ports | Should -BeNullorEmpty
        } # It 
        $int = Get-NcNetInterface | Where-Object {$_.IsHome -match "false"}
          It "All interfaces are at their home ports" -test {
            $int | Should -BeNullOrEmpty
        } # It     
 }  # Context
       Context "Testing disk and volume components" {
        $broken_disks = Get-NcDisk | Where-Object {$_.DiskRaidInfo.ContainerType -eq "broken"}
         It "There are no broken disks present" -test {
           $broken_disks | Should -BeNullOrEmpty
         } # It
        $unassigned_disks = Get-NcDisk | Where-Object {$_.DiskRaidInfo.ContainerType -eq "unassigned"}
         It "There are no unassigned disks present" -test {
           $unassigned_disks | Should -BeNullOrEmpty
         } # It  
        Get-NcVol | Where-Object {$_.State -eq "offline"}
         It "There are no offline volumes" -test {
           $_.State | Should -BeNullOrEmpty
         } # It
        $180days = (get-date).adddays(-180)
        $oldsnaps = (Get-NcSnapshot | Where-Object {($_.Created -lt $180days -and $_.Total -ge 10GB -and $_.Dependency -eq $null)})
        $cv_snaps = (Get-NcSnapshot | Where-Object {($_.Created -lt $180days -and $_.Total -ge 10GB -and $_.Dependency -eq $null -and $_.Name -like "SP_2_*")})
         It "There are no large snapshots older than 180 days (over 10GB and with no dependencies)" -test {
          $oldsnaps | Should -BeNullOrEmpty
         } # It-snaps
         It "There are no large CommVault snapshots older than 180 days" -test {
          $cv_snaps | Should -BeNullOrEmpty    
         } # It-cv_snaps
 } # Context
       Context "Testing Fpolicy (Native and Varonis) components" {
        (Get-NcFpolicyStatus).ForEach{
          It "Fpolicy is enabled and connected for $($_.PolicyName) in $($_.Vserver)" -test {
           $_.Enabled | Should -Be True
        } # It
    } # Get-NcFpolicyStatus
        (Get-NcFpolicyEvent | Where-Object {$_.EventName -eq "evt_ransomware"}).ForEach{
         It "Native Fpolicy events are well-defined for $($_.Vserver)" -test {
          $_.Protocol | Should -Be "cifs"
          $_.FileOperations | Should -Be @("create","rename")
         } # It
    } # Get-NcFpolicyEvent    
        (Get-NcFpolicyPolicy | Where-Object {$_.EngineName -eq "native"}).ForEach{
          It "Native Fpolicy policies are well-defined for $($_.Vserver)" -test {
           $_.PolicyName | Should -Be "pol_ransomware"
           $_.Events | Should -Be "evt_ransomware"
           $_.IsMandatory | Should -Be True
        } # It
    } # Get-NcFpolicyPolicy
        (Get-NcFpolicyScope | Where-Object {$_.PolicyName -eq "pol_ransomware"}).ForEach{
          It "Native Fpolicy scope is well-defined for $($_.Vserver)" -test {
            $_.SharesToInclude | Should -Be "*"
            $_.FileExtensionsToInclude | Should -Contain @('_crypt','0x0','1999','aaa','bleep','ccc','crinf','crjoker','crypt','crypto','ctb2ctbl','ecc','EnCiPhErEd','encoderpass','encrypted','encryptedRSA','exx','ezz',
              'good','ha3','k','keybtc@inbox_com','LeChiffre','locked','locky','lol','lol!','magic','micro','mp3','omg!','pzdc','r16M01D05','r5a','rdm','rokku','rrk','supercrypt','surprise','toxcrypt','ttt','vault',
              'vvv','xrtn','xtbl','xxx','xyz','zepto','zzz')
        } # It
    } # Get-NcFpolicyScope
        $varonis_event = (Get-NcFpolicyEvent | Where-Object {$_.EventName -eq "fp_event_varonis_cifs"})
          It "Varonis Fpolicy events are well-defined for $($varonis_event.Vserver)" -test {
            $varonis_event.Protocol | Should -Be "cifs"
            $varonis_event.FileOperations | Should -Contain @('create','create_dir','open','delete','delete_dir','read','write','rename','rename_dir','setattr')
            $varonis_event.FilterString | Should -Be "open_with_delete_intent"
        } # It
        (Get-NcFpolicyPolicy | Where-Object {$_.PolicyName -eq "Varonis"}).ForEach{
          It "Varonis Fpolicy policy is well-defined for $($_.Vserver)" -test {
            $_.EngineName | Should -BeLike "*-dsm-col-00*"
            $_.Events | Should -Be "fp_event_varonis_cifs"
            $_.IsMandatory | Should -Be False 
        } # It 
     } # Get-NcFpolicyPolicy
        (Get-NcFpolicyScope | Where-Object {$_.PolicyName -eq "Varonis"}).ForEach{
          It "Varonis Fpolicy scope is well-defined for $($_.Vserver)" -test {
            $_.PolicyName | Should -Not -Be $null
            $_.ExportPoliciesToInclude | Should -Be "*"
            $_.VolumesToInclude | Should -Be "*"
        } # It
     } # Get-NcFpolicyScope
        (Get-NcFpolicyExternalEngine | Where-Object {$_.EngineName -eq "fp_ex_eng"}).ForEach{
          It "Varonis external engine configuration is well-defined for $($_.Vserver)" -test {
            $_.EngineName | Should -Not -Be $null
            $_.PortNumber | Should -Be "2002"
            $_.SslOption | Should -Be "no_auth"
        } # It
    } # Get-NcFpolicyExternalEngine
   } # Context
      Context "Testing Vscan components" {
        (Get-NcVscanStatus | Where-Object {$_.Vserver -Like "*nas*"}).ForEach{
          It "Vscan is enabled for $($_.Vserver)" -test {
            $_.Vserver | Should -Not -Be $null
            $_.Enabled | Should -Be True 
        } # It
  } # Get-NcVscanStatus
        (Get-NcRole -RoleName vscanners -AccessLevel readonly).ForEach{
          It "Vscanners role exists and is well-defined" -test {
            $_.RoleName | Should -Not -Be $null
            $_.CommandDirectoryName | Should Be "network interface"
        } # It
  } # Get-NcRole
        (Get-NcUser | Where-Object {$_.UserName -Like "NA\srvcNetAppAV*"}).ForEach{
          It "Vscanner service account exists and is well-defined" -test {
            $_.UserName | Should -Not -Be $null
            $_.Application | Should -Be "ontapi"
            $_.AuthMethod | Should -Be "domain"
            $_.RoleName | Should -Be "vscanners"
            $_.IsLocked | Should -Be $null 
        } # It
     } # Get-NcUser
        (Get-NcVscanScannerPool | Where-Object {$_.Vserver -Like "*nas*"}).ForEach{
          It "Vscan scanner pools exist and are well-defined for NAS-enabled SVM $($_.Vserver)" -test {
            $_.Vserver | Should -Not -Be $null
            $_.ScannerPolicy | Should -Be "primary"
            $_.Active | Should -Be True
        } # It
     } # Get-NcVscanScannerPool
      (Get-NcVscanOnAccessPolicy | Where-Object {($_.Vserver -Like "*nas*" -and $_.PolicyName -NotLike "*default_CIFS*")}).ForEach{
        It "Vscan on-access policies exist and are well-defined for NAS-enabled SVM $($_.Vserver)" -test {
           $_.Protocol | Should -Be "cifs"
           $_.IsPolicyEnabled | Should -Be True 
        } # It
      } # Get-NcVscanOnAccessPolicy
   } # Context    
} # Describe