import { Controller } from "@hotwired/stimulus"

// Greys a native date input's "mm/dd/yyyy" placeholder while it's empty. Date
// inputs have no ::placeholder and render the placeholder in the input's own text
// colour, so this toggles a grey text class on/off based on whether a date is set —
// keeping a chosen date dark while the empty prompt reads as a placeholder.
export default class extends Controller {
  connect() {
    this.refresh()
  }

  refresh() {
    this.element.classList.toggle("text-gray-400", this.element.value === "")
  }
}
