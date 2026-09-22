$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function To-ByteArray {
    param([System.Collections.IEnumerable]$Values)
    $list = New-Object 'System.Collections.Generic.List[byte]'
    foreach ($v in $Values) {
        $list.Add([byte]$v)
    }
    return $list.ToArray()
}

function Concat-Bytes {
    param([object[]]$Parts)
    $ms = New-Object System.IO.MemoryStream
    foreach ($p in $Parts) {
        if ($null -ne $p) {
            $b = [byte[]]$p
            $ms.Write($b, 0, $b.Length)
        }
    }
    $result = $ms.ToArray()
    $ms.Dispose()
    return $result
}

function U16LE {
    param([int]$Value)
    return [byte[]]@(
        [byte]($Value -band 0xFF),
        [byte](($Value -shr 8) -band 0xFF)
    )
}

function U16BE {
    param([int]$Value)
    return [byte[]]@(
        [byte](($Value -shr 8) -band 0xFF),
        [byte]($Value -band 0xFF)
    )
}

function Get-XorChecksum {
    param([byte[]]$Data)
    [int]$x = 0
    foreach ($b in $Data) {
        $x = $x -bxor $b
    }
    return [byte]$x
}

function Make-TapBlock {
    param(
        [byte]$Flag,
        [byte[]]$Payload
    )

    $bodyNoChecksum = Concat-Bytes @([byte[]]@($Flag), $Payload)
    $sum = Get-XorChecksum $bodyNoChecksum
    $body = Concat-Bytes @($bodyNoChecksum, [byte[]]@($sum))
    return Concat-Bytes @((U16LE $body.Length), $body)
}

function Make-Header {
    param(
        [byte]$TypeByte,
        [string]$Name,
        [int]$Length,
        [int]$P1,
        [int]$P2
    )

    $name10 = $Name
    if ($name10.Length -gt 10) {
        $name10 = $name10.Substring(0, 10)
    }
    $name10 = $name10.PadRight(10, " ")
    $nameBytes = [System.Text.Encoding]::ASCII.GetBytes($name10)

    $payload = Concat-Bytes @(
        [byte[]]@($TypeByte),
        $nameBytes,
        (U16LE $Length),
        (U16LE $P1),
        (U16LE $P2)
    )

    return Make-TapBlock 0x00 $payload
}

function Make-CodeFile {
    param(
        [string]$Name,
        [byte[]]$Data,
        [int]$Address
    )
    return Concat-Bytes @(
        (Make-Header 3 $Name $Data.Length $Address 0x8000),
        (Make-TapBlock 0xFF $Data)
    )
}

function Make-ZxNum {
    param([int]$Number)

    $ascii = [System.Text.Encoding]::ASCII.GetBytes($Number.ToString())
    $internal = [byte[]]@(
        0x0E, 0x00, 0x00,
        [byte]($Number -band 0xFF),
        [byte](($Number -shr 8) -band 0xFF),
        0x00
    )

    return Concat-Bytes @($ascii, $internal)
}

function Make-BasicLine {
    param(
        [int]$LineNumber,
        [byte[]]$Content
    )

    $withCR = Concat-Bytes @($Content, [byte[]]@(0x0D))
    return Concat-Bytes @(
        (U16BE $LineNumber),
        (U16LE $withCR.Length),
        $withCR
    )
}

function Validate-Tap {
    param([byte[]]$Tap)

    [int]$i = 0
    [int]$blocks = 0

    while ($i -lt $Tap.Length) {
        if (($i + 2) -gt $Tap.Length) {
            throw "Internal TAP validation failed: truncated block length"
        }

        $len = [int]$Tap[$i] -bor ([int]$Tap[$i + 1] -shl 8)
        $i += 2

        if (($i + $len) -gt $Tap.Length) {
            throw "Internal TAP validation failed: truncated block"
        }

        $body = New-Object byte[] $len
        [Array]::Copy($Tap, $i, $body, 0, $len)

        if ((Get-XorChecksum $body) -ne 0) {
            throw "Internal TAP validation failed: bad checksum"
        }

        $i += $len
        $blocks++
    }

    if ($i -ne $Tap.Length) {
        throw "Internal TAP validation failed: bad total length"
    }

    return $blocks
}

# ZX BASIC tokens
$TOK_CLEAR     = [byte]0xFD
$TOK_LOAD      = [byte]0xEF
$TOK_CODE      = [byte]0xAF
$TOK_RANDOMIZE = [byte]0xF9
$TOK_USR       = [byte]0xC0


# ----------------------------------------------------------------------
# Simple TAP containing EasySD_MB.bin
#
# BASIC:
# 10 CLEAR 32767: LOAD "" CODE 32768:RANDOMIZE USR 32768
# ----------------------------------------------------------------------

function Make-SimpleEasyTap {
    param(
        [string]$BinName,
        [string]$TapName,
        [string]$SpectrumName
    )

    $binPath = Join-Path $Root $BinName
    $tapPath = Join-Path $Root $TapName

    if (-not (Test-Path $binPath)) {
        throw "Missing file: $BinName"
    }

    $binary = [System.IO.File]::ReadAllBytes($binPath)

    if ($binary.Length -eq 0) {
        throw "$BinName is empty"
    }

    if ((32768 + $binary.Length) -gt 65536) {
        throw "$BinName is too large to load at address 32768"
    }

    $content = Concat-Bytes @(
        [byte[]]@($TOK_CLEAR),
        [System.Text.Encoding]::ASCII.GetBytes(" "),
        (Make-ZxNum 32767),
        [System.Text.Encoding]::ASCII.GetBytes(":"),
        [byte[]]@($TOK_LOAD),
        [System.Text.Encoding]::ASCII.GetBytes(' "" '),
        [byte[]]@($TOK_CODE),
        [System.Text.Encoding]::ASCII.GetBytes(" "),
        (Make-ZxNum 32768),
        [System.Text.Encoding]::ASCII.GetBytes(":"),
        [byte[]]@($TOK_RANDOMIZE),
        [System.Text.Encoding]::ASCII.GetBytes(" "),
        [byte[]]@($TOK_USR),
        [System.Text.Encoding]::ASCII.GetBytes(" "),
        (Make-ZxNum 32768)
    )

    $program = Make-BasicLine 10 $content

    $tap = Concat-Bytes @(
        (Make-Header 0 $SpectrumName $program.Length 10 $program.Length),
        (Make-TapBlock 0xFF $program),
        (Make-CodeFile $SpectrumName $binary 32768)
    )

    $blocks = Validate-Tap $tap
    [System.IO.File]::WriteAllBytes($tapPath, $tap)

    Write-Host "$TapName : OK"
    Write-Host "  source: $BinName ($($binary.Length) bytes)"
    Write-Host '  BASIC: 10 CLEAR 32767: LOAD "" CODE 32768:RANDOMIZE USR 32768'
    Write-Host "  TAP size: $($tap.Length) bytes, blocks: $blocks"
}


# ----------------------------------------------------------------------
# Full eLeMeNt startup TAP
# Ported from the proven make_el_tap.py generator.
# ----------------------------------------------------------------------

function Make-FullElementTap {
    $BSROMPath = Join-Path $Root "BSROM140_EL.rom"
    $BSDOSPath = Join-Path $Root "BSDOS.rom"
    $EasyPath  = Join-Path $Root "EasySD_EL.bin"
    $OutPath   = Join-Path $Root "EasySD_EL.tap"

    foreach ($p in @($BSROMPath, $BSDOSPath, $EasyPath)) {
        if (-not (Test-Path $p)) {
            throw "Missing file: $(Split-Path $p -Leaf)"
        }
    }

    $bsrom = [System.IO.File]::ReadAllBytes($BSROMPath)
    $bsdos = [System.IO.File]::ReadAllBytes($BSDOSPath)
    $easy  = [System.IO.File]::ReadAllBytes($EasyPath)

    if ($bsrom.Length -ne 16384) {
        throw "BSROM140_EL.rom: expected 16384 bytes, got $($bsrom.Length)"
    }

    if ($bsdos.Length -ne 16384) {
        throw "BSDOS.rom: expected 16384 bytes, got $($bsdos.Length)"
    }

    if ($easy.Length -gt 0x4000) {
        throw "EasySD_EL.bin is too large for 16K staging page: $($easy.Length) bytes"
    }

    $BASE = 0x7000
    $PORT_7FFD = 0x7FFD

    $code = New-Object 'System.Collections.Generic.List[byte]'

    function Emit {
        param([int[]]$Values)
        foreach ($v in $Values) {
            $code.Add([byte]($v -band 0xFF))
        }
    }

    function EmitWord {
        param([int]$Value)
        $code.Add([byte]($Value -band 0xFF))
        $code.Add([byte](($Value -shr 8) -band 0xFF))
    }

    $PAGE0 = $BASE + $code.Count
    Emit @(0x3E, 0x10)
    $p0jr = $code.Count
    Emit @(0x18, 0x00)

    $PAGE1 = $BASE + $code.Count
    Emit @(0x3E, 0x11)
    $p1jr = $code.Count
    Emit @(0x18, 0x00)

    $PAGE3 = $BASE + $code.Count
    Emit @(0x3E, 0x13)
    $p3jr = $code.Count
    Emit @(0x18, 0x00)

    $SELECT_PAGE = $BASE + $code.Count
    Emit @(0x01)
    EmitWord $PORT_7FFD
    Emit @(0xED, 0x79, 0xC9)

    foreach ($pair in @(
        @($p0jr, $SELECT_PAGE),
        @($p1jr, $SELECT_PAGE),
        @($p3jr, $SELECT_PAGE)
    )) {
        $pos = [int]$pair[0]
        $target = [int]$pair[1]
        $nextAddr = $BASE + $pos + 2
        $disp = $target - $nextAddr

        if (($disp -lt -128) -or ($disp -gt 127)) {
            throw "Internal loader JR out of range"
        }

        $code[$pos + 1] = [byte]($disp -band 0xFF)
    }

    $START = $BASE + $code.Count

    # Enable eLeMeNt DivSD + MB02+ mode: e_zxi_001 = #02
    Emit @(0x01); EmitWord 0x783B
    Emit @(0x3E, 0x01, 0xED, 0x79)
    Emit @(0x01); EmitWord 0x793B
    Emit @(0x3E, 0x02, 0xED, 0x79)

    # 128K page 0 -> MB02+ bank 0, write enabled (96)
    Emit @(0x01); EmitWord $PORT_7FFD
    Emit @(0x3E, 0x10, 0xED, 0x79, 0x3E, 96, 0xD3, 23)
    Emit @(0x21); EmitWord 0xC000
    Emit @(0x11); EmitWord 0x0000
    Emit @(0x01); EmitWord 0x4000
    Emit @(0xED, 0xB0)

    # 128K page 1 -> MB02+ bank 1, write enabled (97)
    Emit @(0x01); EmitWord $PORT_7FFD
    Emit @(0x3E, 0x11, 0xED, 0x79, 0x3E, 97, 0xD3, 23)
    Emit @(0x21); EmitWord 0xC000
    Emit @(0x11); EmitWord 0x0000
    Emit @(0x01); EmitWord 0x4000
    Emit @(0xED, 0xB0)

    # 128K page 3 -> EasySD at #8000
    Emit @(0x01); EmitWord $PORT_7FFD
    Emit @(0x3E, 0x13, 0xED, 0x79)
    Emit @(0x21); EmitWord 0xC000
    Emit @(0x11); EmitWord 0x8000
    Emit @(0x01); EmitWord $easy.Length
    Emit @(0xED, 0xB0)

    # Select BSROM bank 0 read-only and start EasySD
    Emit @(0x3E, 64, 0xD3, 23, 0xC3)
    EmitWord 0x8000

    $loader = $code.ToArray()

    $program = Concat-Bytes @(
        (Make-BasicLine 10  (Concat-Bytes @([byte[]]@($TOK_CLEAR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 28671)))),
        (Make-BasicLine 20  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $BASE)))),
        (Make-BasicLine 30  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $PAGE0)))),
        (Make-BasicLine 40  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 0xC000)))),
        (Make-BasicLine 50  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $PAGE1)))),
        (Make-BasicLine 60  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 0xC000)))),
        (Make-BasicLine 70  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $PAGE3)))),
        (Make-BasicLine 80  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 0xC000)))),
        (Make-BasicLine 90  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $START))))
    )

    $tap = Concat-Bytes @(
        (Make-Header 0 "EASYSD_EL" $program.Length 10 $program.Length),
        (Make-TapBlock 0xFF $program),
        (Make-CodeFile "EL128DIR" $loader $BASE),
        (Make-CodeFile "BSROM140" $bsrom 0xC000),
        (Make-CodeFile "BSDOS" $bsdos 0xC000),
        (Make-CodeFile "EasySD_EL" $easy 0xC000)
    )

    $blocks = Validate-Tap $tap
    [System.IO.File]::WriteAllBytes($OutPath, $tap)

    Write-Host "EasySD_EL.tap : OK"
    Write-Host "  EasySD_EL.bin: $($easy.Length) bytes"
    Write-Host "  Loader: $($loader.Length) bytes"
    Write-Host "  TAP size: $($tap.Length) bytes, blocks: $blocks"
    Write-Host ("  PAGE0=#{0:X4} PAGE1=#{1:X4} PAGE3=#{2:X4} START=#{3:X4}" -f $PAGE0,$PAGE1,$PAGE3,$START)
}

# ----------------------------------------------------------------------
# Full MB03+ Slim startup TAP
# Same staging/copy sequence as the proven eLeMeNt loader; only machine
# switching uses m_zxi_000=#01 on ports #703B/#713B.
# ----------------------------------------------------------------------
function Make-FullSlimTap {
    $BSROMPath = Join-Path $Root "BSROM140_EL.rom"
    $BSDOSPath = Join-Path $Root "BSDOS.rom"
    $EasyPath  = Join-Path $Root "EasySD_SLIM.bin"
    $OutPath   = Join-Path $Root "EasySD_SLIM.tap"

    foreach ($p in @($BSROMPath, $BSDOSPath, $EasyPath)) {
        if (-not (Test-Path $p)) {
            throw "Missing file: $(Split-Path $p -Leaf)"
        }
    }

    $bsrom = [System.IO.File]::ReadAllBytes($BSROMPath)
    $bsdos = [System.IO.File]::ReadAllBytes($BSDOSPath)
    $easy  = [System.IO.File]::ReadAllBytes($EasyPath)

    if ($bsrom.Length -ne 16384) {
        throw "BSROM140_EL.rom: expected 16384 bytes, got $($bsrom.Length)"
    }

    if ($bsdos.Length -ne 16384) {
        throw "BSDOS.rom: expected 16384 bytes, got $($bsdos.Length)"
    }

    if ($easy.Length -gt 0x4000) {
        throw "EasySD_SLIM.bin is too large for 16K staging page: $($easy.Length) bytes"
    }

    $BASE = 0x7000
    $PORT_7FFD = 0x7FFD

    $code = New-Object 'System.Collections.Generic.List[byte]'

    function Emit {
        param([int[]]$Values)
        foreach ($v in $Values) {
            $code.Add([byte]($v -band 0xFF))
        }
    }

    function EmitWord {
        param([int]$Value)
        $code.Add([byte]($Value -band 0xFF))
        $code.Add([byte](($Value -shr 8) -band 0xFF))
    }

    $PAGE0 = $BASE + $code.Count
    Emit @(0x3E, 0x10)
    $p0jr = $code.Count
    Emit @(0x18, 0x00)

    $PAGE1 = $BASE + $code.Count
    Emit @(0x3E, 0x11)
    $p1jr = $code.Count
    Emit @(0x18, 0x00)

    $PAGE3 = $BASE + $code.Count
    Emit @(0x3E, 0x13)
    $p3jr = $code.Count
    Emit @(0x18, 0x00)

    $SELECT_PAGE = $BASE + $code.Count
    Emit @(0x01)
    EmitWord $PORT_7FFD
    Emit @(0xED, 0x79, 0xC9)

    foreach ($pair in @(
        @($p0jr, $SELECT_PAGE),
        @($p1jr, $SELECT_PAGE),
        @($p3jr, $SELECT_PAGE)
    )) {
        $pos = [int]$pair[0]
        $target = [int]$pair[1]
        $nextAddr = $BASE + $pos + 2
        $disp = $target - $nextAddr

        if (($disp -lt -128) -or ($disp -gt 127)) {
            throw "Internal loader JR out of range"
        }

        $code[$pos + 1] = [byte]($disp -band 0xFF)
    }

    $START = $BASE + $code.Count

    # MB03+ Slim: switch to MB02+ / BSDOS machine: m_zxi_000 = #01
    # #703B = m_zxi register select, #713B = m_zxi data
    Emit @(0x01); EmitWord 0x703B
    Emit @(0xAF, 0xED, 0x79)
    Emit @(0x01); EmitWord 0x713B
    Emit @(0x3E, 0x01, 0xED, 0x79)

    # 128K page 0 -> MB02+ bank 0, write enabled (96)
    Emit @(0x01); EmitWord $PORT_7FFD
    Emit @(0x3E, 0x10, 0xED, 0x79, 0x3E, 96, 0xD3, 23)
    Emit @(0x21); EmitWord 0xC000
    Emit @(0x11); EmitWord 0x0000
    Emit @(0x01); EmitWord 0x4000
    Emit @(0xED, 0xB0)

    # 128K page 1 -> MB02+ bank 1, write enabled (97)
    Emit @(0x01); EmitWord $PORT_7FFD
    Emit @(0x3E, 0x11, 0xED, 0x79, 0x3E, 97, 0xD3, 23)
    Emit @(0x21); EmitWord 0xC000
    Emit @(0x11); EmitWord 0x0000
    Emit @(0x01); EmitWord 0x4000
    Emit @(0xED, 0xB0)

    # 128K page 3 -> EasySD at #8000
    Emit @(0x01); EmitWord $PORT_7FFD
    Emit @(0x3E, 0x13, 0xED, 0x79)
    Emit @(0x21); EmitWord 0xC000
    Emit @(0x11); EmitWord 0x8000
    Emit @(0x01); EmitWord $easy.Length
    Emit @(0xED, 0xB0)

    # Select BSROM bank 0 read-only and start EasySD
    Emit @(0x3E, 64, 0xD3, 23, 0xC3)
    EmitWord 0x8000

    $loader = $code.ToArray()

    $program = Concat-Bytes @(
        (Make-BasicLine 10  (Concat-Bytes @([byte[]]@($TOK_CLEAR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 28671)))),
        (Make-BasicLine 20  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $BASE)))),
        (Make-BasicLine 30  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $PAGE0)))),
        (Make-BasicLine 40  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 0xC000)))),
        (Make-BasicLine 50  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $PAGE1)))),
        (Make-BasicLine 60  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 0xC000)))),
        (Make-BasicLine 70  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $PAGE3)))),
        (Make-BasicLine 80  (Concat-Bytes @([byte[]]@($TOK_LOAD), [System.Text.Encoding]::ASCII.GetBytes(' "" '), [byte[]]@($TOK_CODE), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum 0xC000)))),
        (Make-BasicLine 90  (Concat-Bytes @([byte[]]@($TOK_RANDOMIZE), [System.Text.Encoding]::ASCII.GetBytes(" "), [byte[]]@($TOK_USR), [System.Text.Encoding]::ASCII.GetBytes(" "), (Make-ZxNum $START))))
    )

    $tap = Concat-Bytes @(
        (Make-Header 0 "EASYSD_SLM" $program.Length 10 $program.Length),
        (Make-TapBlock 0xFF $program),
        (Make-CodeFile "SLIM128DIR" $loader $BASE),
        (Make-CodeFile "BSROM140" $bsrom 0xC000),
        (Make-CodeFile "BSDOS" $bsdos 0xC000),
        (Make-CodeFile "EasySD_SLM" $easy 0xC000)
    )

    $blocks = Validate-Tap $tap
    [System.IO.File]::WriteAllBytes($OutPath, $tap)

    Write-Host "EasySD_SLIM.tap : OK"
    Write-Host "  EasySD_SLIM.bin: $($easy.Length) bytes"
    Write-Host "  Loader: $($loader.Length) bytes"
    Write-Host "  TAP size: $($tap.Length) bytes, blocks: $blocks"
    Write-Host ("  PAGE0=#{0:X4} PAGE1=#{1:X4} PAGE3=#{2:X4} START=#{3:X4}" -f $PAGE0,$PAGE1,$PAGE3,$START)
}


try {
    Make-SimpleEasyTap "EasySD_MB.bin" "EasySD_MB_BIN.tap" "EASYSD_MB"
    Make-FullElementTap
    Make-FullSlimTap
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}

exit 0
