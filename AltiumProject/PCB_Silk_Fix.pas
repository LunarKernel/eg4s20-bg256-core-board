const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_Silk_Fix.log';

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

function RectMatchesMil(R : TCoordRect; LeftMil, RightMil, BottomMil, TopMil : Double;
                        Tolerance : TCoord) : Boolean;
begin
    Result := CoordNear(R.Left, MilsToCoord(LeftMil), Tolerance) and
              CoordNear(R.Right, MilsToCoord(RightMil), Tolerance) and
              CoordNear(R.Bottom, MilsToCoord(BottomMil), Tolerance) and
              CoordNear(R.Top, MilsToCoord(TopMil), Tolerance);
end;

procedure LogRect(Prefix : String; R : TCoordRect);
begin
    Log(Prefix +
        ' LeftMil=' + FloatToStr(CoordToMils(R.Left)) +
        ' RightMil=' + FloatToStr(CoordToMils(R.Right)) +
        ' BottomMil=' + FloatToStr(CoordToMils(R.Bottom)) +
        ' TopMil=' + FloatToStr(CoordToMils(R.Top)));
end;

function RemoveByRect(Board : IPCB_Board; ObjectId : Integer; Layer : TLayer;
                      LeftMil, RightMil, BottomMil, TopMil : Double;
                      LabelText : String) : Boolean;
var
    Iterator  : IPCB_BoardIterator;
    Obj       : IPCB_Primitive;
    Match     : IPCB_Primitive;
    R         : TCoordRect;
    Tolerance : TCoord;
begin
    Result := False;
    Match := nil;
    Tolerance := MilsToCoord(0.75);

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(AllPrimitives);
    Iterator.AddFilter_LayerSet(MkSet(Layer));
    Iterator.AddFilter_Method(eProcessAll);

    Obj := Iterator.FirstPCBObject;
    while Obj <> nil do
    begin
        R := Obj.BoundingRectangle;
        if (Obj.ObjectId = ObjectId) and
           RectMatchesMil(R, LeftMil, RightMil, BottomMil, TopMil, Tolerance) then
        begin
            Match := Obj;
            Break;
        end;
        Obj := Iterator.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(Iterator);

    if Match <> nil then
    begin
        LogRect('REMOVED_SILK ' + LabelText +
            ' Object=' + Match.ObjectIDString +
            ' ObjId=' + IntToStr(Match.ObjectId) +
            ' Layer=' + IntToStr(Match.Layer), Match.BoundingRectangle);
        Board.RemovePCBObject(Match);
        Result := True;
    end
    else
    begin
        Log('NO_MATCH ' + LabelText +
            ' ObjId=' + IntToStr(ObjectId) +
            ' Layer=' + IntToStr(Layer) +
            ' LeftMil=' + FloatToStr(LeftMil) +
            ' RightMil=' + FloatToStr(RightMil) +
            ' BottomMil=' + FloatToStr(BottomMil) +
            ' TopMil=' + FloatToStr(TopMil));
    end;
end;

procedure SaveCurrentPCB;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

procedure FixSilkDRC;
var
    Board   : IPCB_Board;
    Removed : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running FixSilkDRC.');
            Exit;
        end;

        Removed := 0;
        Log('FixSilkDRC started');
        PCBServer.PreProcess;

        if RemoveByRect(Board, 6, eBottomOverlay, 4342.912, 4362.912, 2764.81, 2928.81, 'bottom fill near U10') then Inc(Removed);
        if RemoveByRect(Board, 5, eBottomOverlay, 3436.048, 3606.0, 3429.0, 3508.981, 'bottom text U10') then Inc(Removed);

        if RemoveByRect(Board, 5, eTopOverlay, 3492.492, 3592.466, 4265.933, 4345.913, 'top text U1') then Inc(Removed);
        if RemoveByRect(Board, 11, eTopOverlay, 3533.346, 3572.716, 4165.708, 4205.078, 'top polyregion near U1') then Inc(Removed);

        if RemoveByRect(Board, 4, eTopOverlay, 6535.84, 6742.005, 3020.55, 3030.55, 'lower connector top silk line') then Inc(Removed);
        if RemoveByRect(Board, 4, eTopOverlay, 6742.008, 6791.89, 3020.55, 3030.55, 'lower connector top right line') then Inc(Removed);
        if RemoveByRect(Board, 4, eTopOverlay, 6781.284, 6791.284, 2752.81, 2959.66, 'lower connector right vertical') then Inc(Removed);
        if RemoveByRect(Board, 4, eTopOverlay, 6781.89, 6791.89, 2934.724, 3030.55, 'lower connector right short vertical') then Inc(Removed);

        if RemoveByRect(Board, 4, eTopOverlay, 6535.839, 6742.005, 4634.724, 4644.724, 'upper connector top silk line') then Inc(Removed);
        if RemoveByRect(Board, 4, eTopOverlay, 6742.008, 6791.89, 4634.724, 4644.724, 'upper connector top right line') then Inc(Removed);
        if RemoveByRect(Board, 4, eTopOverlay, 6781.284, 6791.284, 4366.984, 4573.834, 'upper connector right vertical') then Inc(Removed);
        if RemoveByRect(Board, 4, eTopOverlay, 6781.89, 6791.89, 4548.898, 4644.724, 'upper connector right short vertical') then Inc(Removed);

        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Removed silk objects: ' + IntToStr(Removed));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Silk DRC fix complete. Removed objects: ' + IntToStr(Removed) +
            '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;

