function Invoke-CIPPStandardSafeAttachmentPolicy {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) SafeAttachmentPolicy
    .SYNOPSIS
        (Label) Default Safe Attachment Policy
    .DESCRIPTION
        (Helptext) This creates a Safe Attachment policy
        (DocsDescription) This creates a Safe Attachment policy
    .NOTES
        CAT
            Defender Standards
        TAG
            "lowimpact"
            "CIS"
            "mdo_safedocuments"
            "mdo_commonattachmentsfilter"
            "mdo_safeattachmentpolicy"
        ADDEDCOMPONENT
            {"type":"Select","label":"Action","name":"standards.SafeAttachmentPolicy.Action","values":[{"label":"Allow","value":"Allow"},{"label":"Block","value":"Block"},{"label":"DynamicDelivery","value":"DynamicDelivery"}]}
            {"type":"Select","label":"QuarantineTag","name":"standards.SafeAttachmentPolicy.QuarantineTag","values":[{"label":"AdminOnlyAccessPolicy","value":"AdminOnlyAccessPolicy"},{"label":"DefaultFullAccessPolicy","value":"DefaultFullAccessPolicy"},{"label":"DefaultFullAccessWithNotificationPolicy","value":"DefaultFullAccessWithNotificationPolicy"}]}
            {"type":"boolean","label":"Redirect","name":"standards.SafeAttachmentPolicy.Redirect"}
            {"type":"input","name":"standards.SafeAttachmentPolicy.RedirectAddress","label":"Redirect Address"}
        IMPACT
            Low Impact
        POWERSHELLEQUIVALENT
            Set-SafeAttachmentPolicy or New-SafeAttachmentPolicy
        RECOMMENDEDBY
            "CIS"
        UPDATECOMMENTBLOCK
            Run the Tools\Update-StandardsComments.ps1 script to update this comment block
    .LINK
        https://docs.cipp.app/user-documentation/tenant/standards/edit-standards
    #>

    param($Tenant, $Settings)
    $PolicyName = 'Default Safe Attachment Policy'

    $CurrentState = New-ExoRequest -tenantid $Tenant -cmdlet 'Get-SafeAttachmentPolicy' |
        Where-Object -Property Name -EQ $PolicyName |
        Select-Object Name, Enable, Action, QuarantineTag, Redirect, RedirectAddress

    $StateIsCorrect = ($CurrentState.Name -eq $PolicyName) -and
                      ($CurrentState.Enable -eq $true) -and
                      ($CurrentState.Action -eq $Settings.Action) -and
                      ($CurrentState.QuarantineTag -eq $Settings.QuarantineTag) -and
                      ($CurrentState.Redirect -eq $Settings.Redirect) -and
                      (($null -eq $Settings.RedirectAddress) -or ($CurrentState.RedirectAddress -eq $Settings.RedirectAddress))

    $AcceptedDomains = New-ExoRequest -tenantid $Tenant -cmdlet 'Get-AcceptedDomain'

    $RuleState = New-ExoRequest -tenantid $Tenant -cmdlet 'Get-SafeAttachmentRule' |
        Where-Object -Property Name -EQ "CIPP $PolicyName" |
        Select-Object Name, SafeAttachmentPolicy, Priority, RecipientDomainIs

    $RuleStateIsCorrect = ($RuleState.Name -eq "CIPP $PolicyName") -and
                          ($RuleState.SafeAttachmentPolicy -eq $PolicyName) -and
                          ($RuleState.Priority -eq 0) -and
                          (!(Compare-Object -ReferenceObject $RuleState.RecipientDomainIs -DifferenceObject $AcceptedDomains.Name))

    if ($Settings.remediate -eq $true) {

        if ($StateIsCorrect -eq $true) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Safe Attachment Policy already correctly configured' -sev Info
        } else {
            $cmdparams = @{
                Enable          = $true
                Action          = $Settings.Action
                QuarantineTag   = $Settings.QuarantineTag
                Redirect        = $Settings.Redirect
                RedirectAddress = $Settings.RedirectAddress
            }

            if ($CurrentState.Name -eq $PolicyName) {
                try {
                    $cmdparams.Add('Identity', $PolicyName)
                    New-ExoRequest -tenantid $Tenant -cmdlet 'Set-SafeAttachmentPolicy' -cmdparams $cmdparams -UseSystemMailbox $true
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Updated Safe Attachment Policy' -sev Info
                } catch {
                    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to update Safe Attachment Policy. Error: $ErrorMessage" -sev Error
                }
            } else {
                try {
                    $cmdparams.Add('Name', $PolicyName)
                    New-ExoRequest -tenantid $Tenant -cmdlet 'New-SafeAttachmentPolicy' -cmdparams $cmdparams -UseSystemMailbox $true
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Created Safe Attachment Policy' -sev Info
                } catch {
                    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to create Safe Attachment Policy. Error: $ErrorMessage" -sev Error
                }
            }
        }

        if ($RuleStateIsCorrect -eq $false) {
            $cmdparams = @{
                SafeAttachmentPolicy = $PolicyName
                Priority             = 0
                RecipientDomainIs    = $AcceptedDomains.Name
            }

            if ($RuleState.Name -eq "CIPP $PolicyName") {
                try {
                    $cmdparams.Add('Identity', "CIPP $PolicyName")
                    New-ExoRequest -tenantid $Tenant -cmdlet 'Set-SafeAttachmentRule' -cmdparams $cmdparams -UseSystemMailbox $true
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Updated Safe Attachment Rule' -sev Info
                } catch {
                    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to update Safe Attachment Rule. Error: $ErrorMessage" -sev Error
                }
            } else {
                try {
                    $cmdparams.Add('Name', "CIPP $PolicyName")
                    New-ExoRequest -tenantid $Tenant -cmdlet 'New-SafeAttachmentRule' -cmdparams $cmdparams -UseSystemMailbox $true
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Created Safe Attachment Rule' -sev Info
                } catch {
                    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                    Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to create Safe Attachment Rule. Error: $ErrorMessage" -sev Error
                }
            }
        }
    }

    if ($Settings.alert -eq $true) {

        if ($StateIsCorrect -eq $true) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Safe Attachment Policy is enabled' -sev Info
        } else {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Safe Attachment Policy is not enabled' -sev Alert
        }
    }

    if ($Settings.report -eq $true) {
        Add-CIPPBPAField -FieldName 'SafeAttachmentPolicy' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $tenant
    }

}
