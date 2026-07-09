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
    LOG_PATH        = 'C:\Users\fpna1\SummerProject\eg4s20-bg256-core-board-main\AltiumProject\EG4S20_SummerProject\PCB_AutoLayout_Route.log';

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

procedure Log(Msg : String);
begin
    if LogLines <> nil then
        LogLines.Add(Msg);
end;

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

    DeltaX := TargetX - Comp.X;
    DeltaY := TargetY - Comp.Y;
    Comp.MoveByXY(DeltaX, DeltaY);

    RotDelta := RotationDeg - Comp.Rotation;
    if Abs(RotDelta) > 0.001 then
        Comp.RotateAroundXY(TargetX, TargetY, RotDelta);

    Comp.Layer := Layer;
    Comp.Rotation := RotationDeg;
    PrimCount := 0;
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
        Board := PCBServer.GetCurrentPCBBoard;
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
        PlaceComp(Board, 'J1',  86.0, 54.0, False, 90.0);  { USB/JTAG edge connector }
        PlaceComp(Board, 'J2',  86.0, 13.0, False, 90.0);  { USB/UART edge connector }

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
        Board := PCBServer.GetCurrentPCBBoard;
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
        Board := PCBServer.GetCurrentPCBBoard;
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
        Board := PCBServer.GetCurrentPCBBoard;
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
        Board := PCBServer.GetCurrentPCBBoard;
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
