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
      const inputs = field.querySelectorAll("input[name*='start_date'], input[name*='end_date'], input[name*='title']")
      inputs.forEach(input => {
        input.addEventListener("change", this.boundRecalculate)
        input.addEventListener("input", this.boundRecalculate)
      })
    })
  }

  recalculate() {
    const affiliations = this.getVisibleAffiliations()
    const now = new Date()
    const today = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()))

    // Affiliated since = merged year-based periods (mirrors AffiliationPeriods).
    if (this.hasAffiliatedSinceTarget) {
      this.affiliatedSinceTarget.textContent = this.affiliatedSinceLabel(affiliations, today) || "—"
    }

    // Facilitations/program since — unchanged single-range display, filtered by
    // title. Mirror Affiliation#facilitator?: an exact, case-sensitive match on
    // "Facilitator" (trimmed), so the live figure matches the server render.
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

    if (this.hasFacilitatorSinceTarget) {
      this.updateDisplay(this.facilitatorSinceTarget, facilitatorSince, facilitatorEnd)
    }
  }

  // Merge affiliation intervals into periods and format them as year-based ranges
  // — the client-side mirror of app/services/affiliation_periods.rb.
  affiliatedSinceLabel(affiliations, today) {
    const intervals = affiliations
      .filter(a => a.startDate)
      .map(a => ({ start: new Date(a.startDate), end: a.endDate ? new Date(a.endDate) : null }))
      .sort((a, b) => a.start - b.start)
    if (!intervals.length) return ""

    const periods = []
    for (const iv of intervals) {
      const last = periods[periods.length - 1]
      if (last && (last.end === null || iv.start <= last.end)) {
        last.end = last.end === null || iv.end === null ? null : new Date(Math.max(last.end, iv.end))
      } else {
        periods.push({ start: iv.start, end: iv.end })
      }
    }

    const ongoing = end => end === null || end >= today
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    // A single ongoing period is a fresh org — worth the month's precision.
    if (periods.length === 1 && ongoing(periods[0].end)) {
      const s = periods[0].start
      return s.getUTCFullYear() === today.getUTCFullYear()
        ? `${months[s.getUTCMonth()]} ${s.getUTCFullYear()}`
        : `${s.getUTCFullYear()}`
    }

    return periods
      .map(p => {
        const startYear = p.start.getUTCFullYear()
        if (ongoing(p.end) || startYear === p.end.getUTCFullYear()) return `${startYear}`
        return `${startYear}-${p.end.getUTCFullYear()}`
      })
      .join(", ")
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
        title: field.querySelector("input[name*='title']")?.value || ""
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
