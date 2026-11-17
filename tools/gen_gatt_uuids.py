#!/usr/bin/env python3
"""Generate ios/App/App/Core/GATTUUIDs.swift from Bluetooth SIG assigned numbers.

Source (public, maintained by the SIG):
  https://bitbucket.org/bluetooth-SIG/public/raw/main/assigned_numbers/uuids/service_uuids.yaml
  https://bitbucket.org/bluetooth-SIG/public/raw/main/assigned_numbers/uuids/characteristic_uuids.yaml

Usage:
  python tools/gen_gatt_uuids.py [service.yaml] [characteristic.yaml]

With no arguments the two YAML files are downloaded next to the script's temp cache.
Only 16-bit UUIDs are emitted; 128-bit vendor UUIDs keep their raw CBUUID string at runtime.
"""
from __future__ import annotations

import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ios" / "App" / "App" / "Core" / "GATTUUIDs.swift"

SOURCES = {
    "services": "https://bitbucket.org/bluetooth-SIG/public/raw/main/assigned_numbers/uuids/service_uuids.yaml",
    "characteristics": "https://bitbucket.org/bluetooth-SIG/public/raw/main/assigned_numbers/uuids/characteristic_uuids.yaml",
}


def parse(text: str) -> dict[int, str]:
    """Parse the tiny subset of YAML used by the SIG file (list of uuid/name pairs)."""
    entries: dict[int, str] = {}
    current: int | None = None
    for raw in text.splitlines():
        line = raw.rstrip()
        m = re.match(r"\s*-\s*uuid:\s*0[xX]([0-9A-Fa-f]{4})\s*$", line)
        if m:
            current = int(m.group(1), 16)
            continue
        m = re.match(r"\s*name:\s*(.+?)\s*$", line)
        if m and current is not None:
            name = m.group(1).strip().strip("'\"")
            entries.setdefault(current, name)
            current = None
    return entries


def swift_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def dictionary(name: str, entries: dict[int, str]) -> str:
    lines = [f"    /// {len(entries)} 项标准 16-bit UUID（Bluetooth SIG 分配号）。"]
    lines.append(f"    static let {name}: [UInt16: String] = [")
    for uuid in sorted(entries):
        lines.append(f"        {uuid:#06x}: {swift_string(entries[uuid])},")
    lines.append("    ]")
    return "\n".join(lines)


def main() -> None:
    if len(sys.argv) == 3:
        service_text = Path(sys.argv[1]).read_text(encoding="utf-8")
        char_text = Path(sys.argv[2]).read_text(encoding="utf-8")
    else:
        service_text = urllib.request.urlopen(SOURCES["services"], timeout=60).read().decode()
        char_text = urllib.request.urlopen(SOURCES["characteristics"], timeout=60).read().decode()

    services = parse(service_text)
    characteristics = parse(char_text)
    if len(services) < 60 or len(characteristics) < 200:
        raise SystemExit(f"parsed too little: {len(services)} services, {len(characteristics)} characteristics")

    body = f"""// GATTUUIDs.swift
// 由 tools/gen_gatt_uuids.py 从 Bluetooth SIG assigned_numbers 生成，请勿手改。
// 数据来源：https://bitbucket.org/bluetooth-SIG/public（assigned_numbers/uuids/*.yaml）
// 只收录标准 16-bit UUID；128-bit 厂商私有 UUID 在运行时保留原始字符串。
//
// Generated from Bluetooth SIG assigned numbers. Do not edit by hand.

import Foundation

enum GATTUUIDs {{
{dictionary("serviceNames", services)}

{dictionary("characteristicNames", characteristics)}
}}
"""
    OUT.write_text(body, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({len(services)} services, {len(characteristics)} characteristics)")


if __name__ == "__main__":
    main()
