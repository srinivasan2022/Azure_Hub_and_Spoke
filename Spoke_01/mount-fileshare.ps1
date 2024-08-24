 $storageAccountName = "storageaccount160302"
$shareName = "fileshare01"
$storageAccountKey = "xQ/Q9rEnLtbSVD959EG67sTNDrUf9+u+OAAjjPTIb/3yyPCELIBI/0Q46cVhxWUys0PZ6qx2uaq4+AStO38H7A=="

# Mount point for the file share
\$mountPoint = "Z:"

# Create the credential object
\$user = "\$storageAccountName"
\$pass = ConvertTo-SecureString -String "\$storageAccountKey" -AsPlainText -Force
\$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList \$user, \$pass

# Mount the file share
New-PSDrive -Name \$mountPoint.Substring(0, 1) -PSProvider FileSystem -Root "\\\\\$storageAccountName.file.core.windows.net\\\$shareName" -Credential \$credential -Persist

# Ensure the drive is mounted at startup
\$script = "New-PSDrive -Name \$(\$mountPoint.Substring(0, 1)) -PSProvider FileSystem -Root '\\\\\$storageAccountName.file.core.windows.net\\\$shareName' -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList \$user, \$pass) -Persist"
\$scriptBlock = [scriptblock]::Create(\$script)
Set-Content -Path C:\\mount-fileshare.ps1 -Value \$scriptBlock
