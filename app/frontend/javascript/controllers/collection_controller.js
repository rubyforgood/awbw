import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="collection"
export default class extends Controller {
  connect() {
  }
  static targets = ["content", "form"]

  connect() {
    this.formTarget.addEventListener("change", (event) => {
      if (event.target.type === "checkbox" || event.target.type === "radio") {
        this.submitForm()
      }
    })

    this.formTarget.addEventListener("input", (event) => {
      if (event.target.type === "text") {
        this.debouncedSubmit()
      }
    })
  }

  submitForm() {
     this.formTarget.requestSubmit()
  }

  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.submitForm()
    }, 400)
  }
}
