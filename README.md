# Minecraft Mod Update Auditor

A small personal tool to audit installed Minecraft mods by retrieving their latest update dates
from public APIs (Modrinth and CurseForge) and exporting the results as a CSV file.

## Purpose
This project is designed for **personal maintenance and troubleshooting** of large modded
Minecraft instances (Forge / NeoForge 1.20.x).

It helps identify:
- Outdated or unmaintained mods
- Potential sources of instability
- Mods that may require updating or removal

## Scope
- Queries **public metadata only**
- Does **not** download, redistribute, or host mod files
- Output is generated locally as a CSV report

## Usage
1. Create a text file containing your installed mods (one `.jar` filename per line)
2. Run the PowerShell script (optionally pass paths)
3. Review the generated CSV report

### Example
```powershell
.\mods_update_check.ps1 -ModsListPath "liste_mods.txt" -OutputPath "mods_sorted_by_update.csv"
```

Set your CurseForge API key in the `CF_API_KEY` environment variable before running,
or enter it when prompted.

## Data Sources
- Modrinth API
- CurseForge API (official, with API key)

## Disclaimer
This tool is not affiliated with CurseForge, Modrinth, or Mojang.
All mod metadata belongs to their respective authors.
