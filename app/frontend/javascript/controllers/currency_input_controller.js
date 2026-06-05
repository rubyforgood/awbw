import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  format() {
    let value = this.element.value.replace(/[^\d]/g, "")
    
    if (value === "") {
      this.element.value = ""
      return
    }
    
    value = value.padStart(2, "0")
    
    const dollars = value.slice(0, -2).replace(/^0+/, "") || "0"
    const cents = value.slice(-2)
    this.element.value = `${dollars}.${cents}`
  }
}
