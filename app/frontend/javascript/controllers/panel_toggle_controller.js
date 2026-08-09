import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="panel-toggle"
// Show/hide named panels. Each button and panel carries data-panel-toggle-name;
// a button toggles every panel sharing its name, and every button controlling
// that panel updates its own label + aria-expanded — so one panel can have more
// than one control (e.g. a top toggle plus an in-section "Show" prompt). A
// button marked data-panel-toggle-cta hides itself while its panel is shown (it
// only invites revealing). Revealing a hidden panel that holds a lazy Turbo
// frame lets the frame load on first show, so charts stay off the initial
// request until asked for.
export default class extends Controller {
  static targets = ["button", "panel", "label"]

  toggle(event) {
    const name = event.currentTarget.dataset.panelToggleName
    const panels = this.panelTargets.filter(panel => panel.dataset.panelToggleName === name)
    if (panels.length === 0) return

    const willShow = panels[0].classList.contains("hidden")
    panels.forEach(panel => panel.classList.toggle("hidden", !willShow))
    this.sync(name, willShow)
  }

  // Keep every button that controls this panel consistent with its new state.
  sync(name, shown) {
    this.buttonTargets
      .filter(button => button.dataset.panelToggleName === name)
      .forEach(button => {
        button.setAttribute("aria-expanded", String(shown))
        if (button.dataset.panelToggleCta !== undefined) {
          button.classList.toggle("hidden", shown)
        }
        const label = this.labelTargets.find(target => button.contains(target))
        if (label) {
          label.textContent = shown
            ? button.dataset.panelToggleShownLabel
            : button.dataset.panelToggleHiddenLabel
        }
      })
  }
}
