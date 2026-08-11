import { Controller } from "@hotwired/stimulus"

// Client-side search, filter, and sort for the Features & tips page. The whole
// curated (already audience-scoped, server-side) list renders once; this narrows
// and reorders it in place — no server round-trip.
//
// Each card carries data-area, data-status, data-date (ISO yyyy-mm-dd, which
// sorts/compares correctly as a plain string), and data-text (lowercased
// searchable haystack).
export default class extends Controller {
  static targets = ["card", "list", "count", "empty", "search", "area", "status", "from", "to", "order"]
  static values = {
    query: { type: String, default: "" },
    area: { type: String, default: "all" },
    status: { type: String, default: "all" },
    from: { type: String, default: "" },
    to: { type: String, default: "" },
    order: { type: String, default: "newest" }
  }

  connect() {
    this.refresh()
  }

  search() {
    this.queryValue = this.searchTarget.value.trim().toLowerCase()
  }

  filterArea() {
    this.areaValue = this.areaTarget.value
  }

  filterStatus() {
    this.statusValue = this.statusTarget.value
  }

  setFrom() {
    this.fromValue = this.fromTarget.value
  }

  setTo() {
    this.toValue = this.toTarget.value
  }

  setOrder() {
    this.orderValue = this.orderTarget.value
  }

  clear() {
    this.searchTarget.value = ""
    this.areaTarget.value = "all"
    this.statusTarget.value = "all"
    this.fromTarget.value = ""
    this.toTarget.value = ""
    this.orderTarget.value = "newest"
    this.queryValue = ""
    this.areaValue = "all"
    this.statusValue = "all"
    this.fromValue = ""
    this.toValue = ""
    this.orderValue = "newest"
  }

  queryValueChanged() { this.refresh() }
  areaValueChanged() { this.refresh() }
  statusValueChanged() { this.refresh() }
  fromValueChanged() { this.refresh() }
  toValueChanged() { this.refresh() }
  orderValueChanged() { this.refresh() }

  refresh() {
    if (!this.hasListTarget) return
    this.sort()
    this.filter()
  }

  sort() {
    const newest = this.orderValue !== "oldest"
    const cards = [...this.cardTargets].sort((a, b) => {
      const cmp = a.dataset.date.localeCompare(b.dataset.date)
      return newest ? -cmp : cmp
    })
    cards.forEach((card) => this.listTarget.appendChild(card))
  }

  filter() {
    let visible = 0
    this.cardTargets.forEach((card) => {
      const show = this.matches(card)
      card.classList.toggle("hidden", !show)
      if (show) visible++
    })
    if (this.hasCountTarget) this.countTarget.textContent = visible
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", visible > 0)
  }

  matches(card) {
    const { area, status, date, text } = card.dataset
    if (this.areaValue !== "all" && area !== this.areaValue) return false
    if (this.statusValue !== "all" && status !== this.statusValue) return false
    if (this.queryValue && !text.includes(this.queryValue)) return false
    if (this.fromValue && date < this.fromValue) return false
    if (this.toValue && date > this.toValue) return false
    return true
  }
}
