import GLib from "gi://GLib"
import { readFile } from "ags/file"

export const RICE_DIR =
  GLib.getenv("RICE_DIR") ?? `${GLib.get_user_config_dir()}/rices`

export const RICE_BIN =
  GLib.find_program_in_path("rice") ?? `${GLib.get_home_dir()}/.local/bin/rice`

export type Rice = {
  name: string
  title: string
  tagline: string
  transition: string
  dir: string
  preview: string | null
  colors: Record<string, string>
  fonts: { ui: string; mono: string }
  radius: number
  cardCss: string | null
}

type Table = Record<string, Record<string, string>>

// Enough TOML for palette files: [sections] and `key = "string" | number`.
export function parseToml(text: string): Table {
  const out: Table = {}
  let section = ""
  for (const raw of text.split("\n")) {
    const line = raw.trim()
    if (!line || line.startsWith("#")) continue
    const head = line.match(/^\[([^\]]+)\]$/)
    if (head) {
      section = head[1].trim()
      out[section] ??= {}
      continue
    }
    const kv = line.match(/^([\w-]+)\s*=\s*(?:"([^"]*)"|([^#]*?))\s*(?:#.*)?$/)
    if (kv) (out[section] ??= {})[kv[1]] = kv[2] ?? kv[3]
  }
  return out
}

const exists = (path: string) => GLib.file_test(path, GLib.FileTest.EXISTS)

// card.css may say {{colors.accent}} so it never repeats a palette value
const fill = (css: string, t: Table) =>
  css.replace(/\{\{\s*(\w+)\.(\w+)\s*\}\}/g, (m, sec, key) => t[sec]?.[key] ?? m)

export function loadRice(name: string): Rice | null {
  const dir = `${RICE_DIR}/${name}`
  const file = `${dir}/palette.toml`
  if (!exists(file)) return null

  const t = parseToml(readFile(file))
  const meta = t.meta ?? {}
  return {
    name,
    title: meta.title ?? name,
    tagline: meta.tagline ?? "",
    transition: meta.transition ?? "fade",
    dir,
    preview: exists(`${dir}/preview.png`) ? `${dir}/preview.png` : null,
    colors: t.colors ?? {},
    fonts: { ui: t.fonts?.ui ?? "sans-serif", mono: t.fonts?.mono ?? "monospace" },
    radius: Number(t.shape?.radius ?? 12),
    cardCss: exists(`${dir}/card.css`) ? fill(readFile(`${dir}/card.css`), t) : null,
  }
}

export function loadRices(): Rice[] {
  const dir = GLib.Dir.open(RICE_DIR, 0)
  const names: string[] = []
  for (let n = dir.read_name(); n !== null; n = dir.read_name()) {
    const path = `${RICE_DIR}/${n}`
    if (n.startsWith(".") || GLib.file_test(path, GLib.FileTest.IS_SYMLINK)) continue
    if (GLib.file_test(path, GLib.FileTest.IS_DIR)) names.push(n)
  }
  dir.close()
  return names
    .sort()
    .map(loadRice)
    .filter((r): r is Rice => r !== null)
}

export function currentRice(): string | null {
  try {
    return GLib.path_get_basename(GLib.file_read_link(`${RICE_DIR}/current`))
  } catch {
    return null
  }
}

// "07:00 paper" lines → "paper 07:00 · nacre 17:30 · urushi 21:30"
export function autoSchedule(): string {
  const file = `${RICE_DIR}/auto.conf`
  if (!exists(file)) return ""
  return readFile(file)
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"))
    .map((l) => l.split(/\s+/))
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([time, name]) => `${name} ${time}`)
    .join("  ·  ")
}

// Each card is drawn in its own rice's palette. The generated block gives
// every rice a sensible card for free; an optional card.css in the rice
// folder layers the bespoke material and hover motion on top.
export function cardStyles(rices: Rice[]): string {
  return rices
    .map((r) => {
      const c = r.colors
      const sel = `.card.rice-${r.name}`
      const swatches = ["accent", "accent2", "accent3", "red", "green", "yellow", "blue"]
        .filter((k) => c[k])
        .map((k, i) => `${sel} .swatch.s${i} { background-color: ${c[k]}; }`)
        .join("\n")
      return `
${sel} {
  background-color: ${c.bg};
  color: ${c.fg};
  border-radius: ${r.radius}px;
  border: 1px solid ${c.overlay ?? c.surface};
  font-family: "${r.fonts.ui}";
}
${sel} .title { color: ${c.fg}; }
${sel} .tagline, ${sel} .badge { color: ${c.muted}; font-family: "${r.fonts.mono}"; }
${sel} .mock { background-color: ${c.surface}; border-radius: ${Math.max(r.radius - 6, 0)}px; }
${sel} .mock .bar { background-color: ${c.overlay ?? c.bg}; }
${sel} .mock .win { background-color: ${c.bg}; border: 1px solid ${c.overlay ?? c.surface};
  border-radius: ${Math.max(r.radius - 10, 0)}px; }
${sel} .mock .win.focused { border-color: ${c.accent}; }
${sel} .preview { border-radius: ${Math.max(r.radius - 6, 0)}px; }
${sel}.selected { border-color: ${c.accent}; box-shadow: 0 0 0 2px ${c.accent}, 0 24px 60px rgba(0,0,0,0.45); }
${sel}.active .badge { color: ${c.accent}; }
${swatches}
${r.cardCss ?? ""}`
    })
    .join("\n")
}
