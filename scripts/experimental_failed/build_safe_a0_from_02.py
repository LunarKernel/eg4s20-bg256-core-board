from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

ROOT = Path(r"C:\Users\fpna1\OneDrive\ドキュメント\SummerProject\eg4s20-bg256-core-board")
sys.path.insert(0, str(ROOT / "tmp" / "pydeps"))
sys.path.insert(0, str(ROOT / "scripts"))

import olefile  # type: ignore
import build_a0_schdoc as cfb


SRC = ROOT / "AltiumProject" / "EG4S20_SummerProject" / "02_FPGA_Clock_Flash.SchDoc"
OUT = ROOT / "AltiumProject" / "EG4S20_SummerProject" / "EG4S20BG256_CoreBoard_A0_SAFE3.SchDoc"

DX = 450
DY = 1600


def parse_records(data: bytes) -> list[bytes]:
    records: list[bytes] = []
    pos = 0
    while pos < len(data):
        size = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        records.append(data[pos : pos + size - 1])
        pos += size
    return records


def pack_records(records: list[bytes]) -> bytes:
    return b"".join(struct.pack("<I", len(r) + 1) + r + b"\0" for r in records)


def replace_field(text: str, key: str, value: str) -> str:
    return re.sub(rf"(\|{re.escape(key)}=)[^|]*", rf"\g<1>{value}", text, count=1)


def shift_visible(text: str) -> str:
    if "IsHidden=T" in text:
        return text
    if text.startswith("|RECORD=1|"):
        return text

    def sx(match: re.Match[str]) -> str:
        return match.group(1) + str(int(match.group(2)) + DX)

    def sy(match: re.Match[str]) -> str:
        return match.group(1) + str(int(match.group(2)) + DY)

    text = re.sub(r"(\|(?:Location|Corner)\.X=)(-?\d+)", sx, text)
    text = re.sub(r"(\|(?:Location|Corner)\.Y=)(-?\d+)", sy, text)
    text = re.sub(r"(\|X\d*=)(-?\d+)", sx, text)
    text = re.sub(r"(\|Y\d*=)(-?\d+)", sy, text)
    return text


def main() -> None:
    ole = olefile.OleFileIO(str(SRC))
    records = parse_records(ole.openstream("FileHeader").read())

    sheet = records[1].decode("latin1")
    for key, value in {
        "SheetStyle": "1",
        "CustomX": "4681",
        "CustomY": "3311",
        "CustomXZones": "12",
        "CustomYZones": "8",
    }.items():
        sheet = replace_field(sheet, key, value)
    records[1] = sheet.encode("latin1")

    for i in range(2, len(records)):
        records[i] = shift_visible(records[i].decode("latin1", "ignore")).encode("latin1")

    cfb.write_cfb(
        OUT,
        {
            "FileHeader": pack_records(records),
            "Storage": ole.openstream("Storage").read(),
            "Additional": ole.openstream("Additional").read(),
        },
    )
    print(OUT)
    print(f"offset_all {DX} {DY}")


if __name__ == "__main__":
    main()
