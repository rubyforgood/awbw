import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="org-toggle"
// Allows adding an org from the "current orgs" list to the
// "organizations at registration" chip list.

export default class extends Controller {
  static targets = ["chips", "select", "addForm", "addButton", "empty", "template"]
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

    // Clone the pending-chip template (amber until saved). Keeping the markup in
    // the view means Tailwind reliably compiles its variants.
    const label = this.templateTarget.content.firstElementChild.cloneNode(true)
    label.querySelector("input").value = orgId
    label.querySelector("[data-org-toggle-name]").textContent = orgName

    this.chipsTarget.appendChild(label)

    // Show the section if it was hidden, and drop the empty-state hint.
    this.chipsTarget.closest("[data-org-toggle-target='section']")?.classList.remove("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
  }
}
