import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scholarship-preview"
// Live-previews the "Still owed" stat and the scholarship-amount allocation state
// as the user edits the amount or toggles "Tasks completed" — before saving. The
// amount box, allocation hint chip, and toggle track read neutral grey when off,
// amber while the completed flag is changed-but-unsaved (allocation pending), and
// fuchsia once it matches the stored "allocated" state. On save, the real
// allocation is synced server-side by Scholarship#sync_allocation_amount.
export default class extends Controller {
  static targets = ["completed", "amount", "owed", "amountBox", "allocationStrip", "allocatedHint", "completedTrack"]
  static values = { eventCost: Number, otherAllocated: Number, completedInitial: Boolean }

  connect() {
    this.update()
  }

  update() {
    // Clamp to >= 0: the input has min=0 and the model rejects negatives, but a
    // user can still type "-5"; never preview a negative allocation.
    const dollars = Math.max(parseFloat(this.amountTarget.value) || 0, 0)
    const checked = this.completedTarget.checked
    const allocatedCents = checked ? Math.round(dollars * 100) : 0

    this.renderOwed(allocatedCents)
    this.renderAllocation(checked, allocatedCents)
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

  renderAllocation(checked, allocatedCents) {
    const pending = checked !== this.completedInitialValue
    const state = !checked ? "off" : pending ? "pending" : "allocated"

    if (this.hasCompletedTrackTarget) {
      this.completedTrackTarget.classList.toggle("bg-gray-200", state === "off")
      this.completedTrackTarget.classList.toggle("bg-amber-500", state === "pending")
      this.completedTrackTarget.classList.toggle("bg-fuchsia-600", state === "allocated")
    }

    const box = state === "off" ? "border-gray-100 bg-gray-50" : state === "pending" ? "border-amber-300 bg-amber-50" : "border-fuchsia-300 bg-fuchsia-50"
    if (this.hasAmountBoxTarget) {
      this.amountBoxTarget.className = `rounded-lg border px-4 py-3 ${box}`
    }

    if (this.hasAllocationStripTarget) {
      this.allocationStripTarget.className = `flex flex-wrap items-center justify-between gap-3 rounded-lg border px-4 py-3 ${box}`
    }

    if (this.hasAllocatedHintTarget) {
      if (!checked) {
        this.allocatedHintTarget.innerHTML = `<span class="text-xs text-gray-500">$0 allocated to registration</span>`
      } else {
        const chip = state === "pending" ? "border-amber-200 bg-amber-100 text-amber-700" : "border-fuchsia-200 bg-fuchsia-100 text-fuchsia-700"
        const amount = `$${(allocatedCents / 100).toFixed(2)}`
        this.allocatedHintTarget.innerHTML = `<span class="inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[0.65rem] font-medium ${chip}"><i class="fa-solid fa-circle-check text-[0.55rem]"></i>${amount} allocated to registration</span>`
      }
    }
  }

  // Dollars from an integer cent amount, with thousands separators and the cents
  // dropped for whole dollars ("$1,500", "$750.50") — mirrors the
  // dollars_from_cents view helper.
  formatDollars(cents) {
    const whole = cents % 100 === 0
    return `$${(cents / 100).toLocaleString("en-US", { minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: 2 })}`
  }
}
