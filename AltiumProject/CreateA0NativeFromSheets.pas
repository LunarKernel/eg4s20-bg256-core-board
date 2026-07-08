{ Create one editable A0 schematic in Altium Designer.

  Run scripts\prepare_a0_native.ps1 first, then open the generated PrjScr
  under %TEMP%\eg4s20_altium_a0.

  ponytail: library component replication is unstable in this Altium build, so
  this creates a native editable text/net-label A0 skeleton first.
}

const
    BASE_DIR = 'C:\Users\fpna1\AppData\Local\Temp\eg4s20_altium_a0\EG4S20_SummerProject\';
    LIB_PATH = 'C:\Users\zlx\SummerProject\AltiumProject\CompatLibrary\EG4S20BG256.SCHLIB';
    OUT_SCH = 'C:\Users\fpna1\AppData\Local\Temp\eg4s20_altium_a0\EG4S20_SummerProject\EG4S20BG256_CoreBoard_A0_NATIVE.SchDoc';

var
    ORIGIN_X : Integer;
    ORIGIN_Y : Integer;

procedure SetOrigin(X, Y : Integer);
begin
    ORIGIN_X := X;
    ORIGIN_Y := Y;
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

function OpenSchLib(Path : String) : ISch_Lib;
var
    Doc : IServerDocument;
begin
    Result := nil;
    Doc := Client.OpenDocument('SCHLIB', Path);
    if Doc = nil then Exit;
    Client.ShowDocument(Doc);
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
    Sch.SetState_CustomX(46810);
    Sch.SetState_CustomY(33110);
    Sch.SetState_CustomXZones(12);
    Sch.SetState_CustomYZones(8);
    Sch.SetState_BorderOn(True);
    Sch.SetState_TitleBlockOn(True);
    Sch.SetState_CustomMarginWidth(20);
end;

procedure AddLabel(Sch : ISch_Document; Text : String; X, Y : Integer);
var
    LabelObj : ISch_Label;
begin
    LabelObj := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
    if LabelObj = nil then Exit;
    LabelObj.Location := Point(MilsToCoord(ORIGIN_X + X), MilsToCoord(ORIGIN_Y + Y));
    LabelObj.Text := Text;
    LabelObj.Color := $0000FF;
    Sch.RegisterSchObjectInContainer(LabelObj);
    SchServer.RobotManager.SendMessage(Sch.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, LabelObj.I_ObjectAddress);
end;

procedure AddNetLabel(Sch : ISch_Document; NetName : String; X, Y : Integer);
var
    LabelObj : ISch_NetLabel;
begin
    LabelObj := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    if LabelObj = nil then Exit;
    LabelObj.Location := Point(MilsToCoord(ORIGIN_X + X), MilsToCoord(ORIGIN_Y + Y));
    LabelObj.Text := NetName;
    Sch.RegisterSchObjectInContainer(LabelObj);
    SchServer.RobotManager.SendMessage(Sch.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, LabelObj.I_ObjectAddress);
end;

function FindOpenLibraryComponent(LibDoc : ISch_Lib; LibRef : String) : ISch_Component;
var
    Iterator : ISch_Iterator;
    Comp     : ISch_Component;
begin
    Result := nil;
    if LibDoc = nil then Exit;

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

function PlaceComponent(LibDoc : ISch_Lib; Sch : ISch_Document; LibRef : String;
    Designator : String; PartId, X, Y : Integer) : ISch_Component;
begin
    Result := nil;
    if PartId > 0 then
        AddLabel(Sch, Designator + '.' + IntToStr(PartId) + '  ' + LibRef, X, Y)
    else
        AddLabel(Sch, Designator + '  ' + LibRef, X, Y);
end;

procedure AddCommonPowerLabels(Sch : ISch_Document; X, Y : Integer);
begin
    AddNetLabel(Sch, 'VIN_5V', X, Y);
    AddNetLabel(Sch, 'VCC_3V3', X, Y - 180);
    AddNetLabel(Sch, 'VCC_1V2', X, Y - 360);
    AddNetLabel(Sch, 'GND', X, Y - 540);
end;

procedure BuildConnectors(LibDoc : ISch_Lib; Sch : ISch_Document);
begin
    AddLabel(Sch, '01 CONNECTORS / USB / EXPANSION', 160, 3070);
    PlaceComponent(LibDoc, Sch, '105017-0001', 'J1', 1, 200, 2780);
    PlaceComponent(LibDoc, Sch, 'TPD4E001DBVR', 'U4', 1, 200, 2540);
    PlaceComponent(LibDoc, Sch, 'CH340G', 'U3', 1, 200, 2300);
    AddNetLabel(Sch, 'USB_D+', 1900, 2780);
    AddNetLabel(Sch, 'USB_D-', 1900, 2540);
    AddNetLabel(Sch, 'UART_RXD_F12', 3400, 2780);
    AddNetLabel(Sch, 'UART_TXD_D12', 3400, 2540);
    AddNetLabel(Sch, 'EXP_FPGA_IO', 1900, 2300);
    AddCommonPowerLabels(Sch, 1900, 2040);
end;

procedure BuildFpgaClockFlash(LibDoc : ISch_Lib; Sch : ISch_Document);
begin
    AddLabel(Sch, '02 FPGA / CLOCK / FLASH', 160, 3070);
    PlaceComponent(LibDoc, Sch, 'EG4S20BG256', 'U1', 1, 320, 2780);
    PlaceComponent(LibDoc, Sch, 'EG4S20BG256', 'U1', 2, 320, 2540);
    PlaceComponent(LibDoc, Sch, 'EG4S20BG256', 'U1', 3, 320, 2300);
    PlaceComponent(LibDoc, Sch, 'EG4S20BG256', 'U1', 4, 2100, 2780);
    PlaceComponent(LibDoc, Sch, 'EG4S20BG256', 'U1', 5, 2100, 2540);
    PlaceComponent(LibDoc, Sch, 'EG4S20BG256', 'U1', 6, 2100, 2300);
    PlaceComponent(LibDoc, Sch, '7X-20.000MBB-T_1', 'Y1', 1, 3900, 2780);
    PlaceComponent(LibDoc, Sch, 'W25Q80BLSNIG', 'U2', 1, 3900, 2540);
    AddNetLabel(Sch, 'CLK_20M', 6000, 2780);
    AddNetLabel(Sch, 'SPI_CS', 6000, 2540);
    AddNetLabel(Sch, 'SPI_CLK', 6000, 2300);
    AddNetLabel(Sch, 'SPI_MOSI', 6000, 2060);
    AddNetLabel(Sch, 'SPI_MISO', 6000, 1820);
    AddCommonPowerLabels(Sch, 7200, 2780);
end;

procedure BuildUsbJtag(LibDoc : ISch_Lib; Sch : ISch_Document);
begin
    AddLabel(Sch, '03 USB UART / JTAG', 160, 3070);
    PlaceComponent(LibDoc, Sch, '105017-0001', 'J2', 1, 320, 2780);
    PlaceComponent(LibDoc, Sch, 'TPD4E001DBVR', 'U5', 1, 320, 2540);
    PlaceComponent(LibDoc, Sch, 'CH340G', 'U6', 1, 320, 2300);
    PlaceComponent(LibDoc, Sch, 'GD32F150U', 'U7', 1, 320, 2060);
    AddNetLabel(Sch, 'USB_D+', 2000, 2780);
    AddNetLabel(Sch, 'USB_D-', 2000, 2540);
    AddNetLabel(Sch, 'UART_RXD_F12', 3600, 2780);
    AddNetLabel(Sch, 'UART_TXD_D12', 3600, 2540);
    AddNetLabel(Sch, 'JTAG_TCK', 3600, 2300);
    AddNetLabel(Sch, 'JTAG_TMS', 3600, 2060);
    AddNetLabel(Sch, 'JTAG_TDI', 3600, 1820);
    AddNetLabel(Sch, 'JTAG_TDO', 3600, 1580);
end;

procedure BuildUserIo(LibDoc : ISch_Lib; Sch : ISch_Document);
begin
    AddLabel(Sch, '04 USER IO', 160, 1540);
    PlaceComponent(LibDoc, Sch, '4LED-ANODE', 'DS1', 1, 220, 1260);
    PlaceComponent(LibDoc, Sch, 'BUZZER_EFBAA14D001', 'BZ1', 1, 220, 1020);
    PlaceComponent(LibDoc, Sch, 'ABLS-8.000MHZ-B4-T', 'Y2', 1, 220, 780);
    AddNetLabel(Sch, 'SW1_A9', 220, 420);
    AddNetLabel(Sch, 'SW2_A10', 220, 260);
    AddNetLabel(Sch, 'SW3_B10', 220, 100);
    AddNetLabel(Sch, 'SW4_A11', 220, -60);
    AddNetLabel(Sch, 'LED1_B14', 1300, 420);
    AddNetLabel(Sch, 'LED2_B15', 1300, 260);
    AddNetLabel(Sch, 'LED3_B16', 1300, 100);
    AddNetLabel(Sch, 'LED4_C15', 1300, -60);
    AddNetLabel(Sch, 'BUZZER_H11', 2500, 420);
    AddNetLabel(Sch, 'CLOCK_R7', 2500, 260);
    AddNetLabel(Sch, 'KEY_COL_F10_C11_D11_E11', 3900, 420);
    AddNetLabel(Sch, 'KEY_ROW_E10_C10_F9_D9', 3900, 260);
    AddNetLabel(Sch, 'SEG_A4_A6_B8_E8_A7_B5_A8_C8', 3900, 100);
    AddNetLabel(Sch, 'DIG_SEL_C9_B6_A5_A3', 3900, -60);
end;

procedure BuildPower(LibDoc : ISch_Lib; Sch : ISch_Document);
begin
    AddLabel(Sch, '05 POWER', 2860, 1540);
    PlaceComponent(LibDoc, Sch, 'AMS1117', 'U8', 1, 320, 1180);
    PlaceComponent(LibDoc, Sch, 'RT8097', 'U9', 1, 320, 940);
    PlaceComponent(LibDoc, Sch, 'B340B-13-F', 'D1', 1, 320, 700);
    PlaceComponent(LibDoc, Sch, 'BLM21BD121SN1D', 'FB1', 1, 320, 460);
    PlaceComponent(LibDoc, Sch, 'TL431AIDBZ', 'U10', 1, 2200, 1180);
    PlaceComponent(LibDoc, Sch, 'GRM21BC81C475KA88L', 'C1', 1, 2200, 940);
    PlaceComponent(LibDoc, Sch, 'C1005X7R1H104M_1', 'C2', 1, 2200, 700);
    AddNetLabel(Sch, 'VIN_5V', 2920, 1460);
    AddNetLabel(Sch, 'VCC_3V3', 3420, 1460);
    AddNetLabel(Sch, 'VCC_1V2', 3920, 1460);
    AddNetLabel(Sch, 'GND', 3420, 440);
end;

procedure CreateA0NativeFromSheets;
var
    Target : ISch_Document;
    LibDoc : ISch_Lib;
begin
    LibDoc := nil;

    Target := NewSch;
    if Target = nil then
    begin
        ShowMessage('Failed to create target schematic.');
        Exit;
    end;

    SetA0(Target);
    SetOrigin(0, 0);
    AddLabel(Target, 'EG4S20BG256 CORE BOARD - ONE PAGE A0 NATIVE SCHEMATIC', 1000, 7000);
    AddLabel(Target, 'TEXT/NET-LABEL SKELETON: replace text blocks with library parts after layout is stable.', 1000, 6750);

    SetOrigin(1000, 2500);
    BuildConnectors(LibDoc, Target);
    SetOrigin(7500, 2500);
    BuildFpgaClockFlash(LibDoc, Target);
    SetOrigin(15500, 2500);
    BuildUsbJtag(LibDoc, Target);
    SetOrigin(1000, 500);
    BuildUserIo(LibDoc, Target);
    SetOrigin(8500, 500);
    BuildPower(LibDoc, Target);

    Target.GraphicallyInvalidate;
    SaveAs(OUT_SCH);
    SaveDoc;
    ShowMessage('Created one-page A0 schematic: ' + OUT_SCH);
end;
