import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Makes a whole element (e.g. a table row) navigate to a URL on click, while
// leaving nested interactive elements working normally — a click on a link,
// button, input, or anything opted out with data-clickable-row-ignore is left
// alone. Modifier-clicks (new tab) fall through to the row's own link.
export default class extends Controller {
  static values = { url: String }

  navigate(event) {
    if (event.target.closest("a, button, input, label, select, summary, [data-clickable-row-ignore]")) return
    if (event.metaKey || event.ctrlKey || event.shiftKey) return
    Turbo.visit(this.urlValue)
  }
}
