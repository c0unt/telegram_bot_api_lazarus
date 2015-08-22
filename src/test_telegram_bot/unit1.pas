unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ssl_openssl, HTTPSend, fpjson, jsonparser, inifiles, dateutils;

type

  { TF_gui }

  TF_gui = class(TForm)
    b_sendmessage: TButton;
    b_getmessages: TButton;
    b_set_token: TButton;
    cb_mark_as_read: TCheckBox;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    m_log: TMemo;
    Splitter1: TSplitter;
     procedure b_getmessagesClick(Sender: TObject);
    procedure b_sendmessageClick(Sender: TObject);
    procedure b_set_tokenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { private declarations }
  public
    function api_t_getMe: boolean;
    function api_t_getUpdates: boolean;
    function api_t_sendMessage(chat_id: integer; txt: string):boolean;
    { public declarations }
  end;

var
  F_gui: TF_gui;
  telegram_token:string;
  ini: tinifile;
const
  telegram_url='https://api.telegram.org/bot';
implementation

{$R *.lfm}

{ TF_gui }
function locHTTPEncode(const AStr: string): String;
 const
   NoConversion = ['A'..'Z', 'a'..'z', '*', '@', '.', '_', ';','-','1','2','3','4','5','6','7','8','9','0'];
 var
   Sp, Rp: PChar;

 begin


   SetLength(Result, Length(AStr) * 3);
   Sp := PChar(AStr);
   Rp := PChar(Result);
   while Sp^ <> #0 do
   begin
     if Sp^ in NoConversion then
       Rp^ := Sp^
     else if Sp^ = ' ' then
       Rp^ := '+'
     else
     begin
       FormatBuf(Rp^, 3, '%%%.2x', 6, [Ord(Sp^)]);
       Inc(Rp, 2);
     end;
     Inc(Rp);
     Inc(Sp);
   end;
   SetLength(Result, Rp - PChar(Result));
 end;




procedure TF_gui.b_getmessagesClick(Sender: TObject);
begin
   api_t_getUpdates;
end;

procedure TF_gui.b_sendmessageClick(Sender: TObject);
var chat_id, message:string;
begin
  if InputQuery('Enter chat id', 'Chat id', chat_id) then
  begin
    if InputQuery('Enter message', 'message', message) then
    begin
      api_t_sendMessage(StrToInt64(chat_id),message);
    end;
  end;
end;

procedure TF_gui.b_set_tokenClick(Sender: TObject);
begin
  if  InputQuery('Telegram bot settings','Token:',telegram_token) then
  begin
    if api_t_getMe then
    begin
      GroupBox2.Visible:=true;
      b_set_token.Visible:=false;
    end;
  end;
end;

procedure TF_gui.FormCreate(Sender: TObject);
begin
  ini:=tinifile.Create(ExtractFileDir(ParamStrUTF8(0))+'telegram_bot.ini');
  telegram_token:=ini.ReadString('Settings', 'telegram_token','');
  if telegram_token <> '' then
  begin
    if api_t_getMe then
    begin
      GroupBox2.Visible:=true;
      b_set_token.Visible:=false;
    end;
  end;

end;

function TF_gui.api_t_getMe: boolean;
var
  JsonDoc: TJSONObject;
  JsonParser: TJSONParser;
  mstr: tmemorystream;
  HTTPClient: THTTPSend;
begin
  telegram_token:=Trim(telegram_token);
  HTTPClient:=THTTPSend.Create;
  mstr:= tmemorystream.create;
  result:=false;
  try
    if HttpGetBinary(telegram_url+telegram_token+'/getMe', mstr)  then
    begin
      mstr.position:=0;
      m_log.lines.LoadFromStream(mstr);
      mstr.position:=0;
      JsonParser := TJSONParser.Create(mstr);
      JsonDoc := TJSONObject(JsonParser.Parse);

      if  jsonDoc.findpath('ok').AsBoolean then
      begin
        result:=true;
        ini.WriteString('Settings', 'telegram_token', telegram_token);
        self.Caption:='@'+jsonDoc.findpath('result.username').AsString;
      end;
    end;

  finally
    HTTPClient.Free
  end;

end;
function TF_gui.api_t_sendMessage(chat_id: integer; txt: string): boolean;
var
  JsonDoc: TJSONObject;
  JsonParser: TJSONParser;
  mstr: tmemorystream;
  HTTPClient: THTTPSend;
begin
  telegram_token:=Trim(telegram_token);
  HTTPClient:=THTTPSend.Create;
  mstr:= tmemorystream.create;
  result:=false;

  try
    if HttpGetBinary(telegram_url+telegram_token+'/sendMessage?chat_id='+inttostr(chat_id)+'&text='+locHTTPEncode(txt), mstr)  then
    begin

      mstr.position:=0;
      m_log.lines.LoadFromStream(mstr);
      mstr.position:=0;
      JsonParser := TJSONParser.Create(mstr);
      JsonDoc := TJSONObject(JsonParser.Parse);

      if  jsonDoc.findpath('ok').AsBoolean then
      begin
        result:=true;
    end;
    end;

  finally
    HTTPClient.Free
  end;

end;


function TF_gui.api_t_getUpdates: boolean;
var
  JsonDoc: TJSONObject;
  JsonParser: TJSONParser;
  mstr: tmemorystream;
  offset:Int64;
  HTTPClient: THTTPSend;
  i:integer;
begin
  telegram_token:=Trim(telegram_token);
  HTTPClient:=THTTPSend.Create;
  mstr:= tmemorystream.create;
  result:=false;

  try
    offset:=ini.ReadInt64('Settings','offset',0);

    if HttpGetBinary(telegram_url+telegram_token+'/getUpdates?offset='+inttostr(offset+1), mstr)  then
    begin
      mstr.position:=0;
      m_log.lines.LoadFromStream(mstr);
      mstr.position:=0;
      JsonParser := TJSONParser.Create(mstr);
      JsonDoc := TJSONObject(JsonParser.Parse);

      if  jsonDoc.findpath('ok').AsBoolean then
      begin
        // print all messages to memo
        if jsonDoc.findpath('result').Count<>0 then
        begin
        for i:=0 to  jsonDoc.findpath('result').Count-1 do
        begin
         //here you can do whatever you want with the message
         m_log.Lines.add( '('+
         'chat:'+jsonDoc.findpath('result').Items[i].FindPath('message').FindPath('chat').FindPath('id').AsString+'/'+
         'm:'+jsonDoc.findpath('result').Items[i].FindPath('message').FindPath('message_id').AsString+
         ')'+
         DateTimeToStr(UnixToDateTime(jsonDoc.findpath('result').Items[i].FindPath('message').FindPath('date').AsInt64))+' >> '+
          jsonDoc.findpath('result').Items[i].FindPath('message').FindPath('text').AsString);
        end;

        result:=true;
        offset:=jsonDoc.findpath('result').Items[jsonDoc.findpath('result').Count-1].FindPath('update_id').AsInt64;
        if cb_mark_as_read.Checked then
        begin
          ini.WriteInt64('Settings','offset',offset);


        end;

        end;
      end;
    end;

  finally
    HTTPClient.Free
  end;

end;

end.

