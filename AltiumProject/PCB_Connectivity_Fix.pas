const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_Connectivity_Fix.log';

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

function CoordNear(A, B, Tolerance : TCoord) : Boolean;
begin
    Result := Abs(A - B) <= Tolerance;
end;

function TrackTouches(Track : IPCB_Track; X, Y : TCoord; NetName : String;
                      Tolerance : TCoord) : Boolean;
begin
    Result := False;
    if Track = nil then Exit;
    if Track.Net = nil then Exit;
    if Track.Net.Name <> NetName then Exit;

    Result :=
        (CoordNear(Track.X1, X, Tolerance) and CoordNear(Track.Y1, Y, Tolerance)) or
        (CoordNear(Track.X2, X, Tolerance) and CoordNear(Track.Y2, Y, Tolerance));
end;

function FindTrackTouching(Board : IPCB_Board; X, Y : TCoord; NetName : String) : IPCB_Track;
var
    Iterator  : IPCB_BoardIterator;
    Track     : IPCB_Track;
    Tolerance : TCoord;
begin
    Result := nil;
    Tolerance := MilsToCoord(1.0);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Track := Iterator.FirstPCBObject;
    while Track <> nil do
    begin
        if TrackTouches(Track, X, Y, NetName, Tolerance) then
        begin
            Result := Track;
            Break;
        end;
        Track := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

function ExistingViaAt(Board : IPCB_Board; X, Y : TCoord; NetName : String) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Via       : IPCB_Via;
    Tolerance : TCoord;
begin
    Result := False;
    Tolerance := MilsToCoord(1.0);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eViaObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Via := Iterator.FirstPCBObject;
    while Via <> nil do
    begin
        if (Via.Net <> nil) and (Via.Net.Name = NetName) and
           CoordNear(Via.X, X, Tolerance) and CoordNear(Via.Y, Y, Tolerance) then
        begin
            Result := True;
            Break;
        end;
        Via := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

function AddViaIfMissing(Board : IPCB_Board; X, Y : TCoord; NetName : String) : Boolean;
var
    Track : IPCB_Track;
    Via   : IPCB_Via;
begin
    Result := False;
    if ExistingViaAt(Board, X, Y, NetName) then
    begin
        Log('SKIP_EXISTING_VIA Net=' + NetName +
            ' Xmil=' + FloatToStr(CoordToMils(X)) +
            ' Ymil=' + FloatToStr(CoordToMils(Y)));
        Exit;
    end;

    Track := FindTrackTouching(Board, X, Y, NetName);
    if Track = nil then
    begin
        Log('NO_TRACK_FOR_VIA Net=' + NetName +
            ' Xmil=' + FloatToStr(CoordToMils(X)) +
            ' Ymil=' + FloatToStr(CoordToMils(Y)));
        Exit;
    end;

    Via := PCBServer.PCBObjectFactory(eViaObject, eNoDimension, eCreate_Default);
    Via.X := X;
    Via.Y := Y;
    Via.Size := MilsToCoord(24.0);
    Via.HoleSize := MilsToCoord(12.0);
    Via.Net := Track.Net;
    Board.AddPCBObject(Via);
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast,
        PCBM_BoardRegisteration, Via.I_ObjectAddress);

    Result := True;
    Log('ADDED_VIA Net=' + NetName +
        ' Xmil=' + FloatToStr(CoordToMils(X)) +
        ' Ymil=' + FloatToStr(CoordToMils(Y)));
end;

function TrackMatches(Track : IPCB_Track; X1, Y1, X2, Y2 : TCoord;
                      Layer : TLayer; Tolerance : TCoord) : Boolean;
begin
    Result := False;
    if Track = nil then Exit;
    if Track.Layer <> Layer then Exit;

    Result :=
        (CoordNear(Track.X1, X1, Tolerance) and CoordNear(Track.Y1, Y1, Tolerance) and
         CoordNear(Track.X2, X2, Tolerance) and CoordNear(Track.Y2, Y2, Tolerance)) or
        (CoordNear(Track.X1, X2, Tolerance) and CoordNear(Track.Y1, Y2, Tolerance) and
         CoordNear(Track.X2, X1, Tolerance) and CoordNear(Track.Y2, Y1, Tolerance));
end;

function RemoveExactTrack(Board : IPCB_Board; X1, Y1, X2, Y2 : TCoord; Layer : TLayer) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Track     : IPCB_Track;
    Match     : IPCB_Track;
    Tolerance : TCoord;
    NetName   : String;
begin
    Result := False;
    Match := nil;
    Tolerance := MilsToCoord(1.0);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Track := Iterator.FirstPCBObject;
    while Track <> nil do
    begin
        if TrackMatches(Track, X1, Y1, X2, Y2, Layer, Tolerance) then
        begin
            Match := Track;
            Break;
        end;
        Track := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);

    if Match <> nil then
    begin
        NetName := '';
        if Match.Net <> nil then
            NetName := Match.Net.Name;

        Log('REMOVED_STUB Net=' + NetName +
            ' X1mil=' + FloatToStr(CoordToMils(Match.X1)) +
            ' Y1mil=' + FloatToStr(CoordToMils(Match.Y1)) +
            ' X2mil=' + FloatToStr(CoordToMils(Match.X2)) +
            ' Y2mil=' + FloatToStr(CoordToMils(Match.Y2)));

        Board.RemovePCBObject(Match);
        Result := True;
    end
    else
    begin
        Log('NO_STUB_MATCH X1mil=' + FloatToStr(CoordToMils(X1)) +
            ' Y1mil=' + FloatToStr(CoordToMils(Y1)) +
            ' X2mil=' + FloatToStr(CoordToMils(X2)) +
            ' Y2mil=' + FloatToStr(CoordToMils(Y2)));
    end;
end;

procedure SaveCurrentPCB;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

procedure FixConnectivityDRC;
var
    Board        : IPCB_Board;
    AddedVias    : Integer;
    RemovedStubs : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            Log('ERROR no active PCB board');
            LogLines.SaveToFile(LOG_PATH);
            ShowMessage('No active PCB board. See log: ' + LOG_PATH);
            Exit;
        end;

        Log('FixConnectivityDRC started');
        AddedVias := 0;
        RemovedStubs := 0;

        PCBServer.PreProcess;

        if AddViaIfMissing(Board, MilsToCoord(5403.424), MilsToCoord(2925.55), 'GND') then
            Inc(AddedVias);
        if AddViaIfMissing(Board, MilsToCoord(4256.21), MilsToCoord(3091.79), 'JTAG_TCK') then
            Inc(AddedVias);

        if RemoveExactTrack(Board, MilsToCoord(3787.41), MilsToCoord(3644.962),
                           MilsToCoord(3787.41), MilsToCoord(3665.0), eBottomLayer) then
            Inc(RemovedStubs);
        if RemoveExactTrack(Board, MilsToCoord(3780.668), MilsToCoord(3671.742),
                           MilsToCoord(3787.41), MilsToCoord(3665.0), eBottomLayer) then
            Inc(RemovedStubs);
        if RemoveExactTrack(Board, MilsToCoord(3765.0), MilsToCoord(3671.742),
                           MilsToCoord(3780.668), MilsToCoord(3671.742), eBottomLayer) then
            Inc(RemovedStubs);
        if RemoveExactTrack(Board, MilsToCoord(6504.786), MilsToCoord(2799.0),
                           MilsToCoord(6504.786), MilsToCoord(2847.0), eTopLayer) then
            Inc(RemovedStubs);

        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Added vias: ' + IntToStr(AddedVias));
        Log('Removed stubs: ' + IntToStr(RemovedStubs));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Connectivity fix complete. Added vias: ' + IntToStr(AddedVias) +
            ', removed stubs: ' + IntToStr(RemovedStubs) + '. Log: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;
