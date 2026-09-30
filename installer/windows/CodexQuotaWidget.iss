#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef VersionNumber
  #define VersionNumber AppVersion
#endif
#ifndef PayloadDir
  #error PayloadDir must point to the staged Windows payload.
#endif
#ifndef OutputDirectory
  #error OutputDirectory must be outside the source repository.
#endif

[Setup]
AppId={{6C18E026-7B2A-4E77-A3B3-1F453AE4D96B}
AppName=Codex Quota Widget
AppVersion={#AppVersion}
VersionInfoVersion={#VersionNumber}
AppPublisher=AjiaGit
AppPublisherURL=https://github.com/AjiaGit
DefaultDirName={localappdata}\Programs\CodexQuotaWidget
DefaultGroupName=Codex Quota Widget
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
UninstallDisplayIcon={app}\CodexQuotaWidget.exe
SetupIconFile={#PayloadDir}\CodexQuota.ico
LicenseFile={#PayloadDir}\LICENSE
OutputDir={#OutputDirectory}
OutputBaseFilename=CodexQuotaWidget-{#AppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=no
RestartApplications=no
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
#ifdef ChineseMessages
Name: "chinesesimplified"; MessagesFile: "{#ChineseMessages}"
#endif

[CustomMessages]
english.OptionsGroup=Additional options:
english.DesktopIcon=Create a desktop shortcut
english.AutoStart=Start Codex Quota Widget when I sign in
english.LaunchWidget=Open Codex Quota Widget
english.StopFailed=Codex Quota Widget could not stop its owned processes. Close the widget and try again.
#ifdef ChineseMessages
chinesesimplified.OptionsGroup=其他选项：
chinesesimplified.DesktopIcon=创建桌面快捷方式
chinesesimplified.AutoStart=登录 Windows 时启动 Codex 周额度
chinesesimplified.LaunchWidget=打开 Codex 周额度
chinesesimplified.StopFailed=未能停止本工具的进程，请关闭悬浮窗后重试。
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; GroupDescription: "{cm:OptionsGroup}"; Flags: unchecked
Name: "autostart"; Description: "{cm:AutoStart}"; GroupDescription: "{cm:OptionsGroup}"; Flags: unchecked

[Files]
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Codex Quota Widget"; Filename: "{app}\CodexQuotaWidget.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Codex Quota Widget"; Filename: "{app}\CodexQuotaWidget.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "CodexQuotaWidget"; ValueData: """{app}\CodexQuotaWidget.exe"""; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\CodexQuotaWidget.exe"; Description: "{cm:LaunchWidget}"; Flags: nowait postinstall skipifsilent

[Code]
function StopOwnedWidget(const InstallDirectory: String): Boolean;
var
  ResultCode: Integer;
  ScriptPath: String;
begin
  ScriptPath := AddBackslash(InstallDirectory) + 'Stop.ps1';
  if not FileExists(ScriptPath) then begin
    Result := True;
    Exit;
  end;
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + ScriptPath + '" -Quiet',
    InstallDirectory, SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if not StopOwnedWidget(ExpandConstant('{app}')) then
    Result := CustomMessage('StopFailed');
end;

function InitializeUninstall(): Boolean;
begin
  Result := StopOwnedWidget(ExpandConstant('{app}'));
  if not Result then
    MsgBox(CustomMessage('StopFailed'), mbError, MB_OK);
end;

// User preferences under LOCALAPPDATA\CodexWeeklyMonitor are preserved.
// Explicit removal is available through Stop.ps1 -RemovePreferences.
