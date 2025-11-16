import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="collection"
export default class extends Controller {

  connect() {
    this.element.addEventListener("change", (event) => {
      if (event.target.type === "checkbox" || event.target.type === "radio") {
        this.submitForm()
      }
    })

    this.element.addEventListener("input", (event) => {
      if (event.target.type === "text") {
        this.debouncedSubmit()
      }
    })
  }

  submitForm() {
     this.element.requestSubmit()
  }

  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.submitForm()
    }, 400)
  }
}
