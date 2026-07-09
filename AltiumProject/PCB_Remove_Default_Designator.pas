const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_Remove_Default_Designator.log';

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

procedure LogRect(Prefix : String; R : TCoordRect);
begin
    Log(Prefix +
        ' LeftMil=' + FloatToStr(CoordToMils(R.Left)) +
        ' RightMil=' + FloatToStr(CoordToMils(R.Right)) +
        ' BottomMil=' + FloatToStr(CoordToMils(R.Bottom)) +
        ' TopMil=' + FloatToStr(CoordToMils(R.Top)));
end;

procedure SaveCurrentPCB;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

procedure RemoveDefaultDesignatorTexts;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    TextObj  : IPCB_Text;
    R        : TCoordRect;
    Removed  : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running RemoveDefaultDesignatorTexts.');
            Exit;
        end;

        Removed := 0;
        Log('RemoveDefaultDesignatorTexts started');

        PCBServer.PreProcess;

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eTextObject));
        Iterator.AddFilter_LayerSet(MkSet(eTopOverlay));
        Iterator.AddFilter_Method(eProcessAll);

        TextObj := Iterator.FirstPCBObject;
        while TextObj <> nil do
        begin
            R := TextObj.BoundingRectangle;
            if (TextObj.Text = 'Designator1') and NearOriginText(R) then
            begin
                LogRect('REMOVED_DEFAULT_TEXT Text=' + TextObj.Text +
                    ' Object=' + TextObj.ObjectIDString, R);
                Board.RemovePCBObject(TextObj);
                Inc(Removed);
            end;
            TextObj := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Removed default texts: ' + IntToStr(Removed));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Removed default top overlay texts near origin: ' + IntToStr(Removed) +
            '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;
