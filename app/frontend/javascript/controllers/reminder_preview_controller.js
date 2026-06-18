import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reminder-preview"
// Live-updates the reminder email preview as the admin types a custom message.
// The message target lives inside the server-rendered preview email markup (only
// emitted in preview mode); the input target is the message textarea. The actual
// send re-sanitizes the message server-side, so injecting the raw value here is
// only for the on-page preview.
export default class extends Controller {
  static targets = ["input", "message"]

  inputTargetConnected() {
    this.update()
  }

  messageTargetConnected() {
    this.update()
  }

  update() {
    if (!this.hasMessageTarget || !this.hasInputTarget) return

    const value = this.inputTarget.value.trim()
    this.messageTarget.innerHTML = value
    this.messageTarget.style.display = value ? "" : "none"
  }
}
