{ EG4S20 core board placement helper.

  Run with EG4S20_CoreBoard.PcbDoc active.
  Coordinates below are relative to the 100 mm x 68 mm board's lower-left
  corner.  Placement follows the provided reference photos:
  top side = FPGA, display, keys, buzzer, USB connectors;
  bottom side = power, USB/JTAG controller, flash and small support ICs.
}

const
    BOARD_LEFT_MM   = 71.2469873;
    BOARD_BOTTOM_MM = 59.3089873;
    BOARD_WIDTH_MM  = 100.0;
    BOARD_HEIGHT_MM = 68.0;
    PCB_PATH        = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH        = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_AutoLayout_Route.log';
    AUDIT_PATH      = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_Boundary_Audit.log';

var
    LogLines : TStringList;

function AbsX(LocalMM : Double) : Integer;
begin
    Result := MMsToCoord(BOARD_LEFT_MM + LocalMM);
end;

function AbsY(LocalMM : Double) : Integer;
begin
    Result := MMsToCoord(BOARD_BOTTOM_MM + LocalMM);
end;

function CoordDelta(Target, Current : TCoord) : TCoord;
begin
    if Target >= Current then
        Result := Target - Current
    else
        Result := -(Current - Target);
end;

procedure Log(Msg : String);
begin
    if LogLines <> nil then
        LogLines.Add(Msg);
end;

function GetActivePCBBoard : IPCB_Board;
var
    Server : IPCB_ServerInterface;
begin
    Server := PCBServer;
    Result := Server.GetCurrentPCBBoard;
end;

function CurrentOrOpenedBoard : IPCB_Board; forward;

function FindComponent(Board : IPCB_Board; Designator : String) : IPCB_Component;
var
    Iterator : IPCB_BoardIterator;
    Comp     : IPCB_Component;
    NameText : String;
begin
    Result := nil;
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Comp := Iterator.FirstPCBObject;
    while Comp <> nil do
    begin
        NameText := '';
        if Comp.Name <> nil then
            NameText := Comp.Name.Text;

        if NameText = Designator then
        begin
            Result := Comp;
            Break;
        end;

        Comp := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

procedure BeginObjModify(Obj : IPCB_Primitive);
begin
    PCBServer.SendMessageToRobots(Obj.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
end;

procedure EndObjModify(Obj : IPCB_Primitive);
begin
    PCBServer.SendMessageToRobots(Obj.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
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
    if ExistingViaAt(Board, X, Y, NetName) then Exit;

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

function RemoveExactTrack(Board : IPCB_Board; X1, Y1, X2, Y2 : TCoord; Layer : TLayer) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Track     : IPCB_Track;
    Match     : IPCB_Track;
    Tolerance : TCoord;
    NetName   : String;
begin
    Result := False;
    Tolerance := MilsToCoord(1.0);
    Match := nil;

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
    end;
end;

function MoveComponentPrimitives(Comp : IPCB_Component; DeltaX, DeltaY : TCoord) : Integer;
var
    Iterator : IPCB_GroupIterator;
    Prim     : IPCB_Primitive;
begin
    Result := 0;
    Iterator := Comp.GroupIterator_Create;
    Iterator.AddFilter_ObjectSet(AllPrimitives);
    Iterator.AddFilter_LayerSet(AllLayers);

    Prim := Iterator.FirstPCBObject;
    while Prim <> nil do
    begin
        BeginObjModify(Prim);
        Prim.MoveByXY(DeltaX, DeltaY);
        EndObjModify(Prim);
        Inc(Result);
        Prim := Iterator.NextPCBObject;
    end;

    Comp.GroupIterator_Destroy(Iterator);
end;

procedure PlaceComp(Board : IPCB_Board; Designator : String; LocalX, LocalY : Double;
                    OnBottom : Boolean; RotationDeg : Double);
var
    Comp       : IPCB_Component;
    Layer      : TLayer;
    TargetX    : TCoord;
    TargetY    : TCoord;
    DeltaX     : TCoord;
    DeltaY     : TCoord;
    RotDelta   : Double;
    PrimCount  : Integer;
begin
    Comp := FindComponent(Board, Designator);
    if Comp = nil then
    begin
        Log('MISSING ' + Designator);
        Exit;
    end;

    if OnBottom then
        Layer := eBottomLayer
    else
        Layer := eTopLayer;

    TargetX := AbsX(LocalX);
    TargetY := AbsY(LocalY);

    BeginObjModify(Comp);
    if Comp.Layer <> Layer then
        Comp.FlipComponent;

    DeltaX := CoordDelta(TargetX, Comp.X);
    DeltaY := CoordDelta(TargetY, Comp.Y);
    Comp.MoveByXY(DeltaX, DeltaY);
    PrimCount := MoveComponentPrimitives(Comp, DeltaX, DeltaY);

    RotDelta := RotationDeg - Comp.Rotation;
    if Abs(RotDelta) > 0.001 then
        Comp.RotateAroundXY(TargetX, TargetY, RotDelta);

    Comp.Layer := Layer;
    Comp.Rotation := RotationDeg;
    Comp.Rebuild;
    Comp.SetState_xSizeySize;
    EndObjModify(Comp);

    if OnBottom then
        Log('BOTTOM ' + Designator + ' @ ' + FloatToStr(LocalX) + ',' + FloatToStr(LocalY) +
            ' moved ' + IntToStr(PrimCount) + ' primitives')
    else
        Log('TOP    ' + Designator + ' @ ' + FloatToStr(LocalX) + ',' + FloatToStr(LocalY) +
            ' moved ' + IntToStr(PrimCount) + ' primitives');
end;

procedure SaveCurrentPCB;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

procedure ApplyReferencePlacement;
var
    Board : IPCB_Board;
begin
    LogLines := TStringList.Create;
    try
        Board := GetActivePCBBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running ApplyReferencePlacement.');
            Exit;
        end;

        Log('ApplyReferencePlacement started');
        PCBServer.PreProcess;

        { Top/user side. }
        PlaceComp(Board, 'U1',  27.0, 39.0, False, 0.0);   { FPGA BGA }
        PlaceComp(Board, 'DS1', 68.0, 49.5, False, 0.0);   { 4-digit display }
        PlaceComp(Board, 'BZ1', 15.0, 29.0, False, 0.0);
        PlaceComp(Board, 'Y1',  17.0, 48.0, False, 0.0);   { main clock near FPGA }
        PlaceComp(Board, 'Y2',  45.0, 36.0, False, 0.0);
        PlaceComp(Board, 'SW1', 65.0, 31.0, False, 0.0);
        PlaceComp(Board, 'SW2', 78.0, 31.0, False, 0.0);
        PlaceComp(Board, 'SW3', 65.0, 20.0, False, 0.0);
        PlaceComp(Board, 'SW4', 78.0, 20.0, False, 0.0);
        PlaceComp(Board, 'J1',  83.6, 54.0, False, 90.0);  { USB/JTAG edge connector }
        PlaceComp(Board, 'J2',  83.6, 13.0, False, 90.0);  { USB/UART edge connector }

        { Bottom/support side. }
        PlaceComp(Board, 'U2',  35.0, 39.0, True, 0.0);    { SPI flash close to FPGA }
        PlaceComp(Board, 'U3',  72.0, 51.0, True, 90.0);
        PlaceComp(Board, 'U4',  81.0, 54.0, True, 90.0);
        PlaceComp(Board, 'U5',  81.0, 13.0, True, 90.0);
        PlaceComp(Board, 'U6',  72.0, 16.0, True, 90.0);
        PlaceComp(Board, 'U7',  66.0, 15.0, True, 0.0);
        PlaceComp(Board, 'U8',  18.0, 14.0, True, 0.0);
        PlaceComp(Board, 'U9',  31.0, 14.0, True, 0.0);
        PlaceComp(Board, 'U10', 18.0, 25.5, True, 0.0);
        PlaceComp(Board, 'D1',  43.0, 13.0, True, 0.0);
        PlaceComp(Board, 'FB1', 51.0, 13.0, True, 0.0);
        PlaceComp(Board, 'C1',  25.0, 25.5, True, 0.0);
        PlaceComp(Board, 'C2',  25.0, 30.0, True, 0.0);

        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('ApplyReferencePlacement finished');
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Placement complete. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

procedure ReportZeroLengthFromTos;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    FromTo   : IPCB_FromTo;
    Count    : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := GetActivePCBBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running ReportZeroLengthFromTos.');
            Exit;
        end;

        Log('ReportZeroLengthFromTos started');
        Count := 0;
        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eFromToObject));
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        FromTo := Iterator.FirstPCBObject;
        while FromTo <> nil do
        begin
            if FromTo.RoutedLength = 0 then
            begin
                Inc(Count);
                Log('ZERO_LENGTH Net=' + FromTo.NetName +
                    ' From=' + FromTo.FromPad +
                    ' To=' + FromTo.ToPad);
            end;
            FromTo := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);
        Log('Zero-length FromTo count: ' + IntToStr(Count));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('From-To report complete. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

procedure ReportAllFromTos;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    FromTo   : IPCB_FromTo;
    Count    : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := GetActivePCBBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running ReportAllFromTos.');
            Exit;
        end;

        Log('ReportAllFromTos started');
        Count := 0;
        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eFromToObject));
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        FromTo := Iterator.FirstPCBObject;
        while FromTo <> nil do
        begin
            Inc(Count);
            Log('FROMTO Len=' + IntToStr(FromTo.RoutedLength) +
                ' Net=' + FromTo.NetName +
                ' From=' + FromTo.FromPad +
                ' To=' + FromTo.ToPad);
            FromTo := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);
        Log('FromTo count: ' + IntToStr(Count));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('All From-To report complete. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

procedure ReportConnections;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    Conn     : IPCB_Connection;
    Count    : Integer;
    NetName  : String;
begin
    LogLines := TStringList.Create;
    try
        Board := GetActivePCBBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running ReportConnections.');
            Exit;
        end;

        Log('ReportConnections started');
        Count := 0;
        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eConnectionObject));
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        Conn := Iterator.FirstPCBObject;
        while Conn <> nil do
        begin
            Inc(Count);
            NetName := '';
            if Conn.Net <> nil then
                NetName := Conn.Net.Name;

            Log('CONNECTION Net=' + NetName +
                ' Mode=' + IntToStr(Conn.Mode) +
                ' Layer1=' + IntToStr(Conn.Layer1) +
                ' Layer2=' + IntToStr(Conn.Layer2) +
                ' X1mil=' + FloatToStr(CoordToMils(Conn.X1)) +
                ' Y1mil=' + FloatToStr(CoordToMils(Conn.Y1)) +
                ' X2mil=' + FloatToStr(CoordToMils(Conn.X2)) +
                ' Y2mil=' + FloatToStr(CoordToMils(Conn.Y2)));

            Conn := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);
        Log('Connection count: ' + IntToStr(Count));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Connection report complete. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

procedure AddTopGndShorts;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    Conn     : IPCB_Connection;
    Track    : IPCB_Track;
    Added    : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := GetActivePCBBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running AddTopGndShorts.');
            Exit;
        end;

        Log('AddTopGndShorts started');
        Added := 0;
        PCBServer.PreProcess;

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eConnectionObject));
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        Conn := Iterator.FirstPCBObject;
        while Conn <> nil do
        begin
            if (Conn.Net <> nil) and (Conn.Net.Name = 'GND') then
            begin
                if (Conn.X1 <> Conn.X2) or (Conn.Y1 <> Conn.Y2) then
                begin
                    Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
                    Track.X1 := Conn.X1;
                    Track.Y1 := Conn.Y1;
                    Track.X2 := Conn.X2;
                    Track.Y2 := Conn.Y2;
                    Track.Width := MilsToCoord(6);
                    Track.Layer := eTopLayer;
                    Track.Net := Conn.Net;
                    Board.AddPCBObject(Track);
                    Inc(Added);
                    Log('ADDED_GND_TOP X1mil=' + FloatToStr(CoordToMils(Conn.X1)) +
                        ' Y1mil=' + FloatToStr(CoordToMils(Conn.Y1)) +
                        ' X2mil=' + FloatToStr(CoordToMils(Conn.X2)) +
                        ' Y2mil=' + FloatToStr(CoordToMils(Conn.Y2)));
                end;
            end;
            Conn := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);
        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Added GND shorts: ' + IntToStr(Added));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Added GND shorts: ' + IntToStr(Added) + '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

procedure FixConnectivityDRC;
var
    Board       : IPCB_Board;
    AddedVias   : Integer;
    RemovedStub : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running FixConnectivityDRC.');
            Exit;
        end;

        Log('FixConnectivityDRC started');
        AddedVias := 0;
        RemovedStub := 0;

        PCBServer.PreProcess;

        if AddViaIfMissing(Board, MilsToCoord(5403.424), MilsToCoord(2925.55), 'GND') then
            Inc(AddedVias);
        if AddViaIfMissing(Board, MilsToCoord(4256.21), MilsToCoord(3091.79), 'JTAG_TCK') then
            Inc(AddedVias);

        if RemoveExactTrack(Board, MilsToCoord(3787.41), MilsToCoord(3644.962),
                           MilsToCoord(3787.41), MilsToCoord(3665.0), eBottomLayer) then
            Inc(RemovedStub);
        if RemoveExactTrack(Board, MilsToCoord(3780.668), MilsToCoord(3671.742),
                           MilsToCoord(3787.41), MilsToCoord(3665.0), eBottomLayer) then
            Inc(RemovedStub);
        if RemoveExactTrack(Board, MilsToCoord(3765.0), MilsToCoord(3671.742),
                           MilsToCoord(3780.668), MilsToCoord(3671.742), eBottomLayer) then
            Inc(RemovedStub);
        if RemoveExactTrack(Board, MilsToCoord(6504.786), MilsToCoord(2799.0),
                           MilsToCoord(6504.786), MilsToCoord(2847.0), eTopLayer) then
            Inc(RemovedStub);

        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Added vias: ' + IntToStr(AddedVias));
        Log('Removed stubs: ' + IntToStr(RemovedStub));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Connectivity DRC fix complete. Added vias: ' + IntToStr(AddedVias) +
            ', removed stubs: ' + IntToStr(RemovedStub) +
            '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

procedure RunSilkscreenPreparation;
begin
    ResetParameters;
    RunProcess('PCB:ClipSilkScreen');
end;

function ClampXInsideBoard(Value : TCoord) : TCoord;
var
    MinX : TCoord;
    MaxX : TCoord;
begin
    MinX := AbsX(0.25);
    MaxX := AbsX(BOARD_WIDTH_MM - 0.25);

    if Value < MinX then
        Result := MinX
    else if Value > MaxX then
        Result := MaxX
    else
        Result := Value;
end;

function ClampYInsideBoard(Value : TCoord) : TCoord;
var
    MinY : TCoord;
    MaxY : TCoord;
begin
    MinY := AbsY(0.25);
    MaxY := AbsY(BOARD_HEIGHT_MM - 0.25);

    if Value < MinY then
        Result := MinY
    else if Value > MaxY then
        Result := MaxY
    else
        Result := Value;
end;

function CoordDeltaFromMM(ValueMM : Double) : TCoord;
begin
    if ValueMM < 0.0 then
        Result := -MMsToCoord(Abs(ValueMM))
    else
        Result := MMsToCoord(ValueMM);
end;

function IsAuditedPhysicalPrimitive(Obj : IPCB_Primitive) : Boolean;
begin
    Result := (Obj.ObjectId <> eTextObject) and
              (Obj.ObjectId <> eNetObject) and
              (Obj.ObjectId <> eConnectionObject) and
              (Obj.ObjectId <> eComponentObject) and
              (Obj.Layer <> eMechanical6);
end;

procedure SetCompOrigin(Board : IPCB_Board; Designator : String; LocalX, LocalY : Double;
                        OnBottom : Boolean; RotationDeg : Double);
var
    Comp  : IPCB_Component;
    Layer : TLayer;
begin
    Comp := FindComponent(Board, Designator);
    if Comp = nil then
    begin
        Log('MISSING ' + Designator);
        Exit;
    end;

    if OnBottom then
        Layer := eBottomLayer
    else
        Layer := eTopLayer;

    BeginObjModify(Comp);
    Comp.X := AbsX(LocalX);
    Comp.Y := AbsY(LocalY);
    Comp.Layer := Layer;
    Comp.Rotation := RotationDeg;
    Comp.Rebuild;
    Comp.SetState_xSizeySize;
    EndObjModify(Comp);

    Log('ORIGIN ' + Designator + ' @ ' + FloatToStr(LocalX) + ',' + FloatToStr(LocalY));
end;

procedure MoveCompByMM(Board : IPCB_Board; Designator : String; DeltaXMM, DeltaYMM : Double);
var
    Comp : IPCB_Component;
begin
    Comp := FindComponent(Board, Designator);
    if Comp = nil then
    begin
        Log('MISSING ' + Designator);
        Exit;
    end;

    BeginObjModify(Comp);
    Comp.MoveByXY(CoordDeltaFromMM(DeltaXMM), CoordDeltaFromMM(DeltaYMM));
    Comp.Rebuild;
    Comp.SetState_xSizeySize;
    EndObjModify(Comp);
    Log('MOVED ' + Designator + ' DeltaXMM=' + FloatToStr(DeltaXMM) +
        ' DeltaYMM=' + FloatToStr(DeltaYMM));
end;

function RectOutsideBoard(R : TCoordRect; Margin : TCoord) : Boolean; forward;
function BoardRightCoord : TCoord; forward;
function BoardTopCoord : TCoord; forward;

procedure ClearSelection(Board : IPCB_Board);
var
    Iterator : IPCB_BoardIterator;
    Obj      : IPCB_Primitive;
begin
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(AllPrimitives);
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Obj := Iterator.FirstPCBObject;
    while Obj <> nil do
    begin
        Obj.Selected := False;
        Obj := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

function AddSelectedOutlineTrack(Board : IPCB_Board; X1, Y1, X2, Y2 : TCoord) : IPCB_Track;
begin
    Result := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    Result.X1 := X1;
    Result.Y1 := Y1;
    Result.X2 := X2;
    Result.Y2 := Y2;
    Result.Width := MMsToCoord(0.02);
    Result.Layer := eMechanical6;
    Board.AddPCBObject(Result);
    Result.Selected := True;
end;

procedure RedefineBoardShapeFromSelectedOutline(Board : IPCB_Board);
var
    LeftX   : TCoord;
    RightX  : TCoord;
    BottomY : TCoord;
    TopY    : TCoord;
begin
    LeftX := AbsX(0.0);
    RightX := BoardRightCoord;
    BottomY := AbsY(0.0);
    TopY := BoardTopCoord;

    ClearSelection(Board);
    AddSelectedOutlineTrack(Board, LeftX, BottomY, RightX, BottomY);
    AddSelectedOutlineTrack(Board, RightX, BottomY, RightX, TopY);
    AddSelectedOutlineTrack(Board, RightX, TopY, LeftX, TopY);
    AddSelectedOutlineTrack(Board, LeftX, TopY, LeftX, BottomY);
    Board.ViewManager_FullUpdate;

    Log('Selected board outline: width=' + FloatToStr(BOARD_WIDTH_MM) +
        'mm height=' + FloatToStr(BOARD_HEIGHT_MM) + 'mm');
end;

function MovePadAtMil(Board : IPCB_Board; CenterXMil, CenterYMil, DeltaXMil, DeltaYMil : Double) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Pad       : IPCB_Pad;
    Tolerance : TCoord;
begin
    Result := False;
    Tolerance := MilsToCoord(1.0);

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
            BeginObjModify(Pad);
            Pad.MoveByXY(MilsToCoord(DeltaXMil), MilsToCoord(DeltaYMil));
            EndObjModify(Pad);
            Log('MOVED_PAD CenterMil=' + FloatToStr(CenterXMil) + ',' +
                FloatToStr(CenterYMil) + ' DeltaMil=' + FloatToStr(DeltaXMil) +
                ',' + FloatToStr(DeltaYMil));
            Result := True;
            Break;
        end;
        Pad := Iterator.NextPCBObject;
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

function RemoveDefaultDesignatorTextsFromBoard(Board : IPCB_Board) : Integer;
var
    Iterator : IPCB_BoardIterator;
    TextObj  : IPCB_Text;
    NextText : IPCB_Text;
begin
    Result := 0;
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eTextObject));
    Iterator.AddFilter_LayerSet(MkSet(eTopOverlay));
    Iterator.AddFilter_Method(eProcessAll);

    TextObj := Iterator.FirstPCBObject;
    while TextObj <> nil do
    begin
        NextText := Iterator.NextPCBObject;
        if (TextObj.Text = 'Designator1') and NearOriginText(TextObj.BoundingRectangle) then
        begin
            LogRect('REMOVED_DEFAULT_TEXT Text=' + TextObj.Text +
                ' Object=' + TextObj.ObjectIDString, TextObj.BoundingRectangle);
            Board.RemovePCBObject(TextObj);
            Inc(Result);
        end;
        TextObj := NextText;
    end;

    Board.BoardIterator_Destroy(Iterator);
end;

procedure FixBoundaryOverruns;
var
    Board       : IPCB_Board;
    Iterator    : IPCB_BoardIterator;
    Track       : IPCB_Track;
    NewX1       : TCoord;
    NewY1       : TCoord;
    NewX2       : TCoord;
    NewY2       : TCoord;
    FixedTracks : Integer;
    FixedPrims  : Integer;
    FixedNets   : Integer;
    Margin      : TCoord;
    Obj         : IPCB_Primitive;
    R           : TCoordRect;
    ShiftX      : TCoord;
    ShiftY      : TCoord;
    GndNet      : IPCB_Net;
    MovedPads   : Integer;
    RemovedText : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running FixBoundaryOverruns.');
            Exit;
        end;

        Log('FixBoundaryOverruns started');
        FixedTracks := 0;
        FixedPrims := 0;
        FixedNets := 0;
        MovedPads := 0;
        RemovedText := 0;
        Margin := MMsToCoord(0.01);
        GndNet := FirstNetByName(Board, 'GND');
        PCBServer.PreProcess;

        SetCompOrigin(Board, 'J1', 81.4, 54.0, False, 90.0);
        SetCompOrigin(Board, 'J2', 81.4, 13.0, False, 90.0);
        RedefineBoardShapeFromSelectedOutline(Board);

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        Track := Iterator.FirstPCBObject;
        while Track <> nil do
        begin
            if (Track.Net <> nil) and (Track.Net.Name = 'GND') and
               RectOutsideBoard(Track.BoundingRectangle, Margin) then
            begin
                NewX1 := ClampXInsideBoard(Track.X1);
                NewY1 := ClampYInsideBoard(Track.Y1);
                NewX2 := ClampXInsideBoard(Track.X2);
                NewY2 := ClampYInsideBoard(Track.Y2);

                BeginObjModify(Track);
                Track.X1 := NewX1;
                Track.Y1 := NewY1;
                Track.X2 := NewX2;
                Track.Y2 := NewY2;
                EndObjModify(Track);
                Inc(FixedTracks);
            end;
            Track := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(AllPrimitives);
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        Obj := Iterator.FirstPCBObject;
        while Obj <> nil do
        begin
            if IsAuditedPhysicalPrimitive(Obj) and RectOutsideBoard(Obj.BoundingRectangle, Margin) then
            begin
                R := Obj.BoundingRectangle;
                ShiftX := 0;
                ShiftY := 0;

                if R.Left < AbsX(0.0) + Margin then
                    ShiftX := AbsX(0.0) + Margin - R.Left
                else if R.Right > BoardRightCoord - Margin then
                    ShiftX := BoardRightCoord - Margin - R.Right;

                if R.Bottom < AbsY(0.0) + Margin then
                    ShiftY := AbsY(0.0) + Margin - R.Bottom
                else if R.Top > BoardTopCoord - Margin then
                    ShiftY := BoardTopCoord - Margin - R.Top;

                if (ShiftX <> 0) or (ShiftY <> 0) then
                begin
                    BeginObjModify(Obj);
                    Obj.MoveByXY(ShiftX, ShiftY);
                    EndObjModify(Obj);
                    Inc(FixedPrims);
                end;
            end;
            Obj := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        if GndNet <> nil then
        begin
            Iterator := Board.BoardIterator_Create;
            Iterator.AddFilter_ObjectSet(MkSet(ePadObject, eTrackObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);

            Obj := Iterator.FirstPCBObject;
            while Obj <> nil do
            begin
                R := Obj.BoundingRectangle;
                if (Obj.Net = nil) and
                   (R.Right > AbsX(98.0)) and
                   (R.Bottom > AbsY(8.0)) and
                   (R.Top < AbsY(62.0)) then
                begin
                    BeginObjModify(Obj);
                    Obj.Net := GndNet;
                    EndObjModify(Obj);
                    Inc(FixedNets);
                end;
                Obj := Iterator.NextPCBObject;
            end;

            Board.BoardIterator_Destroy(Iterator);
        end;

        if MovePadAtMil(Board, 6671.520, 2965.528, -4.0, 0.0) then
            Inc(MovedPads);
        if MovePadAtMil(Board, 6671.520, 4579.700, -4.0, 0.0) then
            Inc(MovedPads);

        RemovedText := RemoveDefaultDesignatorTextsFromBoard(Board);

        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        ResetParameters;
        AddStringParameter('Mode', 'BOARDOUTLINE_FROM_SEL_PRIMS');
        RunProcess('PCB:PlaceBoardOutline');
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Set J1/J2 component origins at local X=81.4mm');
        Log('Fixed GND tracks: ' + IntToStr(FixedTracks));
        Log('Moved remaining outside primitives: ' + IntToStr(FixedPrims));
        Log('Assigned right-edge free pads/tracks to GND: ' + IntToStr(FixedNets));
        Log('Moved right-edge solder-mask pads: ' + IntToStr(MovedPads));
        Log('Removed default designator texts: ' + IntToStr(RemovedText));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('100mm x 68mm board shape applied. Fixed GND tracks: ' +
            IntToStr(FixedTracks) + ', moved remaining outside primitives: ' +
            IntToStr(FixedPrims) + ', assigned free GND objects: ' +
            IntToStr(FixedNets) + ', moved mask pads: ' + IntToStr(MovedPads) +
            ', removed default texts: ' + IntToStr(RemovedText) +
            '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

procedure ApplySelectedBoardShape;
begin
    ResetParameters;
    AddStringParameter('Mode', 'BOARDOUTLINE_FROM_SEL_PRIMS');
    RunProcess('PCB:PlaceBoardOutline');
    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
    ShowMessage('Board shape redefined from selected outline. Save the PCB and run AuditBoundary.');
end;

function CurrentOrOpenedBoard : IPCB_Board;
var
    Doc : IServerDocument;
begin
    Doc := Client.OpenDocument('PCB', PCB_PATH);
    if Doc <> nil then
    begin
        Client.ShowDocument(Doc);
        Result := GetActivePCBBoard;
        if Result <> nil then Exit;
    end;

    Result := GetActivePCBBoard;
end;

function RectOutsideBoard(R : TCoordRect; Margin : TCoord) : Boolean;
var
    BoardLeft   : TCoord;
    BoardRight  : TCoord;
    BoardBottom : TCoord;
    BoardTop    : TCoord;
begin
    BoardLeft := AbsX(0.0);
    BoardRight := AbsX(BOARD_WIDTH_MM);
    BoardBottom := AbsY(0.0);
    BoardTop := AbsY(BOARD_HEIGHT_MM);

    Result := (R.Left < BoardLeft - Margin) or
              (R.Right > BoardRight + Margin) or
              (R.Bottom < BoardBottom - Margin) or
              (R.Top > BoardTop + Margin);
end;

function BoardRightCoord : TCoord;
begin
    Result := AbsX(BOARD_WIDTH_MM);
end;

function BoardTopCoord : TCoord;
begin
    Result := AbsY(BOARD_HEIGHT_MM);
end;

procedure LogRect(Prefix : String; R : TCoordRect);
begin
    Log(Prefix +
        ' LeftMM=' + FloatToStr(CoordToMMs(R.Left)) +
        ' RightMM=' + FloatToStr(CoordToMMs(R.Right)) +
        ' BottomMM=' + FloatToStr(CoordToMMs(R.Bottom)) +
        ' TopMM=' + FloatToStr(CoordToMMs(R.Top)));
end;

procedure LogComponentChildren(Comp : IPCB_Component);
var
    Iterator : IPCB_GroupIterator;
    Prim     : IPCB_Primitive;
begin
    Iterator := Comp.GroupIterator_Create;
    Iterator.AddFilter_ObjectSet(AllPrimitives);
    Iterator.AddFilter_LayerSet(AllLayers);

    Prim := Iterator.FirstPCBObject;
    while Prim <> nil do
    begin
        LogRect('  CHILD Primitive=' + Prim.ObjectIDString +
            ' Layer=' + IntToStr(Prim.Layer), Prim.BoundingRectangle);
        Prim := Iterator.NextPCBObject;
    end;

    Comp.GroupIterator_Destroy(Iterator);
end;

function ComponentHasOutsideChildren(Comp : IPCB_Component; Margin : TCoord) : Boolean;
var
    Iterator : IPCB_GroupIterator;
    Prim     : IPCB_Primitive;
begin
    Result := False;
    Iterator := Comp.GroupIterator_Create;
    Iterator.AddFilter_ObjectSet(AllPrimitives);
    Iterator.AddFilter_LayerSet(AllLayers);

    Prim := Iterator.FirstPCBObject;
    while Prim <> nil do
    begin
        if IsAuditedPhysicalPrimitive(Prim) and RectOutsideBoard(Prim.BoundingRectangle, Margin) then
        begin
            LogRect('  CHILD_OUTSIDE Primitive=' + Prim.ObjectIDString +
                ' Layer=' + IntToStr(Prim.Layer), Prim.BoundingRectangle);
            Result := True;
        end;
        Prim := Iterator.NextPCBObject;
    end;

    Comp.GroupIterator_Destroy(Iterator);
end;

procedure AuditBoundary;
var
    Board       : IPCB_Board;
    Iterator    : IPCB_BoardIterator;
    Obj         : IPCB_Primitive;
    Comp        : IPCB_Component;
    R           : TCoordRect;
    Count       : Integer;
    Outside     : Integer;
    CompCount   : Integer;
    CompOutside : Integer;
    Margin      : TCoord;
    NetName     : String;
    NameText    : String;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running AuditBoundary.');
            Exit;
        end;

        Margin := MMsToCoord(0.01);
        Count := 0;
        Outside := 0;
        CompCount := 0;
        CompOutside := 0;

        Log('AuditBoundary started');
        Log('Expected board: ' + FloatToStr(BOARD_WIDTH_MM) +
            ' mm x ' + FloatToStr(BOARD_HEIGHT_MM) + ' mm');
        Log('Expected left/bottom MM: ' + FloatToStr(BOARD_LEFT_MM) + ', ' + FloatToStr(BOARD_BOTTOM_MM));

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(AllPrimitives);
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        Obj := Iterator.FirstPCBObject;
        while Obj <> nil do
        begin
            if IsAuditedPhysicalPrimitive(Obj) then
            begin
                Inc(Count);
                R := Obj.BoundingRectangle;
                if RectOutsideBoard(R, Margin) then
                begin
                    Inc(Outside);
                    NetName := '';
                    if Obj.Net <> nil then
                        NetName := Obj.Net.Name;
                    LogRect('OUTSIDE Primitive=' + Obj.ObjectIDString +
                        ' Layer=' + IntToStr(Obj.Layer) +
                        ' Net=' + NetName, R);
                end;
            end;
            Obj := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        Comp := Iterator.FirstPCBObject;
        while Comp <> nil do
        begin
            Inc(CompCount);
            if ComponentHasOutsideChildren(Comp, Margin) then
            begin
                Inc(CompOutside);
                NameText := '';
                if Comp.Name <> nil then
                    NameText := Comp.Name.Text;
                R := Comp.BoundingRectangleNoNameComment;
                LogRect('COMP_OUTSIDE ' + NameText, R);
            end;
            Comp := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        Log('Primitive count: ' + IntToStr(Count));
        Log('Outside primitive count: ' + IntToStr(Outside));
        Log('Component count: ' + IntToStr(CompCount));
        Log('Outside component count: ' + IntToStr(CompOutside));
        LogLines.SaveToFile(AUDIT_PATH);
        ShowMessage('Boundary audit complete. Outside primitives: ' + IntToStr(Outside) +
            ', outside components: ' + IntToStr(CompOutside) +
            '. Log saved to: ' + AUDIT_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;
