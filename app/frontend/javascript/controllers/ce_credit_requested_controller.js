import { Controller } from "@hotwired/stimulus"

// Drives the CE-credit box on the registration form. Colors the "Requested"
// toggle to signal save state: amber while the choice is pending (changed but
// not yet saved), the continuing-education theme color once it matches the
// stored "on" value, neutral gray when stored as off. While "Requested" is on it
// reveals the CE details (license number + hours) and keeps the "Provided" badge
// and amount-owed total ($rate × hours) in sync as the admin edits them.
export default class extends Controller {
  static targets = ["checkbox", "track", "details", "license", "licenseBadge", "hours", "amount"]
  static values = { initial: Boolean, rate: Number }

  connect() {
    this.refresh()
  }

  refresh() {
    const checked = this.checkboxTarget.checked
    const pending = checked !== this.initialValue

    this.trackTarget.classList.toggle("bg-amber-500", pending)
    this.trackTarget.classList.toggle("bg-teal-600", checked && !pending)
    this.trackTarget.classList.toggle("bg-gray-200", !checked && !pending)

    if (this.hasDetailsTarget) this.detailsTarget.classList.toggle("hidden", !checked)

    this.updateLicenseBadge()
    this.updateAmount()
  }

  updateLicenseBadge() {
    if (!this.hasLicenseTarget || !this.hasLicenseBadgeTarget) return

    const provided = this.licenseTarget.value.trim().length > 0
    this.licenseBadgeTarget.classList.toggle("bg-teal-50", provided)
    this.licenseBadgeTarget.classList.toggle("text-teal-700", provided)
    this.licenseBadgeTarget.classList.toggle("bg-gray-100", !provided)
    this.licenseBadgeTarget.classList.toggle("text-gray-500", !provided)
    this.licenseBadgeTarget.innerHTML = provided
      ? '<i class="fa-solid fa-circle-check text-[0.55rem]"></i> Provided'
      : '<i class="fa-solid fa-circle-minus text-[0.55rem]"></i> Not provided'
  }

  updateAmount() {
    if (!this.hasHoursTarget || !this.hasAmountTarget) return

    const hours = Math.max(0, parseInt(this.hoursTarget.value, 10) || 0)
    const owed = hours * this.rateValue
    this.amountTarget.textContent = `$${owed.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }
}
