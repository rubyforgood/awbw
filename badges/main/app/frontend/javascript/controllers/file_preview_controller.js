import { Controller } from "@hotwired/stimulus"

const FILE_TYPE_ICONS = {
    "application/pdf": "fa-regular fa-file-pdf",
    "application/msword": "fa-regular fa-file-word",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "fa-regular fa-file-word",
    "application/vnd.oasis.opendocument.text": "fa-regular fa-file-lines",
}

export default class extends Controller {
    static targets = ["input", "preview", "placeholder", "filename"]
    // 0 means no client-side limit; the server validates either way. Setting it
    // stops an oversized file from being direct-uploaded before rejection.
    static values = { maxSize: { type: Number, default: 0 } }

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

        if (this.maxSizeValue > 0 && file.size > this.maxSizeValue) {
            // Clearing the input keeps Active Storage from uploading it on submit
            event.target.value = ""
            this.showError(`That file is ${this.megabytes(file.size)} MB — the maximum is ${this.megabytes(this.maxSizeValue)} MB.`)
            return
        }

        // Update filename
        if (this.hasFilenameTarget) {
            this.filenameTarget.textContent = file.name
        }

        if (file.type.startsWith("image/")) {
            this.showImagePreview(file)
        } else {
            this.showFileIcon(file.type)
        }
    }

    megabytes(bytes) {
        return Math.round((bytes / (1024 * 1024)) * 10) / 10
    }

    // Ensure a placeholder div exists (server may not render one when a persisted file exists)
    ensurePlaceholder() {
        if (this.hasPlaceholderTarget) return this.placeholderTarget

        const wrapper = this.hasPreviewTarget
            ? this.previewTarget.parentElement
            : this.element.querySelector(".flex.flex-col")

        const placeholder = document.createElement("div")
        placeholder.dataset.filePreviewTarget = "placeholder"
        placeholder.className = "absolute inset-0 flex items-center justify-center border border-gray-300 shadow-sm bg-gray-50 text-gray-400 text-6xl"
        wrapper.appendChild(placeholder)
        return placeholder
    }

    showImagePreview(file) {
        if (!this.hasPreviewTarget) return

        const reader = new FileReader()
        reader.onload = e => {
            this.previewTarget.src = e.target.result
            this.previewTarget.classList.remove("hidden")
        }
        reader.readAsDataURL(file)

        if (this.hasPlaceholderTarget) {
            this.placeholderTarget.classList.add("hidden")
        }
    }

    showFileIcon(mimeType) {
        const placeholder = this.ensurePlaceholder()
        const iconClass = FILE_TYPE_ICONS[mimeType] || "fa-regular fa-file"
        placeholder.innerHTML = `<i class="${iconClass} text-5xl"></i>`
        placeholder.classList.remove("hidden")

        if (this.hasPreviewTarget) {
            this.previewTarget.classList.add("hidden")
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
