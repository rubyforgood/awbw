import { Controller } from "@hotwired/stimulus"
import { isFacilitatorTitle } from "../lib/affiliation"

export default class extends Controller {
  static targets = ["facilitatorSince", "affiliatedNote", "affiliatedNoteText", "memberSinceFlag", "affiliationsContainer", "programStatus"]
  // The person form shows a single Mon YYYY – Mon YYYY range; the org form
  // (mergedPeriods) mirrors the AffiliationPeriods service so the live value
  // matches the server render. memberSince is the person's legacy facilitator-since
  // date (person form only), flagged when it disagrees with the facilitator start.
  // statusBuckets carries each bucket's label + pill classes from DomainTheme.
  static values = {
    mergedPeriods: Boolean,
    memberSince: String,
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

    const facilitatorAffiliations = affiliations.filter(a => isFacilitatorTitle(a.title))
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
      if (this.mergedPeriodsValue) {
        this.facilitatorSinceTarget.textContent =
          this.periodsLabel(facilitatorAffiliations, today, "month") || "—"
      } else {
        this.updateDisplay(this.facilitatorSinceTarget, facilitatorSince, facilitatorEnd)
      }
    }

    // Mirrors PersonDecorator/OrganizationDecorator#affiliated_since_note: the
    // earliest start across all roles, surfaced only when it predates (differs by
    // month/year from) the facilitator start, so it isn't redundant.
    if (this.hasAffiliatedNoteTarget) {
      const allStartDates = affiliations.map(a => a.startDate).filter(Boolean).map(d => new Date(d))
      const affiliatedSince = allStartDates.length ? new Date(Math.min(...allStartDates)) : null
      this.updateAffiliatedNote(affiliatedSince, facilitatorSince)
    }

    // Mirrors PersonDecorator#member_since_{earlier_than,differs_from}_facilitator_affiliations?.
    if (this.hasMemberSinceFlagTarget) {
      this.updateMemberSinceFlag(facilitatorSince)
    }

    // Mirrors OrganizationDecorator#organization_status_bucket.
    if (this.hasProgramStatusTarget) {
      const started = a => !a.startDate || new Date(a.startDate) <= today
      const notEnded = a => !a.endDate || new Date(a.endDate) >= today
      let bucket
      if (facilitatorAffiliations.length === 0) {
        bucket = "never_active"
      } else if (facilitatorAffiliations.some(a => started(a) && notEnded(a))) {
        bucket = "active"
      } else if (facilitatorAffiliations.some(a => !started(a) && notEnded(a))) {
        bucket = "upcoming"
      } else {
        bucket = "formerly_active"
      }
      this.updateProgramStatus(bucket)
    }
  }

  updateAffiliatedNote(affiliatedSince, facilitatorSince) {
    const sameMonth = affiliatedSince && facilitatorSince &&
      affiliatedSince.getUTCFullYear() === facilitatorSince.getUTCFullYear() &&
      affiliatedSince.getUTCMonth() === facilitatorSince.getUTCMonth()
    const show = Boolean(affiliatedSince) && !sameMonth
    this.affiliatedNoteTarget.classList.toggle("hidden", !show)
    if (show && this.hasAffiliatedNoteTextTarget) {
      this.affiliatedNoteTextTarget.textContent = `Affiliated since ${this.formatDate(affiliatedSince)}`
    }
  }

  // Compares member_since (fixed) with the live facilitator start; only meaningful
  // when a facilitator affiliation has a start date, matching the decorator guards.
  updateMemberSinceFlag(facilitatorSince) {
    const target = this.memberSinceFlagTarget
    const ms = this.memberSinceValue ? new Date(this.memberSinceValue) : null
    const msMonth = ms ? Date.UTC(ms.getUTCFullYear(), ms.getUTCMonth()) : null
    const facMonth = facilitatorSince ? Date.UTC(facilitatorSince.getUTCFullYear(), facilitatorSince.getUTCMonth()) : null
    if (msMonth === null || facMonth === null || msMonth === facMonth) {
      target.className = "mt-1 text-xs hidden"
      return
    }
    const label = this.formatDate(ms)
    if (msMonth < facMonth) {
      target.className = "mt-1 text-xs text-amber-700"
      target.textContent = `⚠ Earlier date on file: ${label}`
    } else {
      target.className = "mt-1 text-xs text-gray-500"
      target.innerHTML = `<i class="fa-solid fa-circle-info mr-1"></i>Different date on file: ${label}`
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

  // The JS twin of AffiliationPeriods — keep the two in step. Null when no
  // affiliation has a start date, so the caller falls back to the org's start_date.
  periodsLabel(affiliations, today, precision) {
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
    if (precision === "month") {
      return periods
        .map(([ start, finish ]) =>
          ongoing(finish)
            ? this.formatDate(start)
            : `${this.formatDate(start)} – ${this.formatDate(finish)}`)
        .join(", ")
    }
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
      html += '<i class="fa-solid fa-circle-xmark mr-1 text-red-400" title="No active affiliations"></i>'
    }
    html += sinceDate ? this.formatDate(sinceDate) : "—"
    if (endDate) html += ` – ${this.formatDate(endDate)}`
    target.innerHTML = html
  }
}
