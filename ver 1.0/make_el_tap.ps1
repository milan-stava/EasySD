$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$BSROM = Join-Path $Root "BSROM140_EL.rom"
$BSDOS = Join-Path $Root "BSDOS.rom"
$EASY  = Join-Path $Root "EasySD_EL.bin"
$OUT   = Join-Path $Root "EasySD_EL.tap"

function Fail($msg) {
    Write-Host "ERROR: $msg"
    exit 1
}

function Read-Exact($path, $expected = $null) {
    if (-not (Test-Path $path)) {
        Fail "Missing file: $(Split-Path $path -Leaf)"
    }
    $data = [System.IO.File]::ReadAllBytes($path)
    if ($null -ne $expected -and $data.Length -ne $expected) {
        Fail "$(Split-Path $path -Leaf): expected $expected bytes, got $($data.Length)"
    }
    return $data
}

$bsrom = Read-Exact $BSROM 16384
$bsdos = Read-Exact $BSDOS 16384
$easy  = Read-Exact $EASY

if ($easy.Length -gt 16384) {
    Fail "EasySD_EL.bin is too large for 16K staging page: $($easy.Length) bytes"
}

# --- helper for byte list ---
$code = New-Object System.Collections.Generic.List[byte]

function Emit([byte[]]$bytes) {
    foreach ($b in $bytes) { $script:code.Add($b) }
}

function EmitW([int]$v) {
    Emit ([byte[]]@(($v -band 0xFF), (($v -shr 8) -band 0xFF)))
}

$BASE = 0x7000
$PORT7FFD = 0x7FFD

$PAGE0 = $BASE + $code.Count
Emit ([byte[]]@(0x3E,0x10))
$p0jr = $code.Count
Emit ([byte[]]@(0x18,0x00))

$PAGE1 = $BASE + $code.Count
Emit ([byte[]]@(0x3E,0x11))
$p1jr = $code.Count
Emit ([byte[]]@(0x18,0x00))

$PAGE3 = $BASE + $code.Count
Emit ([byte[]]@(0x3E,0x13))
$p3jr = $code.Count
Emit ([byte[]]@(0x18,0x00))

$SELECT = $BASE + $code.Count
Emit ([byte[]]@(0x01)); EmitW $PORT7FFD
Emit ([byte[]]@(0xED,0x79,0xC9))

function Patch-JR([int]$pos, [int]$target) {
    $nextAddr = $BASE + $pos + 2
    $disp = $target - $nextAddr
    if ($disp -lt -128 -or $disp -gt 127) { Fail "Internal loader JR out of range" }
    $script:code[$pos+1] = [byte]($disp -band 0xFF)
}

Patch-JR $p0jr $SELECT
Patch-JR $p1jr $SELECT
Patch-JR $p3jr $SELECT

$START = $BASE + $code.Count

# e_zxi_001 = #02
Emit ([byte[]]@(0x01)); EmitW 0x783B
Emit ([byte[]]@(0x3E,0x01,0xED,0x79))
Emit ([byte[]]@(0x01)); EmitW 0x793B
Emit ([byte[]]@(0x3E,0x02,0xED,0x79))

# page 0 -> MB02 bank 0 write enabled
Emit ([byte[]]@(0x01)); EmitW $PORT7FFD
Emit ([byte[]]@(0x3E,0x10,0xED,0x79,0x3E,96,0xD3,23))
Emit ([byte[]]@(0x21)); EmitW 0xC000
Emit ([byte[]]@(0x11)); EmitW 0x0000
Emit ([byte[]]@(0x01)); EmitW 0x4000
Emit ([byte[]]@(0xED,0xB0))

# page 1 -> MB02 bank 1 write enabled
Emit ([byte[]]@(0x01)); EmitW $PORT7FFD
Emit ([byte[]]@(0x3E,0x11,0xED,0x79,0x3E,97,0xD3,23))
Emit ([byte[]]@(0x21)); EmitW 0xC000
Emit ([byte[]]@(0x11)); EmitW 0x0000
Emit ([byte[]]@(0x01)); EmitW 0x4000
Emit ([byte[]]@(0xED,0xB0))

# page 3 -> EasySD at #8000
Emit ([byte[]]@(0x01)); EmitW $PORT7FFD
Emit ([byte[]]@(0x3E,0x13,0xED,0x79))
Emit ([byte[]]@(0x21)); EmitW 0xC000
Emit ([byte[]]@(0x11)); EmitW 0x8000
Emit ([byte[]]@(0x01)); EmitW $easy.Length
Emit ([byte[]]@(0xED,0xB0))

# select BSROM bank0 read-only and run EasySD
Emit ([byte[]]@(0x3E,64,0xD3,23,0xC3)); EmitW 0x8000

$loader = $code.ToArray()

function Xor-Checksum([byte[]]$data) {
    [byte]$x = 0
    foreach ($b in $data) { $x = $x -bxor $b }
    return $x
}

function Tap-Block([byte]$flag, [byte[]]$payload) {
    $body = New-Object System.Collections.Generic.List[byte]
    $body.Add($flag)
    foreach ($b in $payload) { $body.Add($b) }
    $sum = Xor-Checksum $body.ToArray()
    $body.Add($sum)

    $ret = New-Object System.Collections.Generic.List[byte]
    $len = $body.Count
    $ret.Add([byte]($len -band 0xFF))
    $ret.Add([byte](($len -shr 8) -band 0xFF))
    foreach ($b in $body) { $ret.Add($b) }
    return $ret.ToArray()
}

function Tap-Header([byte]$type, [string]$name, [int]$len, [int]$p1, [int]$p2) {
    $payload = New-Object System.Collections.Generic.List[byte]
    $payload.Add($type)
    $nm = ($name.PadRight(10).Substring(0,10))
    foreach ($b in [System.Text.Encoding]::ASCII.GetBytes($nm)) { $payload.Add($b) }
    foreach ($v in @($len,$p1,$p2)) {
        $payload.Add([byte]($v -band 0xFF))
        $payload.Add([byte](($v -shr 8) -band 0xFF))
    }
    return Tap-Block 0 $payload.ToArray()
}

function Tap-CodeFile([string]$name, [byte[]]$data, [int]$addr) {
    $ret = New-Object System.Collections.Generic.List[byte]
    foreach ($b in (Tap-Header 3 $name $data.Length $addr 0x8000)) { $ret.Add($b) }
    foreach ($b in (Tap-Block 0xFF $data)) { $ret.Add($b) }
    return $ret.ToArray()
}

function ZXNum([int]$n) {
    $ret = New-Object System.Collections.Generic.List[byte]
    foreach ($b in [System.Text.Encoding]::ASCII.GetBytes($n.ToString())) { $ret.Add($b) }
    foreach ($b in [byte[]]@(0x0E,0,0,($n -band 0xFF),(($n -shr 8) -band 0xFF),0)) { $ret.Add($b) }
    return $ret.ToArray()
}

function Basic-Line([int]$n, [byte[]]$content) {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($b in $content) { $c.Add($b) }
    $c.Add(0x0D)

    $ret = New-Object System.Collections.Generic.List[byte]
    $ret.Add([byte](($n -shr 8) -band 0xFF))
    $ret.Add([byte]($n -band 0xFF))
    $ret.Add([byte]($c.Count -band 0xFF))
    $ret.Add([byte](($c.Count -shr 8) -band 0xFF))
    foreach ($b in $c) { $ret.Add($b) }
    return $ret.ToArray()
}

$TCLEAR=0xFD; $TLOAD=0xEF; $TCODE=0xAF; $TRAND=0xF9; $TUSR=0xC0

function Concat([object[]]$parts) {
    $ret = New-Object System.Collections.Generic.List[byte]
    foreach ($part in $parts) {
        foreach ($b in [byte[]]$part) { $ret.Add($b) }
    }
    return $ret.ToArray()
}

$program = New-Object System.Collections.Generic.List[byte]
$lines = @(
    (Basic-Line 10 (Concat @([byte[]]@($TCLEAR), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum 28671)))),
    (Basic-Line 20 (Concat @([byte[]]@($TLOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TCODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum $BASE)))),
    (Basic-Line 30 (Concat @([byte[]]@($TRAND), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TUSR), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum $PAGE0)))),
    (Basic-Line 40 (Concat @([byte[]]@($TLOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TCODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum 0xC000)))),
    (Basic-Line 50 (Concat @([byte[]]@($TRAND), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TUSR), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum $PAGE1)))),
    (Basic-Line 60 (Concat @([byte[]]@($TLOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TCODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum 0xC000)))),
    (Basic-Line 70 (Concat @([byte[]]@($TRAND), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TUSR), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum $PAGE3)))),
    (Basic-Line 80 (Concat @([byte[]]@($TLOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TCODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum 0xC000)))),
    (Basic-Line 90 (Concat @([byte[]]@($TRAND), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TUSR), [System.Text.Encoding]::ASCII.GetBytes(" "), (ZXNum $START))))
)
foreach ($ln in $lines) { foreach ($b in $ln) { $program.Add($b) } }

$tap = New-Object System.Collections.Generic.List[byte]
foreach ($b in (Tap-Header 0 "EASYSD_EL" $program.Count 10 $program.Count)) { $tap.Add($b) }
foreach ($b in (Tap-Block 0xFF $program.ToArray())) { $tap.Add($b) }
foreach ($b in (Tap-CodeFile "EL128DIR" $loader $BASE)) { $tap.Add($b) }
foreach ($b in (Tap-CodeFile "BSROM140" $bsrom 0xC000)) { $tap.Add($b) }
foreach ($b in (Tap-CodeFile "BSDOS" $bsdos 0xC000)) { $tap.Add($b) }
foreach ($b in (Tap-CodeFile "EasySD_EL" $easy 0xC000)) { $tap.Add($b) }

[System.IO.File]::WriteAllBytes($OUT, $tap.ToArray())

Write-Host "TAP build OK"
Write-Host "  EasySD_EL.tap: $($tap.Count) bytes"
Write-Host "  EasySD_EL.bin: $($easy.Length) bytes"
Write-Host "  Loader: $($loader.Length) bytes"
Write-Host ("  PAGE0=#{0:X4} PAGE1=#{1:X4} PAGE3=#{2:X4} START=#{3:X4}" -f $PAGE0,$PAGE1,$PAGE3,$START)
