#!/usr/bin/env nu
# Generate fixed-width offline badges: brand-colored plate, white icon, white label.
#
#   nu tools/gen-badges.nu            # width auto-sized from the longest label
#   nu tools/gen-badges.nu --width 96 # explicit fixed width
#
# Icons are read from assets/*.svg and every fill inside them is forced to white.

def main [--width: int = 0] {
  let root = ($env.FILE_PWD | path dirname)
  let assets = ($root | path join "assets")
  let outdir = ($assets | path join "badges")

  # name: output file stem / label: badge text / src: icon file in assets/ / color: plate color
  let entries = [
    {name: "codeberg",  label: "Codeberg", src: "codeberg.svg",     color: "#2185D0"}
    {name: "cplusplus", label: "C++",      src: "cplusplus.svg",    color: "#00599C"}
    {name: "csharp",    label: "C#",       src: "csharp-plain.svg", color: "#68217A"}
    {name: "ghostty",   label: "Ghostty",  src: "ghostty.svg",      color: "#3551F3"}
    {name: "github",    label: "GitHub",   src: "github.svg",       color: "#181717"}
    {name: "helix",     label: "Helix",    src: "helix.svg",        color: "#281733"}
    {name: "java",      label: "Java",     src: "java-plain.svg",   color: "#0074BD"}
    {name: "kotlin",    label: "Kotlin",   src: "kotlin.svg",       color: "#7F52FF"}
    {name: "niri",      label: "niri",     src: "niri.svg",         color: "#D55C44"}
    {name: "nix",       label: "Nix",      src: "nix.svg",          color: "#5277C3"}
    {name: "nixos",     label: "NixOS",    src: "nixos.svg",        color: "#5277C3"}
    {name: "nushell",   label: "Nushell",  src: "nushell.svg",      color: "#4E9A06"}
    {name: "python",    label: "Python",   src: "python.svg",       color: "#3776AB"}
    {name: "rust",      label: "Rust",     src: "rust.svg",         color: "#000000"}
    {name: "typst",     label: "Typst",    src: "typst.svg",        color: "#239DAD"}
  ]

  # Rough Verdana 11px advance widths, only used to size the fixed width.
  let char_width = {|c|
    let narrow = "ilj.:;!|,I'"
    let mid = " ()[]{}-+#/ftr"
    let wide = "MWmw"
    if ($narrow | str contains $c) { 4 } else if ($mid | str contains $c) { 6 } else if ($wide | str contains $c) { 11 } else if ($c == ($c | str uppercase)) { 8 } else { 7 }
  }
  let text_width = {|s| ($s | split chars | each {|c| do $char_width $c } | math sum) }

  let icon_area = 19   # icon occupies x = 5..19
  let pad = 16
  let auto = (($entries | each {|e| (do $text_width $e.label) + $icon_area + $pad } | math max))
  let width = (if $width > 0 { $width } else { ((($auto / 4) | math ceil) * 4) })

  mkdir $outdir
  let made = ($entries | each {|e|
    let src_path = ($assets | path join $e.src)
    let raw = (open --raw $src_path)

    # viewBox -> scale and offset the icon into a 14x14 box at x=5, y=3
    let vb = ($raw | parse --regex 'viewBox="(?<v>[^"]+)"' | get 0.v)
    let nums = ($vb | split row " " | where {|t| ($t | str trim) != "" } | each {|t| $t | into float })
    let vb_x = ($nums | get 0); let vb_y = ($nums | get 1)
    let vb_w = ($nums | get 2); let vb_h = ($nums | get 3)
    let scale = (14 / ([$vb_w $vb_h] | math max))
    let tx = (5 + (14 - $vb_w * $scale) / 2 - $vb_x * $scale)
    let ty = (3 + (14 - $vb_h * $scale) / 2 - $vb_y * $scale)
    let round4 = {|x| ($x * 10000 | math round) / 10000 }

    # keep the inner markup only, drop its title, force all fills to white
    let inner = ($raw
      | str replace --regex '(?s)^.*?<svg[^>]*>' ''
      | str replace --regex '(?s)</svg>\s*$' ''
      | str replace --regex '(?s)<title>.*?</title>' ''
      | str replace --all --regex 'fill="#[0-9a-fA-F]{3,6}"' 'fill="#fff"'
      | str trim)

    let tx_r = (do $round4 $tx)
    let ty_r = (do $round4 $ty)
    let sc_r = (do $round4 $scale)
    let tf = ("translate(" + ($tx_r | into string) + "," + ($ty_r | into string) + ") scale(" + ($sc_r | into string) + ")")
    let text_x = ((($icon_area + $width) / 2) | math floor)
    let svg = ($'<svg xmlns="http://www.w3.org/2000/svg" width="($width)" height="20" viewBox="0 0 ($width) 20" role="img" aria-label="($e.label)"><rect width="($width)" height="20" fill="($e.color)"/><g transform="($tf)" fill="#fff">($inner)</g><text x="($text_x)" y="14" fill="#fff" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="11" text-anchor="middle">($e.label)</text></svg>' + (char nl))

    let path = ($outdir | path join $"($e.name).svg")
    $svg | save --force $path
    {name: $e.name, label: $e.label, width: $width, text_px: (do $text_width $e.label), bytes: ($svg | str length)}
  })

  print $"fixed width: ($width)px \(longest label (($entries | sort-by {|e| do $text_width $e.label } | last).label), text ~(($made | get text_px | math max))px\)"
  print $"output: ($outdir)"
  print ($made | select name label width bytes | to md --pretty)
}
