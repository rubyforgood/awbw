import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scholarship-preview"
// Live-previews the "Scholarship allocated" stat as the user toggles
// "Tasks completed" or edits the amount — before saving. On save, the real
// allocation is synced server-side by Scholarship#sync_allocation_amount.
export default class extends Controller {
  static targets = ["completed", "amount", "allocated"]

  update() {
    const dollars = parseFloat(this.amountTarget.value) || 0
    const allocated = this.completedTarget.checked ? dollars : 0
    this.allocatedTarget.textContent = `$${allocated.toFixed(2)}`
  }
}
