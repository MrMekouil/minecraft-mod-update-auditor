[CmdletBinding()]
param(
    [string]$ModsListPath = "liste_mods.txt",
    [string]$OutputPath = "mods_sorted_by_update.csv"
)

if (-not (Test-Path -Path $ModsListPath)) {
    Write-Error "Mods list file not found: $ModsListPath"
    exit 1
}

$mods = Get-Content $ModsListPath -ErrorAction Stop
$result = @()

# CurseForge: gameId 432 = Minecraft
$cfApiKey = $env:CF_API_KEY
if (-not $cfApiKey) {
    $cfApiKey = Read-Host -Prompt "Enter CurseForge API key (press Enter to skip)"
}
$cfHeaders = @{}
if ($cfApiKey) { $cfHeaders["x-api-key"] = $cfApiKey }
$warnedNoApiKey = $false

function Try-ParseDate($s) {
    try { return [datetime]::Parse($s) } catch { return $null }
}

function Normalize-ModName($s) {
    if (-not $s) { return "" }
    return ($s.ToLowerInvariant() -replace "[^a-z0-9]+", "")
}

foreach ($mod in $mods) {
    $mod = $mod.Trim()
    if (-not $mod) { continue }
    # Nom “approximatif” : on retire la version à partir du premier "-<chiffre>"
    $nameGuess = ($mod -replace "\.jar$", "") -replace "-\d.*$", ""
    $nameEsc = [uri]::EscapeDataString($nameGuess)

    $mrDate = $null; $mrSource = "NOT_FOUND"
    $cfDate = $null; $cfSource = "NOT_FOUND"

    Write-Host "Recherche: $mod  (query='$nameGuess')"

    # --- Modrinth search ---
    try {
        $mrUrl = "https://api.modrinth.com/v2/search?query=$nameEsc&limit=10"
        $mr = Invoke-RestMethod -Uri $mrUrl -Method GET -ErrorAction Stop

        if ($mr.hits.Count -gt 0) {
            $normalizedGuess = Normalize-ModName $nameGuess
            $mrHit = $mr.hits | Where-Object {
                (Normalize-ModName $_.title) -eq $normalizedGuess -or
                (Normalize-ModName $_.slug) -eq $normalizedGuess
            } | Select-Object -First 1

            if (-not $mrHit) { $mrHit = $mr.hits[0] }

            $mrDate = Try-ParseDate $mrHit.date_modified
            $mrSource = "Modrinth"
        }
    } catch {
        $mrSource = "ERROR: $($_.Exception.Message)"
    }

    # --- CurseForge search (requires API key) ---
    if ($cfApiKey) {
        try {
            # search
            $cfSearchUrl = "https://api.curseforge.com/v1/mods/search?gameId=432&classId=6&searchFilter=$nameEsc&pageSize=10"
            $cfSearch = Invoke-RestMethod -Uri $cfSearchUrl -Headers $cfHeaders -Method GET -ErrorAction Stop

            if ($cfSearch.data.Count -gt 0) {
                $normalizedGuess = Normalize-ModName $nameGuess
                $cfHit = $cfSearch.data | Where-Object {
                    (Normalize-ModName $_.name) -eq $normalizedGuess -or
                    (Normalize-ModName $_.slug) -eq $normalizedGuess
                } | Select-Object -First 1

                if (-not $cfHit) { $cfHit = $cfSearch.data[0] }

                $modId = $cfHit.id

                # get mod info (dateModified is reliable)
                $cfModUrl = "https://api.curseforge.com/v1/mods/$modId"
                $cfMod = Invoke-RestMethod -Uri $cfModUrl -Headers $cfHeaders -Method GET -ErrorAction Stop

                $cfDate = Try-ParseDate $cfMod.data.dateModified
                $cfSource = "CurseForge"
            }
        } catch {
            $cfSource = "ERROR: $($_.Exception.Message)"
        }
    } else {
        if (-not $warnedNoApiKey) {
            Write-Warning "CF_API_KEY not set. CurseForge lookups will be skipped."
            $warnedNoApiKey = $true
        }
        $cfSource = "NO_API_KEY"
    }

    # Choisir une date finale: la plus récente trouvée (ou l'autre si une seule existe)
    $finalDate = $null
    $sources = @()

    if ($mrDate) { $sources += "Modrinth" }
    if ($cfDate) { $sources += "CurseForge" }

    if ($mrDate -and $cfDate) {
        $finalDate = if ($mrDate -ge $cfDate) { $mrDate } else { $cfDate }
    } elseif ($mrDate) {
        $finalDate = $mrDate
    } elseif ($cfDate) {
        $finalDate = $cfDate
    }

    $result += [PSCustomObject]@{
        Mod        = $mod
        Query      = $nameGuess
        LastUpdate = if ($finalDate) { $finalDate.ToString("yyyy-MM-ddTHH:mm:ssK") } else { "" }
        Modrinth   = if ($mrDate) { $mrDate.ToString("yyyy-MM-dd") } else { "" }
        CurseForge = if ($cfDate) { $cfDate.ToString("yyyy-MM-dd") } else { "" }
        Sources    = ($sources -join "+")
        MR_Status  = $mrSource
        CF_Status  = $cfSource
    }
}

# Tri: plus ancien -> plus récent (les vides en haut)
$result |
    Sort-Object @{ Expression = { if ($_.LastUpdate) { [datetime]$_.LastUpdate } else { [datetime]"1900-01-01" } } } |
    Export-Csv $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $OutputPath"
