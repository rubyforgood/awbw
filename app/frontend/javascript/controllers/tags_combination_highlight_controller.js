import { Controller } from "@hotwired/stimulus"

// When sector/category checkboxes in "Explore by combination" are checked,
// adds a highlight class to the corresponding tag block in the Sectors/Categories panels above.
const HIGHLIGHT_CLASS = "tags-combination-selected"

export default class extends Controller {
  static targets = ["sectorInput", "categoryInput"]

  connect() {
    this.handleFrameLoad = this.handleFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.handleFrameLoad)
    this.syncHighlights()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  handleFrameLoad(event) {
    const frame = event?.detail?.frameElement
    if (frame?.id === "sectors_tags" || frame?.id === "categories_tags") {
      this.syncHighlights()
    }
  }

  syncHighlights() {
    this.syncSectorHighlights()
    this.syncCategoryHighlights()
  }

  syncSectorHighlights() {
    const selected = this.sectorInputTargets
      .filter(el => el.checked)
      .map(el => el.value.trim())
    const frame = document.getElementById("sectors_tags")
    if (!frame) return
    frame.querySelectorAll("a[data-sector-name]").forEach(link => {
      const name = link.dataset.sectorName?.trim()
      link.classList.toggle(HIGHLIGHT_CLASS, name && selected.includes(name))
    })
  }

  syncCategoryHighlights() {
    const selected = this.categoryInputTargets
      .filter(el => el.checked)
      .map(el => el.value.trim())
    const frame = document.getElementById("categories_tags")
    if (!frame) return
    frame.querySelectorAll("a[data-category-name]").forEach(link => {
      const name = link.dataset.categoryName?.trim()
      link.classList.toggle(HIGHLIGHT_CLASS, name && selected.includes(name))
    })
  }
}
