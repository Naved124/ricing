import { For, createState, type Accessor } from "ags"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { execAsync } from "ags/process"
import { timeout } from "ags/time"
import Gio from "gi://Gio"
import Graphene from "gi://Graphene"
import { RICE_BIN, type Rice } from "../lib/rices"

const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

export type ChooserState = {
  rices: Accessor<Rice[]>
  current: Accessor<string | null>
  auto: Accessor<boolean>
  schedule: Accessor<string>
}

// A miniature desktop drawn in the rice's palette, used when the rice has
// no preview.png yet.
function Mock() {
  return (
    <box class="mock" orientation={Gtk.Orientation.VERTICAL} heightRequest={150}>
      <box class="bar" heightRequest={10} />
      <box spacing={6} vexpand marginTop={8} marginBottom={8} marginStart={8} marginEnd={8}>
        <box class="win focused" hexpand />
        <box orientation={Gtk.Orientation.VERTICAL} spacing={6} hexpand>
          <box class="win" vexpand />
          <box class="win" vexpand />
        </box>
      </box>
    </box>
  )
}

function Card({
  rice,
  current,
  selected,
  onHover,
  onPick,
}: {
  rice: Rice
  current: string | null
  selected: Accessor<string>
  onHover: () => void
  onPick: () => void
}) {
  const base = `card rice-${rice.name}${rice.name === current ? " active" : ""}`
  const swatchCount = ["accent", "accent2", "accent3", "red", "green", "yellow", "blue"].filter(
    (k) => rice.colors[k],
  ).length

  return (
    <box
      class={selected.as((s) => (s === rice.name ? `${base} selected` : base))}
      orientation={Gtk.Orientation.VERTICAL}
      widthRequest={300}
      spacing={14}
    >
      <Gtk.EventControllerMotion onEnter={onHover} />
      <Gtk.GestureClick onReleased={onPick} />
      {rice.preview ? (
        <Gtk.Picture
          class="preview"
          file={Gio.File.new_for_path(rice.preview)}
          contentFit={Gtk.ContentFit.COVER}
          heightRequest={150}
        />
      ) : (
        <Mock />
      )}
      <box class="swatches" spacing={6}>
        {Array.from({ length: swatchCount }, (_, i) => (
          <box class={`swatch s${i}`} />
        ))}
      </box>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
        <label class="title" label={rice.title} xalign={0} />
        <label class="tagline" label={rice.tagline} xalign={0} wrap />
      </box>
      <label
        class="badge"
        xalign={0}
        label={rice.name === current ? "● active" : `↵ ${rice.transition}`}
      />
    </box>
  )
}

export default function Chooser(
  state: ChooserState,
  actions: { onShow: () => void; setAuto: (on: boolean) => void },
) {
  let win: Astal.Window
  let content: Gtk.Box
  const [selected, setSelected] = createState("")

  const names = () => state.rices.get().map((r) => r.name)

  function move(step: number) {
    const list = names()
    if (!list.length) return
    const i = list.indexOf(selected.get())
    setSelected(list[(i + step + list.length) % list.length])
  }

  function apply(name = selected.get()) {
    if (!name) return
    win.visible = false
    // let the chooser unmap before `rice` screenshots the screen
    timeout(150, () => {
      execAsync([RICE_BIN, name]).catch((e) => console.error(e))
    })
  }

  function onKey(_e: Gtk.EventControllerKey, keyval: number) {
    switch (keyval) {
      case Gdk.KEY_Escape:
      case Gdk.KEY_q:
        win.visible = false
        return true
      case Gdk.KEY_Left:
      case Gdk.KEY_Up:
      case Gdk.KEY_h:
      case Gdk.KEY_k:
        move(-1)
        return true
      case Gdk.KEY_Right:
      case Gdk.KEY_Down:
      case Gdk.KEY_l:
      case Gdk.KEY_j:
      case Gdk.KEY_Tab:
        move(1)
        return true
      case Gdk.KEY_Return:
      case Gdk.KEY_KP_Enter:
      case Gdk.KEY_space:
        apply()
        return true
      case Gdk.KEY_a:
        actions.setAuto(!state.auto.get())
        return true
    }
    // 1–9 picks a card directly
    const n = keyval - Gdk.KEY_1
    if (n >= 0 && n < 9 && names()[n]) {
      apply(names()[n])
      return true
    }
    return false
  }

  // click outside the content closes
  function onClick(_e: Gtk.GestureClick, _n: number, x: number, y: number) {
    const [, rect] = content.compute_bounds(win)
    if (!rect.contains_point(new Graphene.Point({ x, y }))) win.visible = false
  }

  return (
    <window
      $={(ref) => (win = ref)}
      name="chooser"
      namespace="rice-chooser"
      class="chooser"
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.EXCLUSIVE}
      onNotifyVisible={({ visible }) => {
        if (!visible) return
        actions.onShow()
        setSelected(state.current.get() ?? names()[0] ?? "")
      }}
    >
      <Gtk.EventControllerKey onKeyPressed={onKey} />
      <Gtk.GestureClick onPressed={onClick} />
      <box
        $={(ref) => (content = ref)}
        class="content"
        orientation={Gtk.Orientation.VERTICAL}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        spacing={28}
      >
        <label class="heading" label="choose a rice" xalign={0} />
        <box class="cards" spacing={28} homogeneous>
          <For each={state.rices}>
            {(rice) => (
              <Card
                rice={rice}
                current={state.current.get()}
                selected={selected}
                onHover={() => setSelected(rice.name)}
                onPick={() => apply(rice.name)}
              />
            )}
          </For>
        </box>
        <box class="footer" spacing={12}>
          <switch
            class="auto"
            valign={Gtk.Align.CENTER}
            active={state.auto}
            onNotifyActive={({ active }) => {
              if (active !== state.auto.get()) actions.setAuto(active)
            }}
          />
          <box orientation={Gtk.Orientation.VERTICAL}>
            <label class="auto-label" label="auto mode" xalign={0} />
            <label class="hint" label={state.schedule} xalign={0} />
          </box>
          <label
            class="hint"
            hexpand
            halign={Gtk.Align.END}
            label="←→ move   ↵ apply   1–9 pick   a auto   esc close"
          />
        </box>
      </box>
    </window>
  )
}
