import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Find the form element
    const form = this.element.closest("form")
    if (!form) return

    // Add a submit event listener to combine date and time before submission
    form.addEventListener("submit", this.combineDateTime.bind(this))
  }

  combineDateTime(event) {
    // Find all date inputs that have corresponding time inputs
    const dateFields = this.element.querySelectorAll('input[data-datetime-part="date"]')
    
    dateFields.forEach(dateInput => {
      const fieldName = dateInput.dataset.datetimeField
      const timeInput = this.element.querySelector(`input[data-datetime-part="time"][data-datetime-field="${fieldName}"]`)
      
      if (timeInput) {
        const dateValue = dateInput.value
        const timeValue = timeInput.value
        
        // Only combine if both date and time have values, or if date has a value and field is required
        if (dateValue && timeValue) {
          // Combine date and time in ISO 8601 format
          dateInput.value = `${dateValue}T${timeValue}`
        } else if (!dateValue) {
          // If date is empty, keep it empty (will trigger validation)
          dateInput.value = ""
        } else if (dateValue && !timeValue && dateInput.required) {
          // If date exists but time is missing and field is required, keep the original date value
          // This will allow server-side validation to handle missing time
          dateInput.value = dateValue
        }
      }
    })
  }
}
