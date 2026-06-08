import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="submit-once"
// Blocks duplicate form submissions (a rapid double-click, or a stale resubmit)
// by disabling the submit control once a submission starts, then re-enabling it
// when the page is restored (Back/bfcache), Turbo caches it, or a Turbo submit
// ends — so the button never gets stuck disabled. Works on both Turbo and
// non-Turbo (turbo: false) forms; it complements Turbo's own submitter disabling
// and is the only such guard on a turbo: false form.
//
// Optional: data-submit-once-submitting-text-value swaps the button label while
// the request is in flight (e.g. "Saving…").
export default class extends Controller {
  static values = { submittingText: String }

  initialize() {
    this.disable = this.disable.bind(this)
    this.enable = this.enable.bind(this)
  }

  connect() {
    this.element.addEventListener("submit", this.disable)
    this.element.addEventListener("turbo:submit-end", this.enable)
    document.addEventListener("turbo:before-cache", this.enable)
    window.addEventListener("pageshow", this.enable)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.disable)
    this.element.removeEventListener("turbo:submit-end", this.enable)
    document.removeEventListener("turbo:before-cache", this.enable)
    window.removeEventListener("pageshow", this.enable)
  }

  disable(event) {
    // The browser only fires submit on a valid form, but guard anyway: never lock
    // the button when HTML validation fails, so the user can fix and resubmit.
    if (typeof this.element.checkValidity === "function" && !this.element.checkValidity()) return

    // Defer one tick: a submit button disabled synchronously is dropped from the
    // serialized form data, so let the in-flight submission build its payload
    // first, then lock out any second click.
    const buttons = event.submitter ? [ event.submitter ] : this.submitButtons
    setTimeout(() => buttons.forEach((btn) => this.lock(btn)), 0)
  }

  enable() {
    this.submitButtons.forEach((btn) => this.unlock(btn))
  }

  lock(button) {
    button.disabled = true
    if (!this.hasSubmittingTextValue) return

    if (button.tagName === "INPUT") {
      button.dataset.submitOnceText = button.value
      button.value = this.submittingTextValue
    } else {
      button.dataset.submitOnceText = button.innerHTML
      button.textContent = this.submittingTextValue
    }
  }

  unlock(button) {
    button.disabled = false
    const original = button.dataset.submitOnceText
    if (original === undefined) return

    if (button.tagName === "INPUT") button.value = original
    else button.innerHTML = original
    delete button.dataset.submitOnceText
  }

  get submitButtons() {
    return Array.from(
      this.element.querySelectorAll('button[type="submit"], input[type="submit"], button:not([type])')
    )
  }
}
