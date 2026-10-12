import { Controller } from "@hotwired/stimulus"

// Expands a collapsible section and scrolls it into view when the page loads
// with a matching URL hash or scroll_to query parameter. The query parameter
// carries the target through Turbo form redirects, which drop URL fragments.
//
//   <div data-controller="dropdown reveal-section"
//        data-reveal-section-anchor-value="registration_form_section"
//        data-reveal-section-target="toggle"> ... the toggle button
//        data-reveal-section-target="content"> ... the collapsible body
//
// The toggle target is clicked (reusing the dropdown controller) only when the
// content is currently hidden, keeping the dropdown's open/closed state honest.
// Both targets are optional: with neither, this is a scroll-to-my-anchor on
// connect, which is what a section arriving inside a lazily-loaded Turbo frame
// needs (the browser resolved the hash long before the frame's content existed).
export default class extends Controller {
  static targets = ["toggle", "content"]
  static values = { anchor: String }

  connect() {
    const url = new URL(window.location.href)
    const matchingHash = url.hash.slice(1) === this.anchorValue
    const matchingQuery = url.searchParams.get("scroll_to") === this.anchorValue
    if (!matchingHash && !matchingQuery) return

    if (this.hasContentTarget && this.contentTarget.classList.contains("hidden")) {
      this.toggleTarget.click()
    }
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })

    if (matchingQuery) url.searchParams.delete("scroll_to")
    url.hash = ""
    history.replaceState(history.state, "", `${url.pathname}${url.search}`)
  }
}
