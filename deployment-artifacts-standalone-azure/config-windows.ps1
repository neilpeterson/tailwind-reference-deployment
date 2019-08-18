# Set-ExecutionPolicy Bypass -Scope Process -Force

# Install-WindowsFeature -name Web-Server -IncludeManagementTools

# Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

# choco install git -y

# choco install dotnetcore-sdk -y --version 2.2.104

Invoke-Command -ScriptBlock {git clone https://github.com/anthonychu/TailwindTraders-Website.gitc c:\tailwind}