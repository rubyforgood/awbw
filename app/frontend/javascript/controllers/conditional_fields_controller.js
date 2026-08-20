import { Controller } from "@hotwired/stimulus"

// Shows/hides fields based on a source control (a <select>, or a checkbox that
// reports its value when on and "" when off). A field appears when its
// data-show-when matches the source's value, or — for option-driven conditions —
// when its data-show-when-attr names a data-* flag that is "true" on the selected
// option (e.g. data-show-when-attr="eventSelector" reads the option's
// data-event-selector).
export default class extends Controller {
  static targets = ["source", "field"]

  connect() {
    this.toggle()
  }

  toggle() {
    const source = this.sourceTarget
    const value = source.type === "checkbox" ? (source.checked ? source.value : "") : source.value
    const selected = source.selectedOptions?.[0]
    this.fieldTargets.forEach(el => {
      const attr = el.dataset.showWhenAttr
      el.hidden = attr
        ? selected?.dataset[attr] !== "true"
        : el.dataset.showWhen !== value
    })
  }
}
