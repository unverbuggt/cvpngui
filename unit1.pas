{
 * This file is part of CVPNGUI.
 *
 * CVPNGUI is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * CVPNGUI is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MyProject. If not, see <https://www.gnu.org/licenses/>.
}

unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Process, AsyncProcess, ExtCtrls, Menus, StrUtils, IniFiles, FileUtil,
  cvpnmod,
  {$IFDEF Windows}
  cvpnwin;
  {$ENDIF Windows}
  {$IFDEF Unix}
  cvpnlin;
  {$ENDIF Unix}


type
  { TForm1 }

  TForm1 = class(TForm)
    btCheck: TButton;
    btStartTinc: TButton;
    btSave: TButton;
    btStopTinc: TButton;
    cbTapAdapter: TComboBox;
    cbTincKey: TComboBox;
    cgCheck: TCheckGroup;
    ckAutostartTinc: TCheckBox;
    ckUpnp: TCheckBox;
    edIpAddress: TEdit;
    edTincPort: TEdit;
    lbTincPort: TLabel;
    lbTincKey: TLabel;
    lbIpAddress: TLabel;
    lbTapAdapter: TLabel;
    meAddTap: TMenuItem;
    meDelAllTap: TMenuItem;
    meSetManIp: TMenuItem;
    meTincLog: TMemo;
    pmTapAdapter: TPopupMenu;
    pmIpAddress: TPopupMenu;
    meTapAdapterSep: TMenuItem;
    meIpAddressSep: TMenuItem;
    procedure btCheckClick(Sender: TObject);
    procedure btSaveClick(Sender: TObject);
    procedure btStartTincClick(Sender: TObject);
    procedure btStopTincClick(Sender: TObject);
    procedure cbTapAdapterChange(Sender: TObject);
    procedure cbTincKeyChange(Sender: TObject);
    procedure ckAutostartTincChange(Sender: TObject);
    procedure ckUpnpChange(Sender: TObject);
    procedure edIpAddressChange(Sender: TObject);
    procedure edTincPortChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure lbTincPortClick(Sender: TObject);
    procedure meAddTapClick(Sender: TObject);
    procedure meDelAllTapClick(Sender: TObject);
    {$IFDEF Windows}
    procedure OpenNC(Sender: TObject);
    procedure OpenNSC(Sender: TObject);
    {$ENDIF Windows}
    procedure meSetManIpClick(Sender: TObject);
    procedure Panel1Click(Sender: TObject);
    procedure ProcessOutput(Sender: TObject);
    procedure ReadConfig();
    procedure WriteConfig();
    procedure CheckConfiguration();
    procedure StartTincd();
    procedure StopTincd();
  private
    AProcess: TAsyncProcess;
    OutputLine: String;
    ConfigFile: String;
    GeneralConfig: GeneralConfigurationType;
    TapConfig: TapConfigurationType;
    TincConfig: TincConfigurationType;
    TapIps: array of String;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.ReadConfig();
var
  Ini: TIniFile;
  FileList: TStringList;
  i : Integer;
begin
  Ini := TIniFile.Create(ConfigFile);
  try
    GeneralConfig.Name := Ini.ReadString('General', 'Name', 'coronavpn');
    GeneralConfig.Network := Ini.ReadString('General', 'Network', '192.168.235.0/24');

    TapConfig.FriendlyName := Ini.ReadString('TapAdapter', 'FriendlyName', '');
    TapConfig.IpAddress := Ini.ReadString('TapAdapter', 'IpAddress', '');

    TincConfig.Name := Ini.ReadString('Tinc', 'Name', '');
    TincConfig.KeyFile := Ini.ReadString('Tinc', 'KeyFile', '');
    TincConfig.Port := Ini.ReadString('Tinc', 'Port', '655');
    TincConfig.UPnP := Ini.ReadBool('Tinc', 'UPnP', True);
    TincConfig.Autostart := Ini.ReadBool('Tinc', 'Autostart', False);

    cbTincKey.Text := TincConfig.Name;
    ckUpnp.Checked := TincConfig.UPnP;
    edTincPort.Text := TincConfig.Port;
    ckAutostartTinc.Checked := TincConfig.Autostart;

    edIpAddress.Text := TapConfig.IpAddress;
    cbTapAdapter.Text := TapConfig.FriendlyName;

    //Tinc
    cbTincKey.Items.Clear;
    {$IFDEF Windows}
    FileList := FindAllFiles(GeneralConfig.Name + '\keys\', '*.key', false);
    {$ENDIF Windows}
    {$IFDEF Unix}
    FileList := FindAllFiles(GeneralConfig.Name + '/keys/', '*.key', false);
    {$ENDIF Unix}
    for i := 0 to FileList.Count - 1 do
      cbTincKey.Items.Add(ChangeFileExt(ExtractFileName(FileList[i]), ''));

  finally
    Ini.Free;
  end;
end;

procedure TForm1.WriteConfig();
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ConfigFile);
  try
    Ini.WriteString('General', 'Name', GeneralConfig.Name);
    Ini.WriteString('General', 'Network', GeneralConfig.Network);

    Ini.WriteString('TapAdapter', 'FriendlyName', TapConfig.FriendlyName);
    Ini.WriteString('TapAdapter', 'IpAddress', TapConfig.IpAddress);

    Ini.WriteString('Tinc', 'Name', TincConfig.Name);
    Ini.WriteString('Tinc', 'KeyFile', TincConfig.KeyFile);
    Ini.WriteString('Tinc', 'Port', TincConfig.Port);
    Ini.WriteBool('Tinc', 'UPnP', TincConfig.UPnP);
    Ini.WriteBool('Tinc', 'Autostart', TincConfig.Autostart);
  finally
    Ini.Free;
  end;
end;

procedure TForm1.CheckConfiguration();
var
  TapErr : CheckTapResult;
  i : Integer;
begin
  //Tap
  TapErr := CheckTAP(GeneralConfig, TapConfig);
  cgCheck.Checked[0] := not (TapErr.errApi or TapErr.errNoTAP); //TAP Adapter installiert?
  cgCheck.Checked[1] := not TapErr.errWrongNet; //richtiges Netzwerk?
  cgCheck.Checked[2] := not TapErr.errWrongIP; //richtige IP Adresse?

  cbTapAdapter.Items.Clear;
  FreeStringArray(TapIps);
  if Length(TapErr.TapAdapters) > 0 then begin
    for i := 0 to High(TapErr.TapAdapters) do begin
      cbTapAdapter.Items.Add(TapErr.TapAdapters[i].FriendlyName);
      if Length(TapErr.TapAdapters[i].TapIpAddresses) > 0 then begin
        AddToStringArray(TapIps, TapErr.TapAdapters[i].TapIpAddresses[0]);
      end else begin
        AddToStringArray(TapIps, 'dhcp');
      end;
    end;
    if TapErr.TapIndex >= 0 then begin
      cbTapAdapter.ItemIndex := TapErr.TapIndex;
      cbTapAdapterChange(nil);
    end;
  end;
  FreeTapAdapters(TapErr.TapAdapters);

  {$IFDEF Windows}
  cgCheck.Checked[3] := FileExists(GeneralConfig.Name + '\' + TincConfig.KeyFile); //Schlüssel gefunden?
  {$ENDIF Windows}
  {$IFDEF Unix}
  cgCheck.Checked[3] := FileExists(GeneralConfig.Name + '/' + TincConfig.KeyFile); //Schlüssel gefunden?
  {$ENDIF Unix}
  if not (TapErr.errApi or TapErr.errNoTAP or TapErr.errWrongNet or TapErr.errWrongIP) then begin
    btStartTinc.Enabled := True;
    btStopTinc.Enabled := True;
  end;
end;

procedure TForm1.StartTincd();
begin
  if not Assigned(AProcess) then begin
    meTincLog.Lines.Add('starte Tinc...');
    AProcess := TAsyncProcess.Create(nil);

    {$IFDEF Windows}
    AProcess.CurrentDirectory := 'tinc';
    AProcess.Executable := 'tinc\tincd.exe';
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add('..\coronavpn');
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('Interface=' + TapConfig.FriendlyName);
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('Name=' + TincConfig.Name);
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('Ed25519PrivateKeyFile=' + TincConfig.KeyFile);
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('BindToAddress=* ' + TincConfig.Port);
    if TincConfig.UPnP then begin
      AProcess.Parameters.Add('-o');
      AProcess.Parameters.Add('UPnP=yes');
    end else begin
      AProcess.Parameters.Add('-o');
      AProcess.Parameters.Add('UPnP=no');
    end;
    AProcess.Parameters.Add('-D');
    AProcess.ShowWindow := swoHIDE;
    AProcess.Options := [poUsePipes, poStderrToOutPut, poDetached];
    {$ENDIF Windows}
    {$IFDEF Unix}
    AProcess.Executable := FindDefaultExecutablePath('tincd');
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add('./coronavpn');
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('Device=/dev/net/tun');
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('Interface=' + TapConfig.FriendlyName);
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('Name=' + TincConfig.Name);
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('Ed25519PrivateKeyFile=' + TincConfig.KeyFile);
    AProcess.Parameters.Add('-o');
    AProcess.Parameters.Add('BindToAddress=* ' + TincConfig.Port);
    if TincConfig.UPnP then begin
      AProcess.Parameters.Add('-o');
      AProcess.Parameters.Add('UPnP=yes');
    end else begin
      AProcess.Parameters.Add('-o');
      AProcess.Parameters.Add('UPnP=no');
    end;
    AProcess.Parameters.Add('-D');
    AProcess.Options := [poUsePipes, poStderrToOutPut];
    {$ENDIF Unix}

    AProcess.OnReadData := @ProcessOutput;
    AProcess.Execute;
    Sleep(500);
    ProcessOutput(nil);
  end;
end;

procedure TForm1.StopTincd();
begin
  if Assigned(AProcess) then begin
    meTincLog.Lines.Add('stoppe Tinc...');
    AProcess.Terminate(0);
    FreeAndNil(AProcess);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
{$IFDEF Windows}
var
  meOpenNC: TMenuItem;
  meOpenNSC: TMenuItem;
{$ENDIF Windows}
begin
  GetNetwork('192.168.235.164/24');
  ConfigFile := ChangeFileExt(ExtractFileName(ParamStr(0)), '.ini');
  ReadConfig();
  CheckConfiguration();
  {$IFDEF Unix}
  if FindDefaultExecutablePath('tincd') = '' then
    meTincLog.Lines.Add('Tinc nicht gefunden');
  {$ENDIF Unix}
  {$IFDEF Windows}
  if not FileExists('tinc\tincd.exe') then
    meTincLog.Lines.Add('Tinc nicht gefunden');
  meTapAdapterSep.Visible:=True;
  meOpenNC := TMenuItem.Create(pmTapAdapter);
  meOpenNC.Caption := 'Öffne Netzwerkverbindung';
  meOpenNC.OnClick := @OpenNC;
  pmTapAdapter.Items.Add(meOpenNC);
  meOpenNSC := TMenuItem.Create(pmTapAdapter);
  meOpenNSC.Caption := 'Öffne Netzwerk- und Freigabecenter';
  meOpenNSC.OnClick := @OpenNSC;
  pmTapAdapter.Items.Add(meOpenNSC);
  {$ENDIF Windows}
  if TincConfig.Autostart and cgCheck.Checked[0] and cgCheck.Checked[1]
     and cgCheck.Checked[2] and cgCheck.Checked[3] then begin
    StartTincd();
  end;
end;

procedure TForm1.cbTapAdapterChange(Sender: TObject);
begin
  if (cbTapAdapter.ItemIndex >= 0) and (Length(TapIps) > 0)
     and (Length(TapIps) = cbTapAdapter.Items.Count) then begin
    edIpAddress.Text := TapIps[cbTapAdapter.ItemIndex];
  end;
  TapConfig.FriendlyName := cbTapAdapter.Text;
  TapConfig.IpAddress := edIpAddress.Text;
end;

procedure TForm1.cbTincKeyChange(Sender: TObject);
begin
  TincConfig.Name := cbTincKey.Text;
  {$IFDEF Windows}
  TincConfig.KeyFile := 'keys\' + cbTincKey.Text + '.key';
  {$ENDIF Windows}
  {$IFDEF Unix}
  TincConfig.KeyFile := 'keys/' + cbTincKey.Text + '.key';
  {$ENDIF Unix}
  CheckConfiguration();
end;

procedure TForm1.ckAutostartTincChange(Sender: TObject);
begin
   TincConfig.Autostart  := ckAutostartTinc.Checked;
end;

procedure TForm1.ckUpnpChange(Sender: TObject);
begin
  TincConfig.UPnP := ckUpnp.Checked;
end;

procedure TForm1.edIpAddressChange(Sender: TObject);
begin
  TapConfig.IpAddress := edIpAddress.Text;
end;

procedure TForm1.edTincPortChange(Sender: TObject);
begin
  TincConfig.Port := edTincPort.Text;
end;

procedure TForm1.btCheckClick(Sender: TObject);
begin
  CheckConfiguration();
end;

procedure TForm1.btSaveClick(Sender: TObject);
begin
  WriteConfig();
end;

procedure TForm1.btStartTincClick(Sender: TObject);
begin
  StartTincd();
end;

procedure TForm1.btStopTincClick(Sender: TObject);
begin
  StopTincd();
end;

procedure TForm1.ProcessOutput(Sender: TObject);
var
  sBuffer: string;
  BytesRead: LongInt;
begin
  if Assigned(AProcess) and (AProcess.Output.NumBytesAvailable > 0) then begin
    setLength(sBuffer, AProcess.Output.NumBytesAvailable);
    BytesRead := AProcess.Output.Read(sBuffer[1], Length(sBuffer));
    OutputLine := OutputLine + sBuffer;
    if EndsText(LineEnding, OutputLine) then begin
      RemovePadChars(OutputLine, [#10, #13]);
      meTincLog.Lines.Add(OutputLine);
      OutputLine := '';
    end;
  end;
  if not AProcess.Running then begin
    if OutputLine <> '' then
       meTincLog.Lines.Add(OutputLine);
    meTincLog.Lines.Add('Tinc läuft nicht mehr...');
    FreeAndNil(AProcess);
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  StopTincd();
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  meTincLog.ScaleDesignToForm(0);
end;

procedure TForm1.lbTincPortClick(Sender: TObject);
begin

end;

procedure TForm1.meAddTapClick(Sender: TObject);
var
  s: String;
  cmd: String;
begin
  {$IFDEF Windows}
  RunAsAdmin(Form1.Handle, 'tap-win64\addtap.bat', '');
  Sleep(1000);
  {$ENDIF Windows}
  {$IFDEF Unix}
  cmd := 'sudo ip tuntap add dev ' + TapConfig.FriendlyName + ' mode tap user $USER;';
  cmd := cmd + 'sudo ip addr add ' + TapConfig.IpAddress + ' dev ' + TapConfig.FriendlyName + '; ';
  cmd := cmd + 'sudo ip link set ' + TapConfig.FriendlyName + ' up; ';
  RunCommand('x-terminal-emulator', ['-e', 'bash', '-c', cmd], s);
  {$ENDIF Unix}
  CheckConfiguration();
end;

procedure TForm1.meDelAllTapClick(Sender: TObject);
var
  s: String;
  i: Integer;
begin
  {$IFDEF Windows}
  RunAsAdmin(Form1.Handle, 'tap-win64\deltapall.bat', '');
  Sleep(1000);
  {$ENDIF Windows}
  {$IFDEF Unix}
  for i := 1 to cbTapAdapter.Items.Count do
    RunCommand('/usr/sbin/ip', ['tuntap','delete',cbTapAdapter.Items[i-1], 'mode', 'tap'], s);
  {$ENDIF Unix}
  CheckConfiguration();
end;
{$IFDEF Windows}
procedure TForm1.OpenNC(Sender: TObject);
var
  s: string;
begin
  RunCommand('control',['netconnections'],s);
end;

procedure TForm1.OpenNSC(Sender: TObject);
var
  s: string;
begin
  RunCommand('control',['/name','Microsoft.NetworkAndSharingCenter'],s);
end;
{$ENDIF Windows}
procedure TForm1.meSetManIpClick(Sender: TObject);
var
  {$IFDEF Windows}
  Ip: array of String;
  Subnet : String;
  Gateway : String;
  Parameters: String;
  {$ENDIF Windows}
  {$IFDEF Unix}
  s: String;
  cmd: String;
  {$ENDIF Unix}
begin
  {$IFDEF Windows}
  Ip := SplitString(TapConfig.IpAddress, '/');
  Subnet := CIDRToSubnetMask(Ip[1]);
  Gateway := GetFirstAddress(GeneralConfig.Network);
  Parameters :=  'interface ipv4 set address name="' + cbTapAdapter.Text + '"'
             + ' static ' + Ip[0] + ' ' + Subnet + ' ' + Gateway;
  RunAsAdmin(Form1.Handle, 'netsh', Parameters);
  Sleep(1000);
  {$ENDIF Windows}
  {$IFDEF Unix}
  cmd := 'sudo ip addr add ' + TapConfig.IpAddress + ' dev ' + TapConfig.FriendlyName + '; ';
  cmd := cmd + 'sudo ip link set ' + TapConfig.FriendlyName + ' up; ';
  RunCommand('x-terminal-emulator', ['-e', 'bash', '-c', cmd], s);
  {$ENDIF Unix}
  CheckConfiguration();
end;

procedure TForm1.Panel1Click(Sender: TObject);
begin

end;

end.

