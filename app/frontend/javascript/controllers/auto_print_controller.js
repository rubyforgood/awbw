import { Controller } from "@hotwired/stimulus"

// Opens the browser print dialog on load. Used by the invoice download page,
// which the server renders (and logs the download) when reached via ?print.
export default class extends Controller {
  connect() {
    window.print()
  }
}
