import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "preview", "placeholder", "filename"]

    connect() {
        this.handleUploadError = this.onUploadError.bind(this)
        this.handleUploadEnd = this.onUploadEnd.bind(this)
        this.element.addEventListener("direct-upload:error", this.handleUploadError)
        this.element.addEventListener("direct-upload:end", this.handleUploadEnd)
    }

    disconnect() {
        this.element.removeEventListener("direct-upload:error", this.handleUploadError)
        this.element.removeEventListener("direct-upload:end", this.handleUploadEnd)
    }

    update(event) {
        const file = event.target.files[0]
        if (!file) return

        this.clearError()

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

    onUploadError(event) {
        event.preventDefault()
        const { error } = event.detail
        this.showError(`Upload failed: ${error}`)
    }

    onUploadEnd(event) {
        this.clearError()
    }

    showError(message) {
        this.clearError()
        const errorEl = document.createElement("p")
        errorEl.className = "text-red-500 text-sm mt-1"
        errorEl.dataset.filePreviewTarget = "error"
        errorEl.textContent = message
        this.element.appendChild(errorEl)
    }

    clearError() {
        const existing = this.element.querySelector('[data-file-preview-target="error"]')
        if (existing) existing.remove()
    }
}
