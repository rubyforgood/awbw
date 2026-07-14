import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="fab"
//
// Toggles the floating help menu (FAQs / contact / videos) open and closed and
// spins the round button. Replaces an inline <script> in the footer that
// violated the CSP script-src policy (same pattern as scroll_to_top in #1948).
export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    this.buttonTarget.classList.toggle("rotate-45")
  }
}
