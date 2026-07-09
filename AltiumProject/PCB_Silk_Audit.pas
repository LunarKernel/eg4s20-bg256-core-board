const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_Silk_Audit.log';

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

function RectIntersectsMil(R : TCoordRect; LeftMil, BottomMil, RightMil, TopMil : Double) : Boolean;
begin
    Result := (R.Right >= MilsToCoord(LeftMil)) and
              (R.Left <= MilsToCoord(RightMil)) and
              (R.Top >= MilsToCoord(BottomMil)) and
              (R.Bottom <= MilsToCoord(TopMil));
end;

function InSuspectZone(R : TCoordRect) : Boolean;
begin
    Result :=
        RectIntersectsMil(R, 3450.0, 2760.0, 4420.0, 3510.0) or
        RectIntersectsMil(R, 3400.0, 4160.0, 3615.0, 4355.0) or
        RectIntersectsMil(R, 6480.0, 2740.0, 6810.0, 3040.0) or
        RectIntersectsMil(R, 6480.0, 4360.0, 6810.0, 4655.0);
end;

procedure LogRect(Prefix : String; R : TCoordRect);
begin
    Log(Prefix +
        ' LeftMil=' + FloatToStr(CoordToMils(R.Left)) +
        ' RightMil=' + FloatToStr(CoordToMils(R.Right)) +
        ' BottomMil=' + FloatToStr(CoordToMils(R.Bottom)) +
        ' TopMil=' + FloatToStr(CoordToMils(R.Top)));
end;

procedure AuditSilkObjects;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    Obj      : IPCB_Primitive;
    R        : TCoordRect;
    Count    : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running AuditSilkObjects.');
            Exit;
        end;

        Count := 0;
        Log('AuditSilkObjects started');

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(AllPrimitives);
        Iterator.AddFilter_LayerSet(MkSet(eTopOverlay, eBottomOverlay));
        Iterator.AddFilter_Method(eProcessAll);

        Obj := Iterator.FirstPCBObject;
        while Obj <> nil do
        begin
            R := Obj.BoundingRectangle;
            if InSuspectZone(R) then
            begin
                Inc(Count);
                LogRect('SUSPECT Object=' + Obj.ObjectIDString +
                    ' ObjId=' + IntToStr(Obj.ObjectId) +
                    ' Layer=' + IntToStr(Obj.Layer), R);
            end;
            Obj := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        Log('Suspect overlay object count: ' + IntToStr(Count));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Silk audit complete. Suspect objects: ' + IntToStr(Count) +
            '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

