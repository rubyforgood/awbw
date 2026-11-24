import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    open: { type: Boolean, default: true },
    closeOnBackdrop: { type: Boolean, default: true }
  }

  connect() {
    if (this.openValue) this.open()
  }

  open() {
    if (!(this.element instanceof HTMLDialogElement) || this.element.open) return

    this.returnTo = document.activeElement
    this.element.showModal()
  }

  close() {
    if (!(this.element instanceof HTMLDialogElement)) return

    this.element.close()

    if (document.activeElement === document.body && this.returnTo?.isConnected) {
      this.returnTo.focus()
    }
  }

  closeOnBackdrop(event) {
    if (this.closeOnBackdropValue && event.target === this.element) this.close()
  }
}
