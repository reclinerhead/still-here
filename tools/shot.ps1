<#
Takes a game screenshot without the Godot window taking focus or showing on screen.

	tools/shot.ps1 <name> <pose> [flags...]
	tools/shot.ps1 dayroom 18,0,0.6,0,4 restore
	tools/shot.ps1 piano_photo 15.5,0,-3.3,8,-18 photo frames=40

Saves shots/<name>.png. The pose is x,y,z,yaw,pitch; the flags are the game's screenshot switches
without their dashes (restore, photo, before-after, gallery, no-flashlight, frames=n; see "Running
and checking" in CLAUDE.md).

Headless Godot can't take screenshots: its dummy renderer never produces a frame. So this runs a
normal window, placed off every screen, with display/window/size/no_focus set through a temporary
override.cfg that is always removed afterwards. Set GODOT to use another console build.
#>
param(
	[Parameter(Mandatory, Position = 0)] [string] $Name,
	[Parameter(Mandatory, Position = 1)] [string[]] $Pose,
	[Parameter(Position = 2, ValueFromRemainingArguments)] [string[]] $Flags = @()
)

$godot = if ($env:GODOT) { $env:GODOT } else { "D:\Tools\GODOT4\Godot_v4.7.2-stable_win64_console.exe" }
$root = Split-Path -Parent $PSScriptRoot
$override = Join-Path $root "override.cfg"
if (Test-Path $override) {
	throw "override.cfg already exists in the project; remove it first"
}
$png = (Join-Path $root "shots\$Name.png").Replace("\", "/")
New-Item -ItemType Directory -Force (Join-Path $root "shots") | Out-Null
$gameArgs = @("--shot=$png", ("--pose=" + ($Pose -join ","))) + ($Flags | ForEach-Object { "--$_" })
Set-Content $override "[display]`n`nwindow/size/no_focus=true`n" -Encoding utf8NoBOM
try {
	# --quit-after: a script error would otherwise leave the hidden window running
	& $godot --position "-4000,-4000" --quit-after 5000 --path $root -- @gameArgs
} finally {
	Remove-Item $override -ErrorAction SilentlyContinue
}
