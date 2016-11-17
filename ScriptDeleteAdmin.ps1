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
./scriptDeleteAdmin.ps1 -ToggleFolderCount 40 -Threshold 200 -MaxFolderLeft 40 -debugMode $true

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
		#nrbr de jours depuis la dérnière connection (au-dela suppression)
		[int]$Threshold ,
		#nbr de dossier restant aprés la suppréssion
		[Parameter(Mandatory=$true)]
		[int]$MaxFolderLeft ,
		#mode debug $true pour ne rien effacer
		[Parameter(Mandatory=$true)]
		[boolean]$debugMode
   )
	
	#init
	if(-not($Threshold)) {$Threshold = 0 ; write-warning "-Threshold 0 par default" }
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
	write-warning "clean dossier sans clé " 
	Get-ChildItem "$($env:SystemDrive)\Users" | ? {$WhiteUsersList -notcontains $_.Name} | % {
	$TestPath = $_.FullName ; 
	$key = Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath') -eq "$TestPath"} | Select-Object -first 1
	if(!$key)
	{
				write-host "key not found for folder $TestPath"
				if($debugMode -eq $false)
				{
						cmd /c rmdir $TestPath  /s /q
						cmd /c rmdir $TestPath  /s /q
						if(!(test-path  $TestPath))
						{
						add-content $LogFile -value "TRASH DOSSIER -> Suppression du dossier user $TestPath réussie"
						write-host "TRASH DOSSIER ->  Suppression du dossier user $TestPath réussie"
						}
						else
						{
						add-content $LogFile -value "DOSSIER -> Suppression du dossier user $TestPath échoué "
						write-host "TRASH DOSSIER -> Suppression du dossier user $TestPath échoué"
						}
				}
				else
				{
						add-content $LogFile -value "DEBUG TRASH DOSSIER ->  Suppression du dossier user $TestPath réussie"
						write-host "DEBUG TRASH DOSSIER ->  Suppression du dossier user $TestPath réussie"
				}
	}
	#$key.GetValue('ProfileImagePath')	
	}
	
	#clean key without folder
	write-warning "clean clé sans dossier " 
	$ProfileList = Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath')  -notmatch 'administrator|Ctx_StreamingSvc|NetworkService|Localservice|systemprofile' -AND $_.GetValue('ProfileImagePath') -Match 'C:\\Users\\'} 
	$ProfileList | %{
	$currentPath = $_.GetValue('ProfileImagePath')
	if (-Not (test-path $currentPath))
	{ 					fa
		write-host "folder not found $currentPath"
		add-content $LogFile -value "REGISTRE TRASH KEY -> Suppression de la clé utilisateur where ProfileImagePath = $currentPath"
						
		$_ | Remove-Item	
	}

	}
	
	# sélection des dossiers hors whiteList
	$UserProfileFolders = Get-ChildItem "$($env:SystemDrive)\Users" | ? {$WhiteUsersList -notcontains $_.Name} | Select Name,FullName,LastAccessTime
	$FinalCollection= @()
	
	$UserProfileFolders | % {
	$name = $_.Name
	#verification date NTUSER.DAT et ajout dans le PSCUSTOMOBJECT $FinalCollection
	if(test-path "$((Get-Item $env:USERPROFILE).Parent.FullName)\$name\NTUSER.DAT")
	{	
		$n = Get-Item "$((Get-Item $env:USERPROFILE).Parent.FullName)\$name\NTUSER.DAT" -force				
		if(  ( (Get-Date)   - $n.LastWriteTime ).Days -ge $Threshold)
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
	$FinalCollection  | sort-object -property NTUSERLastWriteTime | FT
	#delete
	#collection triée par date DESC (Delete du + ancien au + recent) 
	$FinalCollection  | sort-object -property NTUSERLastWriteTime  | % {


		
	
		$PB = Split-Path $_.FullName -Leaf
  		$path = $_.FullName
		add-content $LogFile -value  "------------------------------------------------"
		add-content $LogFile -value  "début suppression $PB `r`n"
		
		#check nbr de dossier restant si < $MaxFolderLeft  exit script
		$CountUserProfileFolders = Get-ChildItem "$($env:SystemDrive)\Users" 
		$c = $CountUserProfileFolders.Count ;
		add-content $LogFile -value "Nombre de dossiers : $c dossiers" ; 
		if($CountUserProfileFolders.Count -lt $MaxFolderLeft){
		write-host "nombre de dossiers inferieur au $treshold exit" ;
		$regCount = (Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList").Count
		add-content $LogFile -value "Nombre de clé de registre user : $regCount clé" ; 
		
		add-content $LogFile -value "Nombre de dossiers users inferieur à la valeur definie $MaxFolderLeft exit!" ; 
		exit 0
		}
			if($debugMode -eq $false)
			{
				Try
				{
						#function wmi test
						$curentUser = Get-WmiObject win32_userprofile| Where-Object {$_.LocalPath -eq $path} | Select-Object -first 1 
						$curentUser.delete()
						add-content $LogFile -value "DOSSIER -> User: $PB - Suppression du dossier user $path réussie"
						write-host "DOSSIER -> User: $PB - Suppression du dossier user $path réussie"
			
				}
				Catch
				{
					add-content $LogFile -value "DOSSIER -> User: $PB - Suppression du dossier user $path échoué "
					write-host "DOSSIER -> User: $PB - Suppression du dossier user $path échoué"
			
				}
			}
			 <#	if($debugMode -eq $false)
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
			
		
			try
			{
				if($debugMode -eq $false)
				{
					Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath') -Match "$PB" -and $_.GetValue('ProfileImagePath') -Match $_.FullName} | Select-Object -first 1 | Remove-Item
				
				
				$test = Get-ChildItem "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList" | ? {$_.GetValue('ProfileImagePath') -Match "$PB" -and $_.GetValue('ProfileImagePath') -Match $_.FullName}
				if($test.Count -eq 0)
						{										
							write-host "REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
							add-content $LogFile -value " REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
						}
						else
						{
							write-host "REGISTRE -> User: $PB - Suppression clé de registre $UserKey échoué"
							add-content $LogFile -value " REGISTRE -> User: $PB - Suppression clé de registre $UserKey échoué"
						}
				}
				else
				{
					write-host "DEBUG REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
					add-content $LogFile -value "DEBUG REGISTRE -> User: $PB - Suppression clé de registre $UserKey réussie"
				}
				
			}
			catch
			{			
				add-content $LogFile -value "REGISTRE -> User: $PB - Suppression clé de registre  échoué"	
				write-host "REGISTRE -> User: $PB - Suppression clé de registre  échoué"
			}  
		#>		
	}	