const
    PCB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\EG4S20_SummerProject\EG4S20_CoreBoard.PcbDoc';

procedure OpenDRCDialog;
var
    Doc : IServerDocument;
begin
    Doc := Client.OpenDocument('PCB', PCB_PATH);
    if Doc <> nil then
        Client.ShowDocument(Doc);

    ResetParameters;
    RunProcess('PCB:DesignRuleCheck');
end;

