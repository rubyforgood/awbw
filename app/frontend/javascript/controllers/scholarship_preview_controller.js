import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scholarship-preview"
// Live-previews the "Still owed" stat and the scholarship-amount allocation
// as the user edits the amount — before saving.
export default class extends Controller {
  static targets = ["amount", "owed", "amountBox"]
  static values = { eventCost: Number, otherAllocated: Number }

  connect() {
    this.update()
  }

  update() {
    const dollars = Math.max(parseFloat(this.amountTarget.value) || 0, 0)
    const allocatedCents = Math.round(dollars * 100)

    this.renderOwed(allocatedCents)
    this.renderAllocation(allocatedCents)
  }

  renderOwed(allocatedCents) {
    if (!this.hasOwedTarget) return
    const owed = Math.max(this.eventCostValue - this.otherAllocatedValue - allocatedCents, 0)
    const paid = owed <= 0
    const box = paid ? "border-gray-300 bg-gray-50" : "border-amber-300 bg-amber-50"
    const text = paid ? "text-gray-500" : "text-amber-700"
    const icon = paid ? "fa-thumbs-up" : "fa-circle-exclamation"
    const label = paid ? "Paid up" : this.formatDollars(owed)
    this.owedTarget.className = `rounded-lg border px-4 py-3 ${box}`
    this.owedTarget.innerHTML = `<dt class="text-xs font-medium uppercase tracking-wide text-gray-400">Still owed</dt><dd class="mt-1 flex items-center gap-1.5 text-sm font-semibold tabular-nums ${text}"><i class="fa-solid ${icon}"></i>${label}</dd>`
  }

  renderAllocation(allocatedCents) {
    if (!this.hasAmountBoxTarget) return
    const box = allocatedCents > 0 ? "border-fuchsia-300 bg-fuchsia-50" : "border-gray-100 bg-gray-50"
    this.amountBoxTarget.className = `rounded-lg border px-4 py-3 ${box}`
  }

  formatDollars(cents) {
    const whole = cents % 100 === 0
    return `$${(cents / 100).toLocaleString("en-US", { minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: 2 })}`
  }
}
