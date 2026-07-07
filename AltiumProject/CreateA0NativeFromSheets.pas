{ Create a native editable A0 schematic inside Altium Designer.

  This script must be run from Altium Designer. It copies placed schematic
  objects using Altium's own API, so component internals stay valid.
}

const
    BASE_DIR = 'C:\Users\fpna1\AppData\Local\Temp\eg4s20_altium_a0\EG4S20_SummerProject\';
    OUT_SCH = 'C:\Users\fpna1\AppData\Local\Temp\eg4s20_altium_a0\EG4S20_SummerProject\EG4S20BG256_CoreBoard_A0_NATIVE.SchDoc';

function OpenSch(Path : String) : ISch_Document;
var
    Doc : IServerDocument;
begin
    Result := nil;
    Doc := Client.OpenDocument('SCH', Path);
    if Doc = nil then Exit;
    Client.ShowDocument(Doc);
    Result := SchServer.GetCurrentSchDocument;
end;

function NewSch : ISch_Document;
var
    Workspace : IWorkspace;
begin
    Result := nil;
    Workspace := GetWorkspace;
    Workspace.DM_CreateNewDocument('SCH');
    Result := SchServer.GetCurrentSchDocument;
end;

procedure SaveAs(Path : String);
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    AddStringParameter('FileName', Path);
    RunProcess('WorkspaceManager:SaveAs');
end;

procedure SaveDoc;
begin
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    RunProcess('WorkspaceManager:Save');
end;

procedure SetA0(Sch : ISch_Document);
begin
    Sch.SetState_SheetStyle(1);
    Sch.SetState_CustomX(4681);
    Sch.SetState_CustomY(3311);
    Sch.SetState_CustomXZones(12);
    Sch.SetState_CustomYZones(8);
    Sch.SetState_BorderOn(True);
    Sch.SetState_TitleBlockOn(True);
    Sch.SetState_CustomMarginWidth(20);
end;

procedure AddTitle(Sch : ISch_Document; Text : String; X, Y : Integer);
var
    LabelObj : ISch_Label;
begin
    LabelObj := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    if LabelObj = nil then Exit;
    LabelObj.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    LabelObj.Text := Text;
    LabelObj.Color := $0000FF;
    Sch.RegisterSchObjectInContainer(LabelObj);
    SchServer.RobotManager.SendMessage(Sch.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, LabelObj.I_ObjectAddress);
end;

procedure CopyTopLevelObjects(Source : ISch_Document; Target : ISch_Document;
    DX, DY : Integer);
var
    Iter   : ISch_Iterator;
    Obj    : ISch_Object;
    NewObj : ISch_Object;
begin
    if (Source = nil) or (Target = nil) then Exit;

    Iter := Source.SchIterator_Create;
    Obj := Iter.FirstSchObject;
    while Obj <> nil do
    begin
        if Obj.OwnerPartId = -1 then
        begin
            NewObj := Obj.Replicate;
            if NewObj <> nil then
            begin
                Target.RegisterSchObjectInContainer(NewObj);
                SchServer.RobotManager.SendMessage(Target.I_ObjectAddress,
                    c_BroadCast, SCHM_PrimitiveRegistration,
                    NewObj.I_ObjectAddress);
            end;
        end;
        Obj := Iter.NextSchObject;
    end;
    Source.SchIterator_Destroy(Iter);
end;

procedure CreateA0NativeFromSheets;
var
    Target : ISch_Document;
    S2     : ISch_Document;
    S3     : ISch_Document;
    S4     : ISch_Document;
    S5     : ISch_Document;
begin
    Target := NewSch;
    if Target = nil then
    begin
        ShowMessage('Failed to create target schematic.');
        Exit;
    end;

    SetA0(Target);
    AddTitle(Target, 'EG4S20BG256 CORE BOARD - A0 NATIVE SCHEMATIC', 120, 3180);
    SaveAs(OUT_SCH);

    S2 := OpenSch(BASE_DIR + '02_FPGA_Clock_Flash.SchDoc');
    S3 := OpenSch(BASE_DIR + '03_USB_JTAG.SchDoc');
    S4 := OpenSch(BASE_DIR + '04_UserIO.SchDoc');
    S5 := OpenSch(BASE_DIR + '05_Power.SchDoc');

    Target := OpenSch(OUT_SCH);
    if Target = nil then
    begin
        ShowMessage('Failed to reopen target schematic.');
        Exit;
    end;

    CopyTopLevelObjects(S2, Target, 120, 2100);
    CopyTopLevelObjects(S3, Target, 1680, 2100);
    CopyTopLevelObjects(S4, Target, 120, 850);
    CopyTopLevelObjects(S5, Target, 1680, 850);

    Target.GraphicallyInvalidate;
    SaveDoc;
    ShowMessage('Created: ' + OUT_SCH);
end;
