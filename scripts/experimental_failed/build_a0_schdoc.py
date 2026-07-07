from __future__ import annotations

import math
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tmp" / "pydeps"))
import olefile  # type: ignore


ROOT = Path(r"C:\Users\fpna1\OneDrive\ドキュメント\SummerProject\eg4s20-bg256-core-board")
PROJECT = ROOT / "AltiumProject" / "EG4S20_SummerProject"
OUT = PROJECT / "EG4S20BG256_CoreBoard_A0.SchDoc"
LIB = ROOT / "AltiumProject" / "CompatLibrary" / "EG4S20BG256.SCHLIB"

SOURCES = [
    ("02_FPGA_Clock_Flash.SchDoc", 80, 2180),
    ("03_USB_JTAG.SchDoc", 1680, 2180),
    ("04_UserIO.SchDoc", 80, 940),
    ("05_Power.SchDoc", 1680, 940),
]

CONNECTORS = [
    ("Header 30X2", "P1", 1, 240, 1820),
    ("Header 30X2", "P4", 2, 720, 1820),
    ("Header 20X2", "P2", 1, 1220, 1820),
    ("Header 20X2_1", "P3", 2, 1580, 1820),
    ("Header 12X2", "P5", 1, 2040, 1820),
    ("Header 12X2_1", "P6", 2, 2380, 1820),
]


def read_stream(path: Path, name: str) -> bytes:
    ole = olefile.OleFileIO(str(path))
    return ole.openstream(name).read()


def parse_records(data: bytes) -> list[bytes]:
    records: list[bytes] = []
    pos = 0
    while pos < len(data):
        if pos + 4 > len(data):
            raise ValueError(f"trailing bytes at {pos}")
        size = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        payload = data[pos : pos + size]
        if len(payload) != size:
            raise ValueError(f"short record at {pos}")
        if not payload.endswith(b"\x00"):
            raise ValueError(f"record at {pos} is not null terminated")
        records.append(payload[:-1])
        pos += size
    return records


def pack_records(records: list[bytes]) -> bytes:
    out = bytearray()
    for rec in records:
        payload = rec + b"\x00"
        out += struct.pack("<I", len(payload))
        out += payload
    return bytes(out)


def replace_field(text: str, key: str, value: str) -> str:
    if re.search(rf"(\|{re.escape(key)}=)[^|]*", text):
        return re.sub(rf"(\|{re.escape(key)}=)[^|]*", rf"\g<1>{value}", text, count=1)
    return text + f"|{key}={value}"


def get_int_field(text: str, key: str) -> int | None:
    m = re.search(rf"(?:^|\|){re.escape(key)}=(-?\d+)", text)
    return int(m.group(1)) if m else None


def set_int_field(text: str, key: str, value: int) -> str:
    return replace_field(text, key, str(value))


def should_offset(text: str) -> bool:
    if "IsHidden=T" in text:
        return False
    if "|OwnerIndex=" in text:
        return False
    if "OwnerPartId=-1" not in text:
        return False
    return text.startswith("|RECORD=")


def offset_coords(text: str, dx: int, dy: int) -> str:
    if not should_offset(text):
        return text

    def repl_x(match: re.Match[str]) -> str:
        return f"{match.group(1)}{int(match.group(2)) + dx}"

    def repl_y(match: re.Match[str]) -> str:
        return f"{match.group(1)}{int(match.group(2)) + dy}"

    # Top-level schematic primitives use mil coordinates in these fields.
    text = re.sub(r"(\|(?:Location|Corner)\.X=)(-?\d+)", repl_x, text)
    text = re.sub(r"(\|(?:Location|Corner)\.Y=)(-?\d+)", repl_y, text)
    text = re.sub(r"(\|X\d*=)(-?\d+)", repl_x, text)
    text = re.sub(r"(\|Y\d*=)(-?\d+)", repl_y, text)
    return text


def make_unique(text: str, salt: int) -> str:
    def repl(match: re.Match[str]) -> str:
        value = match.group(1)
        if len(value) >= 8 and value.isalpha():
            suffix = f"{salt:08X}"[-4:]
            return "UniqueID=" + value[:4] + suffix
        return match.group(0)

    return re.sub(r"UniqueID=([A-Z]{8})", repl, text)


def append_source(
    out_records: list[bytes],
    source_records: list[bytes],
    dx: int,
    dy: int,
    salt_base: int,
) -> None:
    # Skip stream header and sheet-options records.  Keep all schematic objects.
    body = source_records[2:]
    old_owner_to_new_owner: dict[int, int] = {}

    for rec in body:
        new_index = sum(1 for r in out_records if r.startswith(b"|RECORD="))
        new_owner_index = new_index + 1

        text = rec.decode("latin1")
        owner = get_int_field(text, "OwnerIndex")
        if owner is not None and owner in old_owner_to_new_owner:
            text = set_int_field(text, "OwnerIndex", old_owner_to_new_owner[owner])

        old_owner_index = None
        if "IndexInSheet=" in text:
            index = get_int_field(text, "IndexInSheet")
            if index is not None and index >= 0:
                old_owner_index = index + 1
                text = set_int_field(text, "IndexInSheet", new_index)

        if old_owner_index is not None:
            old_owner_to_new_owner[old_owner_index] = new_owner_index

        text = offset_coords(text, dx, dy)
        text = make_unique(text, salt_base + new_owner_index)
        out_records.append(text.encode("latin1"))


def find_component_block(records: list[bytes], lib_ref: str) -> tuple[list[bytes], int]:
    starts: list[tuple[int, str]] = []
    for i, rec in enumerate(records, start=1):
        text = rec.decode("latin1", "ignore")
        m = re.match(r"\|RECORD=1\|LibReference=([^|]+)", text)
        if m:
            starts.append((i, m.group(1)))

    for pos, (ordinal, name) in enumerate(starts):
        if name != lib_ref:
            continue
        next_ordinal = starts[pos + 1][0] if pos + 1 < len(starts) else len(records) + 1
        return records[ordinal - 1 : next_ordinal - 1], ordinal
    raise KeyError(lib_ref)


def append_component_block(
    out_records: list[bytes],
    block: list[bytes],
    source_start_ordinal: int,
    designator: str,
    part_id: int,
    x: int,
    y: int,
    salt_base: int,
) -> None:
    old_to_new_record_ordinal: dict[int, int] = {}
    first = True
    designator_set = False

    for offset, rec in enumerate(block):
        old_ordinal = source_start_ordinal + offset
        new_ordinal = sum(1 for r in out_records if r.startswith(b"|RECORD=")) + 1
        old_to_new_record_ordinal[old_ordinal] = new_ordinal

        text = rec.decode("latin1")
        owner = get_int_field(text, "OwnerIndex")
        if owner is not None and owner in old_to_new_record_ordinal:
            text = set_int_field(text, "OwnerIndex", old_to_new_record_ordinal[owner])

        if "IndexInSheet=" in text:
            index = get_int_field(text, "IndexInSheet")
            if index is not None:
                text = set_int_field(text, "IndexInSheet", new_ordinal - 1)

        if first:
            text = set_int_field(text, "OwnerPartId", -1)
            text = set_int_field(text, "CurrentPartId", part_id)
            text = replace_field(text, "Location.X", str(x))
            text = replace_field(text, "Location.Y", str(y))
            first = False

        if "Name=Designator" in text and not designator_set:
            text = replace_field(text, "Text", designator)
            designator_set = True

        text = make_unique(text, salt_base + new_ordinal)
        out_records.append(text.encode("latin1"))


def append_connectors(out_records: list[bytes]) -> None:
    for salt, (lib_ref, designator, part_id, x, y) in enumerate(CONNECTORS, start=20):
        block = parse_records(read_stream(LIB, [lib_ref, "Data"]))
        append_component_block(
            out_records,
            block,
            1,
            designator,
            part_id,
            x,
            y,
            salt * 0x10000,
        )


def build_fileheader() -> bytes:
    first_path = PROJECT / SOURCES[0][0]
    header_records = parse_records(read_stream(first_path, "FileHeader"))
    out_records: list[bytes] = []

    header = header_records[0].decode("latin1")
    sheet = header_records[1].decode("latin1")

    sheet = replace_field(sheet, "SheetStyle", "1")
    sheet = replace_field(sheet, "CustomX", "4681")
    sheet = replace_field(sheet, "CustomY", "3311")
    sheet = replace_field(sheet, "CustomXZones", "12")
    sheet = replace_field(sheet, "CustomYZones", "8")

    out_records.append(header.encode("latin1"))
    out_records.append(sheet.encode("latin1"))

    for salt, (filename, dx, dy) in enumerate(SOURCES, start=1):
        records = parse_records(read_stream(PROJECT / filename, "FileHeader"))
        append_source(out_records, records, dx, dy, salt * 0x10000)

    record_count = sum(1 for r in out_records if r.startswith(b"|RECORD="))
    header = out_records[0].decode("latin1")
    header = replace_field(header, "Weight", str(record_count))
    out_records[0] = header.encode("latin1")
    return pack_records(out_records)


ENDOFCHAIN = 0xFFFFFFFE
FREESECT = 0xFFFFFFFF
FATSECT = 0xFFFFFFFD


def dir_entry(
    name: str,
    obj_type: int,
    left: int,
    right: int,
    child: int,
    start_sector: int,
    size: int,
) -> bytes:
    encoded = name.encode("utf-16le") + b"\x00\x00"
    encoded = encoded[:64].ljust(64, b"\x00")
    name_len = min(len(name.encode("utf-16le")) + 2, 64)
    entry = bytearray(128)
    entry[0:64] = encoded
    struct.pack_into("<H", entry, 64, name_len)
    entry[66] = obj_type
    entry[67] = 1
    struct.pack_into("<III", entry, 68, left, right, child)
    struct.pack_into("<I", entry, 116, start_sector)
    struct.pack_into("<Q", entry, 120, size)
    return bytes(entry)


def sector_chain(start: int, count: int) -> list[int]:
    if count == 0:
        return []
    return list(range(start, start + count))


def write_cfb(path: Path, streams: dict[str, bytes]) -> None:
    sector_size = 512
    ordered = ["FileHeader", "Storage", "Additional"]
    padded_streams: dict[str, bytes] = {}
    stream_starts: dict[str, int] = {}
    stream_counts: dict[str, int] = {}

    sectors = bytearray()
    next_sector = 0
    for name in ordered:
        data = streams[name]
        count = math.ceil(len(data) / sector_size)
        stream_starts[name] = next_sector
        stream_counts[name] = count
        padded = data.ljust(count * sector_size, b"\x00")
        padded_streams[name] = padded
        sectors += padded
        next_sector += count

    dir_start = next_sector
    dir_entries = [
        dir_entry("Root Entry", 5, FREESECT, FREESECT, 1, ENDOFCHAIN, 0),
        dir_entry("FileHeader", 2, FREESECT, 2, FREESECT, stream_starts["FileHeader"], len(streams["FileHeader"])),
        dir_entry("Storage", 2, FREESECT, 3, FREESECT, stream_starts["Storage"], len(streams["Storage"])),
        dir_entry("Additional", 2, FREESECT, FREESECT, FREESECT, stream_starts["Additional"], len(streams["Additional"])),
    ]
    directory = b"".join(dir_entries).ljust(sector_size, b"\x00")
    sectors += directory
    next_sector += 1

    # Compute FAT sectors. Recalculate until the FAT itself fits.
    data_sector_count = next_sector
    fat_count = 1
    while True:
        needed = math.ceil((data_sector_count + fat_count) / 128)
        if needed == fat_count:
            break
        fat_count = needed

    fat_start = data_sector_count
    total_sectors = data_sector_count + fat_count
    fat = [FREESECT] * (fat_count * 128)

    for name in ordered:
        chain = sector_chain(stream_starts[name], stream_counts[name])
        for a, b in zip(chain, chain[1:]):
            fat[a] = b
        fat[chain[-1]] = ENDOFCHAIN

    fat[dir_start] = ENDOFCHAIN
    for sec in range(fat_start, fat_start + fat_count):
        fat[sec] = FATSECT

    fat_bytes = b"".join(struct.pack("<I", value) for value in fat)
    fat_bytes = fat_bytes[: fat_count * sector_size]

    header = bytearray(512)
    header[0:8] = bytes.fromhex("D0CF11E0A1B11AE1")
    struct.pack_into("<16s", header, 8, b"\x00" * 16)
    struct.pack_into("<HHHHH", header, 24, 0x003E, 0x0003, 0xFFFE, 9, 6)
    struct.pack_into("<I", header, 44, fat_count)
    struct.pack_into("<I", header, 48, dir_start)
    struct.pack_into("<I", header, 56, 0)  # Mini stream cutoff: all streams use FAT.
    struct.pack_into("<I", header, 60, ENDOFCHAIN)
    struct.pack_into("<I", header, 64, 0)
    struct.pack_into("<I", header, 68, ENDOFCHAIN)
    struct.pack_into("<I", header, 72, 0)
    difat = [FREESECT] * 109
    for i in range(fat_count):
        difat[i] = fat_start + i
    struct.pack_into("<109I", header, 76, *difat)

    path.write_bytes(bytes(header) + bytes(sectors) + fat_bytes)


def main() -> None:
    first = PROJECT / SOURCES[0][0]
    streams = {
        "FileHeader": build_fileheader(),
        "Storage": read_stream(first, "Storage"),
        "Additional": read_stream(first, "Additional"),
    }
    write_cfb(OUT, streams)
    print(OUT)
    print("FileHeader bytes", len(streams["FileHeader"]))


if __name__ == "__main__":
    main()
