import { onCleanup } from "ags"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { timeout } from "ags/time"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

// How long each transition runs; must match the durations in style.scss.
const DURATION: Record<string, number> = {
  fade: 450,
  ripple: 750,
  lacquer: 950,
  peel: 850,
}

type Frozen = { win: Astal.Window; picture: Gtk.Picture }
const frozen = new Map<string, Frozen>()

// One frame per monitor: the screenshot `rice` took just before switching,
// pinned above everything while the new rice loads underneath.
export default function Freeze({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const connector = gdkmonitor.connector
  const entry = {} as Frozen
  frozen.set(connector, entry)

  onCleanup(() => {
    frozen.delete(connector)
    entry.win.destroy()
  })

  return (
    <window
      $={(ref) => (entry.win = ref)}
      name={`freeze-${connector}`}
      namespace="rice-freeze"
      class="freeze"
      gdkmonitor={gdkmonitor}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.NONE}
    >
      <Gtk.Picture
        $={(ref) => (entry.picture = ref)}
        class="frame"
        contentFit={Gtk.ContentFit.FILL}
        canShrink
      />
    </window>
  )
}

export function freeze(dir: string, done: () => void) {
  for (const [connector, { win, picture }] of frozen) {
    const own = `${dir}/${connector}.png`
    const path = GLib.file_test(own, GLib.FileTest.EXISTS) ? own : `${dir}/all.png`
    if (!GLib.file_test(path, GLib.FileTest.EXISTS)) continue
    picture.cssClasses = ["frame"]
    picture.set_file(Gio.File.new_for_path(path))
    win.visible = true
  }
  // answer once the frames have had a chance to hit the screen
  timeout(80, done)
}

export function dissolve(transition: string) {
  const name = transition in DURATION ? transition : "fade"
  for (const { picture } of frozen.values()) {
    picture.cssClasses = ["frame", "dissolve", name]
  }
  timeout(DURATION[name] + 60, () => {
    for (const { win, picture } of frozen.values()) {
      win.visible = false
      picture.cssClasses = ["frame"]
      picture.set_paintable(null)
    }
  })
}
