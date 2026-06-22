$signature = @'
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool WriteConsoleInputW(
        IntPtr hConsoleInput,
        byte[] lpBuffer,
        uint nLength,
        out uint lpNumberOfEventsWritten
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AllocConsole();

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile
    );


}
'@

Add-Type -TypeDefinition $signature

[Win32]::AllocConsole()

$GENERIC_READ = [uint32]2147483648 # 0x80000000, used decimal to avoid signed overflow in PowerShell
$GENERIC_WRITE = [uint32]0x40000000
$FILE_SHARE_READ = 1
$OPEN_EXISTING = 3

$hStdin = [Win32]::CreateFile("CONIN$", $GENERIC_READ -bor $GENERIC_WRITE, $FILE_SHARE_READ, [IntPtr]::Zero, $OPEN_EXISTING, 0, [IntPtr]::Zero)

if ($hStdin -eq [IntPtr]::Zero -or $hStdin.ToInt64() -eq -1) {
    throw "Failed to open CONIN$. Error code: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
}

function Send-Key([uint16]$virtualKeyCode, [uint16]$char = 0) {
    $bytes = New-Object byte[] 20
    
    # EventType = 1 (KEY_EVENT)
    $bytes[0] = 1
    $bytes[1] = 0
    
    # bKeyDown = 1
    $bytes[4] = 1
    $bytes[5] = 0
    $bytes[6] = 0
    $bytes[7] = 0
    
    # wRepeatCount = 1
    $bytes[8] = 1
    $bytes[9] = 0
    
    # wVirtualKeyCode
    $bytes[10] = $virtualKeyCode -band 0xFF
    $bytes[11] = ($virtualKeyCode -shr 8) -band 0xFF
    
    # wVirtualScanCode = 0
    $bytes[12] = 0
    $bytes[13] = 0
    
    # uChar
    $bytes[14] = $char -band 0xFF
    $bytes[15] = ($char -shr 8) -band 0xFF
    
    # dwControlKeyState = 0
    $bytes[16] = 0
    $bytes[17] = 0
    $bytes[18] = 0
    $bytes[19] = 0

    $written = 0
    $result = [Win32]::WriteConsoleInputW($hStdin, $bytes, 1, [ref]$written)
    Write-Host "WriteConsoleInput result: $result, written: $written"
    if (-not $result) {
        throw "WriteConsoleInput failed"
    }
}

$outputFile = "integration_output.txt"
if (Test-Path $outputFile) { Remove-Item $outputFile }

# Start Dart process
$process = Start-Process dart -ArgumentList "test/bin/echo_stdin.dart", $outputFile -NoNewWindow -PassThru

# Wait for READY
$timeout = 10
$elapsed = 0
while ($elapsed -lt $timeout) {
    if (Test-Path $outputFile) {
        $content = Get-Content $outputFile
        if ($content -contains "READY") {
            break
        }
    }
    Start-Sleep -Milliseconds 500
    $elapsed += 0.5
}

if ($elapsed -ge $timeout) {
    if ($process) { $process | Stop-Process -Force }
    throw "Timed out waiting for READY"
}

# Send keys
Send-Key -virtualKeyCode 0x41 -char 97 # 'a'
Start-Sleep -Milliseconds 200

Send-Key -virtualKeyCode 0x26 # Up Arrow
Start-Sleep -Milliseconds 200

Send-Key -virtualKeyCode 0x20 -char 32 # Space
Start-Sleep -Milliseconds 200

Send-Key -virtualKeyCode 0x0D # Enter
Start-Sleep -Milliseconds 200

# Kill process
$process | Stop-Process -Force

# Verify output
$content = Get-Content $outputFile
Write-Host "Output content:"
$content | ForEach-Object { Write-Host $_ }

$expectedA = "[97]"
$expectedUp = "[27,91,65]"
$expectedSpace = "[32]"
$expectedEnter = "[13]"

$hasA = $false
$hasUp = $false
$hasSpace = $false
$hasEnter = $false

foreach ($line in $content) {
    if ($line -eq $expectedA) { $hasA = $true }
    if ($line -eq $expectedUp) { $hasUp = $true }
    if ($line -eq $expectedSpace) { $hasSpace = $true }
    if ($line -eq $expectedEnter) { $hasEnter = $true }
}

if (-not $hasA) { throw "Failed to find 'a' in output" }
if (-not $hasUp) { throw "Failed to find Up Arrow in output" }
if (-not $hasSpace) { throw "Failed to find Space in output" }
if (-not $hasEnter) { throw "Failed to find Enter in output" }

Write-Host "Integration test passed!"
Remove-Item $outputFile
