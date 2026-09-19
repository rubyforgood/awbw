import { Controller } from "@hotwired/stimulus"

// Records the invoice "Download PDF" click via Ahoy, then opens the print
// dialog. The ping uses keepalive so it survives the blocking print dialog.
export default class extends Controller {
  static values = { url: String }

  print() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken },
      keepalive: true
    })

    window.print()
  }
}
