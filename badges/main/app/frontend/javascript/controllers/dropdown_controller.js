import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dropdown"
export default class extends Controller {
  //Your element should have it's initial utility classes defined when the page
  //loads (eg. class="hidden"). Pass into the controller what classes should be toggled including
  //the classes from the initial state (data-dropdown-utility-class="hidden block")

  static classes = ["utility"];
  static values = {
    element: String,
  };

  connect() {
    this.open = false;
    this.handleOutsideClick = this.handleOutsideClick.bind(this);
    this.handleEscapeKey = this.handleEscapeKey.bind(this);
  }

  toggle() {
    const element = document.getElementById(this.elementValue);
    if (!element) return;

    this.utilityClasses.forEach((c) => element.classList.toggle(c));
    this.manageEventListeners();
    this.open = !this.open;
  }

  manageEventListeners() {
    if (this.open) {
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
    const element = document.getElementById(this.elementValue);
    if (!element) return;

    const isClickInsideElement = element.contains(event.target);
    const isClickOnToggle = this.element.contains(event.target);

    if (!isClickInsideElement && !isClickOnToggle) {
      this.close();
    }
  }

  handleEscapeKey(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  close() {
    const element = document.getElementById(this.elementValue);
    if (!element) return;

    if (this.open) {
      this.utilityClasses.forEach((c) => element.classList.toggle(c));
      this.removeEventListeners();
      this.open = false;
    }
  }

  disconnect() {
    this.removeEventListeners();
  }
}
