import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scholarship-preview"
// Live-previews the "Still owed" stat and the scholarship-amount allocation
// as the user edits the amount — before saving.
//
// Grant-funded scholarships have no event/registration to allocate against, so
// instead the pending award is split live across "Allocated" (counts once the
// recipient's tasks are completed) and "Amount due" (what's still owed them).
export default class extends Controller {
  static targets = [
    "amount", "owed", "amountBox", "allocationStrip", "allocatedHint",
    "completed", "grantAmount", "grantAllocated", "grantDue"
  ]
  static values = { eventCost: Number, otherAllocated: Number, grantFunded: Boolean }

  connect() {
    this.update()
  }

  update() {
    const dollars = Math.max(parseFloat(this.amountTarget.value) || 0, 0)
    const allocatedCents = Math.round(dollars * 100)

    this.renderOwed(allocatedCents)
    this.renderAllocation(allocatedCents)
    this.renderGrantSplit(allocatedCents)
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
    const allocated = allocatedCents > 0
    const box = allocated ? "border-fuchsia-300 bg-fuchsia-50" : "border-gray-100 bg-gray-50"

    if (this.hasAmountBoxTarget) {
      this.amountBoxTarget.className = `rounded-lg border px-4 py-3 ${box}`
    }

    if (this.hasAllocationStripTarget) {
      this.allocationStripTarget.className = `flex flex-wrap items-center justify-between gap-3 rounded-lg border px-4 py-3 ${box}`
    }

    if (this.hasAllocatedHintTarget) {
      if (!allocated) {
        this.allocatedHintTarget.innerHTML = `<span class="text-xs text-gray-500">$0 allocated to registration</span>`
      } else {
        const amount = this.formatDollars(allocatedCents)
        this.allocatedHintTarget.innerHTML = `<span class="inline-flex items-center gap-1 rounded-full border border-fuchsia-200 bg-fuchsia-100 px-2 py-0.5 text-[0.65rem] font-medium text-fuchsia-700"><i class="fa-solid fa-circle-check text-[0.55rem]"></i>${amount} allocated to registration</span>`
      }
    }
  }

  // Grant-funded only: the award counts as allocated once tasks are completed;
  // whatever isn't allocated is still due to the recipient.
  renderGrantSplit(amountCents) {
    if (!this.grantFundedValue) return

    const completed = this.hasCompletedTarget && this.completedTarget.checked
    const allocatedCents = completed ? amountCents : 0
    const dueCents = Math.max(amountCents - allocatedCents, 0)

    if (this.hasGrantAmountTarget) {
      this.grantAmountTarget.textContent = this.formatDollars(amountCents)
    }

    if (this.hasGrantAllocatedTarget) {
      this.grantAllocatedTarget.textContent = this.formatDollars(allocatedCents)
    }

    if (this.hasGrantDueTarget) {
      const paid = dueCents <= 0
      const cls = paid ? "border-green-200 bg-green-50 text-green-700" : "border-amber-200 bg-amber-50 text-amber-700"
      const icon = paid ? "fa-circle-check" : "fa-circle-exclamation"
      const label = paid ? "Paid" : `${this.formatDollars(dueCents)} due`
      this.grantDueTarget.innerHTML = `<span class="inline-flex items-center gap-1.5 rounded-full border px-3 py-0.5 text-xs font-medium ${cls}"><i class="fas ${icon}"></i>${label}</span>`
    }
  }

  formatDollars(cents) {
    const whole = cents % 100 === 0
    return `$${(cents / 100).toLocaleString("en-US", { minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: 2 })}`
  }
}
