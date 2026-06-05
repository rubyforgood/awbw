import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lightbox"
//
// Opens gallery images in an inline modal instead of navigating away, and lets
// the viewer scroll through all of the gallery's images with next/previous
// controls, the arrow keys, or by closing with Escape / a backdrop click.
//
// Each clickable image is an "item" target whose href points at the full-size
// image. The modal, image, counter, and nav buttons live in the same scope.
export default class extends Controller {
  static targets = ["item", "modal", "image", "counter", "prev", "next"]
  static values = { index: Number }

  open(event) {
    const index = this.itemTargets.indexOf(event.currentTarget)
    if (index === -1) return

    this.indexValue = index
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
    this.modalTarget.focus()
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
  }

  next() {
    if (this.isClosed) return
    this.indexValue = (this.indexValue + 1) % this.itemTargets.length
  }

  prev() {
    if (this.isClosed) return
    const count = this.itemTargets.length
    this.indexValue = (this.indexValue - 1 + count) % count
  }

  closeOnEscape() {
    if (this.isClosed) return
    this.close()
  }

  backdropClose(event) {
    if (event.target === this.modalTarget) this.close()
  }

  indexValueChanged() {
    const item = this.itemTargets[this.indexValue]
    if (!item) return

    this.imageTarget.src = item.getAttribute("href")
    this.imageTarget.alt = item.dataset.caption || ""

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.indexValue + 1} of ${this.itemTargets.length}`
    }

    const single = this.itemTargets.length <= 1
    if (this.hasPrevTarget) this.prevTarget.classList.toggle("hidden", single)
    if (this.hasNextTarget) this.nextTarget.classList.toggle("hidden", single)
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }

  get isClosed() {
    return this.modalTarget.classList.contains("hidden")
  }
}
