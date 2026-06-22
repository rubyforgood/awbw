import { Controller } from "@hotwired/stimulus"

// Toggles an address's state field between a US state dropdown (validated server
// side) and a free-text region input, based on the selected country. Only the
// active input stays enabled, so exactly one value submits under the shared
// `[state]` name. Each address block scopes its own controller instance, so this
// works for cocoon-added addresses too.
export default class extends Controller {
  static targets = ["country", "stateSelect", "stateText"]
  static values = { usCountry: String }

  connect() {
    this.update()
  }

  update() {
    const isUs = this.countryTarget.value === "" || this.countryTarget.value === this.usCountryValue
    this.activate(this.stateSelectTarget, isUs)
    this.activate(this.stateTextTarget, !isUs)
  }

  // Show and enable the active field (and its wrapper), hide and disable the other
  // so it neither submits nor blocks form validation while hidden.
  activate(field, active) {
    field.disabled = !active
    const wrapper = field.closest("[data-address-region-wrapper]") || field
    wrapper.classList.toggle("hidden", !active)
  }
}
