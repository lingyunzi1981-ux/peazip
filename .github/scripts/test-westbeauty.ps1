$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$brand = '西美压缩'
$evidence = Join-Path $env:RUNNER_TEMP 'westbeauty-evidence'
$installer = Join-Path $env:RUNNER_TEMP 'delivery\WestBeautyCompression-Setup-x64.exe'
# Both Chinese text and spaces in the actual installation destination.
$installDir = Join-Path $env:ProgramFiles '西美压缩 验收'
$work = Join-Path $env:RUNNER_TEMP '西美压缩 测试 & unicode'
New-Item -ItemType Directory -Force $work,$evidence | Out-Null
$results = [Collections.Generic.List[object]]::new()
function Check([string]$Name, [bool]$Condition, [switch]$Soft) {
    $results.Add(@{ test=$Name; passed=$Condition })
    Write-Host "CHECK $Name : $Condition"
    if (-not $Condition -and -not $Soft) { throw "Acceptance failed: $Name" }
}
function Start-App([string]$File, [string[]]$Arguments = @()) {
    $info = [Diagnostics.ProcessStartInfo]::new($File)
    $info.UseShellExecute = $false
    foreach ($arg in $Arguments) { $info.ArgumentList.Add($arg) }
    return [Diagnostics.Process]::Start($info)
}
function Run-App([string]$File, [string[]]$Arguments, [int]$Timeout = 120) {
    $p = Start-App $File $Arguments
    if (-not $p.WaitForExit($Timeout * 1000)) { $p.Kill($true); throw "Timed out: $File" }
    Check "Exit code: $([IO.Path]::GetFileName($File)) $($Arguments[0])" ($p.ExitCode -eq 0)
}
function Save-Screenshot([string]$Name) {
    try {
        Add-Type -AssemblyName System.Drawing, System.Windows.Forms
        $bounds = [Windows.Forms.SystemInformation]::VirtualScreen
        $bmp = [Drawing.Bitmap]::new($bounds.Width,$bounds.Height)
        $graphics = [Drawing.Graphics]::FromImage($bmp)
        $graphics.CopyFromScreen($bounds.Location,[Drawing.Point]::Empty,$bounds.Size)
        $bmp.Save((Join-Path $evidence $Name),[Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose(); $bmp.Dispose()
    } catch { "Screenshot unavailable: $_" | Add-Content (Join-Path $evidence 'screenshots.log') }
}
function Close-Gui($Process) {
    $Process.Refresh()
    if (-not $Process.HasExited) {
        $null = $Process.CloseMainWindow()
        if (-not $Process.WaitForExit(10000)) { $Process.Kill($true); throw 'GUI did not close normally' }
    }
    Check 'GUI normal close' ($Process.ExitCode -eq 0)
}
try {
    Run-App $installer @('/SP-','/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$installDir",'/TASKS=desktopicon,contextmenu',"/LOG=$(Join-Path $evidence 'install.log')")
    foreach ($rel in @("$brand.exe",'peazip.exe','pea.exe','dragdropfilesdll.dll','res\bin\7z\7z.exe','res\bin\7z\7z.dll','res\share\lang\zh-cn.txt','unins000.exe','LICENSE.txt')) {
        Check "Installed payload: $rel" (Test-Path (Join-Path $installDir $rel))
    }
    Check 'Installed configuration is not portable' (-not (Test-Path (Join-Path $installDir 'res\portable')))
    $app = Join-Path $installDir "$brand.exe"
    Check 'Unicode executable metadata' ((Get-Item $app).VersionInfo.ProductName -eq $brand)
    $uninstallKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7F79973A-49E8-4B57-A2D9-575754424731}_is1'
    Check 'Unicode Add/Remove Programs name' ((Get-ItemProperty $uninstallKey).DisplayName -eq $brand)
    $shell = New-Object -ComObject WScript.Shell
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) "$brand.lnk"
    Check 'Unicode desktop shortcut exists' (Test-Path $shortcutPath)
    # WScript.Shell has a legacy ANSI path; read the shortcut via IShellLinkW.
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
public class UnicodeShellLink { }
[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
public interface IUnicodeShellLink {
  [PreserveSig] int GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int length, IntPtr data, uint flags);
}
public static class ShortcutReader {
  public static string Target(string file) {
    object instance = new UnicodeShellLink();
    try {
      ((IPersistFile)instance).Load(file, 0);
      var output = new StringBuilder(32768);
      Marshal.ThrowExceptionForHR(((IUnicodeShellLink)instance).GetPath(output, output.Capacity, IntPtr.Zero, 0));
      return output.ToString();
    } finally { Marshal.FinalReleaseComObject(instance); }
  }
}
'@
    $shortcutTarget = [ShortcutReader]::Target($shortcutPath)
    @{ expected=$app; unicode_target=$shortcutTarget; wscript_target=$shell.CreateShortcut($shortcutPath).TargetPath } | ConvertTo-Json | Set-Content (Join-Path $evidence 'shortcut-targets.json') -Encoding utf8
    Copy-Item $shortcutPath (Join-Path $evidence 'desktop-shortcut.lnk')
    Check 'Shortcut target is exact Unicode executable' ($shortcutTarget -eq $app)
    $registryChecks = @(
        @('Software\Classes\*\shell\WestBeautyCompress','西美压缩 - 添加到压缩文件...','-add2archive'),
        @('Software\Classes\Directory\shell\WestBeautyZip','西美压缩 - 压缩为 ZIP','-add2zip'),
        @('Software\Classes\SystemFileAssociations\.zip\shell\WestBeautyExtract','西美压缩 - 解压到当前文件夹','-ext2here'),
        @('Software\Classes\SystemFileAssociations\.7z\shell\WestBeautyExtractFolder','西美压缩 - 解压到新文件夹','-ext2newfolder')
    )
    foreach ($entry in $registryChecks) {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($entry[0])
        Check "Context menu exact Unicode: $($entry[1])" ($null -ne $key -and $key.GetValue('') -eq $entry[1])
        $command = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$($entry[0])\command")
        Check 'Context command quotes path and input' ($command.GetValue('') -eq "`"$app`" $($entry[2]) `"%1`"")
        $key.Dispose(); $command.Dispose()
    }
    $gui = Start-App $app
    Start-Sleep 10
    $gui.Refresh()
    Check 'GUI remains running' (-not $gui.HasExited)
    @{ title=$gui.MainWindowTitle; handle=$gui.MainWindowHandle.ToInt64(); responding=$gui.Responding } | ConvertTo-Json | Set-Content (Join-Path $evidence 'gui-process.json') -Encoding utf8
    Check 'GUI has responsive main window' ($gui.MainWindowHandle -ne 0 -and $gui.Responding)
    Check 'GUI title includes brand' ($gui.MainWindowTitle.Contains($brand)) -Soft
    $gui.MainWindowTitle | Set-Content (Join-Path $evidence 'window-title.txt') -Encoding utf8
    Save-Screenshot 'main-window.png'
    Close-Gui $gui
    $conf = Join-Path $env:APPDATA 'WestBeautyCompression\conf.txt'
    Check 'Configuration written in per-user AppData' (Test-Path $conf)
    Check 'First launch defaults to Simplified Chinese' ((Get-Content $conf -Raw -Encoding utf8).Contains('zh-cn.txt'))
    # Core backend round-trip with byte-level equality, Unicode, spaces and shell metacharacters.
    $inputDir = Join-Path $work '输入资料'
    New-Item -ItemType Directory -Force (Join-Path $inputDir '子目录 空格') | Out-Null
    [IO.File]::WriteAllText((Join-Path $inputDir '中文 测试 & 文件.txt'),'西美压缩 Unicode round-trip ä Ω',[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllBytes((Join-Path $inputDir '子目录 空格\binary.dat'),[byte[]](0..255))
    [IO.File]::WriteAllBytes((Join-Path $inputDir 'empty.txt'),[byte[]]@())
    $seven = Join-Path $installDir 'res\bin\7z\7z.exe'
    foreach ($format in @('zip','7z','tar')) {
        $archive = Join-Path $work "中文 压缩包.$format"
        $out = Join-Path $work "解压 $format"
        Run-App $seven @('a',"-t$format",$archive,"$inputDir\*",'-y')
        Run-App $seven @('t',$archive)
        Run-App $seven @('x',$archive,"-o$out",'-y')
        foreach ($file in Get-ChildItem $inputDir -File -Recurse) {
            $relative = [IO.Path]::GetRelativePath($inputDir,$file.FullName)
            $copy = Join-Path $out $relative
            Check "$format preserves $relative" ((Test-Path $copy) -and (Get-FileHash $copy).Hash -eq (Get-FileHash $file.FullName).Hash)
        }
    }
    # Password workflow uses only a synthetic CI fixture password, never a user secret.
    $encrypted = Join-Path $work '加密.7z'
    Run-App $seven @('a','-t7z',$encrypted,"$inputDir\*",'-pSynthetic-CI-Fixture','-mhe=on','-y')
    Run-App $seven @('t',$encrypted,'-pSynthetic-CI-Fixture')
    $wrong = Start-App $seven @('t',$encrypted,'-pWrong-CI-Fixture','-y')
    if (-not $wrong.WaitForExit(30000)) { $wrong.Kill($true); throw 'Wrong-password test hung' }
    Check 'Wrong archive password fails' ($wrong.ExitCode -ne 0)
    $bad = Join-Path $work '损坏.zip'
    [IO.File]::WriteAllText($bad,'not a valid archive')
    $badProc = Start-App $seven @('t',$bad)
    if (-not $badProc.WaitForExit(30000)) { $badProc.Kill($true); throw 'Corruption test hung' }
    Check 'Corrupt archive fails instead of silent success' ($badProc.ExitCode -ne 0)
    # Exercise actual frontend compression verbs, not only backend binaries.
    foreach ($kind in @(@('zip','-add2zip'),@('7z','-add27z'))) {
        $frontSource = Join-Path $work "前端$($kind[0])输入"
        New-Item -ItemType Directory -Force $frontSource | Out-Null
        Copy-Item (Join-Path $inputDir '*') $frontSource -Recurse
        $frontOutput = "$frontSource.$($kind[0])"
        $compress = Start-App $app @($kind[1],$frontSource)
        $deadline = [DateTime]::UtcNow.AddSeconds(90)
        while (-not $compress.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep 1; $compress.Refresh() }
        Save-Screenshot "frontend-compress-$($kind[0]).png"
        Check "Frontend $($kind[0]) compression completes" $compress.HasExited -Soft
        if (-not $compress.HasExited) { $compress.Kill($true); $compress.WaitForExit(); continue }
        Check "Frontend $($kind[0]) archive exists" (Test-Path $frontOutput)
        Run-App $seven @('t',$frontOutput)
        $frontUnpack = Join-Path $work "前端$($kind[0])校验"
        Run-App $seven @('x',$frontOutput,"-o$frontUnpack",'-y')
        $matching = @(Get-ChildItem $frontUnpack -Recurse -File | Where-Object Name -eq '中文 测试 & 文件.txt')
        Check "Frontend $($kind[0]) content and Unicode name" ($matching.Count -eq 1 -and (Get-FileHash $matching[0].FullName).Hash -eq (Get-FileHash (Join-Path $inputDir '中文 测试 & 文件.txt')).Hash)
    }
    # Exercise the same frontend extraction verb registered in Explorer.
    $frontDir = Join-Path $work '前端解压'
    New-Item -ItemType Directory -Force $frontDir | Out-Null
    $frontArchive = Join-Path $frontDir '实际右键.zip'
    Copy-Item (Join-Path $work '中文 压缩包.zip') $frontArchive
    $front = Start-App $app @('-ext2here',$frontArchive)
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    $frontFile = Join-Path $frontDir '中文 测试 & 文件.txt'
    while (-not (Test-Path $frontFile) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep 1 }
    Save-Screenshot 'frontend-extract.png'
    $frontOK = Test-Path $frontFile
    Check 'Frontend context extraction creates Unicode file' $frontOK -Soft
    $front.Refresh()
    if ($frontOK) {
        Check 'Frontend context extraction byte equality' ((Get-FileHash $frontFile).Hash -eq (Get-FileHash (Join-Path $inputDir '中文 测试 & 文件.txt')).Hash)
        if (-not $front.HasExited) { Close-Gui $front }
    } elseif (-not $front.HasExited) { $front.Kill($true); $front.WaitForExit() }
    # Upgrade/reinstall must preserve existing user preferences and succeed.
    $confHash = (Get-FileHash $conf).Hash
    Run-App $installer @('/SP-','/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$installDir",'/TASKS=desktopicon,contextmenu',"/LOG=$(Join-Path $evidence 'reinstall.log')")
    Check 'Reinstall preserves per-user configuration' ((Get-FileHash $conf).Hash -eq $confHash)
    Run-App (Join-Path $installDir 'unins000.exe') @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=$(Join-Path $evidence 'uninstall.log')")
    Start-Sleep 3
    Check 'Uninstall removes main executable' (-not (Test-Path $app))
    Check 'Uninstall removes desktop shortcut' (-not (Test-Path $shortcutPath))
    Check 'Uninstall removes Add/Remove Programs entry' (-not (Test-Path $uninstallKey))
    foreach ($entry in $registryChecks) {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($entry[0])
        Check "Uninstall cleans context entry $($entry[0])" ($null -eq $key)
        if ($key) { $key.Dispose() }
    }
    Check 'Uninstall preserves user settings intentionally' (Test-Path $conf)
    Check 'All acceptance checks passed' (-not @($results | Where-Object { -not $_.passed }).Count)
} catch {
    $_ | Out-String | Set-Content (Join-Path $evidence 'failure.txt') -Encoding utf8
    Save-Screenshot 'failure.png'
    throw
} finally {
    $results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $evidence 'acceptance-results.json') -Encoding utf8
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    @"
Automated environment: $os
This is a real Windows runner, not Linux emulation.
Automated checks do not replace Windows 10/11 interactive desktop QA.
Still required: manual install/cancel/UAC, Explorer multi-select and Windows 11 menus,
DPI 100/150/200%, standard-user GUI, drag/drop, RAR samples and large archives,
SmartScreen/reputation and independent security review. No protection was disabled.
"@ | Set-Content (Join-Path $evidence 'verification-boundaries.txt') -Encoding utf8
}
