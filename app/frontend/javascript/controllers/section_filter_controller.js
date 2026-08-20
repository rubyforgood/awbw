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
      } else if (role === "bulk_payment") {
        el.classList.toggle("hidden", sectionRole !== "bulk_payment")
      } else if (role === "continuing_education") {
        el.classList.toggle("hidden", sectionRole !== "continuing_education")
      } else {
        el.classList.toggle("hidden", sectionRole === "scholarship" || sectionRole === "bulk_payment" || sectionRole === "continuing_education")
      }
    })
  }
}
