<#

.SYNOPSIS
Script de nettoyage profils utilisateurs.

.DESCRIPTION
		.nbr de dossiers dans /users pour activer le déclenchement
		[Parameter(Mandatory=$true)]
		[int]$ToggleFolderCount ,
		.nrbr de jours depuis la dérnière connection (au-dela suppréssion)
		[Parameter(Mandatory=$true)]
		[int]$Threshold ,
		.nbr de dossier restant aprés la suppréssion
		[Parameter(Mandatory=$true)]
		[int]$MaxFolderLeft ,
		.mode debug $true pour ne rien effacer
		[Parameter(Mandatory=$true)]
		[boolean]$debugMode

.EXAMPLE
./PurgeUser.ps1 -ToggleFolderCount 40 -Threshold 200 -MaxFolderLeft 40 -debugMode $true

.NOTES
		nbr de dossiers dans /users pour activer le déclenchement
		[Parameter(Mandatory=$true)]
		[int]$ToggleFolderCount ,
		nrbr de jours depuis la dérnière connection (au-dela suppréssion)
		[int]$Threshold ,
		nbr de dossier restant aprés la suppréssion
		[Parameter(Mandatory=$true)]
		[int]$MaxFolderLeft ,
		mode debug $true pour ne rien effacer
		[Parameter(Mandatory=$true)]
		[boolean]$debugMode

.LINK

#>



Param(
		#nbr de dossiers dans /users pour activer le déclenchement
		[Parameter(Mandatory=$true)]
		[int]$ToggleFolderCount ,
		#nbr de jours depuis la dérnière connection (au-dela suppression)
		[int]$Threshold ,
		#nbr de dossiers utilisateurs restant (hors whitelist)
		[Parameter(Mandatory=$true)]
		[int]$MaxFolderLeft ,
		#mode debug $true pour ne rien effacer
		[Parameter(Mandatory=$true)]
		[boolean]$debugMode
   )
	
	$LogFile = "c:\temp\_logs\PurgeUser.log"
	#$Maillinglist =@("s.monchatre@probtp.com";"n.bazillou@probtp.com";"c.castello@probtp.com";"j.meredieu@probtp.com";"p.clignac@probtp.com";"o.woillot@probtp.com";"y.viano@probtp.com";"j.degeorges@probtp.com")
	$Maillinglist =@("d.mousel@probtp.com";"s.monchatre@probtp.com";"c.castello@probtp.com")

	
	## SENDMAIL: FONCTION D'ENVOI DE MAIL A LA MAILLINGLIST
		function sendMail($s, $to, $p) {
			$smtpServer = "smtp.probtp"
			$smtpFrom = "PurgeUserScript@probtp.com"
			$messageSubject = $s[0]
			Foreach ($dest in $Maillinglist){		
			$smtpTo = $dest
			$message = New-Object System.Net.Mail.MailMessage $smtpfrom, $smtpto
			$message.Subject = $messageSubject
			$message.IsBodyHTML = $false
			$message.Body = $s[1]
			$message.Priority = $p
			$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
			$smtp.Send($message)
		}
	}	
	
	
	#Sécurité variable d'environement
	if(!(Test-Path Env:\_PC_FONCTION_ACCUEIL_TEL))
	{
		 write-warning "Alerte : type de poste invalide" 
		 add-content $LogFile -value "Alerte : type de poste invalide"
		 $poste = $env:computername
		 $subject = "PurgeUser.ps1 Alerte :  $poste type de poste invalide"
		 $body = "type de poste invalide"
		 $email =@($subject,$body)
		 sendMail -s $email -to $Maillinglist -p "High"	
		 exit 666
	}
	
	#init
	if(-not($Threshold)){$Threshold = 0 ; write-warning "-Threshold 0 par default" }
	$User= $env:username
	$LogFile = "c:\temp\_logs\PurgeUser.log"
	$date = get-date -format F
	$WhiteUsersList = @("Administrateur","netshield","service_bmc_fpac","pb11997",$User,"Public")

	add-content $LogFile -value "#################################################"
	add-content $LogFile -value "$date : début nettoyage profils utilisateurs"
	add-content $LogFile -value "`r`n"
	add-content $LogFile -value "Param ToggleFolderCount = $ToggleFolderCount "
	add-content $LogFile -value "Param Treshold = $Threshold "
	add-content $LogFile -value "Param MaxFolderLeft = $MaxFolderLeft"
	add-content $LogFile -value "Param debug = $debugMode"
	
	#step ignore script $ToggleFolderCount
	$InitialProfileFolders = Get-ChildItem "$($env:SystemDrive)\Users"
	if($InitialProfileFolders.Count -lt $ToggleFolderCount)
	{
	add-content $LogFile -value "Nombre de dossiers inferieur à la valeur ToggleFolderCount exit "	
	exit 0
	}
	
	
	
	$CountUserProfileFolders = (Get-ChildItem "$($env:SystemDrive)\Users").Count 
	add-content $LogFile -value "Nombre de dossiers utilisateurs initial : $CountUserProfileFolders"
	add-content $LogFile -value "`r`n"
	
	#clean folder without key	
	$countTrashFolder =0;
	$TrashFolderLog = "";
	write-warning "clean dossier sans clé " 
	Get-ChildItem "$($env:SystemDrive)\Users" | ? {$WhiteUsersList -notcontains $_.Name} | % {
	$TestPath = $_.FullName ; 

	$key = Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath') -eq "$TestPath"} | Select-Object -first 1
	if(!$key)
	{
	write-host " $TestPath pas de clé!"
		$countTrashFolder++
		
			
				if($debugMode -eq $false)
				{
						cmd /c rmdir "$TestPath"  /s /q
						#cmd /c rmdir "$TestPath"  /s /q
						if(!(test-path  $TestPath))
						{
						$TrashFolderLog += "TRASH DOSSIER -> Suppression du dossier user $TestPath réussie `r`n"					
						}
						else
						{
							$TrashFolderLog += "TRASH DOSSIER -> Suppression du dossier user $TestPath échoué `r`n"						
						}
				}
				else
				{
							$TrashFolderLog += "DEBUG TRASH DOSSIER ->  Suppression du dossier user $TestPath réussie `r`n"
				}
	}
	#$key.GetValue('ProfileImagePath')	
	}
	write-host $TrashFolderLog
	add-content $LogFile -value "suppression des dossiers sans clés : $countTrashFolder"
	add-content $LogFile -value $TrashFolderLog
	
	#clean key without folder
	$countTrashKey=0;
	$TrashKeyLog = "";
	write-warning "clean clé sans dossier " 
	$ProfileList = Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath')  -notmatch 'administrator|Ctx_StreamingSvc|NetworkService|Localservice|systemprofile' -AND $_.GetValue('ProfileImagePath') -Match 'C:\\Users\\'} 
	$ProfileList | %{
	
	$currentPath = $_.GetValue('ProfileImagePath')
	if (-Not (test-path $currentPath))
	{ 					
		write-host "folder not found $currentPath"
		$countTrashKey++
		$TrashKeyLog += "REGISTRE TRASH KEY -> Suppression de la clés utilisateur where ProfileImagePath = $currentPath `r`n"
		if($debugMode -eq $false)
		{			
		$_ | Remove-Item	
		
		
		}
	}

	}
		add-content $LogFile -value "suppression des clés sans dossier : $countTrashKey"
		add-content $LogFile -value $TrashKeyLog
	
	# sélection des dossiers hors whiteList
	$UserProfileFolders = Get-ChildItem "$($env:SystemDrive)\Users" | ? {$WhiteUsersList -notcontains $_.Name} | Select Name,FullName,LastAccessTime
	$FinalCollection= @()
	
	$UserProfileFolders | % {
	$name = $_.Name
	#verification date NTUSER.DAT et ajout dans le PSCUSTOMOBJECT $FinalCollection
	if(test-path "$((Get-Item $env:USERPROFILE).Parent.FullName)\$name\NTUSER.DAT")
	{	
		$n = Get-Item "$((Get-Item $env:USERPROFILE).Parent.FullName)\$name\NTUSER.DAT" -force				
		if(((Get-Date)   - $n.LastWriteTime ).Days -ge $Threshold)
		{
			write-host  $((Get-Date)   - $n.LastWriteTime ).Days" greater or equal $Threshold"
		
			$ntdate = $n.LastWriteTime
			add-content $LogFile -value  "$name NTUSER.DAT : LastWriteTime $ntdate suppression autorisée par le parametre treshold"
			$AllowDelete = $true
			$objAverage = New-Object System.Object
			$objAverage | Add-Member -type NoteProperty -name Name -value $_.Name
			$objAverage | Add-Member -type NoteProperty -name FullName -value $_.FullName
			$objAverage | Add-Member -type NoteProperty -name NTUSERLastWriteTime -value  $n.LastWriteTime
			$objAverage | Add-Member -type NoteProperty -name NTuserLWTDays -value ( (Get-Date)   - $n.LastWriteTime ).Days
			$FinalCollection += $objAverage			
		}
		else
		{
			$ntdate = $n.LastWriteTime
			add-content $LogFile -value  "$name NTUSER.DAT : LastWriteTime $ntdate suppression refusée par le parametre treshold"		
		}
	}
	else
	{
		add-content $LogFile -value  "$name NTUSER.DAT : fichier manquant aucune une vérification précise ne peut s'appliquer"
	}
	
	}
	
	
	add-content $LogFile -value  " "
	add-content $LogFile -value  "---------------------SUPPRESSION DES PROFILS VALIDES-----------------------------------"
	$cf = $FinalCollection.Count
	add-content $LogFile -value  "Collection finale count: $cf"
	$FinalCollection  | sort-object -property NTUSERLastWriteTime | FT
	#delete
	#collection triée par date DESC (Delete du + ancien au + recent) 
	$CountUserLeft = -1;
	$FinalCollection  | sort-object -property NTUSERLastWriteTime  | % {

	$CountUserLeft++
	$index = $FinalCollection.Length - $CountUserLeft
	$index
	
		$PB = Split-Path $_.FullName -Leaf
  		$path = $_.FullName
	
		
		if($index -le $MaxFolderLeft){
		write-host "nombre de dossiers inferieur au MaxLeftFolder exit" ;
		$regCount = (Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList").Count
		add-content $LogFile -value "Nombre de clé de registre user : $regCount clé" ; 
		
		add-content $LogFile -value "Nombre de dossiers users inferieur à la valeur definie $MaxFolderLeft exit!" ; 
		exit 0
		}
		add-content $LogFile -value  "`r`n début suppression $PB "
		add-content $LogFile -value "Index de suppression dans la collection : $index dossiers" ; 
		 <#		if($debugMode -eq $false)
			{
				Try
				{
						#function wmi test
						$curentUser = Get-WmiObject win32_userprofile| Where-Object {$_.LocalPath -eq $path} | Select-Object -first 1 
						$curentUser.delete()
						add-content $LogFile -value "PROFIL -> User: $PB - Suppression du PROFIL user $path réussie"
						write-host "PROFIL -> User: $PB - Suppression du PROFIL user $path réussie"
			
				}
				Catch
				{
					add-content $LogFile -value "PROFIL -> User: $PB - Suppression du PROFIL user $path échoué "
					write-host "PROFIL -> User: $PB - Suppression du PROFIL user $path échoué"
			
				}
			}
			#>
			if($debugMode -eq $false)
				{
				##action de delete general
				
				Try
					{
						
						
						cmd /c rmdir $path /s /q
						#pass 2
						cmd /c rmdir $path /s /q

						if(!(test-path  $path))
						{
						add-content $LogFile -value "DOSSIER -> User: $PB - Suppression du dossier user $path réussie"
						write-host "DOSSIER -> User: $PB - Suppression du dossier user $path réussie"
						}
						else
						{
						add-content $LogFile -value "DOSSIER -> User: $PB - Suppression du dossier user $path échoué "
						write-host "DOSSIER -> User: $PB - Suppression du dossier user $path échoué"
						}
					}
					Catch
					{
						$ErrorMessage = $_.Exception.Message
						add-content $LogFile -value "DOSSIER -> User: $PB - Suppression du dossier user $path échoué : $ErrorMessage"
						write-host "DOSSIER -> User: $PB - Suppression du dossier user $path échoué"
					}
				}
				else
				{
					add-content $LogFile -value "DEBUG DOSSIER -> User: $PB - Suppression du dossier user $path réussie"
					write-host "DEBUG DOSSIER -> User: $PB - Suppression du dossier user $path réussie"
				}
			
		
			
				if($debugMode -eq $false)
				{
					Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath') -Match "$PB" -and $_.GetValue('ProfileImagePath') -Match $_.FullName} | Select-Object -first 1 | Remove-Item
				
				
				$test = Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath') -Match "$PB" -and $_.GetValue('ProfileImagePath') -Match $_.FullName}
				if($test)
						{	
							write-host "REGISTRE -> User: $PB - Suppression clé de registre $UserKey échoué"
							add-content $LogFile -value " REGISTRE -> User: $PB - Suppression clé de registre $UserKey échoué"									
							
						}
						else
						{	
							write-host "REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
							add-content $LogFile -value " REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
						
						}
				}
				else
				{
					write-host "DEBUG REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
					add-content $LogFile -value "DEBUG REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
				}
				
			
				
	}	