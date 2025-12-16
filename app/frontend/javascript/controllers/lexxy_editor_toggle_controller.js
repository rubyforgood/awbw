import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lexxy-editor-toggle"
export default class extends Controller {


  static targets = ["legacy", "lexxy"]

  connect() {
  }

  toggle() {
    this.legacyTargets.forEach(el => {
      el.classList.toggle("hidden")
    })

    this.lexxyTargets.forEach(el => {
      el.classList.toggle("hidden")
    })
  }

}
