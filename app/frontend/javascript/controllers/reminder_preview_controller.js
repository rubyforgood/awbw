import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reminder-preview"
// Live-updates the reminder email preview as the admin edits the custom message
// and subject. The message target lives inside the server-rendered preview email
// markup (only emitted in preview mode); subjectPreview is the subject line shown
// above the rendered email. The actual send re-sanitizes the message server-side,
// so injecting the raw values here is only for the on-page preview.
export default class extends Controller {
  static targets = ["input", "message", "subjectInput", "subjectPreview", "eventCard", "eventCardToggle", "cardStatus"]

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

  eventCardTargetConnected() {
    this.syncEventCard()
  }

  eventCardToggleTargetConnected() {
    this.syncEventCard()
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

  // Action handler. Announces as well as syncing — the connect callbacks use
  // syncEventCard directly so the live region stays silent on page load.
  toggleEventCard() {
    this.syncEventCard()

    if (!this.hasCardStatusTarget || !this.hasEventCardToggleTarget) return

    this.cardStatusTarget.textContent = this.eventCardToggleTarget.checked
      ? "Event details box hidden from the email."
      : "Event details box shown in the email."
  }

  syncEventCard() {
    if (!this.hasEventCardTarget || !this.hasEventCardToggleTarget) return

    this.eventCardTarget.style.display = this.eventCardToggleTarget.checked ? "none" : ""
  }
}
