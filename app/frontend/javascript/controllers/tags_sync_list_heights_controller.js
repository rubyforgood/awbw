import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["source", "dest", "sector", "category"]

    connect() {
        // height sync
        this.syncHeights()
        this.resizeObserver = new ResizeObserver(() => this.syncHeights())
        this.resizeObserver.observe(this.sourceTarget)
    }

    disconnect() {
        this.resizeObserver?.disconnect()
    }

    // --------------------
    // HEIGHT SYNC
    // --------------------
    syncHeights() {
        if (!this.hasSourceTarget || !this.hasDestTarget) {
            console.warn("[sync-list-heights] missing targets")
            return
        }

        const height = this.sourceTarget.offsetHeight
        this.destTarget.style.height = `${height}px`
        this.destTarget.style.overflowY = "auto"
    }

    // --------------------
    // APPLY FILTERS
    // --------------------
    applyFilters() {
        const selectedSectors = this.sectorTargets
            .filter(el => el.checked)
            .map(el => el.value)

        const selectedCategories = this.categoryTargets
            .filter(el => el.checked)
            .map(el => el.value)

        // Start fresh with only filter parameters (intentional - clears pagination, etc.)
        const params = new URLSearchParams()

        if (selectedSectors.length > 0) {
            params.set("sector_names_all", selectedSectors.join("--"))
        }

        if (selectedCategories.length > 0) {
            params.set("category_names_all", selectedCategories.join("--"))
        }

        // Always redirect to /taggings with the selected filters
        const taggingsPath = "/taggings"
        window.location.href = taggingsPath + (params.toString() ? "?" + params.toString() : "")
    }
}
