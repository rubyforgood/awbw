import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="org-toggle"
// Allows adding an org from the "current orgs" list to the
// "organizations at registration" chip list.

export default class extends Controller {
  static targets = ["chips"]

  add(event) {
    const button = event.currentTarget
    const orgId = button.dataset.orgId
    const orgName = button.dataset.orgName

    // Check if already present
    const existing = this.chipsTarget.querySelector(`input[value="${orgId}"]`)
    if (existing) {
      existing.checked = true
      return
    }

    const label = document.createElement("label")
    label.className = "inline-flex items-center gap-1 px-4 py-1 rounded-full text-xs border cursor-pointer transition-colors bg-red-50 border-red-200 text-red-400 line-through has-[:checked]:bg-emerald-50 has-[:checked]:border-emerald-200 has-[:checked]:text-emerald-800 has-[:checked]:no-underline"

    const input = document.createElement("input")
    input.type = "checkbox"
    input.name = "event_registration[organization_ids][]"
    input.value = orgId
    input.checked = true
    input.className = "sr-only"

    const nameSpan = document.createElement("span")
    nameSpan.textContent = orgName

    const xSpan = document.createElement("span")
    xSpan.className = "text-xs opacity-50"
    xSpan.innerHTML = "&times;"

    label.appendChild(input)
    label.appendChild(nameSpan)
    label.appendChild(xSpan)

    this.chipsTarget.appendChild(label)

    // Show the section if it was hidden
    this.chipsTarget.closest("[data-org-toggle-target='section']")?.classList.remove("hidden")

    button.remove()
  }
}
