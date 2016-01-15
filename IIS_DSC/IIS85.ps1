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

Configuration IIS85install
{
    Import-DscResource -Module PSDesiredStateConfiguration
        
    Node $AllNodes.NodeName
    {
        # Set LCM to reboot if necessary
        LocalConfigurationManager
        {
            AllowModuleOverwrite = $true
            RebootNodeIfNeeded = $true
        }
        WindowsFeature "NET-Framework-Core"
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
            Source = "$Node.NETPath"
        }
        
        WindowsFeature "Web-Server"
        {
            Ensure = "Present"
            Name = "Web-Server"            
        }
                      
        foreach ($Feature in @("Web-Http-Redirect","Web-Log-Libraries","Web-Request-Monitor","Web-Http-Tracing","Web-Dyn-Compression","Web-IP-Security","Web-Url-Auth","Web-Scripting-Tools","Web-App-Dev","Web-Net-Ext","Web-Net-Ext45","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Asp-Net","Web-Asp-Net45","WAS","WAS-Process-Model","Web-Mgmt-Service"))
        {
            WindowsFeature "$Feature$Number"
            {
                Ensure = "Present"
                Name = $Feature
                DependsOn = "[WindowsFeature]Web-Server"
            }
        }
        WindowsFeature "Web-Dir-Browsing"
        {
            Ensure = "Absent"
            Name = "Web-Dir-Browsing"
        }
        
        Service StopW3SVC #W3SVC
        {
            Name = "W3SVC"
            State = "Stopped"
            DependsOn = "[WindowsFeature]Web-Server"
        }
        
        Service StopWAS #WAS
        {
            Name = "WAS"
            State = "Stopped"
            DependsOn = "[Service]StopW3SVC"
        }
                
        File MoveLogDirectories
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "C:\inetpub\logs"
            DestinationPath = "L:\logs"
            DependsOn = "[Service]StopWAS"
        }
        
        File MoveWebRoot
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "C:\inetpub"
            DestinationPath = "W:\inetpub"
            DependsOn = "[Service]StopWAS"
        }
        
        File RemoveDestWebRootLogs
        {
            Ensure = "Absent"
            Type = "Directory"
            Recurse = $true
            DestinationPath = "W:\inetpub\logs"
            Force = $true
        }
        
        File RemoveDestWebRootHistory
        {
            Ensure = "Absent"
            Type = "Directory"
            Recurse = $true
            DestinationPath = "W:\inetpub\history"
            Force = $true
        }
        
        
        
    }
}