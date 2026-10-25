import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Optional status targets carry data-field-name matching a field's (unwrapped) name and
// show "Saved" or "Not saved: <reason>" beside that field.
export default class extends Controller {
  static targets = ["status"]
  static values = { url: String, id: Number, stream: Boolean }

  initialize() {
    this.hideTimers = new Map()
  }

  disconnect() {
    this.hideTimers.forEach(timer => clearTimeout(timer))
    this.hideTimers.clear()
  }

  save(event) {
    const field = event.target
    if (!field.name) return

    // Fix Rails fields_for bracket wrapping: [sector_to_keep][published] -> sector_to_keep[published]
    const name = field.name.replace(/^\[([^\]]+)\]/, "$1")

    const formData = new FormData()

    if (field.type === "checkbox") {
      formData.append(name, field.checked ? "1" : "0")
    } else {
      formData.append(name, field.value)
    }
    formData.append("id", this.idValue)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": this.streamValue ? "text/vnd.turbo-stream.html" : "application/json"
      },
      body: formData
    }).then(response => {
      if (response.ok) {
        if (this.streamValue) response.text().then(html => Turbo.renderStreamMessage(html))
        field.classList.add("ring-2", "ring-green-300")
        setTimeout(() => field.classList.remove("ring-2", "ring-green-300"), 1000)
        this.showSaved(name)
      } else {
        field.classList.add("ring-2", "ring-red-300")
        setTimeout(() => field.classList.remove("ring-2", "ring-red-300"), 2000)
        response.json().catch(() => ({})).then(body => this.showFailed(name, body.error))
      }
    }).catch(() => this.showFailed(name))
  }

  showSaved(name) {
    const status = this.statusFor(name)
    if (!status) return

    this.render(status, "fa-circle-check", "Saved", "text-green-700")
    this.hideTimers.set(status, setTimeout(() => status.classList.add("hidden"), 3000))
  }

  showFailed(name, reason) {
    const status = this.statusFor(name)
    if (!status) return

    this.render(status, "fa-triangle-exclamation", reason ? `Not saved: ${reason}` : "Not saved", "text-red-700")
  }

  render(status, icon, message, colorClass) {
    clearTimeout(this.hideTimers.get(status))
    const iconElement = document.createElement("i")
    iconElement.className = `fa-solid ${icon}`
    status.replaceChildren(iconElement, ` ${message}`)
    status.classList.remove("hidden", "text-green-700", "text-red-700")
    status.classList.add(colorClass)
  }

  statusFor(name) {
    return this.statusTargets.find(status => status.dataset.fieldName === name)
  }
}
