<#
  Spike 17 - parche de escenas: inventory_ui.tscn e item_detail_panel.tscn

  Qué hace (y nada más):
    - Da nombre único (%) a los 4 rótulos de cabecera y a los 6 rótulos de stats,
      renombrando los que se llamaban Label, Label2... (la View los usa por %).
    - Retira el texto fijo (text = "...") de esos rótulos y de UseButton /
      EmptyMessage del panel de detalle: ahora se rellenan por código con tr().
    - Cambia slot_label_key de los 6 EquipSlot a claves INVENTORY_SLOT_*.

  Uso: desde la raíz del proyecto y con esas escenas cerradas en el editor:
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\patch_spike17_scenes.ps1

  Si algo no encaja (nodo no encontrado, línea repetida) lanza un error ANTES de
  escribir nada. Deja una copia de cada fichero en %TEMP%\athelia_spike17_*.
#>
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$backupDir = Join-Path $env:TEMP ("athelia_spike17_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $backupDir | Out-Null

function Update-Scene {
	param(
		[string]$Path,
		[hashtable]$Nodes,      # unique_id -> @{ Name; Unique; DropText }
		[hashtable]$LineSwaps   # línea exacta -> línea nueva
	)

	if (-not (Test-Path $Path)) { throw "No existe $Path" }
	$full = (Resolve-Path $Path).Path
	$raw = [System.IO.File]::ReadAllText($full)
	$nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
	$lines = $raw -split "`r?`n"

	$out = New-Object System.Collections.Generic.List[string]
	$seen = @{}
	$dropped = @{}
	$swapped = @{}
	$current = $null

	foreach ($line in $lines) {
		if ($line.StartsWith('[')) {
			$current = $null
			if ($line -match '^\[node name="(?<name>[^"]*)"(?<rest>.*unique_id=(?<id>\d+).*)\]$') {
				$id = $Matches['id']
				$rest = $Matches['rest']
				if ($Nodes.ContainsKey($id)) {
					$spec = $Nodes[$id]
					$seen[$id] = $true
					$current = $spec
					$out.Add('[node name="' + $spec.Name + '"' + $rest + ']')
					if ($spec.Unique) { $out.Add('unique_name_in_owner = true') }
					continue
				}
			}
			$out.Add($line)
			continue
		}

		if ($null -ne $current) {
			if ($current.Unique -and $line -eq 'unique_name_in_owner = true') { continue }
			if ($current.DropText -and $line -match '^text = ') {
				$dropped[$current.Name] = 1 + [int]$dropped[$current.Name]
				continue
			}
		}

		if ($LineSwaps.ContainsKey($line)) {
			$swapped[$line] = 1 + [int]$swapped[$line]
			$out.Add($LineSwaps[$line])
			continue
		}

		$out.Add($line)
	}

	# Validación antes de escribir
	$missing = @($Nodes.Keys | Where-Object { -not $seen.ContainsKey($_) })
	if ($missing.Count -gt 0) { throw "Nodos no encontrados en ${Path}: $($missing -join ', ')" }
	foreach ($k in $Nodes.Keys) {
		$n = $Nodes[$k]
		if ($n.DropText -and $dropped[$n.Name] -ne 1) { throw "El nodo $($n.Name) de $Path no tenía exactamente una línea text=" }
	}
	foreach ($k in $LineSwaps.Keys) {
		if ($swapped[$k] -ne 1) { throw "Se esperaba exactamente una línea [$k] en $Path" }
	}

	Copy-Item $full (Join-Path $backupDir (Split-Path $full -Leaf))
	[System.IO.File]::WriteAllText($full, ($out -join $nl), $utf8)
	Write-Host ("OK  {0}  nodos={1}  textos retirados={2}  líneas cambiadas={3}" -f $Path, $seen.Count, $dropped.Count, $swapped.Count)
}

# ---- inventory_ui.tscn ----
$inventoryNodes = @{
	'79342375'   = @{ Name = 'TitleLabel';           Unique = $true; DropText = $true }
	'330350379'  = @{ Name = 'EquipmentHeader';      Unique = $true; DropText = $true }
	'2015276585' = @{ Name = 'BagHeader';            Unique = $true; DropText = $true }
	'604820057'  = @{ Name = 'StatsHeader';          Unique = $true; DropText = $true }
	'1670427972' = @{ Name = 'StatsHPCaption';       Unique = $true; DropText = $true }
	'1299213597' = @{ Name = 'StatsStaminaCaption';  Unique = $true; DropText = $true }
	'177300997'  = @{ Name = 'StatsGoldCaption';     Unique = $true; DropText = $true }
	'1475983522' = @{ Name = 'StatsSTRCaption';      Unique = $true; DropText = $true }
	'961296871'  = @{ Name = 'StatsDEXCaption';      Unique = $true; DropText = $true }
	'953793920'  = @{ Name = 'StatsCONCaption';      Unique = $true; DropText = $true }
}
$inventorySwaps = @{
	'slot_label_key = "head"'   = 'slot_label_key = "INVENTORY_SLOT_HEAD"'
	'slot_label_key = "body"'   = 'slot_label_key = "INVENTORY_SLOT_BODY"'
	'slot_label_key = "hands"'  = 'slot_label_key = "INVENTORY_SLOT_HANDS"'
	'slot_label_key = "feet"'   = 'slot_label_key = "INVENTORY_SLOT_FEET"'
	'slot_label_key = "weapon"' = 'slot_label_key = "INVENTORY_SLOT_WEAPON"'
	'slot_label_key = "shield"' = 'slot_label_key = "INVENTORY_SLOT_SHIELD"'
}
Update-Scene -Path '.\ui\inventory\inventory_ui.tscn' -Nodes $inventoryNodes -LineSwaps $inventorySwaps

# ---- item_detail_panel.tscn ----
$detailNodes = @{
	'78495662'  = @{ Name = 'UseButton';    Unique = $false; DropText = $true }
	'949574173' = @{ Name = 'EmptyMessage'; Unique = $false; DropText = $true }
}
Update-Scene -Path '.\ui\inventory\item_detail_panel.tscn' -Nodes $detailNodes -LineSwaps @{}

Write-Host "Copias de seguridad en $backupDir"
