$mods = Get-Content "liste_mods.txt"
$result = @()

# CurseForge: gameId 432 = Minecraft
$cfApiKey = $env:CF_API_KEY
$cfHeaders = @{}
if ($cfApiKey) { $cfHeaders["x-api-key"] = $cfApiKey }

function Try-ParseDate($s) {
    try { return [datetime]::Parse($s) } catch { return $null }
}

foreach ($mod in $mods) {
    # Nom “approximatif” : on retire la version à partir du premier "-<chiffre>"
    $nameGuess = ($mod -replace "\.jar$", "") -replace "-\d.*$", ""
    $nameEsc = [uri]::EscapeDataString($nameGuess)

    $mrDate = $null; $mrSource = "NOT_FOUND"
    $cfDate = $null; $cfSource = "NOT_FOUND"

    Write-Host "Recherche: $mod  (query='$nameGuess')"

    # --- Modrinth search ---
    try {
        $mrUrl = "https://api.modrinth.com/v2/search?query=$nameEsc&limit=1"
        $mr = Invoke-RestMethod -Uri $mrUrl -Method GET

        if ($mr.hits.Count -gt 0) {
            $mrDate = Try-ParseDate $mr.hits[0].date_modified
            $mrSource = "Modrinth"
        }
    } catch {
        $mrSource = "ERROR"
    }

    # --- CurseForge search (requires API key) ---
    if ($cfApiKey) {
        try {
            # search
            $cfSearchUrl = "https://api.curseforge.com/v1/mods/search?gameId=432&classId=6&searchFilter=$nameEsc&pageSize=1"
            $cfSearch = Invoke-RestMethod -Uri $cfSearchUrl -Headers $cfHeaders -Method GET

            if ($cfSearch.data.Count -gt 0) {
                $modId = $cfSearch.data[0].id

                # get mod info (dateModified is reliable)
                $cfModUrl = "https://api.curseforge.com/v1/mods/$modId"
                $cfMod = Invoke-RestMethod -Uri $cfModUrl -Headers $cfHeaders -Method GET

                $cfDate = Try-ParseDate $cfMod.data.dateModified
                $cfSource = "CurseForge"
            }
        } catch {
            $cfSource = "ERROR"
        }
    } else {
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
    Export-Csv "mods_sorted_by_update.csv" -NoTypeInformation -Encoding UTF8

Write-Host "OK -> mods_sorted_by_update.csv"
