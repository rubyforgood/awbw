import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="column-toggle"
// Each instance is a single slide switch that shows/hides the table columns
// whose data-column-toggle-col value matches this switch's `group` value, so a
// table can host several independent column toggles (e.g. "User confirmation",
// "CE status"). Columns live outside the switch's element, under a shared
// [data-column-toggle-root] ancestor.
//
// The chosen state is remembered per group in sessionStorage and reapplied on
// connect, so it survives Turbo frame re-renders (e.g. applying a search
// filter) instead of snapping back to the server-rendered defaults. State is
// namespaced by the scope declared on the [data-column-toggle-root] ancestor
// (e.g. the event id) so different tables/records keep independent toggles.

export default class extends Controller {
  static targets = ["toggle", "track", "knob"]
  static values = { group: String }

  connect() {
    const stored = this.storedState()
    if (stored !== null) this.apply(stored)
  }

  toggle() {
    const checked = this.toggleTarget.checked
    this.store(checked)
    this.apply(checked)
  }

  apply(checked) {
    this.toggleTarget.checked = checked
    const root = this.rootElement || document

    root.querySelectorAll(`[data-column-toggle-col="${this.groupValue}"]`).forEach((el) => {
      el.classList.toggle("hidden", !checked)
    })

    this.trackTarget.classList.toggle("bg-gray-300", !checked)
    this.trackTarget.classList.toggle("bg-blue-600", checked)
    this.knobTarget.style.transform = checked ? "translateX(16px)" : ""
  }

  get rootElement() {
    return this.element.closest("[data-column-toggle-root]")
  }

  storageKey() {
    const scope = this.rootElement?.dataset.columnToggleScope || "default"
    return `column-toggle:${scope}:${this.groupValue}`
  }

  storedState() {
    try {
      const value = sessionStorage.getItem(this.storageKey())
      return value === null ? null : value === "1"
    } catch {
      return null
    }
  }

  store(checked) {
    try {
      sessionStorage.setItem(this.storageKey(), checked ? "1" : "0")
    } catch {
      // sessionStorage can be unavailable (private mode); toggling still works in-page.
    }
  }
}
