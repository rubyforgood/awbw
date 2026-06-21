import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="confirm-modal"
//
// Shared, single-instance confirmation modal that replaces the browser's native
// confirm() dialog. Rendered once in the layout (shared/_confirm_modal). Other
// code opens it by calling confirmModal(message) (see confirm_modal.js), which
// dispatches a "confirm-modal:open" window event carrying the message and a
// resolve callback. Turbo's data-turbo-confirm is routed here via
// Turbo.setConfirmMethod in application.js.
//
// The element is a full-screen overlay; the dialog target is the card inside it.
export default class extends Controller {
  static targets = ["dialog", "message", "confirm", "cancel"];

  connect() {
    this.resolve = null;
  }

  open(event) {
    event.preventDefault();

    const { message, options = {}, resolve } = event.detail;
    this.resolve = resolve;

    this.messageTarget.textContent = message || "Are you sure?";
    this.confirmTarget.textContent = options.confirmLabel || "Confirm";
    this.cancelTarget.textContent = options.cancelLabel || "Cancel";

    this.element.classList.remove("hidden");
    this.confirmTarget.focus();
  }

  confirm() {
    this.finish(true);
  }

  cancel() {
    this.finish(false);
  }

  backdropClick(event) {
    if (event.target === this.element) this.cancel();
  }

  keydown(event) {
    // Enter is handled natively by the focused Confirm button.
    if (event.key !== "Escape") return;

    event.preventDefault();
    this.cancel();
  }

  finish(result) {
    if (this.element.classList.contains("hidden")) return;

    this.element.classList.add("hidden");
    const resolve = this.resolve;
    this.resolve = null;
    if (resolve) resolve(result);
  }

  disconnect() {
    // Resolve any pending request so a navigated-away modal never hangs a promise.
    this.finish(false);
  }
}
