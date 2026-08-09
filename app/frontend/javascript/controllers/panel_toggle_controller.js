import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="panel-toggle"
// Show/hide named panels. Each button and panel carries data-panel-toggle-name;
// a button toggles every panel sharing its name, and every button controlling
// that panel is kept in sync — its label, its aria-expanded, and (for a button
// marked data-panel-toggle-cta) its own visibility, since a CTA only invites
// revealing and hides once its panel shows. This lets one panel have several
// controls (a top toggle plus an in-section "Show" prompt) that never disagree.
// Revealing a hidden panel that holds a lazy Turbo frame loads the frame on first
// show, so charts stay off the initial request until asked for.
export default class extends Controller {
  static targets = ["button", "panel", "label"]

  connect() {
    // Reconcile every control with its panel's actual visibility on load, so a
    // CTA and its top toggle can't disagree (and it self-heals after a Turbo
    // restore or frame reload).
    this.panelNames().forEach(name => this.sync(name, this.panelShown(name)))
  }

  toggle(event) {
    const name = event.currentTarget.dataset.panelToggleName
    if (this.panelsFor(name).length === 0) return

    const shown = !this.panelShown(name)
    this.panelsFor(name).forEach(panel => panel.classList.toggle("hidden", !shown))
    this.sync(name, shown)
  }

  // Bring every button that controls the named panel into line with its state.
  sync(name, shown) {
    this.buttonsFor(name).forEach(button => {
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

  panelsFor(name) {
    return this.panelTargets.filter(panel => panel.dataset.panelToggleName === name)
  }

  buttonsFor(name) {
    return this.buttonTargets.filter(button => button.dataset.panelToggleName === name)
  }

  panelShown(name) {
    const panel = this.panelsFor(name)[0]
    return panel ? !panel.classList.contains("hidden") : false
  }

  panelNames() {
    return [ ...new Set(this.panelTargets.map(panel => panel.dataset.panelToggleName)) ]
  }
}
