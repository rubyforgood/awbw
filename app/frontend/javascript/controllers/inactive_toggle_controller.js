import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.endDateInput = this.element.querySelector("input[type='date'][name*='end_date']");
    if (this.endDateInput) {
      this.apply();
    }
  }

  toggle() {
    this.apply();
  }

  apply() {
    if (!this.endDateInput) return;
    const value = this.endDateInput.value;
    const isPast = value && new Date(value) < new Date(new Date().toDateString());

    if (isPast) {
      this.element.classList.add("bg-gray-100", "border-gray-300", "opacity-60");
      this.element.classList.remove("bg-white", "border-gray-200");
    } else {
      this.element.classList.remove("bg-gray-100", "border-gray-300", "opacity-60");
      this.element.classList.add("bg-white", "border-gray-200");
    }
  }
}
