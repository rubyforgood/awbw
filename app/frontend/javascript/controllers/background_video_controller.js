import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="background-video"
// One toggle pauses every muted background video and autoplaying carousel on the page (WCAG 2.2.2).
export default class extends Controller {
  static targets = ["player", "toggle", "icon"]
  static outlets = ["carousel"]
  static values = { paused: Boolean }

  toggle() {
    this.pausedValue = !this.pausedValue
  }

  // Re-sends the pause to a player that finishes loading after the visitor paused.
  playerLoaded({ target }) {
    if (this.pausedValue) this.command(target, "pauseVideo")
  }

  pausedValueChanged(paused, previous) {
    if (previous === undefined) return

    this.playerTargets.forEach((player) => this.command(player, paused ? "pauseVideo" : "playVideo"))
    this.carouselOutlets.forEach((carousel) => carousel.setAutoplay(!paused))
    this.toggleTargets.forEach((toggle) => {
      toggle.setAttribute("aria-label", paused ? "Play videos and slideshows" : "Pause videos and slideshows")
    })
    this.iconTargets.forEach((icon) => {
      icon.classList.toggle("fa-pause", !paused)
      icon.classList.toggle("fa-play", paused)
    })
  }

  command(player, func) {
    player.contentWindow?.postMessage(JSON.stringify({ event: "command", func, args: [] }), "https://www.youtube.com")
  }
}
