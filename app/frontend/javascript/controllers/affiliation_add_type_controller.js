import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  stamp(event) {
    const item = event.detail?.item
    if (!item) return

    const input = item.querySelector("input[name*='[type]']")
    if (!input) return

    input.value = this.hasSelectTarget ? this.selectTarget.value : "job"
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
