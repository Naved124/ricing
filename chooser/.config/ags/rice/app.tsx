import { For, This, createBinding, createState } from "ags"
import app from "ags/gtk4/app"
import { Astal } from "ags/gtk4"
import { execAsync } from "ags/process"
import style from "./style.scss"
import Chooser from "./widget/Chooser"
import Freeze, { freeze, dissolve } from "./widget/Freeze"
import { RICE_BIN, autoSchedule, cardStyles, currentRice, loadRices } from "./lib/rices"

// One instance ("rice") owns the chooser and the freeze/dissolve overlay, so
// `rice` talks to it with `ags request -i rice <cmd>`:
//   toggle | show | hide      the chooser
//   reload                    re-read ~/.config/rices (after a switch)
//   freeze <dir>              cover every monitor with <dir>/<connector>.png
//   dissolve <transition>     reveal the new rice and drop the overlay

app.start({
  instanceName: "rice",
  css: style,
  gtkTheme: "Adwaita",
  main() {
    const [rices, setRices] = createState(loadRices())
    const [current, setCurrent] = createState(currentRice())
    const [auto, setAuto] = createState(false)
    const [schedule, setSchedule] = createState(autoSchedule())

    function reload() {
      const list = loadRices()
      app.apply_css(style, true)
      app.apply_css(cardStyles(list))
      setCurrent(currentRice())
      setRices(list)
      setSchedule(autoSchedule())
      execAsync([RICE_BIN, "auto", "status"])
        .then((out) => setAuto(out.trim() === "on"))
        .catch(() => setAuto(false))
    }

    function toggleAuto(on: boolean) {
      setAuto(on)
      execAsync([RICE_BIN, "auto", on ? "on" : "off"])
        .catch((e) => console.error(e))
        .finally(reload)
    }

    reload()

    const chooser = Chooser(
      { rices, current, auto, schedule },
      { onShow: reload, setAuto: toggleAuto },
    ) as Astal.Window
    app.add_window(chooser)

    app.connect("request", (_app, argv: string[], res: (r: string) => void) => {
      const [cmd, arg] = argv
      switch (cmd) {
        case "toggle":
          chooser.visible = !chooser.visible
          return res("ok")
        case "show":
          chooser.visible = true
          return res("ok")
        case "hide":
          chooser.visible = false
          return res("ok")
        case "reload":
          reload()
          return res("ok")
        case "freeze":
          if (!arg) return res("usage: freeze <dir>")
          return freeze(arg, () => res("ok"))
        case "dissolve":
          dissolve(arg ?? "fade")
          return res("ok")
        default:
          return res(`unknown command: ${cmd}`)
      }
    })

    const monitors = createBinding(app, "monitors")
    return (
      <For each={monitors}>
        {(monitor) => (
          <This this={app}>
            <Freeze gdkmonitor={monitor} />
          </This>
        )}
      </For>
    )
  },
})
