import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="allocation-ref"
// Clicking an allocation's "Ref" yellow-highlights the row it points to (the
// reverted/reversing allocation) and scrolls it into view. The important
// modifier wins over each row's own background class.
export default class extends Controller {
  static targets = ["row"]

  highlight(event) {
    const id = String(event.params.id)
    this.rowTargets.forEach((row) => {
      const match = row.dataset.allocationId === id
      row.classList.toggle("bg-yellow-100!", match)
      if (match) row.scrollIntoView({ behavior: "smooth", block: "center" })
    })
  }
}
