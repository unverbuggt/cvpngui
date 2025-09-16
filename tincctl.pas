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

unit tincctl;

interface

uses
  StrUtils, SysUtils, cvpnmod;

const
  PROT_MAJOR = 17;
  PROT_MINOR = 7;

type
  request_t = (ALL := -(1),ID := 0,METAKEY,CHALLENGE,CHAL_REPLY,
    ACK,STATUS,ERROR,TERMREQ,PING,PONG,ADD_SUBNET,
    DEL_SUBNET,ADD_EDGE,DEL_EDGE,KEY_CHANGED,
    REQ_KEY,ANS_KEY,PACKET,CONTROL,REQ_PUBKEY,
    ANS_PUBKEY,SPTPS_PACKET,UDP_INFO,MTU_INFO,
    LAST);

  request_type = (REQ_INVALID := -(1),REQ_STOP := 0,REQ_RELOAD,
    REQ_RESTART,REQ_DUMP_NODES,REQ_DUMP_EDGES,
    REQ_DUMP_SUBNETS,REQ_DUMP_CONNECTIONS,
    REQ_DUMP_GRAPH,REQ_PURGE,REQ_SET_DEBUG,
    REQ_RETRY,REQ_CONNECT,REQ_DISCONNECT,REQ_DUMP_TRAFFIC,
    REQ_PCAP,REQ_LOG);

  rdn_type = (DN_C1 := 0, DN_C2, DN_NAME, DN_NID, DN_HOSTNAME,
    DN_SPORT, DN_PORT, DN_CID, DN_DID, DN_DLEN, DN_COMPRESSION,
    DN_OPTIONS, DN_STATUS, DN_NEXTHOP, DN_VIA, DN_DISTANCE,
    DN_MTU, DN_MINMTU, DN_MAXMTU, DN_LASTTS, DN_RTT,
    DN_INPACKETS, DN_INBYTES, DN_OUTPACKETS, DN_OUTBYTES, DN_CNT);
  procedure ConnectTinc(GeneralConfig: GeneralConfigurationType);

implementation

procedure ConnectTinc(GeneralConfig: GeneralConfigurationType);
var
  pid: array of String;
  Host: String;
  Port: Integer;
  Key: String;
  Cmd: String;
begin
  {$IFDEF Windows}
  pid := SplitString(ReadTestFile(GeneralConfig.Name + '\pid'), ' ');
  {$ENDIF Windows}
  {$IFDEF Unix}
  pid := SplitString(ReadTestFile(GeneralConfig.Name + '/pid'), ' ');
  {$ENDIF Unix}
  if (Length(pid) <> 5) then begin
    Exit;
  end;
  Host := pid[2];
  Port := StrToInt(pid[4]);
  Key := pid[1];

  Cmd := '0 ^' + Key + ' 0' + #10;
end;

end.
