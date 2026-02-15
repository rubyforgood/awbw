import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, id: Number }

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
        "Accept": "application/json"
      },
      body: formData
    }).then(response => {
      if (response.ok) {
        field.classList.add("ring-2", "ring-green-300")
        setTimeout(() => field.classList.remove("ring-2", "ring-green-300"), 1000)
      } else {
        field.classList.add("ring-2", "ring-red-300")
        setTimeout(() => field.classList.remove("ring-2", "ring-red-300"), 2000)
      }
    })
  }
}
