# Run with PowerShell 7: UTF-8 source and Unicode process arguments end-to-end.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$brand = '西美压缩'
$version = '11.3.0.1'
$stage = Join-Path $env:RUNNER_TEMP 'WestBeautyRuntime'
$evidence = Join-Path $env:RUNNER_TEMP 'westbeauty-evidence'
$delivery = Join-Path $env:RUNNER_TEMP 'delivery'
New-Item -ItemType Directory -Force $stage,$evidence,$delivery | Out-Null
$portable = Join-Path $env:RUNNER_TEMP 'peazip-portable-11.3.0.zip'
$portableHash = '3fb15b9852c94ba5ee8d1af5568fad0cad0999854225b4432b9c98b315a4f768'
Invoke-WebRequest 'https://github.com/peazip/PeaZip/releases/download/11.3.0/peazip_portable-11.3.0.WIN64.zip' -OutFile $portable
if ((Get-FileHash $portable -Algorithm SHA256).Hash -ne $portableHash) { throw 'Official runtime SHA256 mismatch' }
$expanded = Join-Path $env:RUNNER_TEMP 'peazip-runtime'
Expand-Archive $portable $expanded -Force
Copy-Item (Join-Path $expanded 'peazip_portable-11.3.0.WIN64\*') $stage -Recurse -Force
# An installed app must use the user's writable AppData, never Program Files.
Remove-Item (Join-Path $stage 'res\portable') -Force
# Keep source-version language/help resources aligned with the freshly built GUI.
Copy-Item 'peazip-sources\res\share\*' (Join-Path $stage 'res\share') -Recurse -Force
foreach ($name in @('peazip.exe','pea.exe')) {
    $candidates = @(Get-ChildItem 'peazip-sources\dev' -Recurse -File -Filter $name)
    if ($candidates.Count -ne 1) { throw "Expected exactly one freshly built $name; found $($candidates.Count)" }
    Copy-Item $candidates[0].FullName (Join-Path $stage $name) -Force
}
# Retain PeaZip's integrity checks for the rebuilt PEA helper. Embed its exact
# build hash into the GUI instead of allowing all files or disabling checks.
$peaHash = (Get-FileHash (Join-Path $stage 'pea.exe') -Algorithm SHA256).Hash
$hashSource = (Resolve-Path 'peazip-sources/dev/externalprograms.pas').Path
$hashText = [IO.File]::ReadAllText($hashSource)
$pattern = "(HPEA_WIN64_X\s*=\s*')[A-Fa-f0-9]{64}(')"
if ([regex]::Matches($hashText,$pattern).Count -ne 1) { throw 'PEA integrity constant was not found exactly once' }
$hashText = [regex]::Replace($hashText,$pattern,('${1}' + $peaHash + '${2}'))
[IO.File]::WriteAllText($hashSource,$hashText,[Text.UTF8Encoding]::new($false))
& 'C:\Lazarus\lazbuild.exe' --build-all --recursive --no-write-project 'peazip-sources/dev/project_peach.lpi'
if ($LASTEXITCODE -ne 0) { throw 'GUI rebuild with exact PEA hash failed' }
$gui = @(Get-ChildItem 'peazip-sources\dev' -Recurse -File -Filter 'peazip.exe')
if ($gui.Count -ne 1) { throw 'GUI rebuild output is ambiguous' }
Copy-Item $gui[0].FullName (Join-Path $stage 'peazip.exe') -Force
# Verify upstream DLL guards still match the packaged binaries.
foreach ($item in @(
    @('H7Z_WIN64_X','res\bin\7z\7z.exe'),
    @('H7ZDLL_WIN64_X','res\bin\7z\7z.dll'),
    @('HDDDLL_WIN64_X','dragdropfilesdll.dll')
)) {
    $match = [regex]::Match($hashText,($item[0] + "\s*=\s*'([A-Fa-f0-9]{64})'"))
    if (-not $match.Success -or (Get-FileHash (Join-Path $stage $item[1])).Hash -ne $match.Groups[1].Value) { throw "Runtime integrity guard mismatch: $($item[1])" }
}
Copy-Item $hashSource (Join-Path $evidence 'build-generated-externalprograms.pas')
choco install imagemagick.app rcedit innosetup -y --no-progress
if ($LASTEXITCODE -ne 0) { throw 'Build-tool installation failed' }
$icon = Join-Path $stage 'WestBeautyCompression.ico'
& magick -background none '.github/branding/westbeauty-compression.svg' -define icon:auto-resize=256,128,64,48,32,16 $icon
if ($LASTEXITCODE -ne 0) { throw 'Brand icon generation failed' }
& rcedit (Join-Path $stage 'peazip.exe') --set-icon $icon --set-version-string ProductName $brand --set-version-string FileDescription "$brand - 文件与压缩管理器" --set-file-version $version --set-product-version $version
if ($LASTEXITCODE -ne 0) { throw 'Executable resource branding failed' }
Copy-Item (Join-Path $stage 'peazip.exe') (Join-Path $stage "$brand.exe")
Copy-Item 'LICENSE' (Join-Path $stage 'LICENSE.txt')
@"
西美压缩 $version
基于 PeaZip 11.3.0，保留原开源版权和许可。
完整对应源码：https://github.com/$env:GITHUB_REPOSITORY/tree/$env:GITHUB_SHA
7-Zip 等随附组件的许可见 res\share\copying。
本构建未进行商业代码签名；Windows 可能显示未知发布者或 SmartScreen 提示。
此包不能据此宣称已通过所有 Windows 10/11 桌面验收。
"@ | Set-Content (Join-Path $stage '西美压缩-说明.txt') -Encoding utf8BOM
# Vendor-maintained complete translation, checked into this repository with attribution.
$lang = (Resolve-Path '.github/workflows/ChineseSimplified.isl').Path
$license = (Resolve-Path 'LICENSE').Path
$iss = Join-Path $env:RUNNER_TEMP 'westbeauty.iss'
$script = @"
[Setup]
AppId={{7F79973A-49E8-4B57-A2D9-575754424731}
AppName=$brand
AppVerName=$brand $version
AppVersion=$version
AppPublisher=West Beauty Group
DefaultDirName={autopf}\West Beauty Compression
DefaultGroupName=$brand
UninstallDisplayName=$brand
UninstallDisplayIcon={app}\$brand.exe
SetupIconFile=$icon
OutputDir=$delivery
OutputBaseFilename=WestBeautyCompression-Setup-x64
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
PrivilegesRequired=admin
DisableDirPage=no
DisableProgramGroupPage=yes
ChangesAssociations=yes
CloseApplications=yes
RestartApplications=no
LicenseFile=$license

[Languages]
Name: "chinesesimp"; MessagesFile: "$lang"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加选项："; Flags: checkedonce
Name: "contextmenu"; Description: "添加压缩和解压到 Windows 右键菜单"; GroupDescription: "附加选项："; Flags: checkedonce

[Files]
Source: "$stage\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{app}\res\portable"

[Icons]
Name: "{group}\$brand"; Filename: "{app}\$brand.exe"
Name: "{group}\卸载 $brand"; Filename: "{uninstallexe}"
Name: "{autodesktop}\$brand"; Filename: "{app}\$brand.exe"; Tasks: desktopicon

[Registry]
"@
# Do not hijack default associations or UserChoice; add explicit Open With choices.
foreach ($root in @('*','Directory')) {
    foreach ($entry in @(
        @('WestBeautyCompress', "$brand - 添加到压缩文件...", '-add2archive'),
        @('WestBeautyZip', "$brand - 压缩为 ZIP", '-add2zip'),
        @('WestBeauty7z', "$brand - 压缩为 7Z", '-add27z')
    )) {
        $key = "$root\shell\$($entry[0])"
        $script += "`nRoot: HKLM; Subkey: `"Software\Classes\$key`"; ValueType: string; ValueName: `"`"; ValueData: `"$($entry[1])`"; Flags: uninsdeletekey; Tasks: contextmenu"
        $script += "`nRoot: HKLM; Subkey: `"Software\Classes\$key`"; ValueType: string; ValueName: `"Icon`"; ValueData: `"{app}\$brand.exe`"; Tasks: contextmenu"
        $script += "`nRoot: HKLM; Subkey: `"Software\Classes\$key\command`"; ValueType: string; ValueName: `"`"; ValueData: `"`"`"{app}\$brand.exe`"`" $($entry[2]) `"`"%1`"`"`"; Tasks: contextmenu"
    }
}
foreach ($extension in @('.7z','.zip','.rar','.tar','.gz','.bz2','.xz','.zst','.cab','.iso','.wim','.pea')) {
    $key = "Software\Classes\SystemFileAssociations\$extension\shell"
    foreach ($entry in @(
        @('WestBeautyOpen', "用$brand打开", '-ext2openasarchive'),
        @('WestBeautyExtract', "$brand - 解压到当前文件夹", '-ext2here'),
        @('WestBeautyExtractFolder', "$brand - 解压到新文件夹", '-ext2newfolder')
    )) {
        $script += "`nRoot: HKLM; Subkey: `"$key\$($entry[0])`"; ValueType: string; ValueName: `"`"; ValueData: `"$($entry[1])`"; Flags: uninsdeletekey; Tasks: contextmenu"
        $script += "`nRoot: HKLM; Subkey: `"$key\$($entry[0])`"; ValueType: string; ValueName: `"Icon`"; ValueData: `"{app}\$brand.exe`"; Tasks: contextmenu"
        $script += "`nRoot: HKLM; Subkey: `"$key\$($entry[0])\command`"; ValueType: string; ValueName: `"`"; ValueData: `"`"`"{app}\$brand.exe`"`" $($entry[2]) `"`"%1`"`"`"; Tasks: contextmenu"
    }
    $script += "`nRoot: HKLM; Subkey: `"Software\Classes\$extension\OpenWithProgids`"; ValueType: string; ValueName: `"WestBeautyCompression.Archive`"; ValueData: `"`"; Flags: uninsdeletevalue; Tasks: contextmenu"
}
$script += @"

Root: HKLM; Subkey: "Software\Classes\WestBeautyCompression.Archive"; ValueType: string; ValueName: ""; ValueData: "$brand 压缩文件"; Flags: uninsdeletekey; Tasks: contextmenu
Root: HKLM; Subkey: "Software\Classes\WestBeautyCompression.Archive\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\$brand.exe,0"; Tasks: contextmenu
Root: HKLM; Subkey: "Software\Classes\WestBeautyCompression.Archive\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\$brand.exe"" -ext2openasarchive ""%1"""; Tasks: contextmenu

[Run]
Filename: "{app}\$brand.exe"; Description: "运行 $brand"; Flags: nowait postinstall skipifsilent
"@
# UTF-8 with BOM is unambiguous on every supported Inno Setup 6 compiler.
[IO.File]::WriteAllText($iss, $script, [Text.UTF8Encoding]::new($true))
foreach ($text in @("AppName=$brand", "{group}\$brand", "用$brand打开", '解压到当前文件夹')) {
    if (-not [IO.File]::ReadAllText($iss).Contains($text)) { throw "Unicode source check failed: $text" }
}
Copy-Item $iss,$lang $evidence
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
& $iscc $iss 2>&1 | Tee-Object (Join-Path $evidence 'installer-compile.log')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed' }
$installer = Join-Path $delivery 'WestBeautyCompression-Setup-x64.exe'
if ((Get-Item $installer).Length -lt 10000000) { throw 'Installer payload unexpectedly small' }
$hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  WestBeautyCompression-Setup-x64.exe" | Set-Content (Join-Path $delivery 'SHA256SUMS.txt') -Encoding ascii
@{ version=$version; commit=$env:GITHUB_SHA; source="https://github.com/$env:GITHUB_REPOSITORY/tree/$env:GITHUB_SHA"; runtime_sha256=$portableHash; pea_sha256=$peaHash; installer_sha256=$hash; authenticode=(Get-AuthenticodeSignature $installer).Status.ToString(); os=(Get-CimInstance Win32_OperatingSystem).Caption; powershell=$PSVersionTable.PSVersion.ToString() } | ConvertTo-Json | Set-Content (Join-Path $evidence 'build-manifest.json') -Encoding utf8
