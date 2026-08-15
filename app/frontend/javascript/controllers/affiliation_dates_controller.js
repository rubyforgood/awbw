import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["affiliatedSince", "facilitatorSince", "affiliationsContainer", "programStatus"]
  // "Affiliated since" has two live formats: the person form shows a single
  // Mon YYYY – Mon YYYY range; the org form (affiliatedSincePeriods) shows merged
  // year-based periods, mirroring the AffiliationPeriods service so the live value
  // matches the server render. affiliatedSinceFallback is the org's own start_date
  // (already formatted) shown when no affiliation carries a start date.
  //
  // Program status (org edit form): derived live from the visible Facilitator rows
  // alone, mirroring OrganizationDecorator#organization_status_bucket. statusBuckets
  // holds each bucket's label + pill classes (from DomainTheme).
  static values = {
    affiliatedSincePeriods: Boolean,
    affiliatedSinceFallback: String,
    statusBuckets: Object
  }

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

    // Affiliated since — the org form shows merged year-based periods, the person
    // form a single Mon YYYY range. Both live-update from the visible rows.
    if (this.hasAffiliatedSinceTarget) {
      if (this.affiliatedSincePeriodsValue) {
        const label = this.affiliatedSincePeriodsLabel(affiliations, today) || this.affiliatedSinceFallbackValue
        this.affiliatedSinceTarget.textContent = label || "—"
      } else {
        const startDates = affiliations.map(a => a.startDate).filter(Boolean)
        const affiliatedSince = startDates.length
          ? new Date(Math.min(...startDates.map(d => new Date(d))))
          : null
        const allInactive = affiliations.length > 0 &&
          affiliations.every(a => a.endDate && new Date(a.endDate) < today)
        const affiliatedEnd = allInactive
          ? new Date(Math.max(...affiliations.map(a => new Date(a.endDate))))
          : null
        this.updateDisplay(this.affiliatedSinceTarget, affiliatedSince, affiliatedEnd)
      }
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

    // Program status — active when any Facilitator row is still active, formerly
    // active when they've all ended, never active when there are none.
    if (this.hasProgramStatusTarget) {
      let bucket
      if (facilitatorAffiliations.length === 0) {
        bucket = "never_active"
      } else {
        bucket = allFacInactive ? "formerly_active" : "active"
      }
      this.updateProgramStatus(bucket)
    }
  }

  updateProgramStatus(bucket) {
    const style = this.statusBucketsValue[bucket]
    if (!style) return
    const base = "inline-flex items-center rounded-full text-xs font-medium border px-2.5 py-0.5"
    this.programStatusTarget.textContent = style.label
    this.programStatusTarget.className = `${base} ${style.classes}`
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

  // Merged, year-based "Affiliated since" label for the org form, mirroring the
  // AffiliationPeriods service: overlapping/touching intervals collapse into one
  // period (a nil end is ongoing and swallows later intervals), a real gap starts
  // a new one. A single ongoing period keeps month precision when it began this
  // year; any multi-period list is year-only. Returns null when no affiliation
  // carries a start date, so the caller can fall back to the org's start_date.
  affiliatedSincePeriodsLabel(affiliations, today) {
    const intervals = affiliations
      .filter(a => a.startDate)
      .map(a => [ new Date(a.startDate), a.endDate ? new Date(a.endDate) : null ])
      .sort((a, b) => a[0] - b[0])
    if (!intervals.length) return null

    const periods = []
    intervals.forEach(([ start, finish ]) => {
      const last = periods[periods.length - 1]
      if (last && (last[1] === null || start <= last[1])) {
        last[1] = last[1] === null || finish === null ? null : new Date(Math.max(last[1], finish))
      } else {
        periods.push([ start, finish ])
      }
    })

    const ongoing = finish => finish === null || finish >= today
    // A single ongoing period is a fresh org — worth the month's precision.
    if (periods.length === 1 && ongoing(periods[0][1])) {
      return this.yearOrMonth(periods[0][0], today)
    }
    return periods
      .map(([ start, finish ]) =>
        ongoing(finish) || start.getUTCFullYear() === finish.getUTCFullYear()
          ? `${start.getUTCFullYear()}`
          : `${start.getUTCFullYear()}-${finish.getUTCFullYear()}`)
      .join(", ")
  }

  yearOrMonth(date, today) {
    return date.getUTCFullYear() === today.getUTCFullYear()
      ? this.formatDate(date)
      : `${date.getUTCFullYear()}`
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
