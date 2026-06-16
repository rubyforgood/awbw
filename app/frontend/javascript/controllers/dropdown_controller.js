import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dropdown"
//
//
// Your elements should have their initial utility classes defined in your view. These classes
// should be included in the payload-params. Add key:value pairs for each element that should
// have classes toggle via the payload-params. Multiple space separated values are allowed per key.
// Params should be defined on the element that triggers the action.
//
// data-action="dropdown#toggle"
// data-dropdown-payload-param='[{"answer_5":"hidden block"}, {"question_5_arrow":"rotate-180"}]'
//
export default class extends Controller {
  // add a content target if you want the dropdown to close with "escape button" or clicking outside of content
  // add an expand target (the toggle button) if you want to trigger the toggle on initial connect
  static targets = ["content", "expand"];

  connect() {
    this.listenersActive = false;
    this.handleOutsideClick = this.handleOutsideClick.bind(this);
    this.handleEscapeKey = this.handleEscapeKey.bind(this);
    if (this.hasExpandTarget) {
      this.expandTarget.click();
    }
  }

  toggle(event) {
    this.processPayload(event.params.payload);
    this.manageEventListeners();
    this.listenersActive = !this.listenersActive;
  }

  toggleClassesOnElement(element, classString) {
    const classes = this.parseClassString(classString);
    classes.forEach((className) => {
      element.classList.toggle(className);
    });
  }

  parseClassString(classString) {
    return classString
      .split(" ")
      .filter((className) => className.trim() !== "");
  }

  manageEventListeners() {
    if (this.listenersActive) {
      this.removeEventListeners();
    } else {
      // Add delay to avoid immediate trigger
      setTimeout(() => {
        this.addEventListeners();
      }, 0);
    }
  }

  addEventListeners() {
    document.addEventListener("click", this.handleOutsideClick);
    document.addEventListener("keydown", this.handleEscapeKey);
  }

  removeEventListeners() {
    document.removeEventListener("click", this.handleOutsideClick);
    document.removeEventListener("keydown", this.handleEscapeKey);
  }

  handleOutsideClick(event) {
    if (!this.hasContentTarget) return;

    const isClickInsideContent = this.contentTarget.contains(event.target);
    const isClickOnToggle = this.element.contains(event.target);

    if (!isClickInsideContent && !isClickOnToggle) {
      this.close();
    }
  }

  handleEscapeKey(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  close() {
    if (this.listenersActive) {
      this.processPayload(this.lastPayload);
      this.removeEventListeners();
      this.listenersActive = false;
    }
  }

  processPayload(payloadArray) {
    this.lastPayload = payloadArray;

    payloadArray.forEach((item) => {
      Object.entries(item).forEach(([elementId, classString]) => {
        const element = document.getElementById(elementId);
        this.toggleClassesOnElement(element, classString);
      });
    });
  }

  disconnect() {
    this.removeEventListeners();
  }
}
