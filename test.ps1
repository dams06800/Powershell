$curentUser = Get-WmiObject win32_userprofile| Where-Object {$_.LocalPath -eq $path} | Select-Object -first 1 
$curentUser.delete()