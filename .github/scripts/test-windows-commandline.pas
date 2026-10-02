program test_windows_commandline;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, windows_commandline;
var inspection, command, original: AnsiString; checks: Integer;
procedure Check(const name: AnsiString; condition: Boolean);
begin
  if not condition then begin WriteLn('FAIL: ',name); Halt(1); end;
  Inc(checks); WriteLn('PASS: ',name);
end;
function Accepted(const value: AnsiString): Boolean;
var masked: AnsiString;
begin
  if not InspectQuotedWindows7Zip(value,masked) then masked:=value;
  Result:=not HasWindowsConsoleMetacharacters(masked);
end;
begin
  checks:=0;
  command:='"C:\Program Files\西美压缩\res\bin\7z\7z.exe" a "C:\资料 & 备份\中文.zip" "C:\输入\*"';
  original:=command;
  Check('quoted Chinese path is recognized',InspectQuotedWindows7Zip(command,inspection));
  Check('quoted ampersand is data for direct 7z',Accepted(command));
  Check('original command is not changed',command=original);
  Check('console still rejects ampersand paths',HasWindowsConsoleMetacharacters(command));
  Check('unquoted command chaining remains rejected',not Accepted(command+' & calc.exe'));
  Check('unquoted pipe remains rejected',not Accepted(command+' | cmd.exe'));
  Check('unquoted output redirect remains rejected',not Accepted(command+' > file.txt'));
  Check('unquoted semicolon remains rejected',not Accepted(command+' ; command'));
  Check('unmatched quotes remain rejected',not Accepted('"C:\7z.exe" a "input & command'));
  Check('newline remains rejected',not Accepted(command+#10+'calc.exe'));
  Check('shell wrapper is not exempt',not InspectQuotedWindows7Zip('"C:\Windows\System32\cmd.exe" /c "a & b"',inspection));
  Check('shell wrapper remains rejected',not Accepted('"C:\Windows\System32\cmd.exe" /c "a & b"'));
  Check('relative executable is not exempt',not InspectQuotedWindows7Zip('"7z.exe" a "a & b"',inspection));
  Check('executable suffix spoof is not exempt',not InspectQuotedWindows7Zip('"C:\7z.exe.cmd" a "a & b"',inspection));
  Check('arguments must be separated',not InspectQuotedWindows7Zip('"C:\7z.exe"a "a & b"',inspection));
  Check('UNC 7z path is recognized',InspectQuotedWindows7Zip('"\\server\share\7z.exe" a "a & b"',inspection));
  WriteLn('Windows command inspection checks passed: ',checks);
end.
