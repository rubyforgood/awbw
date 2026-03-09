import { Controller } from "@hotwired/stimulus"

/**
 * Dynamically styles a <select> as a colored chip based on its current value.
 *
 * Usage:
 *   <select data-controller="chip-select"
 *           data-chip-select-styles-value='{"active":"bg-green-100 text-green-700","inactive":"bg-gray-100 text-gray-600"}'
 *           data-action="change->chip-select#update">
 */
export default class extends Controller {
  static values = { styles: Object }

  connect() {
    this.update()
  }

  update() {
    if (this._allClasses) {
      this.element.classList.remove(...this._allClasses)
    }
    const classes = this.stylesValue[this.element.value]
    if (classes) {
      this.element.classList.add(...classes.split(" "))
    }
  }

  stylesValueChanged() {
    this._allClasses = Object.values(this.stylesValue).join(" ").split(" ")
    this.update()
  }
}
