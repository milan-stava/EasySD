$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

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
    return [byte[]]@([byte]($Value -band 0xFF), [byte](($Value -shr 8) -band 0xFF))
}

function U16BE {
    param([int]$Value)
    return [byte[]]@([byte](($Value -shr 8) -band 0xFF), [byte]($Value -band 0xFF))
}

function Get-XorChecksum {
    param([byte[]]$Data)
    [int]$x = 0
    foreach ($b in $Data) { $x = $x -bxor $b }
    return [byte]$x
}

function Make-TapBlock {
    param([byte]$Flag, [byte[]]$Payload)
    $body0 = Concat-Bytes @([byte[]]@($Flag), $Payload)
    $body = Concat-Bytes @($body0, [byte[]]@((Get-XorChecksum $body0)))
    return Concat-Bytes @((U16LE $body.Length), $body)
}

function Make-Header {
    param([byte]$TypeByte, [string]$Name, [int]$Length, [int]$P1, [int]$P2)
    if ($Name.Length -gt 10) { $Name = $Name.Substring(0,10) }
    $Name = $Name.PadRight(10, ' ')
    $payload = Concat-Bytes @(
        [byte[]]@($TypeByte),
        [System.Text.Encoding]::ASCII.GetBytes($Name),
        (U16LE $Length), (U16LE $P1), (U16LE $P2)
    )
    return Make-TapBlock 0x00 $payload
}

function Make-ZxNum {
    param([int]$Number)
    return Concat-Bytes @(
        [System.Text.Encoding]::ASCII.GetBytes($Number.ToString()),
        [byte[]]@(0x0E,0,0,[byte]($Number -band 0xFF),[byte](($Number -shr 8) -band 0xFF),0)
    )
}

function Make-BasicLine {
    param([int]$LineNumber, [byte[]]$Content)
    $data = Concat-Bytes @($Content, [byte[]]@(0x0D))
    return Concat-Bytes @((U16BE $LineNumber), (U16LE $data.Length), $data)
}

function S { param([string]$Text) return [System.Text.Encoding]::ASCII.GetBytes($Text) }
function Q { param([string]$Text) return S ('"' + $Text + '"') }

function Validate-Tap {
    param([byte[]]$Tap)
    [int]$i=0; [int]$blocks=0
    while ($i -lt $Tap.Length) {
        if ($i + 2 -gt $Tap.Length) { throw "Truncated TAP length" }
        $len = [int]$Tap[$i] -bor ([int]$Tap[$i+1] -shl 8)
        $i += 2
        if ($i + $len -gt $Tap.Length) { throw "Truncated TAP block" }
        $body = New-Object byte[] $len
        [Array]::Copy($Tap,$i,$body,0,$len)
        if ((Get-XorChecksum $body) -ne 0) { throw "Bad TAP checksum" }
        $i += $len; $blocks++
    }
    if ($i -ne $Tap.Length) { throw "Bad TAP total length" }
    return $blocks
}

# ZX BASIC tokens used by the original Switcher 1.0 generator.
$TOK_USR=0xC0; $TOK_INT=0xBA; $TOK_THEN=0xCB; $TOK_REM=0xEA; $TOK_GOTO=0xEC
$TOK_INPUT=0xEE; $TOK_LOAD=0xEF; $TOK_LET=0xF1; $TOK_PAUSE=0xF2; $TOK_PRINT=0xF5
$TOK_IF=0xFA; $TOK_CLS=0xFB; $TOK_CLEAR=0xFD; $TOK_CODE=0xAF

function T { param([int]$v) return [byte[]]@([byte]$v) }

function Build-Basic {
    $lines = New-Object 'System.Collections.Generic.List[byte[]]'
    $lines.Add((Make-BasicLine 10  (Concat-Bytes @((T $TOK_CLEAR),(S ' '),(Make-ZxNum 32767),(S ':'),(T $TOK_LOAD),(S ' "" '),(T $TOK_CODE),(S ' '),(Make-ZxNum 32768)))))
    $lines.Add((Make-BasicLine 20  (T $TOK_CLS)))
    $lines.Add((Make-BasicLine 30  (Concat-Bytes @((T $TOK_LET),(S ' s='),(T $TOK_USR),(S ' '),(Make-ZxNum 32779)))))
    $lines.Add((Make-BasicLine 35  (Concat-Bytes @((T $TOK_LET),(S ' m='),(T $TOK_USR),(S ' '),(Make-ZxNum 32782)))))
    $lines.Add((Make-BasicLine 36  (Concat-Bytes @((T $TOK_LET),(S ' c=m-'),(Make-ZxNum 2),(S '*'),(T $TOK_INT),(S ' (m/'),(Make-ZxNum 2),(S ')')))))
    $lines.Add((Make-BasicLine 37  (Concat-Bytes @((T $TOK_LET),(S ' d='),(T $TOK_INT),(S ' (m/'),(Make-ZxNum 2),(S ')-'),(Make-ZxNum 2),(S '*'),(T $TOK_INT),(S ' (m/'),(Make-ZxNum 4),(S ')')))))
    $lines.Add((Make-BasicLine 38  (Concat-Bytes @((T $TOK_LET),(S ' e='),(T $TOK_INT),(S ' (m/'),(Make-ZxNum 4),(S ')')))))
    $lines.Add((Make-BasicLine 40  (Concat-Bytes @((T $TOK_PRINT),(S ' '),(Q 'EasySD/EasyCF switcher 1.1')))))
    $lines.Add((Make-BasicLine 50  (T $TOK_PRINT)))
    $lines.Add((Make-BasicLine 60  (Concat-Bytes @((T $TOK_PRINT),(S ' '),(Q 'Current: '),(S ';')))))

    foreach ($x in @(@(70,0,'CF'),@(80,1,'SD1'),@(90,2,'SD2'))) {
        $lines.Add((Make-BasicLine $x[0] (Concat-Bytes @((T $TOK_IF),(S ' s='),(Make-ZxNum $x[1]),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_PRINT),(S ' '),(Q $x[2])))))
    }
    foreach ($x in @(@(92,3,'EasyHDD detected'),@(93,4,'EasySD 1.0 detected'),@(94,5,'EasyCF detected'))) {
        $lines.Add((Make-BasicLine $x[0] (Concat-Bytes @((T $TOK_IF),(S ' s='),(Make-ZxNum $x[1]),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_PRINT),(S ' '),(Q $x[2])))))
    }
    $lines.Add((Make-BasicLine 95 (Concat-Bytes @((T $TOK_IF),(S ' s='),(Make-ZxNum 255),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_PRINT),(S ' '),(Q 'NOT DETECTED')))))
    $lines.Add((Make-BasicLine 96 (Concat-Bytes @((T $TOK_IF),(S ' s>'),(Make-ZxNum 2),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_GOTO),(S ' '),(Make-ZxNum 500)))))
    $lines.Add((Make-BasicLine 100 (T $TOK_PRINT)))

    foreach ($x in @(@(110,'c','1 - CF'),@(120,'d','2 - SD1'),@(130,'e','3 - SD2'))) {
        $n=[int]$x[0]; $f=[string]$x[1]; $label=[string]$x[2]
        $lines.Add((Make-BasicLine $n (Concat-Bytes @((T $TOK_PRINT),(S ' '),(Q $label),(S ';')))))
        $lines.Add((Make-BasicLine ($n+1) (Concat-Bytes @((T $TOK_IF),(S (' '+$f+'=')),(Make-ZxNum 0),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_PRINT),(S ' '),(Q '  NOT DETECTED')))))
        $lines.Add((Make-BasicLine ($n+2) (Concat-Bytes @((T $TOK_IF),(S (' '+$f+'=')),(Make-ZxNum 1),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_PRINT)))))
    }

    $lines.Add((Make-BasicLine 140 (Concat-Bytes @((T $TOK_PRINT),(S ' '),(Q '0 - Exit')))))
    $lines.Add((Make-BasicLine 150 (T $TOK_PRINT)))
    $lines.Add((Make-BasicLine 160 (Concat-Bytes @((T $TOK_INPUT),(S ' '),(Q 'Select: '),(S ';a')))))
    $lines.Add((Make-BasicLine 170 (Concat-Bytes @((T $TOK_IF),(S ' a='),(Make-ZxNum 0),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_GOTO),(S ' '),(Make-ZxNum 9999)))))

    foreach ($x in @(@(180,1,32768),@(190,2,32771),@(200,3,32775))) {
        $lines.Add((Make-BasicLine $x[0] (Concat-Bytes @((T $TOK_IF),(S ' a='),(Make-ZxNum $x[1]),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_LET),(S ' r='),(T $TOK_USR),(S ' '),(Make-ZxNum $x[2]),(S ':'),(T $TOK_GOTO),(S ' '),(Make-ZxNum 300)))))
    }

    $lines.Add((Make-BasicLine 210 (Concat-Bytes @((T $TOK_GOTO),(S ' '),(Make-ZxNum 160)))))
    $lines.Add((Make-BasicLine 300 (Concat-Bytes @((T $TOK_IF),(S ' r='),(Make-ZxNum 0),(S ' '),(T $TOK_THEN),(S ' '),(T $TOK_GOTO),(S ' '),(Make-ZxNum 20)))))
    $lines.Add((Make-BasicLine 310 (T $TOK_PRINT)))
    $lines.Add((Make-BasicLine 320 (Concat-Bytes @((T $TOK_PRINT),(S ' '),(Q 'NOT DETECTED - SWITCH NOT POSSIBLE')))))
    $lines.Add((Make-BasicLine 330 (Concat-Bytes @((T $TOK_PAUSE),(S ' '),(Make-ZxNum 0)))))
    $lines.Add((Make-BasicLine 340 (Concat-Bytes @((T $TOK_GOTO),(S ' '),(Make-ZxNum 20)))))
    $lines.Add((Make-BasicLine 500 (T $TOK_PRINT)))
    $lines.Add((Make-BasicLine 510 (Concat-Bytes @((T $TOK_PRINT),(S ' '),(Q 'EasySD/EasyCF 1.1 not installed')))))
    $lines.Add((Make-BasicLine 520 (T $TOK_PRINT)))
    $lines.Add((Make-BasicLine 530 (Concat-Bytes @((T $TOK_PRINT),(S ' '),(Q 'Press any key')))))
    $lines.Add((Make-BasicLine 540 (Concat-Bytes @((T $TOK_PAUSE),(S ' '),(Make-ZxNum 0)))))
    $lines.Add((Make-BasicLine 550 (Concat-Bytes @((T $TOK_GOTO),(S ' '),(Make-ZxNum 9999)))))
    $lines.Add((Make-BasicLine 9999 (Concat-Bytes @((T $TOK_REM),(S ' End')))))

    return Concat-Bytes $lines.ToArray()
}

try {
    $binPath = Join-Path $Root 'SWITCH_ALL.bin'
    $tapPath = Join-Path $Root 'SWITCH_MENU.tap'
    if (-not (Test-Path $binPath)) { throw 'SWITCH_ALL.bin not found' }
    $code = [System.IO.File]::ReadAllBytes($binPath)
    if ($code.Length -ne 557) { throw "Unexpected SWITCH_ALL.bin size: $($code.Length), expected 557" }

    $basic = Build-Basic
    $tap = Concat-Bytes @(
        (Make-Header 0 'SWITCH1.1' $basic.Length 10 $basic.Length),
        (Make-TapBlock 0xFF $basic),
        (Make-Header 3 'SWITCHCODE' $code.Length 32768 32768),
        (Make-TapBlock 0xFF $code)
    )
    $blocks = Validate-Tap $tap
    [System.IO.File]::WriteAllBytes($tapPath,$tap)

    if ($tap.Length -ne 1797) { throw "Unexpected SWITCH_MENU.tap size: $($tap.Length), expected 1797" }
    Write-Host "SWITCH_MENU.tap: $($tap.Length) B, $blocks valid blocks"
    Write-Host "BASIC: $($basic.Length) B, CODE: $($code.Length) B"
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
exit 0
