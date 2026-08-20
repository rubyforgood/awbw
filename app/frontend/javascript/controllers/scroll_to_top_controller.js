import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="scroll-to-top"
//
// Scrolls the window to the top on connect. Attached to the duplicate-person
// warning, which only renders when a create attempt surfaces possible
// duplicates, so the warning is brought into view whether it arrives via Turbo
// Stream or a full-page re-render. Replaces an inline
// <script>window.scrollTo(0,0)</script> that violated the CSP script-src policy.
export default class extends Controller {
  connect() {
    window.scrollTo(0, 0);
  }
}
