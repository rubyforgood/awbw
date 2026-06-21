import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["affiliatedSince", "facilitatorSince", "affiliationsContainer"]

  initialize() {
    this.boundRecalculate = () => this.recalculate()
    this.boundReattach = () => {
      this.attachFieldListeners()
      this.recalculate()
    }
  }

  connect() {
    this.element.addEventListener("cocoon:after-insert", this.boundReattach)
    this.element.addEventListener("cocoon:after-remove", this.boundReattach)
    this.attachFieldListeners()
    this.recalculate()
    this.element.dataset.affiliationDatesReady = ""
  }

  disconnect() {
    this.element.removeEventListener("cocoon:after-insert", this.boundReattach)
    this.element.removeEventListener("cocoon:after-remove", this.boundReattach)
  }

  attachFieldListeners() {
    if (!this.hasAffiliationsContainerTarget) return
    const fields = this.affiliationsContainerTarget.querySelectorAll(".nested-fields")
    fields.forEach(field => {
      const inputs = field.querySelectorAll("input[name*='start_date'], input[name*='end_date'], textarea[name*='title']")
      inputs.forEach(input => {
        input.addEventListener("change", this.boundRecalculate)
        input.addEventListener("input", this.boundRecalculate)
      })
    })
  }

  recalculate() {
    const affiliations = this.getVisibleAffiliations()

    // Affiliated since = min start_date of all affiliations
    const allStartDates = affiliations.map(a => a.startDate).filter(Boolean)
    const affiliatedSince = allStartDates.length
      ? new Date(Math.min(...allStartDates.map(d => new Date(d))))
      : null

    // Affiliated end = only if ALL affiliations are inactive (end_date in the past)
    const now = new Date()
    const today = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()))
    const allInactive = affiliations.length > 0 &&
      affiliations.every(a => a.endDate && new Date(a.endDate) < today)
    const affiliatedEnd = allInactive
      ? new Date(Math.max(...affiliations.map(a => new Date(a.endDate))))
      : null

    // Facilitator since/end — same logic filtered by title. Mirror
    // Affiliation#facilitator?: an exact, case-sensitive match on "Facilitator"
    // (trimmed), so the live figure matches what the server will render.
    const facilitatorAffiliations = affiliations.filter(a =>
      a.title.trim() === "Facilitator"
    )
    const facStartDates = facilitatorAffiliations.map(a => a.startDate).filter(Boolean)
    const facilitatorSince = facStartDates.length
      ? new Date(Math.min(...facStartDates.map(d => new Date(d))))
      : null
    const allFacInactive = facilitatorAffiliations.length > 0 &&
      facilitatorAffiliations.every(a => a.endDate && new Date(a.endDate) < today)
    const facilitatorEnd = allFacInactive
      ? new Date(Math.max(...facilitatorAffiliations.map(a => new Date(a.endDate))))
      : null

    if (this.hasAffiliatedSinceTarget) {
      this.updateDisplay(this.affiliatedSinceTarget, affiliatedSince, affiliatedEnd)
    }
    if (this.hasFacilitatorSinceTarget) {
      this.updateDisplay(this.facilitatorSinceTarget, facilitatorSince, facilitatorEnd)
    }
  }

  getVisibleAffiliations() {
    if (!this.hasAffiliationsContainerTarget) return []
    const fields = this.affiliationsContainerTarget.querySelectorAll(".nested-fields")
    return Array.from(fields)
      .filter(field => {
        const destroyInput = field.querySelector("input[name*='_destroy']")
        return !destroyInput || destroyInput.value !== "1"
      })
      .map(field => ({
        startDate: field.querySelector("input[name*='start_date']")?.value || "",
        endDate: field.querySelector("input[name*='end_date']")?.value || "",
        title: field.querySelector("textarea[name*='title']")?.value || ""
      }))
  }

  formatDate(date) {
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    return `${months[date.getUTCMonth()]} ${date.getUTCFullYear()}`
  }

  updateDisplay(target, sinceDate, endDate) {
    if (!target) return
    let html = ""
    if (endDate) {
      html += '<i class="fa-solid fa-circle-xmark text-red-400 mr-1" title="No active affiliations"></i>'
    }
    html += sinceDate ? this.formatDate(sinceDate) : "—"
    if (endDate) html += ` – ${this.formatDate(endDate)}`
    target.innerHTML = html
  }
}
