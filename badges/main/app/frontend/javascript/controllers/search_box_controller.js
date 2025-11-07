import { Controller } from "@hotwired/stimulus"

console.log("💡 search_box_controller.js loaded by Vite")

export default class extends Controller {
    static targets = ["select"]

    connect() {
        console.log("✅ search-box connected")
        this.selectTargets.forEach(select => {
            select.addEventListener("change", () => this.element.requestSubmit())
        })
    }
}
