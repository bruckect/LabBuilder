<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_DFSSPOKE
.Desription
    Builds a Server that is joined to a domain and then made into a Spoke for a DFS Hub and Spoke
    replication group.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_DFSSPOKE
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName DFSDsc
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName NetworkingDsc

    Node $AllNodes.NodeName {
        # Assemble the Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature FileServerInstall
        {
            Ensure = 'Present'
            Name   = 'FS-FileServer'
        }

        WindowsFeature DFSNameSpaceInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-DFS-Namespace'
            DependsOn = '[WindowsFeature]FileServerInstall'
        }

        WindowsFeature DFSReplicationInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-DFS-Replication'
            DependsOn = '[WindowsFeature]DFSNameSpaceInstall'
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        # Join this Server to the Domain
        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        WaitforDisk Disk2
        {
            DiskId           = 1
            RetryIntervalSec = 60
            RetryCount       = 60
            DependsOn        = '[Computer]JoinDomain'
        }

        Disk DVolume
        {
            DiskId      = 1
            DriveLetter = 'D'
            DependsOn   = '[WaitforDisk]Disk2'
        }
    }
}
