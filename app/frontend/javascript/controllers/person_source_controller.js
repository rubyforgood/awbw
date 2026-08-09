import { Controller } from "@hotwired/stimulus"

// Toggles the new-subscription person picker between choosing an existing person
// and entering a new one (first/last/email). Only the active mode's inputs stay
// enabled, so just that mode's data is submitted — the server never sees both a
// person_id and person_attributes at once.
export default class extends Controller {
  static targets = ["radio", "existingGroup", "newGroup", "existingField", "newField"]

  connect() {
    this.select()
  }

  select() {
    const creatingNew = this.radioTargets.find(radio => radio.checked)?.value === "new"

    this.existingGroupTarget.classList.toggle("hidden", creatingNew)
    this.newGroupTarget.classList.toggle("hidden", !creatingNew)
    this.existingFieldTargets.forEach(field => field.disabled = creatingNew)
    this.newFieldTargets.forEach(field => field.disabled = !creatingNew)
  }
}
