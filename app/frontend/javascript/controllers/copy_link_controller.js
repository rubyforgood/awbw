import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="copy-link"
// Copies a direct shareable URL to the clipboard and gives the user feedback.
export default class extends Controller {
  static targets = ["input", "label"]
  static values = { confirmedLabel: { type: String, default: "Copied!" } }

  async copy() {
    const url = this.inputTarget.value

    try {
      await navigator.clipboard.writeText(url)
    } catch {
      // Fallback for browsers without the async clipboard API
      this.inputTarget.select()
      document.execCommand("copy")
    }

    this.confirm()
  }

  confirm() {
    if (!this.hasLabelTarget) return

    const original = this.labelTarget.textContent
    this.labelTarget.textContent = this.confirmedLabelValue

    if (this.resetTimeout) clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => {
      this.labelTarget.textContent = original
    }, 2000)
  }

  disconnect() {
    if (this.resetTimeout) clearTimeout(this.resetTimeout)
  }
}
