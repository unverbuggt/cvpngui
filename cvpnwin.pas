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

unit cvpnwin;

interface

uses
  StrUtils,
  Windows, ShellApi, SysUtils, Winsock2,
  cvpnmod;

const
  AF_UNSPEC = 0;
  AF_INET = 2;
  MAX_ADAPTER_ADDRESS_LENGTH = 8;
  GAA_FLAG_INCLUDE_GATEWAYS = $0080;
  IP_ADAPTER_DHCPV4_ENABLED = $00000004;

type
  ULONG = Cardinal;
  UINT = Cardinal;

  PIP_ADAPTER_UNICAST_ADDRESS = ^IP_ADAPTER_UNICAST_ADDRESS;
  IP_ADAPTER_UNICAST_ADDRESS = record
    Union: record
      case Integer of
        0: (
            Alignment: ULONGLONG;
          );
        1: (
            Length: ULONG;
            Flags: DWORD;
          );
    end;
    Next: PIP_ADAPTER_UNICAST_ADDRESS;
    Address: SOCKET_ADDRESS;
    PrefixOrigin: DWORD;
    SuffixOrigin: DWORD;
    DadState: DWORD;
    ValidLifetime: ULONG;
    PreferredLifetime: ULONG;
    LeaseLifetime: ULONG;
    OnLinkPrefixLength: Byte;
  end;

  PIP_ADAPTER_GATEWAY_ADDRESS_LH = ^IP_ADAPTER_GATEWAY_ADDRESS_LH;
  IP_ADAPTER_GATEWAY_ADDRESS_LH = record
    Union: record
      case Integer of
        0: (
            Alignment: ULONGLONG;
          );
        1: (
            Length: ULONG;
            Flags: DWORD;
          );
    end;
    Next: PIP_ADAPTER_GATEWAY_ADDRESS_LH;
    Address: SOCKET_ADDRESS;
  end;

  PIP_ADAPTER_ADDRESSES = ^IP_ADAPTER_ADDRESSES;
  IP_ADAPTER_ADDRESSES = record
    Union: record
      case Integer of
        0: (
            Alignment: ULONGLONG;
          );
        1: (
            Length: ULONG;
            IfIndex: DWORD;
          );
    end;
    Next: PIP_ADAPTER_ADDRESSES;
    AdapterName: PCHAR;
    FirstUnicastAddress: PIP_ADAPTER_UNICAST_ADDRESS;
    FirstAnycastAddress: Pointer;
    FirstMulticastAddress: Pointer;
    FirstDnsServerAddress: Pointer;
    DnsSuffix: PWCHAR;
    Description: PWCHAR;
    FriendlyName: PWCHAR;
    PhysicalAddress: array [0..MAX_ADAPTER_ADDRESS_LENGTH-1] of Byte;
    PhysicalAddressLength: DWORD;
    Flags: DWORD;
    Mtu: DWORD;
    IfType: DWORD;
    OperStatus: DWORD;
    Ipv6IfIndex: DWORD;
    ZoneIndices: array [0..15] of DWORD;
    FirstPrefix: Pointer;
    TransmitLinkSpeed: ULONGLONG;
    ReceiveLinkSpeed: ULONGLONG;
    FirstWinsServerAddress: Pointer;
    FirstGatewayAddress: PIP_ADAPTER_GATEWAY_ADDRESS_LH;
  end;

  function GetAdaptersAddresses(
    Family: ULONG;
    Flags: ULONG;
    Reserved: Pointer;
    AdapterAddresses: PIP_ADAPTER_ADDRESSES;
    SizePointer: PULONG
  ): ULONG; stdcall; external 'iphlpapi.dll';

  function CheckTAP(GeneralConfig: GeneralConfigurationType; TapConfig: TapConfigurationType): CheckTapResult;
  function RunAsAdmin(const Handle: Hwnd; const Path, Params: string): Boolean;

implementation

function CheckTAP(GeneralConfig: GeneralConfigurationType;
                 TapConfig: TapConfigurationType): CheckTapResult;
var
  BufLen: ULONG;
  RetVal: ULONG;
  AdapterAddresses, CurrentAdapter: PIP_ADAPTER_ADDRESSES;
  UnicastAddress: PIP_ADAPTER_UNICAST_ADDRESS;
  GatewayAddress: PIP_ADAPTER_GATEWAY_ADDRESS_LH;
  NewTapAdapter: TapAdapter;
  FoundAdapter: Boolean;
  IpConf: array of String;
  Ip: String;
  Cidr: String;
begin
  result.errApi := True;
  result.errNoTAP := True;
  result.errWrongNet := True;
  result.errWrongIP := True;
  result.TapIndex := -1;

  BufLen := 0;
  RetVal := GetAdaptersAddresses(AF_INET, GAA_FLAG_INCLUDE_GATEWAYS, nil, nil, @BufLen);

  if RetVal <> ERROR_BUFFER_OVERFLOW then begin
    Exit;
  end;

  GetMem(AdapterAddresses, BufLen);
  try
    RetVal := GetAdaptersAddresses(AF_INET, GAA_FLAG_INCLUDE_GATEWAYS, nil, AdapterAddresses, @BufLen);
    if RetVal <> NO_ERROR then begin
      Exit;
    end;
    result.errApi := False;

    CurrentAdapter := AdapterAddresses;
    while CurrentAdapter <> nil do
    begin
      FreeStringArray(NewTapAdapter.TapIpAddresses);
      FreeStringArray(NewTapAdapter.TapGatewayAddresses);
      NewTapAdapter := Default(TapAdapter);
      FoundAdapter := False;
      if StartsWith(WideCharToString(CurrentAdapter^.Description), 'TAP-Win32 Adapter V9')
         or StartsWith(WideCharToString(CurrentAdapter^.Description), 'TAP-Windows Adapter V9')
      then begin
         result.errNoTAP := False;
         FoundAdapter := True;
         NewTapAdapter.Description := WideCharToString(CurrentAdapter^.Description);
      end;

      if (NewTapAdapter.Description <> '') then begin
        if (WideCharToString(CurrentAdapter^.FriendlyName) = TapConfig.FriendlyName) then
           result.errWrongName := False;
        NewTapAdapter.FriendlyName := WideCharToString(CurrentAdapter^.FriendlyName);
      end;

      if FoundAdapter then
      begin
        UnicastAddress := CurrentAdapter^.FirstUnicastAddress;
        while UnicastAddress <> nil do
        begin
          with UnicastAddress^.Address.lpSockaddr^ do begin
            if sa_family = AF_INET then begin
              IpConf := SplitString(TapConfig.IpAddress, '/');
              Ip := inet_ntoa(sin_addr);
              Cidr := IntToStr(UnicastAddress^.OnLinkPrefixLength);
              if (GetNetwork(Ip + '/' + Cidr) = GeneralConfig.Network) then begin
                result.errWrongNet := False;
                if (Ip = IpConf[0]) then begin
                  result.errWrongIP := False;
                  result.TapIndex := Length(result.TapAdapters);
                end;
              end else if (NewTapAdapter.FriendlyName = TapConfig.FriendlyName)
                 and (LowerCase(TapConfig.IpAddress) = 'dhcp')
                 and ((CurrentAdapter^.Flags and IP_ADAPTER_DHCPV4_ENABLED) <> 0) then
              begin
                result.errWrongNet := False;
                result.errWrongIP := False;
                result.TapIndex := Length(result.TapAdapters);
              end;
              if (UnicastAddress^.PrefixOrigin = 1 {IpPrefixOriginManual})
                 or (UnicastAddress^.PrefixOrigin = 3 {IpPrefixOriginDhcp}) then
              begin
                AddToStringArray(NewTapAdapter.TapIpAddresses, Ip + '/' + Cidr);
              end;
            end;
          end;
          UnicastAddress := UnicastAddress^.Next;
        end;

        GatewayAddress := CurrentAdapter^.FirstGatewayAddress;
        if GatewayAddress <> nil then begin
          with GatewayAddress^.Address.lpSockaddr^ do begin
            if sa_family = AF_INET then begin
              AddToStringArray(NewTapAdapter.TapGatewayAddresses, inet_ntoa(sin_addr));
            end;
          end;
        end;
        AddToTapAdapters(result.TapAdapters, NewTapAdapter);
      end;

      CurrentAdapter := CurrentAdapter^.Next;

    end;
  finally
    FreeMem(AdapterAddresses);
  end;
end;

function RunAsAdmin(const Handle: Hwnd; const Path, Params: string): Boolean;
var
  sei: TShellExecuteInfoA;
begin
  FillChar(sei, SizeOf(sei), 0);
  sei.cbSize := SizeOf(sei);
  sei.Wnd := Handle;
  sei.fMask := SEE_MASK_FLAG_DDEWAIT or SEE_MASK_FLAG_NO_UI;
  sei.lpVerb := 'runas';
  sei.lpFile := PAnsiChar(Path);
  sei.lpParameters := PAnsiChar(Params);
  sei.nShow := SW_SHOWNORMAL;
  Result := ShellExecuteExA(@sei);
end;

end.
