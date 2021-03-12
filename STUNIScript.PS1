# STUNI SCCM-Device-Quick-Tuneup_RUNTIME_SCRIPT
# OS Inband Performance Tuneup
# Adapted from original QTUNI By Paul Thompson 2018-04-10 to be run specifically under a SCCM Script with lower CPU utilisation.
# Borrrowed from Reddit https://www.reddit.com/r/SCCM/comments/m33wwc/stuni_script_improve_machine_performance_patching/ and uploaded for use.
#
# Use to improve machine performance before patching and result in more quick & successful patching in a maintenance windows.
# Typically run a few days prior to say a monthly patch run.
#
# Designed for use with Windows Servers 2008 32bit and later.  May be used on Workstations Windows 7 and above if cleanmgr already installed.
#
# Functionality of this script :
# 1. Add Runtime Auditing							all actions logged to Event Log  System, under Event Log Name STUNI and reported in final result STD output.
# 2. Run Check WMI Repository                      	for any Windows machine.  Script will exit with error if this verification of the repository fails
# 3. Run DISM Image Cleanup							for Server 2012 and later machines.
# 4. Check for CleanMgr	& Install if required		for Server 2008, Server 2008R2, Server 2012 and Server 2012R2 will automatically install binaries if not available.
# 5. Add CleanMgr Registry settings					for Server 2008 through to Server 2019, removes unnecessary files broadly across the machine
# 6. Run CleanMgr									for Server 2008 through to Server 2019.
# 7. Run cleanup ccmcache folder contents			for any SCCM Client installed machine.
# 8. Run Cleanup SoftwareDistribution folder		for any Windows machine.
# 9. Run Remove folder SoftwareDistribution.bak		for any Windows machine.
# 10. Run Remove folder SoftwareDistribution.old	for any Windows machine.
# 11. Run Optimize C drive storage					for any Windows machine.


# Versions
# 1.00:20200804:PT:Creation
# 1.10:20200811:PT:Added check of winmgmt /verifyrepository
# 1.20:20200811:PT:Remove BINHEX cleanmgr install capability for Server 2012R2, due to SCCM script size limit of 200KB. Worked out an alternative if locally available.
# 1.30:20200918:PT:Changes to script Standard Output and Exit codes, to work better for SCCM reporting
# 2.00:20201007:PT:Standardise version number
# 3.00:20210312:PT:Cleanup script notes

# Run script singly for machine clean-up
# or
# Add certificate signed script, import into SCCM and run run against machines in GUI.
#
# Limited std output.  Monitor SYSTEM eventlog of machine for STUNI to determine process stage.


################################
# PREPARATIONS
################################

# Check PowerShell Version
if(($PSVersionTable.PSVersion).major -lt 2){ 
	write-host "ERROR 100 POWERSHELL VERSION LESS THAN 2"
	exit 100
}

# Script Start Runtime Milestone
$STARTMS = (Get-Date)


##########
$PGMSTEP = "02-Prepare Environment Variables"
try {
	Set-Variable -Name myVariable -Option Private
	$PGMNAME = "STUNI SCCM SCRIPT TUNEUP FOR WINDOWS"
	$PGMSHORT= "STUNI"
	$PGMVER = "3.00"
	$EVENTLOGNAME = "System"
	$CLEANMGRRUNTIMEOUT = 900
}
catch {
	$ERRORCODE = "99"
	$ERRORDESC = "ERROR $ERRORCODE Catch at $PGMSTEP"
	write-host $ERRORDESC
	exit $ERRORCODE
}


##########
$PGMSTEP = "03-Prepare Eventlog working"
try {
	if (-not [system.diagnostics.eventlog]::SourceExists("$PGMSHORT") ) { [system.diagnostics.EventLog]::CreateEventSource("$PGMSHORT", "System") }	
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 1 -EntryType Information -Message "$PGMSHORT $PGMVER $PGMNAME STARTED. USER = $env:USERDOMAIN\$env:USERNAME" -Category 1 -RawData 10,20
}
catch {
	$ERRORCODE = "99"
	$ERRORDESC = "ERROR $ERRORCODE Catch at $PGMSTEP"
	write-host $ERRORDESC
	exit $ERRORCODE
}



################################
# FUNCTIONS
################################
function FCTestAdmin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
################################
function FCRegistryAdd {
	if (Test-Path $registryPath) {
		New-ItemProperty -Path $registryPath -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
	} else {
		New-Item -Path $registryPath -Force | Out-Null
		New-ItemProperty -Path $registryPath -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
	}
}
################################




################################
# MAIN
################################

##########
$PGMSTEP = "10-Check Elevated Working"
$LOGNOTE = "STARTING"
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 1001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	if ((FCTestAdmin) -eq $false)  {
		$ERRORCODE = "10"
		$ERRORDESC = "ERROR $ERRORCODE Failed at $PGMSTEP"
		exit $ERRORCODE	
	}
	$LOGNOTE = "COMPLETED"
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 1099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
}
catch {
	$ERRORCODE = "10"
	$ERRORDESC = "ERROR $ERRORCODE Catch at $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "11-Check WMI Verify Repository"
$LOGNOTE = "STARTING"
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 1101 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	$P11RTN = Start-Process -WindowStyle hidden -FilePath 'winmgmt' -ArgumentList '/verifyrepository' -Passthru -Wait 
	if ($($P11RTN.ExitCode) -ne '0')  {
		$ERRORCODE = "11"
		$ERRORDESC = "ERROR $ERRORCODE Failed at $PGMSTEP. CHECK MACHINE WMI REPOSITORY STATE"
		Write-Host $ERRORDESC
		exit $ERRORCODE	
	}
	$LOGNOTE = "COMPLETED"
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 1199 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
}
catch {
	$ERRORCODE = "11"
	$ERRORDESC = "ERROR $ERRORCODE Catch at $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}




##########
$PGMSTEP = "20-Attempt DISM Cleanup"
$LOGNOTE = "STARTING"
# ATTEMPT DISM CLEANUP
# First determine if the version of PowerShell is late enough to conduct some basic tests.
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 2001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	if(($PSVersionTable.PSVersion).major -gt 2) {
		# PS is OK, so begin further checks on the OS
		Try {
			$OSVersion = Get-CimInstance -ClassName Win32_OperatingSystem
			if ($OSversion.caption -notlike '*2008*'){
				Start-Process -WindowStyle hidden -FilePath 'dism.exe' -ArgumentList '/online /Cleanup-Image /StartComponentCleanup' -Passthru -Wait | Out-Null
				$LOGNOTE = "COMPLETED"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 2099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
			} else {
				$ERRORDESC = "DISM CLEANUP NOT AVAILABLE ON 2008 MACHINE. IGNORED & CONTINUING"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 2050 -EntryType Information -Message "$ERRORDESC" -Category 1 -RawData 10,20
				# Allowed to continue
			}
		}
		catch {
			$ERRORCODE = "20"
			$ERRORDESC = "ERROR $ERRORCODE Catch inside at $PGMSTEP"
			Write-Host $ERRORDESC
			Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
			exit $ERRORCODE
		}
	}else{
		$ERRORDESC = "DISM CLEANUP CHECK NOT POSSIBLE WITH OLDER POWERSHELL VERSIONS. IGNORED & CONTINUING."
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 2051 -EntryType Information -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "20"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "30-Check if Cleanmgr is installed"
$LOGNOTE = "STARTING"
Try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	if(Test-Path "C:\Windows\System32\cleanmgr.exe") {
		$CLEANMGRINSTALLED = "YES"
		$LOGNOTE = "COMPLETED"
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	}else{
		$CLEANMGRINSTALLED = "NO"
		$ERRORDESC = "CLEANMGR NOT INSTALLED IN OS."
		#Write-Host $ERRORDESC
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3050 -EntryType Information -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "30"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "31-Attempt to install Cleanmgr executable"
$LOGNOTE = "STARTING"
Try {
	if ($CLEANMGRINSTALLED -eq "NO") {
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3101 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
		$OSVerMajor = [environment]::OSVersion.Version.Major | Out-String -Stream
		$OSVerMinor = [environment]::OSVersion.Version.Minor | Out-String -Stream
		$OSVerString = "$OSVerMajor$OSVerMinor"
		if( $OSVerString -eq "60" )
		{
			$OSCHK = "Server 2008 32bit OS"
			$CLEANERFILE1 = "C:\Windows\winsxs\x86_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_6d4436615d8bd133\cleanmgr.exe"
			$CLEANERFILE2 = "C:\Windows\winsxs\x86_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_5dd66fed98a6c5bc\cleanmgr.exe.mui"
			if((Test-Path -path $CLEANERFILE1) -And (Test-Path -path $CLEANERFILE2)) {
				$LOGNOTE = "FOUND Server 2008 32bit OS"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3102 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
				Copy-Item $CLEANERFILE1 -Destination "C:\Windows\System32" -Force
				Copy-Item $CLEANERFILE2 -Destination "C:\Windows\System32\en-US" -Force
				$CLEANMGRINSTALLED = "YES"
				$LOGNOTE = "COMPLETED"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3199 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
			}else{
				$LOGNOTE = "Unable to determine OS to install applicable cleanmgr.exe.  Possible code error"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3170 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
			}
		}elseif( $OSVerString -eq "61" )
		{
			$OSCHK = "Server 2008R2 64bit OS"
			$CLEANERFILE1 = "C:\Windows\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe"
			$CLEANERFILE2 = "C:\Windows\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui"
			if((Test-Path -path $CLEANERFILE1) -And (Test-Path -path $CLEANERFILE2)) {
				$LOGNOTE = $OSCHK
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3161 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
				Copy-Item $CLEANERFILE1 -Destination "C:\Windows\System32" -Force
				Copy-Item $CLEANERFILE2 -Destination "C:\Windows\System32\en-US" -Force
				$CLEANMGRINSTALLED = "YES"
				$LOGNOTE = "COMPLETED"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3199 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
				
			}else{
				$LOGNOTE = "Unable to determine OS to install applicable cleanmgr.exe.  Possible code error"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3171 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
			}
		}elseif( $OSVerString -eq "62" )
		{
			$OSCHK = "Server 2012 64bit OS"
			$CLEANERFILE1 = "C:\Windows\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe"
			$CLEANERFILE2 = "C:\Windows\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui"
			if((Test-Path -path $CLEANERFILE1) -And (Test-Path -path $CLEANERFILE2)) {
				$LOGNOTE = $OSCHK
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3162 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
				Copy-Item $CLEANERFILE1 -Destination "C:\Windows\System32" -Force
				Copy-Item $CLEANERFILE2 -Destination "C:\Windows\System32\en-US" -Force
				$CLEANMGRINSTALLED = "YES"
				$LOGNOTE = "COMPLETED"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3199 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
				
			}else{
				$LOGNOTE = "Unable to determine OS to install applicable cleanmgr.exe.  Possible code error"
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3172 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
			}
		}elseif( $OSVerString -eq "63" )
		{
			$LOGNOTE = "Unable to automtically install CleanMgr.  Must be manually installed from QTUNI \ Additions script"
			Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3163 -EntryType Warning -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
		}else{
			$LOGNOTE = "Unable to determine OS to install applicable cleanmgr.exe.  Possible code error"
			Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 3179 -EntryType Warning -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
		}
	}
}
catch {
	$ERRORCODE = "31"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "40-Load Registry with CleanMgr settings"
$LOGNOTE = "STARTING"
Try {
	if ($CLEANMGRINSTALLED -eq "YES" ) {
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 4001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
			
		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd
		
		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Internet Cache Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Memory Dump Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Service Pack Cleanup"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error memory dump files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error minidump files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Setup Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Sync Files"
		$RegName = "Autorun"
		$RegValue = "00000001"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Upgrade Discarded Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Defender"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Archive Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Queue Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Archive Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Queue Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Temp Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows ESD installation files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Upgrade Log Files"
		$RegName = "StateFlags0100"
		$RegValue = "00000002"
		FCRegistryAdd

		$LOGNOTE = "COMPLETED"
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 4099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	}else{
		$ERRORDESC = "CLEANMGR REGISTRY NOT LOADED DUE TO CLEANMGR NOT INSTALLED. MANUALLY INSTALL CLEANMGR REGISTRY SETTINGS. IGNORED & CONTINUING"
		Write-Host $ERRORDESC
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 4050 -EntryType Warning -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "40"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "50-Attempt CLEANMGR Cleanup"
$LOGNOTE = "STARTING"
try {
	if ($CLEANMGRINSTALLED -eq "YES" ) {
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 5001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
		# Check if cleanmgr is already running
		if((get-process -Name "cleanmgr" -ErrorAction SilentlyContinue)){
			$ERRORDESC = "CLEANMGR FOUND RUNNING. IGNORING, STEPPING ON & CONTINUING"
			Write-Host $ERRORDESC
			Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 5051 -EntryType Warning -Message "$ERRORDESC" -Category 1 -RawData 10,20
		}else{
			Start-Process  -WindowStyle hidden -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:100' | Out-Null
			# Lower runtime priority improves OS environment in 1 and 2 CPU machines.
			$STARTEDPROCESS = get-process -Name "cleanmgr"
			$STARTEDPROCESS.PriorityClass = 'BelowNormal' 
			Wait-Process -Name "cleanmgr" -Timeout $CLEANMGRRUNTIMEOUT -ErrorAction SilentlyContinue
			# Found CleanMgr can hang up, possible due to CB or WDATP. Thus we stop the process if found a good time later if still running
			if((get-process -Name "cleanmgr" -ErrorAction SilentlyContinue)){
				$ERRORDESC = "CLEANMGR RUNNING MORE THAN $CLEANMGRRUNTIMEOUT SECONDS. FORCE STOPPING PROCESS & CONTINUING"
				Write-Host $ERRORDESC
				Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 5052 -EntryType Warning -Message "$ERRORDESC" -Category 1 -RawData 10,20
				stop-process -Name "cleanmgr" -Force -Confirm:$false -ErrorAction SilentlyContinue
			}
			$LOGNOTE = "COMPLETED"
			Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 5099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
		}
	}else{
			$ERRORDESC = "CLEANMGR NOT EXECUTED NO EXECUTABLE FOUND. MANUALLY RESOLVE.  IGNORED & CONTINUING."
		Write-Host $ERRORDESC
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 5050 -EntryType Warning -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "50"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "60-Attempt ccmcache Cleanup"
$LOGNOTE = "STARTING"
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 6001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	if( Test-Path -path "C:\WINDOWS\ccmcache" ){
		# file with path $path doesn't exist
		$resman = new-object -com 'UIResource.UIResourceMgr'
		$cacheInfo = $resman.GetCacheInfo()
		$cacheinfo.GetCacheElements() | where-object {$_.LastReferenceTime -lt (get-date).AddDays(-0)} | foreach {$cacheInfo.DeleteCacheElement($_.CacheElementID)}
		$LOGNOTE = "COMPLETED"
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 6099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	} else {
		$ERRORDESC = "CCMCACHE FOLDER NOT FOUND. MANUALLY INVESTIGATE. IGNORED & CONTINUING. "
		Write-Host $ERRORDESC
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 6050 -EntryType Warning -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "60"
	$ERRORDESC = "ERROR $ERRORCODE Failed at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "70-Attempt SoftwareDistribution DownloadFolder Cleanup"
$LOGNOTE = "STARTING"
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	$SoftwareDistributionLocation = "$env:windir\SoftwareDistribution\Download"
	if ( Test-Path -Path $SoftwareDistributionLocation -PathType Container ) {
		$SoftwareDistribution = Get-ChildItem $SoftwareDistributionLocation -Recurse
		$SoftwareDistributionCount = ($SoftwareDistribution).Count
		if($SoftwareDistributionCount -gt "0"){
			$SoftwareDistribution | Remove-Item -Confirm:$false -Recurse -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		}
		$LOGNOTE = "COMPLETED"
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20	
	} else {
		$ERRORDESC = "SOFTWARE DISTRIBUTION DOWNLOAD FOLDER CLEANUP HAS NO FILES FOUND. THATS OK. IGNORED & CONTINUING."
		#Write-Host $ERRORDESC
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7050 -EntryType Information -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "70"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}




##########
$PGMSTEP = "71-Attempt SoftwareDistribution.bak Folder Deletion"
$LOGNOTE = "STARTING"
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7101 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	$SoftwareDistributionLocation2 = "$env:windir\SoftwareDistribution.bak"
	if ( Test-Path -Path $SoftwareDistributionLocation2 -PathType Container ) {
		Remove-Item –path $SoftwareDistributionLocation2 –Recurse -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		$LOGNOTE = "COMPLETED"
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7199 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	} else {
		$ERRORDESC = "SOFTWARE DISTRIBUTION.BAK FOLDER NOT FOUND. THATS OK. IGNORED & CONTINUING."
		#Write-Host $ERRORDESC
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7150 -EntryType Information -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "71"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	#Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "72-Attempt SoftwareDistribution.old Folder Deletion"
$LOGNOTE = "STARTING"
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7201 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	$SoftwareDistributionLocation3 = "$env:windir\SoftwareDistribution.old"
	if ( Test-Path -Path $SoftwareDistributionLocation3 -PathType Container ) {
		Remove-Item –path $SoftwareDistributionLocation3 –Recurse -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		$LOGNOTE = "COMPLETED"
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7299 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	} else {
		$ERRORDESC = "SOFTWARE DISTRIBUTION.OLD FOLDER NOT FOUND. THATS OK. IGNORED & CONTINUING"
		#Write-Host $ERRORDESC
		Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 7250 -EntryType Information -Message "$ERRORDESC" -Category 1 -RawData 10,20
		# Allowed to continue
	}
}
catch {
	$ERRORCODE = "72"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	#Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}



##########
$PGMSTEP = "80-Attempt Disk Optimization C Drive"
$LOGNOTE = "STARTING"
try {
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 8001 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
	$OptDrive = "C"
	$Arglist = $OptDrive + ":"
	Start-Process -WindowStyle hidden -FilePath 'Defrag.exe' -ArgumentList $Arglist -Passthru -Wait | Out-Null
	$LOGNOTE = "COMPLETED"
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 8099 -EntryType Information -Message "$LOGNOTE $PGMSTEP" -Category 1 -RawData 10,20
}
catch {
	$ERRORCODE = "80"
	$ERRORDESC = "ERROR $ERRORCODE Catch at edge of $PGMSTEP"
	Write-Host $ERRORDESC
	Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 64999 -EntryType Error -Message "$ERRORDESC" -Category 1 -RawData 10,20
	exit $ERRORCODE
}

# Script End Runtime Logging
$ENDMS = (Get-Date)


# All Completed OK
# Script End Runtime Logging
$ENDMS = (Get-Date)
$SCRIPTRUNTIME = [math]::round(($ENDMS - $STARTMS).TotalSeconds,1)
Write-Host "EXECUTED $PGMSHORT v$PGMVER $SCRIPTRUNTIME SECONDS"
Write-EventLog -LogName "$EVENTLOGNAME" -Source "$PGMSHORT" -EventID 2 -EntryType Information -Message "$PGMSHORT $PGMVER $PGMNAME SCRIPT COMPLETED SUCCESSFULLY. $SCRIPTRUNTIME SECONDS. USER = $env:USERDOMAIN\$env:USERNAME" -Category 1 -RawData 10,20
exit 0