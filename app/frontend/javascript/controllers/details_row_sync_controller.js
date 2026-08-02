import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="details-row-sync"
// Keeps a row of <details> cards in lockstep: opening or closing one mirrors its
// open/closed state onto the rest of the row. Each card fires a native `toggle`
// event (which does not bubble, so nested <details> inside a card are ignored);
// we copy the toggled card's `open` onto its siblings. Mirroring only sets cards
// whose state actually differs, so the cascade of toggle events it triggers
// converges immediately instead of looping.
export default class extends Controller {
  static targets = ["card"]

  sync(event) {
    const open = event.target.open
    this.cardTargets.forEach(card => {
      if (card.open !== open) card.open = open
    })
  }
}
