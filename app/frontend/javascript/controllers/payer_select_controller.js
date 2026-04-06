import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["personField", "organizationField"]

  toggle(event) {
    const payerType = event.target.value
    
    if (payerType === "Person") {
      this.personFieldTarget.classList.remove("hidden")
      this.organizationFieldTarget.classList.add("hidden")
    } else if (payerType === "Organization") {
      this.personFieldTarget.classList.add("hidden")
      this.organizationFieldTarget.classList.remove("hidden")
    } else {
      this.personFieldTarget.classList.add("hidden")
      this.organizationFieldTarget.classList.add("hidden")
    }
  }
}
