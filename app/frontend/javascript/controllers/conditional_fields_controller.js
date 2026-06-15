import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "field"]

  connect() {
    this.toggle()
  }

  toggle() {
    const value = this.sourceTarget.value
    this.fieldTargets.forEach(el => {
      el.hidden = el.dataset.showWhen !== value
    })
  }
}
