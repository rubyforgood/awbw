import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="org-toggle"
// Allows adding an org from the "current orgs" list to the
// "organizations at registration" chip list.

export default class extends Controller {
  static targets = ["chips", "select", "addForm", "addButton", "empty"]
  static outlets = ["remote-select"]

  // Legacy button-based add (kept for any view still rendering add buttons).
  add(event) {
    const button = event.currentTarget
    this.addChip(button.dataset.orgId, button.dataset.orgName)
    button.remove()
  }

  // Dropdown-based add: pick an org from the select to append it as a chip.
  addFromSelect(event) {
    const select = event.currentTarget
    const option = select.selectedOptions[0]
    if (!option || !option.value) return

    this.addChip(option.value, option.textContent.trim())
    option.remove()
    select.value = ""
  }

  // Reveal the inline org search when "Add organization" is clicked.
  showAddForm() {
    this.addFormTarget.classList.remove("hidden")
    if (this.hasAddButtonTarget) this.addButtonTarget.classList.add("hidden")
  }

  // Pick an org from the searchable remote select, append it as a chip, then
  // reset the search box so another can be added. Nothing is persisted until
  // the surrounding form is saved.
  addFromRemote(event) {
    const select = event.currentTarget
    const option = select.selectedOptions[0]
    if (!option || !option.value) return

    this.addChip(option.value, option.textContent.trim())
    if (this.hasRemoteSelectOutlet) this.remoteSelectOutlet.clear()
  }

  addChip(orgId, orgName) {
    // Re-check it if a crossed-out chip for this org already exists.
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

    // Show the section if it was hidden, and drop the empty-state hint.
    this.chipsTarget.closest("[data-org-toggle-target='section']")?.classList.remove("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
  }
}
