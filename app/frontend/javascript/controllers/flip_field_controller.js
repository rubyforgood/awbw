import { Controller } from "@hotwired/stimulus"

// Shows a field's current value read-only with an edit pencil; the pencil flips
// to a picker (a <select>) to choose a different value, and flips back — syncing
// the displayed text from the chosen option. The toggle control stays visible in
// both states so the picker is never a trap.
export default class extends Controller {
  static targets = ["display", "picker", "select"]

  toggle() {
    const showingPicker = !this.pickerTarget.classList.contains("hidden")
    if (showingPicker) {
      this.displayTarget.textContent = this.selectedText()
    }
    this.displayTarget.classList.toggle("hidden")
    this.pickerTarget.classList.toggle("hidden")
    if (!showingPicker) this.selectTarget.focus()
  }

  selectedText() {
    const select = this.selectTarget
    return select.options[select.selectedIndex]?.text ?? ""
  }
}
