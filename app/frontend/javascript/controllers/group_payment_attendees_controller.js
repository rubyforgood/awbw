import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template", "hiddenInput"]
  static values = { count: { type: Number, default: 0 } }

  connect() {
    if (this.rowsTarget.children.length === 0) {
      this.addRow()
    }
  }

  addRow() {
    const index = this.countValue++
    const fragment = this.templateTarget.content.cloneNode(true)

    fragment.querySelectorAll("[data-group-payment-attendees-target=\"row\"]").forEach(row => {
      row.dataset.index = index
    })

    fragment.querySelectorAll("input").forEach(input => {
      input.name = input.name.replace("INDEX", index)
      input.id = input.id.replace("INDEX", index)
    })

    fragment.querySelectorAll("label").forEach(label => {
      label.htmlFor = label.htmlFor.replace("INDEX", index)
    })

    this.rowsTarget.appendChild(fragment)
  }

  removeRow(event) {
    const row = event.target.closest("[data-group-payment-attendees-target=\"row\"]")
    if (row) {
      row.remove()
      this.serialize()
    }
  }

  serialize() {
    const attendees = []
    this.rowsTarget.querySelectorAll("[data-group-payment-attendees-target=\"row\"]").forEach(row => {
      const first_name = row.querySelector("[data-attendee-field=\"first_name\"]")?.value || ""
      const last_name = row.querySelector("[data-attendee-field=\"last_name\"]")?.value || ""
      const email = row.querySelector("[data-attendee-field=\"email\"]")?.value || ""
      if (first_name || last_name || email) {
        attendees.push({ first_name, last_name, email })
      }
    })
    this.hiddenInputTarget.value = JSON.stringify(attendees)
  }
}
