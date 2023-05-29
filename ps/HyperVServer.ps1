[CmdletBinding()]
param(
	[parameter(Mandatory = $true)]
	[string]$Action,
	[parameter(Mandatory = $true)]
	[string]$VMName,
	[parameter(Mandatory = $true)]
	[string]$Computername,
	[parameter(Mandatory = $false)]
	[string]$CheckpointName,
	[parameter(Mandatory = $false)]
	[int]$StartVMWaitTimeBasedCheckInterval = 30,
	[parameter(Mandatory = $false)]
	[string]$StartVMStatusCheckType = "HeartBeatApplicationsHealthy",
	[parameter(Mandatory = $false)]
	[string]$HyperV_StartVMWaitingNumberOfStatusNotifications,
	[parameter(Mandatory = $false)]
	[int]$HyperV_StartVMAppHealthyHeartbeatTimeout,
	[parameter(Mandatory = $false)]
	[string]$HyperV_PsModuleVersion)

[string]$ConfirmPreference = "None"

$timeBasedStatusWaitInterval = $StartVMWaitTimeBasedCheckInterval;
$statusCheckType = $StartVMStatusCheckType;
$waitingTimeNumberOfStatusNotifications = $HyperV_StartVMWaitingNumberOfStatusNotifications
$appHealthyHeartbeatTimeout = $HyperV_StartVMAppHealthyHeartbeatTimeout;
$hyperVPsModuleVersion = $HyperV_PsModuleVersion;

$Action = $Action.ToLowerInvariant();

function Get-HyperVCmdletsAvailable {
	write-output "Check if Hyper-V PowerShell management commandlets are installed."

	$hyperVCommands = (
		('GET-VM'),
		('Get-VMCheckpoint'),
		('Restore-VMCheckpoint'),
		('Start-VM'),
		('Stop-VM'),
		('Checkpoint-VM'),
		('Remove-VMCheckpoint'),
		('Disable-VMEventing'),
		('Enable-VMEventing')
	)

	foreach ($cmdName in $hyperVCommands) {
		if (!(Get-Command $cmdName -errorAction SilentlyContinue)) {
			write-output -ForegroundColor Yellow "Windows feature ""Microsoft-Hyper-V-Management-PowerShell"" is not installed on the build agent."
			write-output -ForegroundColor Yellow "Please install ""Microsoft-Hyper-V-Management-PowerShell"" by using an Administrator account"
			write-output -ForegroundColor Yellow "You can use PowerShell with the following command to install the missing components:"
			write-output -ForegroundColor Green "Enable-WindowsOptionalFeature –FeatureName Microsoft-Hyper-V-Management-PowerShell,Microsoft-Hyper-V-Management-Clients –Online -All"

			#throw "Microsoft-Hyper-V-Management-PowerShell are not installed."
			Write-Error
			exit 1

			return
		}
	}

	write-output "Microsoft-Hyper-V-Management-PowerShell are installed."

}

# Too many Hyper-V powershell actions in a short period can lead to wrong data in PS-HyperV-cache
# We disable the cache before doing any actions to avoid invalid data
# Disable the cache leads to increased workfload
# At the end of our actions we re-enable the cache again
function Set-HyperVCmdletCacheDisabled {
	<#
	.Notes
	Disable hyper-v commandlet cache because this causes some trouble in cases of high workloads / number of hyper-v changes/actions
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			write-output "Disable Hyper-V cmdlet caching."
			if ($hyperVPsModuleVersion -eq "1.0" -or $hyperVPsModuleVersion -eq "1.1") {
				Disable-VMEventing -force
			}
			else {
				Disable-VMEventing -ComputerName $Computername -force
			}
		}
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Set-HyperVCmdletCacheEnabled {
	<#
	.Notes
	(re-)enable hyper-v commandlet cache again so that other scripts are not affected.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			write-output "(Re-)Enable Hyper-V cmdlet caching."
			if ($hyperVPsModuleVersion -eq "1.0" -or $hyperVPsModuleVersion -eq "1.1") {
				Enable-VMEventing -force
			}
			else {
				Enable-VMEventing -ComputerName $Computername -force
			}
		}
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Get-ParameterOverview {
	write-output "Action is $Action.";
	write-output "Assigned VM name(s) are $VMName.";
	write-output "Assigned Hyper-V server host is $Computername.";

	if ($Action -eq "StartVM") {
		write-output "Status check type: $statusCheckType";
		if ($statusCheckType -eq "WaitingTime") {
			write-output "Waiting time interval (in sec): $timeBasedStatusWaitInterval"
		}
	}

	if ($CheckpointName) {
		write-output "Assigned checkpoint name is $CheckpointName.";
	}
}


function Get-VMExists {
	[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope = "Function", Target = "*")]
	param([System.Collections.ArrayList]$vmnames, [string]$hostname)

	write-output "Checking if all configured VMs are found on host $hostname";

	$nonExistingVMs;
	for ($i = 0; $i -lt $vmnames.Count; $i++) {
		$vmname = $vmnames[$i];

		$vm = Get-VM -Name $vmname -Computername $hostname
		if ($null -eq $vm) {
			Write-Error "VM $vmname doesn't exist on Hyper-V server $hostname"
		}
	}
	$notExistingVM = $notExistingVM.Trim;

	if ($notExistingVM.Count -gt 0) {
		Write-Error "The task found some non existing VM names. Please check VMs $notExistingVM on host $hostname.";
		#throw "The task found some non existing VM names. Please check VMs $notExistingVM on host $hostname.";
		Write-Error "The task found some non existing VM names. Please check VMs $notExistingVM on host $hostname.";
		exit 1;
	}
	$notExistingVM += " $vmname"

	write-output "All configured VMs are found on host $hostname";
}

function Get-VMNamesFromVMNameParameter {
	<#
	.Notes this function works supports one or more VMnames in VMName build process parameter
	#>

	$vmNames = New-Object System.Collections.ArrayList;

	if ($VMName.Contains(",")) {
		$tempNames = New-Object System.Collections.ArrayList;
		$splittedNames = $VMName.Split(",");
		$vmNames = $tempNames;

		for ($i = 0; $i -lt $splittedNames.Count; $i++) {
			$tempNames.Add($splittedNames[$i].Trim()) | Out-Null
		}

	}
	else {
		# https://stackoverflow.com/questions/28034605/arraylist-prints-numbers
		$VMName = $VMName.Trim();
		$vmNames.Add($VMName) | Out-Null;
	}

	Write-Debug "Found $($vmNames.Count) VM names in VMName parameter";

	# , is a workaround for powershell issues with arraylist -> otherwise this object is converted to string
	return , $vmNames;
}

#region task core actions
function Start-HyperVVM {
	<#
	.Notes
	Starts one or more VMs and waits for healthy signal from VM extensions.

	ToDo
	It is possible that not all OS or Extensions support health signals. Maybe add an alternative approach.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		$vmnames,
		[Parameter()]
		$hostname,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			for ($i = 0; $i -lt $vmnames.Count; $i++ ) {
				$vmname = $vmnames[$i];

				$vm = Get-VM -Name $vmname -Computername $hostname
				if ($vm.Heartbeat -ne "OkApplicationsHealthy") {
					write-output "Starting VM $vmname on host $hostname";
					Start-VM -VMName $vmname -Computername $hostname -ErrorAction Stop
				}
				else {
					write-output "VM $vmname on host $hostname is already started";
				}
			}
			<# Post-impact code #>
		}
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Get-ApplicationsHealthyStatusOfStartHyperVVM {
	param($vmnames, $hostname)

	write-output "Waiting until all VM(s) have been started (using ApplicationHealthy status)."

	$finishedVMs = New-Object System.Collections.ArrayList;

	$workInProgress = $true;
	while ($workInProgress) {
		for ($i = 0; $i -lt $vmnames.Count; $i++) {
			$vmname = $vmnames[$i];

			$vm = Get-VM -Name $vmname -Computername $hostname

			if ($vm.Status -match "Starting") {
				write-output "VM $vmname on host $hostname is still in status Starting"
			}
			else {
				$finishedVMs.Add($vmname) | Out-Null
				write-output "VM $vmname is now ready."
			}

			# After we reached the last vm in the parameter list we need to decide about the next steps
			if ($vmnames.Count -ne $finishedVMs.Count) {
				$workInProgress = $true;
				Start-Sleep -Seconds 5
				write-output "Checking status again in 5 sec."
			}
			else {
				$workInProgress = $false;
			}
		}
	}

	$workInProgress = $true;
	while ($workInProgress) {
		for ($i = 0; $i -lt $vmnames.Count; $i++) {
			$circuitBreaker = $false;
			$vm = Get-VM -Name $vmname -Computername $hostname
			write-output "Waiting until VM $vmname heartbeat state is ""Application healthy""."

			# backup for future -and $vm.Heartbeat -ne "OkApplicationsUnknown"
			# hyper-v show unkown in case the hyper-v extensions are not uptodate
			while ($vm.Heartbeat -ne "OkApplicationsHealthy" -and !$circuitBreaker) {
				Start-Sleep -Seconds 5
				write-output "Checking status again in 5 sec."
				$vm = Get-VM -Name $vmname -Computername $hostname
				$heartbeatTimeout = $appHealthyHeartbeatTimeout;

				if ($null -eq $heartbeatTimeout -or $heartbeatTimeout -eq 0) {
					Write-Verbose "Assigning default value to heartbeat timeout because it is $heartbeatTimeout";
					# If the Heartbeat Timeout is set we stay at the default of 5 minutes.
					$heartbeatTimeout = 5 * 60;
					write-output "Default heartbeat timeout is $heartbeatTimeout";
				}
				else {
					write-output "Assigning custom value to heartbeat timeout $heartbeatTimeout"
				}


				if ($vm.State -eq "Running" -and $vm.Uptime.Seconds -gt $heartbeatTimeout) {
					$circuitBreaker = $true;
					Write-Warning "Starting VM $vmname reached $heartbeatTimeout minute timeout limit";
					Write-Warning "Hyper-V heartbeat has not reported healthy state."
					Write-Warning "VM $vmname is in running state and the task finishs execution";
					break;
				}

				if ($vm.State -ne "Running" -and $vm.Uptime.Seconds -gt $heartbeatTimeout) {
					$circuitBreaker = $true;
					Write-Warning "Starting VM $vmname reached $heartbeatTimeout minute timeout limit";
					Write-Warning "Hyper-V heartbeat has not reported healthy state."
					Write-Error "Abording starting VM $vmname because VM state is not running"
					Write-Error "Please check logs on Hyper-V server and Build agent to find the root cause and fix any issues."
					continue
				}
			}

			$workInProgress = $false;
			write-output "The VM $vmname has been started.";
		}
	}

	write-output "All VM(s) have been started."
}

function Get-TimeBasedStatusOfStartHyperVVM {
	param($vmnames, $hostname)

	write-output "Waiting until all VM(s) have been started (using TimeBased check)."
	$finishedVMs = New-Object System.Collections.ArrayList;

	$workInProgress = $true;
	while ($workInProgress) {
		for ($i = 0; $i -lt $vmnames.Count; $i++) {
			$vmname = $vmnames[$i];

			$vm = Get-VM -Name $vmname -Computername $hostname

			if ($vm.Status -match "Starting") {
				write-output "VM $vmname on host $hostname is still in status Starting"
			}
			else {
				$finishedVMs.Add($vmname) | Out-Null
				write-output "VM $vmname is now ready."
			}

			# After we reached the last vm in the parameter list we need to decide about the next steps
			if ($vmnames.Count -lt $finishedVMs.Count) {
				$workInProgress = $true;
				Start-Sleep -Seconds 5
				write-output "Checking status again in 5 sec."
			}
			else {
				$workInProgress = $false;
			}
		}
	}

	if ($null -eq $waitingTimeNumberOfStatusNotifications -or 0 -eq $waitingTimeNumberOfStatusNotifications) {
		Write-Verbose "Assigning default value to Waiting time status notifications $waitingTimeNumberOfStatusNotifications";
		$waitingTimeNumberOfStatusNotifications = 30;
	}
	else {
		write-output "Assigning custom value to Waiting time status notifications $waitingTimeNumberOfStatusNotifications";
	}

	[int]$waitingInterval = ($timeBasedStatusWaitInterval / 30);

	for ($i = 1; $i -le $waitingTimeNumberOfStatusNotifications; $i++) {
		Start-Sleep -Seconds $waitingInterval
		$timeBasedStatusWaitIntervalLeft = $timeBasedStatusWaitInterval - $i * $waitingInterval;

		write-output "Waiting interval is reached in $timeBasedStatusWaitIntervalLeft sec."
	}
	write-output "Waiting interval $timeBasedStatusWaitInterval seconds reached. We go on ..."
}

function Get-StatusOfStartHyperVVM {
	param($vmnames, $hostname)

	switch ($statusCheckType) {
		"WaitingTime" { Get-TimeBasedStatusOfStartHyperVVM -vmnames $vmNames -hostname $hostName }
		"HeartBeatApplicationsHealthy" { Get-ApplicationsHealthyStatusOfStartHyperVVM -vmnames $vmNames -hostname $hostName }
		default { write-output "No check for StartVM configured." }
	}
}


function Stop-VMUnfriendly {
	<#
	.Notes
	alternative approach to shutdown VMs in case regular shutdown is not possible.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	param(
		[Parameter()]
		$vmname,
		[Parameter()]
		$hostname,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			$id = (
				get-vm -ComputerName $hostname | Where-Object { $_.name -eq "$vmname" } | Select-Object id).id.guid
			If ($id) {
				write-output "VM GUID found: $id"
			}
			Else {
				write-warning "VM or GUID not found for VM: $vmname.";
				break
			}

			$vm_pid = (Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'vmwp' -and $_.CommandLine -match $id }).ProcessId
			If ($vm_pid) {
				write-warning "Found VM worker process id: $vm_pid"
				Write-warning "Killing VM worker process of VM: $vmname"
				stop-process $vm_pid -Force
			}
			Else {
				write-output "No VM worker process found for VM: $vmname"
			}

		}

		<# Post-impact code #>
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Stop-VMByTurningOffVM {
	<#
	.Notes
	helper method for stop vm. this one turns the vm off (instead of regular shutdown) -> dataloss is possible in some cases -> e.g. cache not flushed to disk
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		$vmnames,
		[Parameter()]
		$hostName,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			for ($i = 0; $i -lt $vmnames.Count; $i++) {
				$vmname = $vmnames[$i];
				$vm = Get-VM -Name $vmname -Computername $hostname
				if ($vm.State -ne "Off") {
					write-output "Direct turning off the VM $vmname (no regular gracefull shutdown)."
					write-debug "Current VM $vmname state: $($vm.State)"
					write-debug "Current VM $vmname status: $($vm.Status)"

					Stop-VM -Name $vmname -ComputerName $hostname -TurnOff -Force -ErrorAction SilentlyContinue
					Start-Sleep -Seconds 5
					write-debug "Current VM $vmname state: $($vm.State)"
					write-debug "Current VM $vmname status: $($vm.Status)"
					write-output "VM $vmname on $hostname is now turned off."
				}
				else {
					write-output "VM $($vm.Name) is already turned off."
				}
			}
		}
		<# Post-impact code #>
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Start-HyperVVMShutdown {
	<#
	.Notes
	Stops one or more VMs. In conjunction with get-statusstopofvm the function starts with a friendly shutdown approach and after 5 min. does a hard or unfriendly shutdown.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		$vmnames,
		[Parameter()]
		$hostname,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			for ($i = 0; $i -lt $vmnames.Count; $i++) {
				$vmname = $vmnames[$i];

				#Stop-VMUnfriendly -vmname $vmname -hostname $hostname -Confirm:$false
				$vm = Get-VM -Name $vmname -Computername $hostname

				if ($vm.State -ne "Off") {
					write-output "Shutting down VM $vmname on $hostname started."
					$vm = Get-VM -Name $vmname -Computername $hostname

					Stop-VM -Name $vmname -ComputerName $hostname -Force -ErrorAction Stop
				}
				else {
					write-output "VM $vmname on $hostname is already turned off."
				}
			}
		}

		<# Post-impact code #>
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Get-StatusOfShutdownVM {
	write-output "Waiting until all VM(s) has been shutted down."

	$finishedVMs = New-Object System.Collections.ArrayList;

	$workInProgress = $true;
	$retryCounter = 0;

	while ($workInProgress) {
		for ($i = 0; $i -lt $vmnames.Count; $i++) {
			$vmname = $vmnames[$i];
			write-output "Waiting until VM $vmname state is ""Off""."
			$vm = Get-VM -Name $vmname -Computername $hostname

			if ($vm.State -eq 'Off') {
				$finishedVMs.Add($vmname) | Out-Null
				write-output "VM $vmname is turned off."
			}
		}

		if ($vmnames.Count -ne $finishedVMs.Count) {
			$workInProgress = $true;
			$retryCounter++;
			if ($retryCounter -gt 30) {
				# we reached a timeout of approx. 5 min
				# its now the time to stop VMs in a very unfriendly way
				Stop-VMByTurningOffVM -vmnames $vmnames -hostName $hostname
				return;
			}

			Start-Sleep -Seconds 10
			$finishedVMs.Clear();
			write-output "Checking status again in 10 sec."
		}
		else {
			write-output "All configured VMs have been shut down."
			$workInProgress = $false;
		}
	}

	write-output "All VM(s) have been shutted down."
}

function Start-TurnOfVM {
	<#
	.Notes
	Stops one or more VMs. In conjunction with get-statusstopofvm the function starts with a friendly shutdown approach and after 5 min. does a hard or unfriendly shutdown.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		$vmnames,
		[Parameter()]
		$hostname,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			Stop-VMByTurningOffVM -vmnames $vmnames -hostname $hostname -Confirm:$false
		}
		<# Post-impact code #>
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

}

function New-HyperVCheckpoint {
	<#
	.Notes
	Creates a new checkpoint for one or more VMs. The checkpoint name should be the same on all VMs because they are considered as a unit.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		$vmnames,
		[Parameter()]
		$hostname,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			for ($i = 0; $i -lt $vmnames.Count; $i++) {
				$vmname = $vmnames[$i]

				$checkpoint = Get-VMCheckpoint -VMname $vmname -ComputerName $hostname | Where-Object { $_.Name -eq "$CheckpointName" }
				if ($null -ne $checkpoint) {
					Write-Error "Checkpoint $CheckpointName on VM $vmname already exists. Please remove the old checkpoint or choose a different name"
					#throw "Duplicate checkpoint name."
					Write-Error "Duplicate checkpoint name."
					exit 1
				}

				write-output "Creating checkpoint $CheckpointName for VM $vmname on host $hostname"
				Checkpoint-VM -Name $vmname -ComputerName $hostname -CheckpointName $CheckpointName -ErrorAction Stop
			}

		}

		<# Post-impact code #>
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Get-StatusOfNewHyperVCheckpoint {
	param($vmnames, $hostname)

	write-output "Waiting until checkpoint for all VM(s) has been created."

	$finishedVMs = New-Object System.Collections.ArrayList;

	$workInProgress = $true;
	while ($workInProgress) {
		for ($i = 0; $i -lt $vmnames.Count; $i++) {
			$vmname = $vmnames[$i];
			write-output "Waiting until VM $vmname checkpoint state is not ""Creating""."
			$vm = Get-VM -Name $vmname -Computername $hostname

			if ($vm.Status -match "Creating") {
				write-output "Creating a checkpoint on VM $vmname on host $hostname is still in progress"
			}
			else {
				$finishedVMs.Add($vmname) | Out-Null
				write-output "Checkpoint $CheckpointName for the VM $vmname on host $hostname has been created.";
			}

			if ($vmnames.Count -ne $finishedVMs.Count) {
				$workInProgress = $true;
				Start-Sleep -Seconds 5
				write-output "Checking status again in 5 sec."
			}
			else {
				$workInProgress = $false;
			}
		}
	}

	write-output "checkpoints for all VM(s) have been created."
}

function Restore-HyperVCheckpoint {
	<#
	.Notes
	Restores the environment (all VMs) back to specified checkpoint
	In case of an production checkpoint you need to add start-vm in your build -> we try to keep the functions as simple as possible
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		$vmnames,
		[Parameter()]
		$hostname,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			for ($i = 0; $i -lt $vmnames.Count; $i++) {
				$vmname = $vmnames[$i];
				$checkpoint = Get-VMCheckpoint -VMname $vmname -ComputerName $hostname | Where-Object { $_.Name -eq "$CheckpointName" }

				if ($null -eq $checkpoint) {
					write-error "Checkpoint $CheckpointName of VM $vmname on host $hostname doesnt exist."
					#throw "Checkpoint $CheckpointName of VM $vmname on host $hostname doesnt exist."
					exit 1
				}

				write-output "Restoring checkpoint $CheckpointName for VM $vmname on host $hostname have been started."
				Restore-VMcheckpoint -VMName $vmname -ComputerName $hostname -Name $CheckpointName -Confirm:$false -ErrorAction Stop
			}
		}
		<# Post-impact code #>
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Get-StatusOfRestoreHyperVCheckpoint {
	param($vmnames, $hostname)

	write-output "Waiting until restoring checkpoint has been finished for all VM(s)."

	$finishedVMs = new-object System.collections.arraylist;

	$workInProgress = $true;
	while ($workInProgress) {
		for ($i = 0; $i -lt $vmnames.Count; $i++) {
			$vmname = $vmnames[$i];
			write-output "Waiting until VM $vmname state is not ""Applying""."
			$vm = Get-VM -Name $vmname -Computername $hostname

			if ($vm.Status -match "Applying") {
				write-output "Restoring checkpoint for VM $vmname on host $hostname is still in progress.";
			}
			else {
				$finishedVMs.Add($vmname) | Out-Null
				write-output "Checkpoint $CheckpointName for the VM $vmname has been restored.";
			}

			if ($vmnames.Count -ne $finishedVMs.Count) {
				$workInProgress = $true;
				Start-Sleep -Seconds 5
				write-output "Checking status again in 5 sec."
			}
			else {
				$workInProgress = $false;
			}
		}
	}

	write-output "Restoring checkpoints has been finished for all VM(s)."
}

function Remove-HyperVCheckpoint {
	<#
	.Notes
	Remove checkpoint on one or more VMs
	Function checks if checkpoint exists -> makes it a little bit more robust
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	Param(
		[Parameter()]
		$vmnames,
		[Parameter()]
		$hostname,
		[Parameter()]
		[switch]
		$Force
	)

	Begin {
		if (-not $PSBoundParameters.ContainsKey('Verbose')) {
			$VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
		}
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
			$ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		}
		if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
			$WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
		}
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}

	Process {
		<# Pre-impact code #>

		# -Confirm --> $ConfirmPreference = 'Low'
		# ShouldProcess intercepts WhatIf* --> no need to pass it on
		if ($Force -or $PSCmdlet.ShouldProcess("ShouldProcess?")) {
			Write-Verbose ('[{0}] Reached command' -f $MyInvocation.MyCommand)
			# Variable scope ensures that parent session remains unchanged
			$ConfirmPreference = 'None'

			for ($i = 0; $i -lt $vmnames.Count; $i++) {
				$vmname = $vmnames[$i];
				$checkpoint = Get-VMCheckpoint -VMname $vmname -ComputerName $hostname | Where-Object { $_.Name -eq "$CheckpointName" }

				if ($null -eq $checkpoint) {
					Write-Warning "Checkpoint $CheckpointName of VM $vmname on host $hostname doesnt exist."
					#throw "Checkpoint $CheckpointName of VM $vmname on host $hostname doesnt exist."
					exit 1
				}

				write-output "Removing checkpoint $CheckpointName for VM $vmname on host $hostname have been started."
				Remove-VMCheckpoint -VMName $vmname -ComputerName $hostname -Name $CheckpointName -Confirm:$false -ErrorAction Stop
			}
		}

		<# Post-impact code #>
	}

	End {
		Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
	}
}

function Get-StatusOfRemoveHyperVCheckpoint {
	param($vmnames, $hostname)

	write-output "Waiting until removing checkpoint has been finished for all VM(s)."

	$finishedVMs = new-object System.collections.arraylist;

	$workInProgress = $true;
	while ($workInProgress) {
		for ($i = 0; $i -lt $vmnames.Count; $i++) {
			$vmname = $vmnames[$i];
			write-output "Waiting until VM $vmname state is not ""Merging""."
			$vm = Get-VM -Name $vmname -Computername $hostname

			if ($vm.Status -match "Merge") {
				write-output "Removing checkpoint $CheckpointName for VM $vmname on host $hostname is still in progress.";
			}
			else {
				$finishedVMs.Add($vmname) | Out-Null
				write-output "Checkpoint $CheckpointName for the VM $vmname has been removed.";
			}

			if ($vmnames.Count -ne $finishedVMs.Count) {
				$workInProgress = $true;
				Start-Sleep -Seconds 5
				write-output "Checking status again in 5 sec."
			}
			else {
				$workInProgress = $false;
			}
		}
	}

	write-output "Removing checkpoint has been finished for all VM(s)."
}
#endregion

#region Control hyper-v
Try {
	if (![string]::IsNullOrEmpty($hyperVPsModuleVersion)) {
		# in case something it not working as expected we want to know which modules are available
		$availableModules = Get-Module hyper-v -ListAvailable
		Write-Debug ($availableModules | Format-Table | Out-String)

		write-output "Loading Hyper-V PowerShell module version $hyperVPsModuleVersion";
		Import-Module –Name Hyper-V -RequiredVersion $hyperVPsModuleVersion -Force -Global;

		# in case something it not working as expected we want to know which modules are loaded
		$checkLoadedModules = Get-Module hyper-v
		Write-Debug ($checkLoadedModules | Format-Table | Out-String)
	}
	else {
		write-output "Loading Hyper-V system default PowerShell module"
	}

	Get-HyperVCmdletsAvailable
	Get-ParameterOverview
	Set-HyperVCmdletCacheDisabled -Confirm:$false

	$vmNames = Get-VMNamesFromVMNameParameter
	$hostName = $Computername
	Get-VMExists -vmnames $vmNames -hostname $hostName

	switch ($Action) {
		"startvm" {
			Start-HyperVVM -vmnames $vmNames -hostname $hostName -Confirm:$false
			Get-StatusOfStartHyperVVM -vmnames $vmNames -hostname $hostName
		}
		"shutdownvm" {
			Start-HyperVVMShutdown -vmnames $vmNames -hostname $hostName -Confirm:$false
			Get-StatusOfShutdownVM -vmnames $vmNames -hostname $hostName
		}
		"turnoffvm" {
			Start-TurnOfVM -vmnames $vmNames -hostname $hostName -Confirm:$false
		}
		"createcheckpoint" {
			New-HyperVCheckpoint -vmnames $vmNames -hostname $hostName -Confirm:$false
			Get-StatusOfNewHyperVCheckpoint -vmnames $vmNames -hostname $hostName
		}
		"restorecheckpoint" {
			Restore-HyperVCheckpoint -vmnames $vmNames -hostname $hostName -Confirm:$false
			Get-StatusOfRestoreHyperVCheckpoint -vmnames $vmNames -hostname $hostName
		}
		"removecheckpoint" {
			Remove-HyperVCheckpoint -vmnames $vmNames -hostname $hostName -Confirm:$false
			Get-StatusOfRemoveHyperVCheckpoint -vmnames $vmNames -hostname $hostName
		}
		default {
			Write-Error "Invalid command $Action. Aborting execution.";
			exit 1;
		}
	}
}
Catch {
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent();

	Write-Warning ('You have may not enough permission to use the hyper-v cmdlets, please check this:
	Add the ' + $currentUser.Name + ' user to the ""Hyper-V Administrator"" and ""Remote Management Users"" group on the target hyper-v host which the agent wants to access.
	You can authorize the build agent user using two commands: net localgroup "Hyper-V Administrators" ' + $currentUser.Name + ' /add and net localgroup "Remote Management Users" ' + $currentUser.Name + ' /add')
	Write-Error $_.Exception.Message;
	exit 1;
}
finally {
	Set-HyperVCmdletCacheEnabled -Confirm:$false
}
#endregion