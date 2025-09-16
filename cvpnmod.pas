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
 * along with CVPNGUI. If not, see <https://www.gnu.org/licenses/>.
}

unit cvpnmod;

interface

uses
    StrUtils, SysUtils;

type
  GeneralConfigurationType = record
    Name: String;
    Network: String;
  end;

  TapConfigurationType = record
    FriendlyName: String;
    IpAddress: String;
  end;

  TincConfigurationType = record
    Name: String;
    KeyFile: String;
    Port: String;
    UPnP: Boolean;
    Autostart: Boolean;
  end;

  TapAdapter = record
    Description: String;
    FriendlyName: String;
    TapIpAddresses: Array of String;
    TapGatewayAddresses: Array of String;
  end;


  CheckTapResult = record
    errApi: Boolean;
    errNoTAP: Boolean;
    errWrongName: Boolean;
    errWrongNet: Boolean;
    errWrongIP: Boolean;
    TapIndex: Integer;
    TapAdapters: array of TapAdapter;
  end;

  TStringArray = array of String;
  TTapAdapters = array of TapAdapter;

  function StartsWith(const s, prefix: string): Boolean;
  function ReadTestFile(path: string): String;
  procedure AddToStringArray(var Arr: TStringArray; const Value: String);
  procedure FreeStringArray(var Arr: TStringArray);
  procedure AddToTapAdapters(var Arr: TTapAdapters; const Value: TapAdapter);
  procedure FreeTapAdapters(var Arr: TTapAdapters);

  function CIDRToSubnetMask(const cidr: String): String;
  function SubnetMaskToCIDR(const SubnetMask: string): String;
  function GetNetwork(const CidrIp: String): String;
  function GetFirstAddress(const CidrIp: String): String;

implementation

function StartsWith(const s, prefix: string): Boolean;
begin
  Result := Copy(s, 1, Length(prefix)) = prefix;
end;

function ReadTestFile(path: string): String;
var
  f: TextFile;
begin
  AssignFile(f, path);
  {$I-}
  Reset(f);
  {$I+}
  if IOResult <> 0 then begin
    result := '';
    Exit;
  end;
  ReadLn(f, result);
  CloseFile(f);
end;

procedure AddToStringArray(var Arr: TStringArray; const Value: String);
var
  len: Integer;
begin
  len := Length(Arr);
  SetLength(Arr, len + 1);
  Arr[len] := Value;
end;

procedure FreeStringArray(var Arr: TStringArray);
var
  i: Integer;
begin
  for i := 0 to High(Arr) do
    Arr[i] := '';
  SetLength(Arr, 0);
end;

procedure AddToTapAdapters(var Arr: TTapAdapters; const Value: TapAdapter);
var
  len: Integer;
  i: Integer;
begin
  len := Length(Arr);
  SetLength(Arr, len + 1);
  Arr[len] := Value;
  SetLength(Arr[len].TapIpAddresses, Length(Value.TapIpAddresses));
  for i := 0 to High(Value.TapIpAddresses) do
    Arr[len].TapIpAddresses[i] := Value.TapIpAddresses[i];
  SetLength(Arr[len].TapGatewayAddresses, Length(Value.TapGatewayAddresses));
  for i := 0 to High(Value.TapGatewayAddresses) do
    Arr[len].TapGatewayAddresses[i] := Value.TapGatewayAddresses[i];
end;

procedure FreeTapAdapters(var Arr: TTapAdapters);
var
  i: Integer;
begin
  for i := 0 to High(Arr) do begin
    FreeStringArray(Arr[i].TapIpAddresses);
    FreeStringArray(Arr[i].TapGatewayAddresses);
    Arr[i] := Default(TapAdapter);
  end;
  SetLength(Arr, 0);
end;

function CIDRToSubnetMask(const cidr: String): String;
var
  mask: LongWord;
  i: Integer;
  octets: array[0..3] of Byte;
begin
  try
    if cidr = '0' then begin
      mask := 0;
    end else begin
      mask := LongWord($FFFFFFFF shl (32 - StrToInt(cidr)));
    end;

    for i := 0 to 3 do
      octets[i] := (mask shr (8 * (3 - i))) and $FF;

    Result := Format('%d.%d.%d.%d', [octets[0], octets[1], octets[2], octets[3]]);
  except
    Result := '0.0.0.0';
  end;
end;

function SubnetMaskToCIDR(const SubnetMask: string): String;
var
  parts: array of String;
  i, k: Integer;
  binarystr: string;
begin
  try
    parts := SplitString(SubnetMask, '.');

    binarystr := '';
    for i := 0 to High(parts) do
      binarystr := binarystr + IntToBin(StrToInt(parts[i]),8);

    for i := 1 to Length(binarystr) do begin
      k := i;
      if binarystr[i] <> '1' then begin
        k := k - 1;
        Break;
      end;
    end;

    Result := IntToStr(k);
  except
    Result := '0';
  end;
end;

function GetNetwork(const CidrIp: String): String;
var
  parts: array of String;
  ip: String;
  cidr: String;
  subnet: string;
  ip_octets: array[0..3] of Byte;
  sn_octets: array[0..3] of Byte;
  i: Integer;
begin
  try
    parts := SplitString(CidrIp, '/');
    ip := parts[0];
    cidr :=  parts[1];
    subnet := CIDRToSubnetMask(cidr);

    parts := SplitString(ip, '.');
    for i := 0 to High(parts) do
      ip_octets[i] := StrToInt(parts[i]);

    parts := SplitString(subnet, '.');
    for i := 0 to High(parts) do
      sn_octets[i] := StrToInt(parts[i]);

    for i := 0 to 3 do
      ip_octets[i] := ip_octets[i] and sn_octets[i];

    Result := Format('%d.%d.%d.%d', [ip_octets[0], ip_octets[1], ip_octets[2], ip_octets[3]]) + '/' + cidr;
  except
    Result := '';
  end;
end;

function GetFirstAddress(const CidrIp: String): String;
var
  parts: array of String;
  ip: String;
  cidr: String;
  subnet: string;
  ip_octets: array[0..3] of Byte;
  sn_octets: array[0..3] of Byte;
  i: Integer;
begin
  try
    parts := SplitString(CidrIp, '/');
    ip := parts[0];
    cidr :=  parts[1];
    subnet := CIDRToSubnetMask(cidr);

    parts := SplitString(ip, '.');
    for i := 0 to High(parts) do
      ip_octets[i] := StrToInt(parts[i]);

    parts := SplitString(subnet, '.');
    for i := 0 to High(parts) do
      sn_octets[i] := StrToInt(parts[i]);

    for i := 0 to 3 do
      ip_octets[i] := ip_octets[i] and sn_octets[i];

    ip_octets[3] := ip_octets[3] + 1;

    Result := Format('%d.%d.%d.%d', [ip_octets[0], ip_octets[1], ip_octets[2], ip_octets[3]]);
  except
    Result := '';
  end;
end;

end.
