const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_Text_Audit.log';

var
    LogLines : TStringList;

procedure Log(Msg : String);
begin
    if LogLines <> nil then
        LogLines.Add(Msg);
end;

function CurrentOrOpenedBoard : IPCB_Board;
var
    Doc : IServerDocument;
begin
    Doc := Client.OpenDocument('PCB', PCB_PATH);
    if Doc <> nil then
        Client.ShowDocument(Doc);

    Result := PCBServer.GetCurrentPCBBoard;
end;

procedure LogRect(Prefix : String; R : TCoordRect);
begin
    Log(Prefix +
        ' LeftMil=' + FloatToStr(CoordToMils(R.Left)) +
        ' RightMil=' + FloatToStr(CoordToMils(R.Right)) +
        ' BottomMil=' + FloatToStr(CoordToMils(R.Bottom)) +
        ' TopMil=' + FloatToStr(CoordToMils(R.Top)));
end;

procedure AuditOverlayTexts;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    TextObj  : IPCB_Text;
    R        : TCoordRect;
    Count    : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running AuditOverlayTexts.');
            Exit;
        end;

        Count := 0;
        Log('AuditOverlayTexts started');

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eTextObject));
        Iterator.AddFilter_LayerSet(MkSet(eTopOverlay, eBottomOverlay));
        Iterator.AddFilter_Method(eProcessAll);

        TextObj := Iterator.FirstPCBObject;
        while TextObj <> nil do
        begin
            Inc(Count);
            R := TextObj.BoundingRectangle;
            LogRect('TEXT Layer=' + IntToStr(TextObj.Layer) +
                ' Text=' + TextObj.Text, R);
            TextObj := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        Log('Overlay text count: ' + IntToStr(Count));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Overlay text audit complete. Text count: ' + IntToStr(Count) +
            '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

