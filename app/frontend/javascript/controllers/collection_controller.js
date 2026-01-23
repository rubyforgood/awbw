import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="collection"
export default class extends Controller {
  static classes = ["unselected", "selected"];
  connect() {
    this.element.addEventListener("change", (event) => {
      const { type } = event.target;

      if (type === "checkbox") {
        this.toggleClass(event.target);
      }

      if (
        type === "checkbox" ||
        type === "radio" ||
        type === "select-one" ||
        type === "select-multiple"
      ) {
        this.submitForm();
      }
    });
    this.element.addEventListener("input", (event) => {
      if (event.target.type === "text") {
        this.debouncedSubmit();
      }
    });
  }

  submitForm() {
    this.blurOldResults();
    this.element.requestSubmit();
  }

  debouncedSubmit() {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.submitForm();
    }, 400);
  }

  toggleClass(el) {
    const button = el.closest("label");
    if (!button || !this.selectedClasses) return;

    // Toggle selected classes
    this.selectedClasses.forEach((cls) => {
      button.classList.toggle(cls);
    });

    // Toggle unselected classes
    this.unselectedClasses.forEach((cls) => {
      button.classList.toggle(cls);
    });
  }

  blurOldResults() {
    const elements = document.querySelectorAll(".blur-on-submit");

    elements.forEach((el) => {
      el.classList.add("blur-sm");
    });
  }
}
