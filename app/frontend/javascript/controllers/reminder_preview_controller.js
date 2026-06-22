import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reminder-preview"
// Live-updates the reminder email preview as the admin edits the custom message
// and subject. The message target lives inside the server-rendered preview email
// markup (only emitted in preview mode); subjectPreview is the subject line shown
// above the rendered email. The actual send re-sanitizes the message server-side,
// so injecting the raw values here is only for the on-page preview.
export default class extends Controller {
  static targets = ["input", "message", "subjectInput", "subjectPreview"]

  inputTargetConnected() {
    this.update()
  }

  messageTargetConnected() {
    this.update()
  }

  subjectInputTargetConnected() {
    this.updateSubject()
  }

  subjectPreviewTargetConnected() {
    this.updateSubject()
  }

  update() {
    if (!this.hasMessageTarget || !this.hasInputTarget) return

    const value = this.inputTarget.value.trim()
    this.messageTarget.innerHTML = value
    this.messageTarget.style.display = value ? "" : "none"
  }

  updateSubject() {
    if (!this.hasSubjectPreviewTarget || !this.hasSubjectInputTarget) return

    this.subjectPreviewTarget.textContent = this.subjectInputTarget.value.trim()
  }
}
