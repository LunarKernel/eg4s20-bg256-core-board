const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';
    LOG_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\PCB_SolderMaskRule_Fix.log';

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

procedure SaveCurrentPCB;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

procedure FixSolderMaskSliverRule;
var
    Board    : IPCB_Board;
    Iterator : IPCB_BoardIterator;
    Rule     : IPCB_Rule;
    Changed  : Integer;
begin
    LogLines := TStringList.Create;
    try
        Board := CurrentOrOpenedBoard;
        if Board = nil then
        begin
            ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running FixSolderMaskSliverRule.');
            Exit;
        end;

        Changed := 0;
        Log('FixSolderMaskSliverRule started');

        PCBServer.PreProcess;

        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eRuleObject));
        Iterator.AddFilter_LayerSet(AllLayers);
        Iterator.AddFilter_Method(eProcessAll);

        Rule := Iterator.FirstPCBObject;
        while Rule <> nil do
        begin
            if Rule.RuleKind = eRule_MinimumSolderMaskSliver then
            begin
                Log('RULE_BEFORE Name=' + Rule.Name +
                    ' MINSOLDERMASKWIDTH=' + Rule.ParameterByName('MINSOLDERMASKWIDTH'));
                Rule.AddOrReplaceParameter('MINSOLDERMASKWIDTH', '3mil');
                Log('RULE_AFTER Name=' + Rule.Name +
                    ' MINSOLDERMASKWIDTH=' + Rule.ParameterByName('MINSOLDERMASKWIDTH'));
                Inc(Changed);
            end;
            Rule := Iterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(Iterator);

        PCBServer.PostProcess;
        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        SaveCurrentPCB;

        Log('Changed solder mask sliver rules: ' + IntToStr(Changed));
        LogLines.SaveToFile(LOG_PATH);
        ShowMessage('Solder mask sliver rule fix complete. Changed rules: ' + IntToStr(Changed) +
            '. Log saved to: ' + LOG_PATH);
    finally
        if LogLines <> nil then
            LogLines.Free;
    end;
end;
