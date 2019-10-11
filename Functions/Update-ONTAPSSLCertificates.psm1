<#
.NOTES
File Name:  Update-ONTAPSSLCertificates.psm1
.COMPONENT  
-NetApp PowerShell Toolkit 9.6 (will likely work on older versions as well)
.SYNOPSIS
Version: 
1.0 - Initial release
.DESCRIPTION
Replaces ONTAP SVM SSL certificates that have expired or are going to expire in 30 days or less.
.PARAMETER Controller
IP/DNS name of the cluster management LIF. 
.EXAMPLE
Update-ONTAPSSLCertificates -Controller lab-clst-01.lab.com
#>
function Update-ONTAPSSLCertificates {
    param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Controller
    )
    BEGIN {
        if (-not (Get-Module DataONTAP)) {
			Import-Module DataONTAP
			if (-not (Get-Module DataONTAP)) {
				throw "Unable to import DataONTAP module, please install it before running this function"
			} # if
		} # if
        Connect-NcController $Controller
            if (!$global:CurrentNcController) {
                throw "Please connect to a NetApp controller before running this function"
            } # if
    } # begin
    PROCESS {
        # Collect list of self-signed SVM SSL certificates that will be expiring within 30 days
        $Certificates = Get-NcVserver | ?{$_.VserverType -eq "data"} | Get-NcSecurityCertificate | ?{$_.Type -eq "server" -and $_.CommonName -eq $_.Vserver -and $_.ExpirationDateDT -lt (Get-Date).AddDays(3655)}
            if (!$Certificates) {
                throw "No expiring certificates found!"
            } # if 
        # Loop through list of identified certificates
        foreach ($Certificate in $Certificates) {
            # Removes all identified SSL certificates from the system, confirming each one. Add -Confirm:$false to command to remove prompts
            Remove-NcSecurityCertificate -CommonName $($Certificate.CommonName) -Type $($Certificate.Type) -SerialNumber $($Certificate.SerialNumber) -CertificateAuthority $($Certificate.CertificateAuthority) -Vserver $($Certificate.Vserver)
                if ($LASTEXITCODE -eq 0) {
                    Write-Output -InputObject "Successfully removed certificate <$($Certificate.CommonName)> from SVM <$($Certificate.Vserver)>"
                } # if
            # Generates new 10-year self-signed SSL certificate with the same settings as the one that was removed (with the exception of the term)
            $NewCert = New-NcSecurityCertificate -CommonName $($Certificate.CommonName) -Type $($Certificate.Type) -Vserver $($Certificate.Vserver) -ExpireDays 3650 -HashFunction $($Certificate.HashFunction)
            # Re-enable SSL for the affected SVMs using the newly created certificate using ZAPI call since cmdlet is broken (bug ID #1074255)
            $Request = @"
            <security-ssl-modify>
            <certificate-authority>$($NewCert.Vserver)</certificate-authority>
            <certificate-serial-number>$($NewCert.SerialNumber)</certificate-serial-number>
            <common-name>$($NewCert.Vserver)</common-name>
            <server-authentication-enabled>true</server-authentication-enabled>
            <vserver>$($NewCert.Vserver)</vserver>
            </security-ssl-modify>
"@
            Write-Verbose -Message "Adding certificate <$($NewCert.CommonName)> for SVM <$($NewCert.Vserver)>..."
            Invoke-NcSystemApi -VserverContext $($NewCert.Vserver) -Request $Request | Out-Null
                if ((Get-NcSecuritySSL -VserverContext $Certificate.Vserver).ServerAuth -eq $true) {
                    Write-Output -InputObject "New certificate added and Server Authentication re-enabled"
                } # if
                else {
                    throw "SVM Server Authentication was not re-enabled successfully, please troubleshoot or enable manually" 
                } # else 
        } #foreach
    } # process
} # fuction