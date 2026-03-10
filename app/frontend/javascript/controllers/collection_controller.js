import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="collection"
export default class extends Controller {
  static classes = ["unselected", "selected"];

  handleChange(event) {
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
  }

  handleInput(event) {
    if (event.target.type === "text" || event.target.type === "search") {
      this.debouncedSubmit();
    }
  }

  disconnect() {
    clearTimeout(this.timeout);
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

    this.selectedClasses.forEach((cls) => {
      button.classList.toggle(cls);
    });

    this.unselectedClasses.forEach((cls) => {
      button.classList.toggle(cls);
    });
  }

  clearAndSubmit(event) {
    event.preventDefault();

    this.element.querySelectorAll('input[type="text"], input[type="search"]').forEach(input => {
      input.value = '';
    });
    this.element.querySelectorAll('select').forEach(select => {
      select.selectedIndex = 0;
    });
    this.element.querySelectorAll('input[type="checkbox"], input[type="radio"]').forEach(input => {
      if (input.checked) {
        this.toggleClass(input);
      }
      input.checked = false;
    });
    this.element.reset();
    this.submitForm();
  }

  blurOldResults() {
    const frame = this.element.closest("turbo-frame");
    const scope = frame || document;
    const elements = scope.querySelectorAll(".blur-on-submit");

    elements.forEach((el) => {
      el.classList.add("blur-sm");
    });
  }
}
