import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="timeframe"
export default class extends Controller {
  static targets = ["input", "output"]

  connect() {
    this.update()
  }

  update() {
    let totalMinutes = this.inputTargets
      .map(el => parseInt(el.value || 0, 10))
      .reduce((a, b) => a + b, 0)

    totalMinutes = Math.ceil(totalMinutes / 15) * 15

    const hours = Math.floor(totalMinutes / 60)
    const minutes = totalMinutes % 60

    const formatted =
      hours > 0
        ? `${hours}:${minutes.toString().padStart(2, "0")} hours`
        : `${minutes} mins`

    this.outputTarget.textContent = formatted
  }
}
