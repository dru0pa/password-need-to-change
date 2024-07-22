# PowerShell script that can send email notifications to domain users before their passwords will be expired.
# I havce modifed this to work with PowerShell 7 on a Windows 2022 Server.
# AddDays(10) is set to look for passwords that need to expire in ten days. This can be change to what is required.

# Query AD users 
$Users = Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False} -Properties DisplayName, EmailAddress, msDS-UserPasswordExpiryTimeComputed | `
Select-Object -Property DisplayName,  EmailAddress, @{Name="ExpirationDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}} | `
Sort-Object "ExpirationDate" 

# Check if the password will be expired soon and send email notification.
$UserList = foreach ($User in $users) {
if ($User.ExpirationDate -le (Get-Date).AddDays(10) -and $User.ExpirationDate -ge (Get-Date))  
 {
    # Create PSCustomObject to save a list of users who will have a password expired soon
    [PSCustomObject]@{
        Name       = $User.DisplayName
        EmailAddress = $User.EmailAddress
        ExpiryDate = $User.ExpirationDate
        }
    # Send email
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $SMTP = "192.168.10.1" #Chnage to your SMTP server
    $From = administrator@cyberark.lan #Chnage to an account to send the email from
    $username = administrator@cyberark.lan #Chnage to an account username
    #Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Shared\admincred.txt" #This will create the password for the account and store it in an encrypted format.
    $Pass = Get-Content "C:\Shared\admincred.txt" | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential -argumentlist $username, $Pass
    $Subject = "Password Expiration Warning"
    $Body = "Dear $($User.DisplayName)," + "`n`nYour password will expire in $User.ExpirationDate. Please change your password as soon as possible." + "`n`nRegards," + "`nIT Department"
    $EmailBody = "Hello $($User.DisplayName)," + "`n`n" +
                 "This is a reminder that your password will expire in $($User.ExpirationDate)." + "`n`n" +
                 "Please take a moment to change your password to ensure continued access to your account." + "`n`n" +
                 "Thank you," + "`n" +
                 "IT Team"

   # Try to send the email, catch any exceptions, and log them
    Try {
    Send-MailMessage -From $From -To $User.EmailAddress -Subject $Subject -Body $EmailBody -SmtpServer $SMTP -Credential $cred -Port 25
    # Log success
    Add-Content -Path "C:\Shared\Logs\EmailSuccess.log" -Value "Email sent successfully to $($User.DisplayName) at $($User.EmailAddress) on $(Get-Date) "
}
Catch {
    # Write the error message to the file EmailFailure.log under C:\Shared\Logs.
    Write-Host "Error sending email to $($User.DisplayName) at $($User.EmailAddress): $_"
    Add-Content -Path "C:\Shared\Logs\EmailFailure.Log" -Value "Error sending email to $($User.DisplayName) at $($User.EmailAddress) on $(Get-Date) $_"
}
}
}
$Userlist | sort-object ExpirationDate 
