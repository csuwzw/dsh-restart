<#
  由 dsh-restart 插件通过 WMI（Win32_Process.Create）启动。

  为什么必须是 WMI：DSH 桌面版把插件宿主（Host）关在自己的 job object 里，
  从 Host 里普通 spawn 出来的进程会一起被带走；WMI 创建的进程父链是
  WmiPrvSE.exe → svchost.exe → services.exe，完全脱离该 job，且仍在
  explorer 的交互会话里，所以能拉起带界面的新实例。

  职责：结束旧实例 → 等它真正消失 → 释放残留端口 → 拉起新实例。
#>
param(
	[Parameter(Mandatory = $true)][int]$OldPid,
	[Parameter(Mandatory = $true)][string]$Exe,
	[int]$Port = 19387,
	[int]$TimeoutSeconds = 45
)

$ErrorActionPreference = 'SilentlyContinue'

$home_ = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$logDir = Join-Path $home_ 'logs'
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir 'dsh-restart-plugin.log'

function Write-Log([string]$Message) {
	try {
		$line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Message
		Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
	} catch {}
}

Write-Log "armed: oldPid=$OldPid port=$Port exe=$Exe"

# 1) 结束旧实例整棵树。桌面版没有任何能被插件触发的优雅退出入口
#    （生产版菜单里没有"重启应用与 Host"，托盘只有打开/退出，
#    渲染进程也没有 quit/restart API），所以这里直接终止。
#    Host 会因 IPC 断开自行走 shutdown 流程，端口随之释放。
if (Get-Process -Id $OldPid -ErrorAction SilentlyContinue) {
	& taskkill.exe /PID $OldPid /T /F > $null 2>&1
	Write-Log "taskkill /PID $OldPid /T /F -> exit=$LASTEXITCODE"
} else {
	Write-Log "old pid $OldPid already gone"
}

# 2) 等旧进程消失。
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
	if (-not (Get-Process -Id $OldPid -ErrorAction SilentlyContinue)) { break }
	Start-Sleep -Milliseconds 200
}
$alive = [bool](Get-Process -Id $OldPid -ErrorAction SilentlyContinue)

# 3) 兜底：端口还被占着就清掉占用者（正常情况下 Host 已随旧实例退出）。
$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $listeners) {
	$owner = $listener.OwningProcess
	if ($owner -and $owner -ne 0) {
		Write-Log "port $Port still held by pid $owner -> terminating"
		& taskkill.exe /PID $owner /T /F > $null 2>&1
	}
}
if ($listeners.Count -gt 0) { Start-Sleep -Milliseconds 800 }

# 4) 拉起新实例，命令行与用户双击图标完全一致（主进程不接受任何参数）。
Start-Process -FilePath $Exe -WorkingDirectory (Split-Path -LiteralPath $Exe)
$launchedAt = Get-Date
Write-Log "launched: $Exe (old alive=$alive)"

# 5) 事后确认：等这次拉起的新实例把 Host 跑起来，只写日志、不重试。
#    桌面版固定以 --port 0 启动（Web 端口由系统分配），新实例的端口与旧实例不同，
#    所以这里不按 $Port 判断：先找新主进程，再找它下面跑 desktop-host 的 Host 子进程。
#    Host 与 runner 的进程名相同，靠命令行区分。
#
#    **判据是「Host 进程活着」，不是「端口能枚举出来」**。端口枚举在本机实测不可靠：
#    netstat 与 Get-NetTCPConnection 都会间歇性返回空或抛「找不到任何匹配的
#    MSFT_NetTCPConnection 对象」——同一个 pid 连续五次尝试里两次拿到 1 行、两次拿到 0 行、
#    两次抛异常，而进程存活判据五次全对。1.0.2 首版把端口非空当成功条件，于是出现
#    「重启真的成功了、日志却报 listening=[]」的假阴性。端口现在只作为附加信息尽力读取，
#    读不到就留空，不影响判定。
$exeName = Split-Path -Leaf $Exe
$started = @()
$newMain = $null
$newHost = $null
$listenPorts = @()
$verifyDeadline = $launchedAt.AddSeconds(30)
while ((Get-Date) -lt $verifyDeadline) {
	$started = @(Get-CimInstance Win32_Process -Filter "Name='$($exeName.Replace("'", "''"))'" -ErrorAction SilentlyContinue |
		Where-Object { $_.CreationDate -ge $launchedAt.AddSeconds(-2) })
	$ids = @($started.ProcessId)
	# 新进程树里唯一「父进程不在树内」的那个，就是这次拉起的主进程。
	$newMain = $started | Where-Object { $ids -notcontains $_.ParentProcessId } |
		Sort-Object CreationDate -Descending | Select-Object -First 1
	if ($newMain -ne $null) {
		$newHost = $started | Where-Object {
			$_.ParentProcessId -eq $newMain.ProcessId -and $_.CommandLine -match 'dsh-desktop-host[\\/]lib[\\/]index\.js'
		} | Select-Object -First 1
	}
	if ($newHost -ne $null) {
		# 端口：两条通道都试，都失败也无所谓，只用于日志可读性。
		$nsPorts = @(netstat.exe -ano 2>$null | ForEach-Object {
			$f = @(($_ -split '\s+') | Where-Object { $_ -ne '' })
			if ($f.Count -ge 5 -and $f[3] -eq 'LISTENING' -and $f[4] -eq "$($newHost.ProcessId)") {
				[int](($f[1] -split ':')[-1])
			}
		})
		$cimPorts = @(Get-NetTCPConnection -OwningProcess $newHost.ProcessId -State Listen -ErrorAction SilentlyContinue |
			ForEach-Object { $_.LocalPort })
		$listenPorts = @(@($nsPorts) + @($cimPorts) | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
		break
	}
	Start-Sleep -Milliseconds 500
}
$mainPid = if ($newMain -ne $null) { $newMain.ProcessId } else { 0 }
$hostPid = if ($newHost -ne $null) { $newHost.ProcessId } else { 0 }
$verdict = if ($hostPid -gt 0) { 'ok' } else { 'fail' }
Write-Log ("verify: main={0} host={1} listening=[{2}] verdict={3} after {4}s" -f $mainPid, $hostPid, ($listenPorts -join ','), $verdict, [int]((Get-Date) - $launchedAt).TotalSeconds)
