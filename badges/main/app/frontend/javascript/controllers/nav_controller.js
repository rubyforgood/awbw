import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["section", "caret"]

    toggleSection(event) {
        const sectionName = event.currentTarget.dataset.section

        this.sectionTargets.forEach((section) => {
            section.classList.toggle(
                "hidden",
                section.dataset.section !== sectionName || !section.classList.contains("hidden")
            )
        })

        this.caretTargets.forEach((caret) => {
            if (caret.dataset.section === sectionName) {
                caret.classList.toggle("rotate-180")
            } else {
                caret.classList.remove("rotate-180")
            }
        })
    }
}
