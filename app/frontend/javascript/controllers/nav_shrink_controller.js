import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-shrink"
// Collapses the portal's secondary nav rows once the page is scrolled past a
// threshold. Declarative scroll@window action, so Turbo handles cleanup.
export default class extends Controller {
  update() {
    this.element.classList.toggle("scrolled", window.scrollY > 100)
  }
}
