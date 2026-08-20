import { Controller } from "@hotwired/stimulus"

// CE license picker. When the admin chooses a license from the dropdown, fill the
// type / number / state / expiry fields from that license (carried on each option's
// data attributes) so the fields describe the selected license. Choosing "Create
// new license" clears them for a fresh entry.
export default class extends Controller {
  static targets = ["select", "kind", "number", "state", "expires"]

  sync() {
    const option = this.selectTarget.selectedOptions[0]
    if (!option) return

    const isNew = this.selectTarget.value === "new"
    this.kindTarget.value = isNew ? "" : (option.dataset.kind || "")
    this.numberTarget.value = isNew ? "" : (option.dataset.number || "")
    this.stateTarget.value = isNew ? "" : (option.dataset.state || "")
    this.expiresTarget.value = isNew ? "" : (option.dataset.expires || "")
  }
}
