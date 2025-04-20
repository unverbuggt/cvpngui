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

unit cvpnlin;

interface

uses
  StrUtils,
  BaseUnix, Sockets, SysUtils,
  cvpnmod;

const
  AF_INET = 2;

type
  pifaddrs = ^ifaddrs;
  ifaddrs = record
    ifa_next: pifaddrs;       { Pointer to next struct }
    ifa_name: PChar;          { Interface name }
    ifa_flags: Cardinal;      { Interface flags }
    ifa_addr: psockaddr;      { Interface address }
    ifa_netmask: psockaddr;   { Interface netmask }
    ifa_broadaddr: psockaddr; { Interface broadcast address }
    ifa_dstaddr: psockaddr;   { P2P interface destination }
    ifa_data: Pointer;        { Address specific data }
  end;

  function getifaddrs(var ifap: pifaddrs): Integer; cdecl; external 'libc.so' name 'getifaddrs'; {do not localize}
  procedure freeifaddrs(ifap: pifaddrs); cdecl; external 'libc.so' name 'freeifaddrs'; {do not localize}

  function CheckTAP(GeneralConfig: GeneralConfigurationType; TapConfig: TapConfigurationType): CheckTapResult;

implementation

function CheckTAP(GeneralConfig: GeneralConfigurationType;
                 TapConfig: TapConfigurationType): CheckTapResult;
var
  LAddrList, LAddrInfo: pifaddrs;
  uid: string;
  ifpath: string;
  tap_uid: string;
  tun_flags: string;
  NewTapAdapter: TapAdapter;
  FoundAdapter: Boolean;
  i, k : Integer;
  IpConf: array of String;
  Ip: String;
  Cidr: String;
begin
  result.errApi := True;
  result.errNoTAP := True;
  result.errWrongNet := True;
  result.errWrongIP := True;
  result.TapIndex := -1;

  uid := IntToStr(fpgetuid);
  if getifaddrs(LAddrList) = 0 then
  try
    result.errApi := False;
    LAddrInfo := LAddrList;
    repeat
      FreeStringArray(NewTapAdapter.TapIpAddresses);
      FreeStringArray(NewTapAdapter.TapGatewayAddresses);
      NewTapAdapter := Default(TapAdapter);
      FoundAdapter := False;
      ifpath := '/sys/class/net/' + LAddrInfo^.ifa_name;
      tun_flags := ReadTestFile(ifpath + '/tun_flags');
      if tun_flags <> '' then begin
        if (StrToInt(tun_flags) and $2) <> 0 then begin
          tap_uid := ReadTestFile(ifpath + '/owner');
          FoundAdapter := tap_uid = uid;
        end;
      end;
      if FoundAdapter then begin
        result.errNoTAP := false;
        NewTapAdapter.FriendlyName := LAddrInfo^.ifa_name;
        k := -1;
        for i := 0 to High(result.TapAdapters) do begin
          if result.TapAdapters[i].FriendlyName = NewTapAdapter.FriendlyName then begin
            k := i;
            Break;
          end;
        end;
        if (LAddrInfo^.ifa_addr <> nil) then begin
          if (LAddrInfo^.ifa_addr^.sa_family = AF_INET) then begin
            Ip := NetAddrToStr(LAddrInfo^.ifa_addr^.sin_addr);
            Cidr := SubnetMaskToCIDR(NetAddrToStr(LAddrInfo^.ifa_netmask^.sin_addr));
            IpConf := SplitString(TapConfig.IpAddress, '/');
            if (GetNetwork(Ip + '/' + Cidr) = GeneralConfig.Network) then begin
              result.errWrongNet := False;
              if (Ip = IpConf[0]) then begin
                result.errWrongIP := False;
                if k = -1 then begin
                  result.TapIndex := Length(result.TapAdapters);
                end else begin
                  result.TapIndex := k;
                end;
              end;
            end;
            if k = -1 then begin
              AddToStringArray(NewTapAdapter.TapIpAddresses, Ip + '/' + Cidr);
            end else begin
              AddToStringArray(result.TapAdapters[k].TapIpAddresses, Ip + '/' + Cidr);
            end;
          end;
        end;
        if k = -1 then begin
          AddToTapAdapters(result.TapAdapters, NewTapAdapter);
        end;
      end;
      LAddrInfo := LAddrInfo^.ifa_next;
    until LAddrInfo = nil;
  finally
    freeifaddrs(LAddrList);
  end;
end;

end.
