import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scholarship-preview"
// Live-previews the "Scholarship allocated" and "Still owed" stats as the user
// toggles "Tasks completed" or edits the amount — before saving. On save, the
// real allocation is synced server-side by Scholarship#sync_allocation_amount.
export default class extends Controller {
  static targets = ["completed", "amount", "allocated", "owed"]
  static values = { eventCost: Number, otherAllocated: Number }

  update() {
    const dollars = parseFloat(this.amountTarget.value) || 0
    const allocatedCents = this.completedTarget.checked ? Math.round(dollars * 100) : 0

    if (this.hasAllocatedTarget) {
      this.allocatedTarget.textContent = `$${(allocatedCents / 100).toFixed(2)}`
    }

    if (this.hasOwedTarget) {
      const owed = Math.max(this.eventCostValue - this.otherAllocatedValue - allocatedCents, 0)
      const paid = owed <= 0
      const cls = paid ? "border-green-200 bg-green-50 text-green-700" : "border-amber-200 bg-amber-50 text-amber-700"
      const icon = paid ? "fa-circle-check" : "fa-circle-exclamation"
      const label = paid ? "Paid" : `$${(owed / 100).toFixed(2)} due`
      this.owedTarget.innerHTML = `<span class="inline-flex items-center gap-1.5 rounded-full border px-3 py-0.5 text-xs font-medium ${cls}"><i class="fas ${icon}"></i>${label}</span>`
    }
  }
}
