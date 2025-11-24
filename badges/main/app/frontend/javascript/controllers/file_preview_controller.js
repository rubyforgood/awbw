import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "preview", "placeholder", "filename"]

    update(event) {
        const file = event.target.files[0]
        if (!file) return

        // Update filename
        if (this.hasFilenameTarget) {
            this.filenameTarget.textContent = file.name
        }

        // Update preview image (if you have one)
        if (this.hasPreviewTarget) {
            const reader = new FileReader()
            reader.onload = e => {
                this.previewTarget.src = e.target.result
                this.previewTarget.classList.remove("hidden")
            }
            reader.readAsDataURL(file)
        }

        // Hide placeholder if present
        if (this.hasPlaceholderTarget) {
            this.placeholderTarget.classList.add("hidden")
        }
    }
}
