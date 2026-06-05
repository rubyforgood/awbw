import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="collection"
export default class extends Controller {
  static classes = ["unselected", "selected"];
  static outlets = ["search-type-select"];

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
      // skip submit on tom-select keyboard input
      const target = event.target;
      if (target.type !== "text") return;

      const isTomSelect = target.closest(".ts-control");

      if (!isTomSelect) {
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

  clearAndSubmit(event) {
    event.preventDefault();

    this.element
      .querySelectorAll('input[type="text"], input[type="search"]')
      .forEach((input) => {
        input.value = "";
      });
    this.element.querySelectorAll("select").forEach((select) => {
      select.selectedIndex = 0;
    });
    this.element
      .querySelectorAll('input[type="checkbox"], input[type="radio"]')
      .forEach((input) => {
        if (input.checked) {
          this.toggleClass(input);
        }
        input.checked = false;
      });
    this.element.reset();

    if (this.hasSearchTypeSelectOutlet) {
      this.searchTypeSelectOutlets.forEach((controller) => {
        controller.toggle({ target: { value: "" } });
      });
    }

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
