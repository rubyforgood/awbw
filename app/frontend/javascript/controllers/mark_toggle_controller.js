import { Controller } from "@hotwired/stimulus"

// Reveals the "mark" toggle once a tag/topic is chosen and captions it with that
// record's configured mark label (falling back to "Marked"), read from the
// selected option's data-mark-label. The label lives on the tag/topic, so the
// caption has to follow the select client-side.
export default class extends Controller {
  static targets = ["select", "field", "label"]

  connect() {
    this.update()
  }

  update() {
    const option = this.selectTarget.selectedOptions[0]
    const chosen = Boolean(option && option.value)
    this.fieldTarget.classList.toggle("hidden", !chosen)
    if (chosen) this.labelTarget.textContent = option.dataset.markLabel?.trim() || "Marked"
  }
}
