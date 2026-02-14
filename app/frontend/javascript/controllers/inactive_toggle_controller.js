import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.checkbox = this.element.querySelector("input[type='checkbox']");
    if (this.checkbox) {
      this.apply();
    }
  }

  toggle() {
    this.apply();
  }

  apply() {
    if (!this.checkbox) return;
    if (this.checkbox.checked) {
      this.element.classList.add("bg-gray-100", "border-gray-300", "opacity-60");
      this.element.classList.remove("bg-white", "border-gray-200");
    } else {
      this.element.classList.remove("bg-gray-100", "border-gray-300", "opacity-60");
      this.element.classList.add("bg-white", "border-gray-200");
    }
  }
}
