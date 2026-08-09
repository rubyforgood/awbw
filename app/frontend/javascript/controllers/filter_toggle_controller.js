import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-toggle"
// Expands/collapses the secondary row of the shared events filter bar
// (events/_registrant_filters), rotating the chevron and swapping the toggle button's
// label. The server renders the content without the `hidden` class when a
// collapsed filter is already active, so an active filter is never hidden on
// load — connect() syncs the chevron and label to that initial state.
export default class extends Controller {
  static targets = ["content", "chevron", "label"]
  static values = {
    moreLabel: { type: String, default: "More filters" },
    fewerLabel: { type: String, default: "Fewer filters" }
  }

  connect() {
    this.sync(!this.contentTarget.classList.contains("hidden"))
  }

  toggle(event) {
    const expanded = !this.contentTarget.classList.toggle("hidden")
    event.currentTarget.setAttribute("aria-expanded", String(expanded))
    this.sync(expanded)
  }

  sync(expanded) {
    this.chevronTarget.classList.toggle("rotate-180", expanded)
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = expanded ? this.fewerLabelValue : this.moreLabelValue
    }
  }
}
