param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\docs\architecture.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$width = 1600
$height = 900
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

function New-Brush([string]$hex) {
    return New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($hex))
}

function Draw-RoundedRect($g, $pen, $brush, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    if ($brush) { $g.FillPath($brush, $path) }
    if ($pen) { $g.DrawPath($pen, $path) }
    $path.Dispose()
}

function Draw-CenteredText($g, [string]$text, $font, $brush, $rect) {
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($text, $font, $brush, $rect, $format)
    $format.Dispose()
}

$bg = New-Brush '#07111f'
$panel = New-Brush '#0e2037'
$subnet = New-Brush '#12314a'
$node = New-Brush '#163b57'
$orange = New-Brush '#ffad42'
$green = New-Brush '#65e6a7'
$white = New-Brush '#edf5ff'
$muted = New-Brush '#a9bdd2'
$bluePen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#4d9de0'), 3)
$greenPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#65e6a7'), 5)
$dashPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#6a87a6'), 3)
$dashPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$title = New-Object System.Drawing.Font('Segoe UI', 30, [System.Drawing.FontStyle]::Bold)
$heading = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$body = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Regular)
$small = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Regular)

try {
    $graphics.FillRectangle($bg, 0, 0, $width, $height)
    $graphics.DrawString('Codyssey AWS Web Service Architecture', $title, $white, 70, 42)
    $graphics.DrawString('Region: ap-northeast-2 (Seoul)', $body, $muted, 74, 98)

    Draw-RoundedRect $graphics $bluePen $panel 455 160 1050 650 28
    $graphics.DrawString('VPC  10.0.0.0/16', $heading, $white, 495, 190)

    Draw-RoundedRect $graphics $dashPen $subnet 770 280 650 420 24
    $graphics.DrawString('Public Subnet  10.0.1.0/24', $heading, $white, 810, 310)
    $graphics.DrawString('Route Table: 0.0.0.0/0  ->  Internet Gateway', $small, $muted, 812, 355)

    Draw-RoundedRect $graphics $dashPen $null 845 395 510 285 18
    $graphics.DrawString('Security Group (attached to EC2)', $body, $green, 860, 402)
    Draw-RoundedRect $graphics $bluePen $node 900 440 390 135 20
    Draw-CenteredText $graphics "EC2`nNginx :80`nWelcome to nginx!" $heading $white (New-Object System.Drawing.RectangleF(920, 448, 350, 120))
    $graphics.DrawString('Inbound / outbound settings:', $body, $muted, 860, 605)
    $graphics.DrawString('see Markdown configuration tables', $body, $muted, 860, 635)

    Draw-RoundedRect $graphics $bluePen $node 500 380 190 125 18
    Draw-CenteredText $graphics "Internet`nGateway" $heading $orange (New-Object System.Drawing.RectangleF(515, 395, 160, 95))


    Draw-RoundedRect $graphics $bluePen $node 75 345 250 145 20
    Draw-CenteredText $graphics "Web browser`nGET /" $heading $white (New-Object System.Drawing.RectangleF(95, 365, 210, 105))

    $graphics.DrawLine($greenPen, 325, 418, 500, 418)
    $graphics.DrawLine($greenPen, 690, 443, 900, 490)
    $graphics.FillPolygon($green, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(890,480)), (New-Object System.Drawing.PointF(912,493)), (New-Object System.Drawing.PointF(886,501))))
    $graphics.DrawString('HTTP :80', $body, $green, 350, 380)
    $graphics.DrawString('Internet traffic', $small, $muted, 704, 420)

    $graphics.DrawString('Outbound: EC2  ->  Route Table  ->  Internet Gateway  ->  Internet', $body, $muted, 495, 750)
    $graphics.DrawString('SIMULATED DESIGN - No AWS resources created  |  EBS gp3 8 GiB encrypted  |  IMDSv2 required', $small, $muted, 75, 838)

    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory | Out-Null
    }
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
    foreach ($resource in @($bg,$panel,$subnet,$node,$orange,$green,$white,$muted,$bluePen,$greenPen,$dashPen,$title,$heading,$body,$small)) {
        if ($resource) { $resource.Dispose() }
    }
}

Write-Host "Created $OutputPath"
