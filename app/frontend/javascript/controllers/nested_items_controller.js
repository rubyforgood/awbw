import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container"]

  add() {
    const id = new Date().getTime()
    const html = this.templateTarget.innerHTML.replaceAll("new_invoice_line_items", id)
    this.containerTarget.insertAdjacentHTML("beforeend", html)
  }
}