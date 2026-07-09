const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_100x68_Cleanup.log';
    BOARD_LEFT_MM = 71.2469873;
    BOARD_BOTTOM_MM = 59.3089873;

var
    LogLines : TStringList;

procedure Log(Msg : String);
begin
    if LogLines <> nil then
        LogLines.Add(Msg);
end;

procedure FlushLog;
begin
    if LogLines <> nil then
        LogLines.SaveToFile(LOG_PATH);
end;

function AbsX(LocalMM : Double) : TCoord;
begin
    Result := MMsToCoord(BOARD_LEFT_MM + LocalMM);
end;

function AbsY(LocalMM : Double) : TCoord;
begin
    Result := MMsToCoord(BOARD_BOTTOM_MM + LocalMM);
end;

procedure BeginObjModify(Obj : IPCB_Primitive);
begin
    PCBServer.SendMessageToRobots(Obj.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
end;

procedure EndObjModify(Obj : IPCB_Primitive);
begin
    PCBServer.SendMessageToRobots(Obj.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
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

procedure SaveCurrentPCB;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

function FirstNetByName(Board : IPCB_Board; NetName : String) : IPCB_Net;
var
    Iterator : IPCB_BoardIterator;
    Obj      : IPCB_Primitive;
begin
    Result := nil;
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(AllPrimitives);
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Obj := Iterator.FirstPCBObject;
    while Obj <> nil do
    begin
        if (Obj.Net <> nil) and (Obj.Net.Name = NetName) then
        begin
            Result := Obj.Net;
            Break;
        end;
        Obj := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

function NearOriginText(R : TCoordRect) : Boolean;
var
    Limit : TCoord;
begin
    Limit := MilsToCoord(700.0);
    Result := (Abs(R.Left) <= Limit) and
              (Abs(R.Right) <= Limit) and
              (Abs(R.Bottom) <= Limit) and
              (Abs(R.Top) <= Limit);
end;

function CoordNear(A, B, Tolerance : TCoord) : Boolean;
begin
    Result := Abs(A - B) <= Tolerance;
end;

function SetPadAtMilNet(Board : IPCB_Board; CenterXMil, CenterYMil : Double; Net : IPCB_Net) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Pad       : IPCB_Pad;
    Tolerance : TCoord;
begin
    Result := False;
    Tolerance := MilsToCoord(0.8);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(ePadObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Pad := Iterator.FirstPCBObject;
    while Pad <> nil do
    begin
        if CoordNear(Pad.X, MilsToCoord(CenterXMil), Tolerance) and
           CoordNear(Pad.Y, MilsToCoord(CenterYMil), Tolerance) then
        begin
            Log('Setting pad net at ' + FloatToStr(CenterXMil) + ',' + FloatToStr(CenterYMil));
            FlushLog;
            Pad.Net := Net;
            Log('Set pad net done at ' + FloatToStr(CenterXMil) + ',' + FloatToStr(CenterYMil));
            FlushLog;
            Result := True;
            Break;
        end;
        Pad := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

function MovePadAtMil(Board : IPCB_Board; CenterXMil, CenterYMil, DeltaXMil, DeltaYMil : Double) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Pad       : IPCB_Pad;
    Tolerance : TCoord;
begin
    Result := False;
    Tolerance := MilsToCoord(0.8);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(ePadObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Pad := Iterator.FirstPCBObject;
    while Pad <> nil do
    begin
        if CoordNear(Pad.X, MilsToCoord(CenterXMil), Tolerance) and
           CoordNear(Pad.Y, MilsToCoord(CenterYMil), Tolerance) then
        begin
            Log('Moving pad at ' + FloatToStr(CenterXMil) + ',' + FloatToStr(CenterYMil));
            FlushLog;
            Pad.MoveByXY(MilsToCoord(DeltaXMil), MilsToCoord(DeltaYMil));
            Log('Move pad done at ' + FloatToStr(CenterXMil) + ',' + FloatToStr(CenterYMil));
            FlushLog;
            Result := True;
            Break;
        end;
        Pad := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

function TrackMatchesMil(Track : IPCB_Track; X1Mil, Y1Mil, X2Mil, Y2Mil : Double;
                         Tolerance : TCoord) : Boolean;
begin
    Result :=
        (CoordNear(Track.X1, MilsToCoord(X1Mil), Tolerance) and
         CoordNear(Track.Y1, MilsToCoord(Y1Mil), Tolerance) and
         CoordNear(Track.X2, MilsToCoord(X2Mil), Tolerance) and
         CoordNear(Track.Y2, MilsToCoord(Y2Mil), Tolerance)) or
        (CoordNear(Track.X1, MilsToCoord(X2Mil), Tolerance) and
         CoordNear(Track.Y1, MilsToCoord(Y2Mil), Tolerance) and
         CoordNear(Track.X2, MilsToCoord(X1Mil), Tolerance) and
         CoordNear(Track.Y2, MilsToCoord(Y1Mil), Tolerance));
end;

function SetTrackAtMilNet(Board : IPCB_Board; X1Mil, Y1Mil, X2Mil, Y2Mil : Double;
                          Net : IPCB_Net) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Track     : IPCB_Track;
    Tolerance : TCoord;
begin
    Result := False;
    Tolerance := MilsToCoord(0.8);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Track := Iterator.FirstPCBObject;
    while Track <> nil do
    begin
        if TrackMatchesMil(Track, X1Mil, Y1Mil, X2Mil, Y2Mil, Tolerance) then
        begin
            Log('Setting track net at ' + FloatToStr(X1Mil) + ',' + FloatToStr(Y1Mil));
            FlushLog;
            Track.Net := Net;
            Log('Set track net done at ' + FloatToStr(X1Mil) + ',' + FloatToStr(Y1Mil));
            FlushLog;
            Result := True;
            Break;
        end;
        Track := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

function RemovePadAtMil(Board : IPCB_Board; CenterXMil, CenterYMil : Double) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Pad       : IPCB_Pad;
    Match     : IPCB_Pad;
    Tolerance : TCoord;
begin
    Result := False;
    Match := nil;
    Tolerance := MilsToCoord(0.8);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(ePadObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Pad := Iterator.FirstPCBObject;
    while Pad <> nil do
    begin
        if CoordNear(Pad.X, MilsToCoord(CenterXMil), Tolerance) and
           CoordNear(Pad.Y, MilsToCoord(CenterYMil), Tolerance) then
        begin
            Match := Pad;
            Break;
        end;
        Pad := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);

    if Match <> nil then
    begin
        Log('Removing short pad at ' + FloatToStr(CenterXMil) + ',' + FloatToStr(CenterYMil));
        FlushLog;
        Board.RemovePCBObject(Match);
        Result := True;
    end;
end;

function RemoveTrackAtMil(Board : IPCB_Board; X1Mil, Y1Mil, X2Mil, Y2Mil : Double) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Track     : IPCB_Track;
    Match     : IPCB_Track;
    Tolerance : TCoord;
begin
    Result := False;
    Match := nil;
    Tolerance := MilsToCoord(0.8);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Track := Iterator.FirstPCBObject;
    while Track <> nil do
    begin
        if TrackMatchesMil(Track, X1Mil, Y1Mil, X2Mil, Y2Mil, Tolerance) then
        begin
            Match := Track;
            Break;
        end;
        Track := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);

    if Match <> nil then
    begin
        Log('Removing short track at ' + FloatToStr(X1Mil) + ',' + FloatToStr(Y1Mil));
        FlushLog;
        Board.RemovePCBObject(Match);
        Result := True;
    end;
end;

procedure Cleanup100x68DRC;
var
    Board       : IPCB_Board;
    Iterator    : IPCB_BoardIterator;
    TextObj     : IPCB_Text;
    GndNet      : IPCB_Net;
    FixedNets   : Integer;
    FixedTexts  : Integer;
    MovedPads   : Integer;
    RemovedShorts : Integer;
begin
    LogLines := TStringList.Create;
    try
        Log('Cleanup100x68DRC started');
        FlushLog;

        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            Log('ERROR: no active PCB board');
            FlushLog;
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running Cleanup100x68DRC.');
            Exit;
        end;

        FixedNets := 0;
        FixedTexts := 0;
        MovedPads := 0;
        RemovedShorts := 0;
        GndNet := FirstNetByName(Board, 'GND');
        if GndNet <> nil then
            Log('Board opened, GND found=True')
        else
            Log('Board opened, GND found=False');
        FlushLog;

        Log('Starting right-edge net pass');
        FlushLog;
        if GndNet <> nil then
        begin
            if SetPadAtMilNet(Board, 6711.614, 2983.622, GndNet) then Inc(FixedNets);
            if SetPadAtMilNet(Board, 6724.684, 2938.346, GndNet) then Inc(FixedNets);
            if SetTrackAtMilNet(Board, 6732.165, 2847.810, 6732.165, 2983.622, GndNet) then Inc(FixedNets);
            if SetPadAtMilNet(Board, 6711.614, 4597.794, GndNet) then Inc(FixedNets);
            if SetPadAtMilNet(Board, 6724.684, 4552.520, GndNet) then Inc(FixedNets);
            if SetTrackAtMilNet(Board, 6732.165, 4461.984, 6732.165, 4597.794, GndNet) then Inc(FixedNets);
        end;
        Log('Right-edge pads/tracks set to GND: ' + IntToStr(FixedNets));
        FlushLog;

        Log('Starting default text pass');
        FlushLog;
        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eTextObject));
        Iterator.AddFilter_LayerSet(MkSet(eTopOverlay));
        Iterator.AddFilter_Method(eProcessAll);

        TextObj := Iterator.FirstPCBObject;
        while TextObj <> nil do
        begin
            if (TextObj.Text = 'Designator1') and NearOriginText(TextObj.BoundingRectangle) then
            begin
                BeginObjModify(TextObj);
                TextObj.Layer := eMechanical1;
                EndObjModify(TextObj);
                Inc(FixedTexts);
            end;
            TextObj := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);
        Log('Default Designator1 texts moved off overlay: ' + IntToStr(FixedTexts));
        FlushLog;

        Log('Starting solder-mask pad move pass');
        FlushLog;
        if MovePadAtMil(Board, 6671.520, 2965.528, -4.0, 0.0) then
            Inc(MovedPads);
        if MovePadAtMil(Board, 6671.520, 4579.700, -4.0, 0.0) then
            Inc(MovedPads);
        Log('Solder-mask pads moved: ' + IntToStr(MovedPads));
        FlushLog;

        Log('Starting short-artifact removal pass');
        FlushLog;
        if RemovePadAtMil(Board, 6724.684, 2938.346) then Inc(RemovedShorts);
        if RemoveTrackAtMil(Board, 6732.165, 2847.810, 6732.165, 2983.622) then Inc(RemovedShorts);
        if RemovePadAtMil(Board, 6724.684, 4552.520) then Inc(RemovedShorts);
        if RemoveTrackAtMil(Board, 6732.165, 4461.984, 6732.165, 4597.794) then Inc(RemovedShorts);
        Log('Short artifacts removed: ' + IntToStr(RemovedShorts));
        FlushLog;

        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Cleanup100x68DRC complete');
        FlushLog;
        ShowMessage('100x68 DRC cleanup complete. Right-edge objects: ' +
            IntToStr(FixedNets) + ', texts: ' + IntToStr(FixedTexts) +
            ', moved pads: ' + IntToStr(MovedPads) +
            ', removed shorts: ' + IntToStr(RemovedShorts) + '.');
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;
