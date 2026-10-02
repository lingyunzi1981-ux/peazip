unit windows_commandline;
{$mode objfpc}{$H+}
interface

// Inspection only: never modifies the command that is actually executed.
// Applies exclusively to a quoted, absolute 7z.exe launched directly by TProcess.
function InspectQuotedWindows7Zip(const command: AnsiString; out inspection: AnsiString): Boolean;
function HasWindowsConsoleMetacharacters(const command: AnsiString): Boolean;

implementation
uses SysUtils;

function InspectQuotedWindows7Zip(const command: AnsiString; out inspection: AnsiString): Boolean;
var
  i, closing, separator: Integer;
  executable, masked: AnsiString;
  quoted, absolute: Boolean;
begin
  Result := False;
  inspection := command;
  if (Length(command) < 3) or (command[1] <> '"') then Exit;
  closing := 2;
  while (closing <= Length(command)) and (command[closing] <> '"') do Inc(closing);
  if closing > Length(command) then Exit;
  executable := Copy(command, 2, closing - 2);
  absolute := False;
  if Length(executable) >= 3 then
    absolute := ((executable[1] in ['A'..'Z', 'a'..'z']) and
                 (executable[2] = ':') and (executable[3] = '\')) or
                (Copy(executable, 1, 2) = '\\');
  if not absolute then Exit;
  separator := LastDelimiter('\', executable);
  if LowerCase(Copy(executable, separator + 1, Length(executable))) <> '7z.exe' then Exit;
  if (closing < Length(command)) and (command[closing + 1] <> ' ') then Exit;
  masked := command;
  quoted := False;
  for i := 1 to Length(command) do
  begin
    if Ord(command[i]) < 32 then Exit;
    if command[i] = '"' then quoted := not quoted
    else if quoted then masked[i] := '_';
  end;
  if quoted then Exit; // unmatched quotes: retain the original strict checks
  inspection := masked;
  Result := True;
end;

function HasWindowsConsoleMetacharacters(const command: AnsiString): Boolean;
var i: Integer;
begin
  Result := True;
  for i := 1 to Length(command) do
    if (Ord(command[i]) < 32) or (command[i] in ['|','&',';','<','>','`','$','~']) then Exit;
  Result := False;
end;
end.
