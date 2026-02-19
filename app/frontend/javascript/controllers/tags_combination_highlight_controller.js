import { Controller } from "@hotwired/stimulus"

// When sector/category checkboxes in "Explore by combination" are checked,
// adds a highlight class to the corresponding tag block in the Sectors/Categories panels above.
const HIGHLIGHT_CLASS = "tags-combination-selected"

export default class extends Controller {
  connect() {
    this.boundSync = this.syncHighlights.bind(this)
    this.sectorInputs = () => this.element.querySelectorAll('input[name="sector_names_all[]"]')
    this.categoryInputs = () => this.element.querySelectorAll('input[name="category_names_all[]"]')

    this.sectorInputs().forEach(input => input.addEventListener("change", this.boundSync))
    this.categoryInputs().forEach(input => input.addEventListener("change", this.boundSync))

    document.addEventListener("turbo:frame-load", this.handleFrameLoad)
    this.syncHighlights()
  }

  disconnect() {
    this.sectorInputs().forEach(input => input.removeEventListener("change", this.boundSync))
    this.categoryInputs().forEach(input => input.removeEventListener("change", this.boundSync))
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  handleFrameLoad = (event) => {
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
    const selected = Array.from(this.sectorInputs())
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
    const selected = Array.from(this.categoryInputs())
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
