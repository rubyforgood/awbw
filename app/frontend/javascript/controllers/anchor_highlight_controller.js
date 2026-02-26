import { Controller } from "@hotwired/stimulus"

// Highlights a target element when a link is clicked, then fades after a delay.
//
// Usage:
//   <a href="#some-id"
//      data-controller="anchor-highlight"
//      data-anchor-highlight-target-param="some-id"
//      data-action="click->anchor-highlight#flash">
//     Link text
//   </a>
//
//   <div id="some-id">Highlighted element</div>
//
export default class extends Controller {
  flash(event) {
    const targetId = event.params.target
    if (!targetId) return

    const el = document.getElementById(targetId)
    if (!el) return

    el.style.backgroundColor = "#fef9c3"
    el.style.borderRadius = "0.25rem"
    el.style.transition = "background-color 3s"

    setTimeout(() => {
      el.style.backgroundColor = ""
      el.style.borderRadius = ""
    }, 4000)
  }
}
