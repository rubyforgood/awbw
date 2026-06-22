import { Controller } from "@hotwired/stimulus";

// Compact numbered address picker for the affiliation editor row. The trigger
// button shows only the selected address's number (or a dash); the panel lists
// each address with its full one-line text. Selecting an option writes the
// address id into a hidden field so it saves as the affiliation's
// organization_address_id.
//
// Connects to data-controller="address-select"
export default class extends Controller {
  static targets = ["panel", "input", "label"];

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this);
    this.handleEscapeKey = this.handleEscapeKey.bind(this);
  }

  disconnect() {
    this.removeGlobalListeners();
  }

  toggle() {
    if (this.panelTarget.classList.contains("hidden")) {
      this.open();
    } else {
      this.close();
    }
  }

  open() {
    this.panelTarget.classList.remove("hidden");
    // Defer so the click that opened the panel doesn't immediately close it.
    setTimeout(() => this.addGlobalListeners(), 0);
  }

  close() {
    this.panelTarget.classList.add("hidden");
    this.removeGlobalListeners();
  }

  select(event) {
    const option = event.currentTarget;
    this.inputTarget.value = option.dataset.value;
    this.labelTarget.textContent = option.dataset.number;
    this.close();
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close();
  }

  handleEscapeKey(event) {
    if (event.key === "Escape") this.close();
  }

  addGlobalListeners() {
    document.addEventListener("click", this.handleOutsideClick);
    document.addEventListener("keydown", this.handleEscapeKey);
  }

  removeGlobalListeners() {
    document.removeEventListener("click", this.handleOutsideClick);
    document.removeEventListener("keydown", this.handleEscapeKey);
  }
}
