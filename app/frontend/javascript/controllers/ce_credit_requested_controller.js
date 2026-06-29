import { Controller } from "@hotwired/stimulus"

// Drives the CE-credit box on the registration form. Colors the "Requested"
// toggle to signal save state: amber while the choice is pending (changed but
// not yet saved), the continuing-education theme color once it matches the
// stored "on" value, neutral gray when stored as off. While "Requested" is on it
// reveals the CE details (license number, hours, cost) and keeps the "Provided"
// badge in sync as the admin edits the license number.
export default class extends Controller {
  static targets = ["checkbox", "track", "details", "license", "licenseBadge"]
  static values = { initial: Boolean }

  connect() {
    this.refresh()
  }

  refresh() {
    const checked = this.checkboxTarget.checked
    const pending = checked !== this.initialValue

    this.trackTarget.classList.toggle("bg-amber-500", pending)
    this.trackTarget.classList.toggle("bg-teal-600", checked && !pending)
    this.trackTarget.classList.toggle("bg-gray-200", !checked && !pending)

    this.element.classList.toggle("bg-amber-50", pending)
    this.element.classList.toggle("border-amber-200", pending)
    this.element.classList.toggle("bg-teal-50", checked && !pending)
    this.element.classList.toggle("border-teal-200", checked && !pending)
    this.element.classList.toggle("bg-white", !checked && !pending)
    this.element.classList.toggle("border-gray-200", !checked && !pending)

    if (this.hasDetailsTarget) this.detailsTarget.classList.toggle("hidden", !checked)

    this.updateLicenseBadge()
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
}
