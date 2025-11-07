// app/javascript/controllers/file_preview_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "preview", "filename"]

    connect() {
        this.bindInput(this.inputTarget)
    }

    bindInput(input) {
        input.addEventListener("change", (event) => {
            const file = event.target.files[0]
            if (!file) return

            if (this.hasFilenameTarget) this.filenameTarget.textContent = file.name
            if (this.hasPreviewTarget) {
                const reader = new FileReader()
                reader.onload = (e) => (this.previewTarget.src = e.target.result)
                reader.readAsDataURL(file)
            }
        })
    }
}
