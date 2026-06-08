import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.filter()
  }

  filter() {
    const role = this.selectTarget.value
    this.element.querySelectorAll("[data-section-role]").forEach((el) => {
      const sectionRole = el.dataset.sectionRole
      if (role === "scholarship") {
        el.classList.toggle("hidden", sectionRole !== "scholarship")
      } else if (role === "group_payment") {
        el.classList.toggle("hidden", sectionRole !== "group_payment")
      } else {
        el.classList.toggle("hidden", sectionRole === "scholarship" || sectionRole === "group_payment")
      }
    })
  }
}
