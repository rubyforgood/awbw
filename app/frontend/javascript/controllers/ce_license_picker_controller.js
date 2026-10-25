import { Controller } from "@hotwired/stimulus"

// CE license picker. When the admin chooses a license from the dropdown, fill the
// type / number / state / country / expiry fields from that license (carried on each
// option's data attributes) so the fields describe the selected license. Choosing
// "Create new license" clears them for a fresh entry. A state the US list can't show
// goes in the "Outside USA?" box, opened along with any country on file.
export default class extends Controller {
  static targets = ["select", "kind", "number", "state", "typedState", "country", "outsideUsa", "expires"]

  sync() {
    const option = this.selectTarget.selectedOptions[0]
    if (!option) return

    const isNew = this.selectTarget.value === "new"
    const state = isNew ? "" : (option.dataset.state || "")
    const listed = [...this.stateTarget.options].some((stateOption) => stateOption.value === state)
    this.kindTarget.value = isNew ? "" : (option.dataset.kind || "")
    this.numberTarget.value = isNew ? "" : (option.dataset.number || "")
    this.stateTarget.value = listed ? state : ""
    this.typedStateTarget.value = listed ? "" : state
    this.countryTarget.value = isNew ? "" : (option.dataset.country || "")
    this.outsideUsaTarget.open = option.dataset.outsideUsa === "true"
    this.expiresTarget.value = isNew ? "" : (option.dataset.expires || "")
  }
}
