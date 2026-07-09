const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_Antenna_Fix_Final.log';

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
        Log('NO_STUB_MATCH');
end;

procedure SaveCurrentPCB;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

procedure FixFinalAntenna;
var
    Board   : IPCB_Board;
    Removed : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            Log('ERROR no active PCB board');
            LogLines.SaveToFile(LOG_PATH);
            ShowMessage('No active PCB board. Log: ' + LOG_PATH);
            Exit;
        end;

        Log('FixFinalAntenna started');
        Removed := 0;
        PCBServer.PreProcess;
        if RemoveExactTrack(Board, MilsToCoord(3765.0), MilsToCoord(3671.742),
                           MilsToCoord(3780.668), MilsToCoord(3671.742), eBottomLayer) then
            Inc(Removed);
        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Removed stubs: ' + IntToStr(Removed));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Final antenna fix complete. Removed stubs: ' +
            IntToStr(Removed) + '. Log: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;
