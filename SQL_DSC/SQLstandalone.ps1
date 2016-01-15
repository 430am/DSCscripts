#requires -Version 5
$computers = ''
$OutputPath = 'C:\Install\DSClocal'
$cim = New-CimSession -ComputerName $computers

#requires -Version 5

[DSCLocalConfigurationManager()]
Configuration LCM_Push
{    
    Param(
        [string[]]$ComputerName
    )
    Node $ComputerName
    {
    Settings
        {
            AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $True    
        }
    }
}

foreach ($computer in $computers)
{
    $GUID = (New-Guid).Guid
    LCM_Push -ComputerName $Computer -OutputPath $OutputPath 
    Set-DSCLocalConfigurationManager -Path $OutputPath  -CimSession $computer 
}

Configuration SQLstandalone
{
    Import-DscResource –Module PSDesiredStateConfiguration
    Import-DscResource -Module xSQLServer

    Node $AllNodes.NodeName
    {
        # Set LCM to reboot if needed
        LocalConfigurationManager
        {
            AllowModuleOverwrite = $true
            RebootNodeIfNeeded = $true
        }
        WindowsFeature "NET"
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
            Source = $Node.NETPath 
        }

        if($Node.Features)
        {
           xSqlServerSetup ($Node.NodeName)
           {
               DependsOn = '[WindowsFeature]NET'
               SourcePath = $Node.SourcePath
               SetupCredential = $Node.InstallerServiceAccount
               InstanceName = $Node.InstanceName
               Features = $Node.Features
               SQLSysAdminAccounts = $Node.AdminAccount
               UpdateEnabled = "True"
               UpdateSource = $Node.SourcePath + "\Updates"
               InstallSharedDir = "E:\Program Files\Microsoft SQl Server"
               InstallSharedWOWDir = "E:\Program Files (x86)\Microsoft SQL Server"
               InstanceDir = "E:\Program Files\Microsoft SQL Server"
               InstallSQLDataDir = "E:\Program Files\Microsoft SQL Server\MSSQL12." + $SQLInstanceName + "\MSSQL\Data"
               SQLUserDBDir = "F:\Data"
               SQLUserDBLogDir = "G:\Logs"
               SQLTempDBDir = "H:\TempDB"
               SQLTempDBLogDir = "H:\TempDB"
               SQLBackupDir = "I:\Backups"
           }
         
           xSqlServerFirewall ($Node.NodeName)
           {
               DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
               SourcePath = $Node.SourcePath
               InstanceName = $Node.InstanceName
               Features = $Node.Features
           }
           xSQLServerPowerPlan ($Node.Nodename)
           {
               Ensure = "Present"
           }
           xSQLServerMemory ($Node.Nodename)
           {
               DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
               Ensure = "Present"
               DynamicAlloc = $false
               MinMemory = "256"
               MaxMemory ="1024"
           }
           xSQLServerMaxDop($Node.Nodename)
           {
               DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
               Ensure = "Present"
               DynamicAlloc = $true
           }
        }
    }
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser =$true
            NETPath = "\\NJ09FIL526.mhf.mhc\GOI_Build$\Database\SQLAutoInstall\WIN2012R2\sxs"
            SourcePath = "\\NJ09FIL526.mhf.mhc\GOI_Build$\Database\SQLAutoInstall\SQL2014"
            InstallerServiceAccount = Get-Credential -UserName MHF\PE_svc_SQLInstall -Message "Credentials to Install SQL Server"
            AdminAccount = "MHF\PE_svc_SQLSA"  
        }
    )
}

ForEach ($computer in $computers) {
    $ConfigurationData.AllNodes += @{
            NodeName        = $computer
            InstanceName    = "MSSQLSERVER"
            Features        = "SQLENGINE,FULLTEXT,SSMS,ADV_SSMS"       

    }
   $Destination = "\\"+$computer+"\\c$\Program Files\WindowsPowerShell\Modules"
   Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\xSQLServer' -Destination $Destination -Recurse -Force
}

SQLSA -ConfigurationData $ConfigurationData -OutputPath $OutputPath

#Push################################
foreach($Computer in $Computers) 
{

    Start-DscConfiguration -ComputerName $Computer -Path $OutputPath -Verbose -Wait -Force
}

#Ttest
foreach($Computer in $Computers) 
{
    test-dscconfiguration -ComputerName $Computer
}