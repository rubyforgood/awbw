import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="invoice-editor"
// Live-recomputes each line's amount (quantity × amount-per-person) and the
// invoice total as the blank template is filled in, so the printed PDF stays
// consistent. Quantity/unitPrice/lineAmount targets are paired by DOM order.
export default class extends Controller {
  static targets = ["quantity", "unitPrice", "lineAmount", "total"]

  connect() {
    this.recompute()
  }

  recompute() {
    let totalCents = 0
    this.quantityTargets.forEach((quantityInput, i) => {
      const quantity = parseFloat(quantityInput.value) || 0
      const unitCents = this.toCents(this.unitPriceTargets[i]?.value)
      const amountCents = Math.round(quantity * unitCents)
      totalCents += amountCents
      if (this.lineAmountTargets[i]) {
        this.lineAmountTargets[i].textContent = this.formatDollars(amountCents)
      }
    })
    if (this.hasTotalTarget) this.totalTarget.textContent = this.formatDollars(totalCents)
  }

  toCents(value) {
    if (!value) return 0
    const dollars = parseFloat(String(value).replace(/[^0-9.]/g, "")) || 0
    return Math.round(dollars * 100)
  }

  formatDollars(cents) {
    const whole = cents % 100 === 0
    return `$${(cents / 100).toLocaleString("en-US", { minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: 2 })}`
  }
}
