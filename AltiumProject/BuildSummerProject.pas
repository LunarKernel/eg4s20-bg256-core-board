{ Minimal smoke test for the Altium summer-project generator. }

procedure BuildSmokeTest;
var
    Workspace : IWorkspace;
    SchDoc    : ISch_Document;
    SchObject : TSchObjectHandle;
    LibPath   : String;
begin
    LibPath := 'C:\Users\zlx\OneDrive\ドキュメント\SummerProject\AltiumProject\CompatLibrary\EG4S20BG256.SCHLIB';

    Workspace := GetWorkspace;
    Workspace.DM_CreateNewDocument('SCH');

    SchDoc := SchServer.GetCurrentSchDocument;
    if SchDoc = nil then
    begin
        ShowMessage('Unable to create a schematic document.');
        Exit;
    end;

    SchObject := 0;
    SchDoc.PlaceSchComponent(LibPath, 'CRCW04021K00FKED', SchObject);

    SchDoc.GraphicallyInvalidate;
    if SchObject <> 0 then
        ShowMessage('Component placement succeeded.')
    else
        ShowMessage('Component placement failed.');
end;

procedure FinishPCBTransaction;
begin
    PCBServer.PostProcess;
    ShowMessage('PCB transaction closed.');
end;

procedure DiagnoseLibraries;
var
    I       : Integer;
    Details : String;
begin
    Details := 'Installed libraries: ' + IntToStr(IntegratedLibraryManager.InstalledLibraryCount);
    for I := 0 to IntegratedLibraryManager.InstalledLibraryCount - 1 do
        Details := Details + #13#10 + IntegratedLibraryManager.InstalledLibraryPath(I);
    ShowMessage(Details);
end;

procedure EnumerateTargetLibrary;
var
    I       : Integer;
    Count   : Integer;
    LibPath : String;
    Details : String;
begin
    LibPath := 'C:\Users\zlx\OneDrive\ドキュメント\SummerProject\AltiumProject\CompatLibrary\EG4S20BG256.SCHLIB';
    Count := IntegratedLibraryManager.GetComponentCount(LibPath);
    Details := 'Component count: ' + IntToStr(Count);
    for I := 0 to Count - 1 do
        Details := Details + #13#10 + IntToStr(I) + ': ' +
            IntegratedLibraryManager.GetComponentName(LibPath, I);
    ShowMessage(Details);
end;

procedure ReadSchLibrary;
var
    I       : Integer;
    Count   : Integer;
    Reader  : ILibCompInfoReader;
    Info    : IComponentInfo;
    LibPath : String;
    Details : String;
begin
    LibPath := 'C:\Users\zlx\OneDrive\ドキュメント\SummerProject\AltiumProject\CompatLibrary\EG4S20BG256.SCHLIB';
    Reader := SchServer.CreateLibCompInfoReader(LibPath);
    if Reader = nil then
    begin
        ShowMessage('SchLib reader creation failed.');
        Exit;
    end;

    Reader.ReadAllComponentInfo;
    Count := Reader.NumComponentInfos;
    Details := 'SchLib component count: ' + IntToStr(Count);
    for I := 0 to Count - 1 do
    begin
        Info := Reader.ComponentInfos[I];
        Details := Details + #13#10 + IntToStr(I) + ': ' + Info.CompName;
        if I >= 24 then Break;
    end;
    SchServer.DestroyCompInfoReader(Reader);
    ShowMessage(Details);
end;

procedure InspectCurrentLibrary;
var
    LibDoc   : ISch_Lib;
    Iterator : ISch_Iterator;
    Comp     : ISch_Component;
    Count    : Integer;
    Details  : String;
begin
    LibDoc := SchServer.GetCurrentSchDocument;
    if (LibDoc = nil) or (LibDoc.ObjectID <> eSchLib) then
    begin
        ShowMessage('Activate the SchLib tab before running this test.');
        Exit;
    end;

    Iterator := LibDoc.SchLibIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));
    Comp := Iterator.FirstSchObject;
    Count := 0;
    Details := 'Open SchLib components:';
    while Comp <> nil do
    begin
        Details := Details + #13#10 + IntToStr(Count) + ': ' + Comp.LibReference;
        Count := Count + 1;
        if Count >= 25 then Break;
        Comp := Iterator.NextSchObject;
    end;
    LibDoc.SchIterator_Destroy(Iterator);
    ShowMessage(Details + #13#10 + 'Shown: ' + IntToStr(Count));
end;

procedure PlaceFromOpenLibrary;
var
    Workspace : IWorkspace;
    LibDoc    : ISch_Lib;
    Iterator  : ISch_Iterator;
    Source    : ISch_Component;
    Placed    : ISch_Component;
    SchDoc    : ISch_Document;
begin
    LibDoc := SchServer.GetCurrentSchDocument;
    if (LibDoc = nil) or (LibDoc.ObjectID <> eSchLib) then
    begin
        ShowMessage('Activate the SchLib tab before running this test.');
        Exit;
    end;

    Iterator := LibDoc.SchLibIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));
    Source := Iterator.FirstSchObject;
    while (Source <> nil) and (Source.LibReference <> 'CRCW04021K00FKED') do
        Source := Iterator.NextSchObject;

    if Source = nil then
    begin
        LibDoc.SchIterator_Destroy(Iterator);
        ShowMessage('Source component was not found in the open SchLib.');
        Exit;
    end;

    Placed := Source.Replicate;
    LibDoc.SchIterator_Destroy(Iterator);

    Workspace := GetWorkspace;
    Workspace.DM_CreateNewDocument('SCH');
    SchDoc := SchServer.GetCurrentSchDocument;
    if SchDoc = nil then Exit;

    Placed.Location := Point(MilsToCoord(2500), MilsToCoord(2500));
    Placed.Designator.Text := 'R1';
    Placed.Comment.Text := '1K';
    SchDoc.RegisterSchObjectInContainer(Placed);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Placed.I_ObjectAddress);
    SchDoc.GraphicallyInvalidate;
    ShowMessage('Replicated component placed.');
end;

function FindOpenLibraryComponent(LibDoc : ISch_Lib; LibRef : String) : ISch_Component;
var
    Iterator : ISch_Iterator;
    Comp     : ISch_Component;
begin
    Result := nil;
    Iterator := LibDoc.SchLibIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));
    Comp := Iterator.FirstSchObject;
    while Comp <> nil do
    begin
        if Comp.LibReference = LibRef then
        begin
            Result := Comp;
            Break;
        end;
        Comp := Iterator.NextSchObject;
    end;
    LibDoc.SchIterator_Destroy(Iterator);
end;

function PlaceOpenLibraryComponent(LibDoc : ISch_Lib; SchDoc : ISch_Document;
    LibRef : String; Designator : String; PartId, X, Y : Integer) : ISch_Component;
var
    Source : ISch_Component;
    Placed : ISch_Component;
begin
    Result := nil;
    Source := FindOpenLibraryComponent(LibDoc, LibRef);
    if Source = nil then Exit;

    Placed := Source.Replicate;
    if PartId > 0 then Placed.CurrentPartID := PartId;
    Placed.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    Placed.Designator.Text := Designator;
    SchDoc.RegisterSchObjectInContainer(Placed);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Placed.I_ObjectAddress);
    Result := Placed;
end;

procedure AddNetLabel(SchDoc : ISch_Document; NetName : String; X, Y : Integer);
var
    LabelObj : ISch_NetLabel;
begin
    LabelObj := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    if LabelObj = nil then Exit;
    LabelObj.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    LabelObj.Text := NetName;
    SchDoc.RegisterSchObjectInContainer(LabelObj);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, LabelObj.I_ObjectAddress);
end;

procedure AddSheetLabel(SchDoc : ISch_Document; Caption : String; X, Y : Integer);
var
    LabelObj : ISch_Label;
begin
    LabelObj := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    if LabelObj = nil then Exit;
    LabelObj.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    LabelObj.Text := Caption;
    LabelObj.Color := $0000FF;
    SchDoc.RegisterSchObjectInContainer(LabelObj);
end;

function NewSummerSheet(Caption : String) : ISch_Document;
var
    Workspace : IWorkspace;
begin
    Workspace := GetWorkspace;
    Workspace.DM_CreateNewDocument('SCH');
    Result := SchServer.GetCurrentSchDocument;
    if Result <> nil then AddSheetLabel(Result, Caption, 700, 7300);
end;

procedure CreateSummerSchematics;
var
    LibDoc : ISch_Lib;
    SchDoc : ISch_Document;
begin
    LibDoc := SchServer.GetCurrentSchDocument;
    if (LibDoc = nil) or (LibDoc.ObjectID <> eSchLib) then
    begin
        ShowMessage('Activate EG4S20BG256.SCHLIB before running CreateSummerSchematics.');
        Exit;
    end;

    { Sheet 1 - board connectors and expansion interfaces. }
    SchDoc := NewSummerSheet('01 CONNECTORS AND EXPANSION');
    PlaceOpenLibraryComponent(LibDoc, SchDoc, '105017-0001', 'J1', 1, 1800, 5100);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'CH340G', 'U3', 1, 4300, 5100);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'TPD4E001DBVR', 'U4', 1, 6800, 5100);
    AddNetLabel(SchDoc, 'USB_D+', 2500, 5900);
    AddNetLabel(SchDoc, 'USB_D-', 2500, 5700);
    AddNetLabel(SchDoc, 'UART_RXD_F12', 5200, 5900);
    AddNetLabel(SchDoc, 'UART_TXD_D12', 5200, 5700);
    AddSheetLabel(SchDoc, 'Expansion headers: 3V3 / 5V / GND / FPGA IO', 1800, 2800);
    SchDoc.GraphicallyInvalidate;

    { Sheet 2 - FPGA, clock and configuration flash. }
    SchDoc := NewSummerSheet('02 FPGA CLOCK AND FLASH');
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'EG4S20BG256', 'U1', 1, 1800, 5200);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'EG4S20BG256', 'U1', 2, 4500, 5200);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'EG4S20BG256', 'U1', 3, 7200, 5200);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'EG4S20BG256', 'U1', 4, 1800, 2500);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'EG4S20BG256', 'U1', 5, 4500, 2500);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'EG4S20BG256', 'U1', 6, 7200, 2500);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, '7X-20.000MBB-T_1', 'Y1', 1, 9500, 5600);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'W25Q80BLSNIG', 'U2', 1, 9500, 3300);
    AddNetLabel(SchDoc, 'CLK_20M', 9000, 6100);
    AddNetLabel(SchDoc, 'SPI_CS', 9000, 4000);
    AddNetLabel(SchDoc, 'SPI_CLK', 9000, 3800);
    AddNetLabel(SchDoc, 'SPI_MOSI', 9000, 3600);
    AddNetLabel(SchDoc, 'SPI_MISO', 9000, 3400);
    SchDoc.GraphicallyInvalidate;

    { Sheet 3 - USB UART and JTAG controller. }
    SchDoc := NewSummerSheet('03 USB UART AND JTAG');
    PlaceOpenLibraryComponent(LibDoc, SchDoc, '105017-0001', 'J2', 1, 1700, 5000);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'TPD4E001DBVR', 'U5', 1, 3500, 5000);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'CH340G', 'U6', 1, 5600, 5000);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'GD32F150U', 'U7', 1, 8300, 5000);
    AddNetLabel(SchDoc, 'USB_D+', 2500, 6100);
    AddNetLabel(SchDoc, 'USB_D-', 2500, 5900);
    AddNetLabel(SchDoc, 'UART_RXD_F12', 6900, 5800);
    AddNetLabel(SchDoc, 'UART_TXD_D12', 6900, 5600);
    AddNetLabel(SchDoc, 'JTAG_TCK', 9400, 5800);
    AddNetLabel(SchDoc, 'JTAG_TMS', 9400, 5600);
    AddNetLabel(SchDoc, 'JTAG_TDI', 9400, 5400);
    AddNetLabel(SchDoc, 'JTAG_TDO', 9400, 5200);
    SchDoc.GraphicallyInvalidate;

    { Sheet 4 - user IO peripherals and FPGA pin map. }
    SchDoc := NewSummerSheet('04 USER IO AND PIN MAP');
    PlaceOpenLibraryComponent(LibDoc, SchDoc, '4LED-ANODE', 'DS1', 1, 2300, 5100);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'BUZZER_EFBAA14D001', 'BZ1', 1, 5200, 5100);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'ABLS-8.000MHZ-B4-T', 'Y2', 1, 8000, 5100);
    AddNetLabel(SchDoc, 'SW1_A9', 1200, 3600);
    AddNetLabel(SchDoc, 'SW2_A10', 1200, 3400);
    AddNetLabel(SchDoc, 'SW3_B10', 1200, 3200);
    AddNetLabel(SchDoc, 'SW4_A11', 1200, 3000);
    AddNetLabel(SchDoc, 'SW5_A12', 1200, 2800);
    AddNetLabel(SchDoc, 'SW6_B12', 1200, 2600);
    AddNetLabel(SchDoc, 'SW7_A13', 1200, 2400);
    AddNetLabel(SchDoc, 'SW8_A14', 1200, 2200);
    AddNetLabel(SchDoc, 'LED1_B14', 3500, 3600);
    AddNetLabel(SchDoc, 'LED2_B15', 3500, 3400);
    AddNetLabel(SchDoc, 'LED3_B16', 3500, 3200);
    AddNetLabel(SchDoc, 'LED4_C15', 3500, 3000);
    AddNetLabel(SchDoc, 'LED5_C16', 3500, 2800);
    AddNetLabel(SchDoc, 'LED6_E13', 3500, 2600);
    AddNetLabel(SchDoc, 'LED7_E16', 3500, 2400);
    AddNetLabel(SchDoc, 'LED8_F16', 3500, 2200);
    AddNetLabel(SchDoc, 'BUZZER_H11', 5900, 3600);
    AddNetLabel(SchDoc, 'CLOCK_R7', 5900, 3400);
    AddNetLabel(SchDoc, 'KEY_COL_F10_C11_D11_E11', 7600, 3000);
    AddNetLabel(SchDoc, 'KEY_ROW_E10_C10_F9_D9', 7600, 2800);
    AddNetLabel(SchDoc, 'SEG_A4_A6_B8_E8_A7_B5_A8_C8', 7600, 2400);
    AddNetLabel(SchDoc, 'DIG_SEL_C9_B6_A5_A3', 7600, 2200);
    SchDoc.GraphicallyInvalidate;

    { Sheet 5 - power rails and regulators. }
    SchDoc := NewSummerSheet('05 POWER SUPPLY');
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'AMS1117', 'U8', 1, 2200, 5000);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'RT8097', 'U9', 1, 5000, 5000);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'B340B-13-F', 'D1', 1, 7600, 5000);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'BLM21BD121SN1D', 'FB1', 1, 9400, 5000);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'TL431AIDBZ', 'U10', 1, 5000, 2800);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'GRM21BC81C475KA88L', 'C1', 1, 2500, 2800);
    PlaceOpenLibraryComponent(LibDoc, SchDoc, 'C1005X7R1H104M_1', 'C2', 1, 7500, 2800);
    AddNetLabel(SchDoc, 'VIN_5V', 1200, 5800);
    AddNetLabel(SchDoc, 'VCC_3V3', 3500, 5800);
    AddNetLabel(SchDoc, 'VCC_1V2', 6200, 5800);
    AddNetLabel(SchDoc, 'GND', 5000, 1800);
    SchDoc.GraphicallyInvalidate;

    ShowMessage('Created five summer-project schematic sheets. Save them as 01_Connectors through 05_Power.');
end;

procedure CreateCoreBoardFootprint;
var
    Board : IPCB_Board;
    Pad   : IPCB_Pad;
    Track : IPCB_Track;
    Row   : Integer;
    Col   : Integer;
    X0    : Integer;
    Y0    : Integer;
    Pitch : Integer;
    X1    : Integer;
    Y1    : Integer;
    X2    : Integer;
    Y2    : Integer;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then
    begin
        ShowMessage('Activate EG4S20_CoreBoard.PcbDoc before running CreateCoreBoardFootprint.');
        Exit;
    end;

    PCBServer.PreProcess;

    { EG4S20BG256: compact 16 x 16 BGA land pattern, 1.0 mm pitch. }
    X0 := MMsToCoord(35.0);
    Y0 := MMsToCoord(30.0);
    Pitch := MMsToCoord(1.0);
    for Row := 0 to 15 do
        for Col := 0 to 15 do
        begin
            Pad := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
            Pad.X := X0 + Col * Pitch;
            Pad.Y := Y0 + Row * Pitch;
            Pad.Layer := eTopLayer;
            Pad.TopShape := eCircleShape;
            Pad.TopXSize := MMsToCoord(0.50);
            Pad.TopYSize := MMsToCoord(0.50);
            Pad.Name := Chr(65 + Row) + IntToStr(Col + 1);
            Board.AddPCBObject(Pad);
        end;

    { Top-overlay courtyard around the FPGA. }
    X1 := X0 - MMsToCoord(1.0);
    Y1 := Y0 - MMsToCoord(1.0);
    X2 := X0 + 15 * Pitch + MMsToCoord(1.0);
    Y2 := Y0 + 15 * Pitch + MMsToCoord(1.0);

    Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    Track.X1 := X1; Track.Y1 := Y1; Track.X2 := X2; Track.Y2 := Y1;
    Track.Width := MMsToCoord(0.20); Track.Layer := eTopOverlay; Board.AddPCBObject(Track);
    Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    Track.X1 := X2; Track.Y1 := Y1; Track.X2 := X2; Track.Y2 := Y2;
    Track.Width := MMsToCoord(0.20); Track.Layer := eTopOverlay; Board.AddPCBObject(Track);
    Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    Track.X1 := X2; Track.Y1 := Y2; Track.X2 := X1; Track.Y2 := Y2;
    Track.Width := MMsToCoord(0.20); Track.Layer := eTopOverlay; Board.AddPCBObject(Track);
    Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    Track.X1 := X1; Track.Y1 := Y2; Track.X2 := X1; Track.Y2 := Y1;
    Track.Width := MMsToCoord(0.20); Track.Layer := eTopOverlay; Board.AddPCBObject(Track);

    PCBServer.PostProcess;
    Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
    ShowMessage('Created EG4S20BG256 BGA footprint: 256 pads plus top-overlay outline.');
end;
