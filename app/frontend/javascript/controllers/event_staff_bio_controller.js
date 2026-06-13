import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="event-staff-bio"
// Shows the selected person's read-only profile bio (with a link to edit it on
// their profile) next to the editable event-specific bio. The profile bio is
// the fallback the public staff page shows when the event bio is left blank, so
// the organizer can see it while deciding whether to override it. For a freshly
// added staff row the person isn't known server-side, so we fetch their bio when
// they're picked from the person search.
export default class extends Controller {
  static targets = ["profile"]
  static values = { urlTemplate: String }

  personChanged(event) {
    const id = event.target.value
    if (!id) return this.renderEmpty()
    this.load(id)
  }

  async load(id) {
    this.profileTarget.innerHTML = this.header() + this.muted("Loading profile bio…")
    try {
      const response = await fetch(this.urlTemplateValue.replace("__ID__", id), {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) throw new Error(response.status)
      this.render(await response.json())
    } catch {
      this.profileTarget.innerHTML = this.header() + this.muted("Couldn't load profile bio.")
    }
  }

  render(data) {
    let body
    if (data.has_bio) {
      body = `<div class="text-sm text-gray-600">${data.bio_html}</div>`
    } else if (data.show_bio) {
      body = this.muted("No profile bio on file.")
    } else {
      body = this.muted("This person's profile bio is hidden.")
    }
    this.profileTarget.innerHTML = this.header(data.edit_path) + body
  }

  renderEmpty() {
    this.profileTarget.innerHTML = this.header() + this.muted("Select a person to see their profile bio.")
  }

  header(editPath) {
    const link = editPath
      ? `<a href="${editPath}" class="text-xs font-medium text-blue-600 hover:text-blue-800">Edit on profile</a>`
      : ""
    return `<div class="flex items-center justify-between mb-1"><span class="text-sm font-medium text-gray-700">Profile bio</span>${link}</div>`
  }

  muted(text) {
    return `<p class="text-sm text-gray-400 italic">${text}</p>`
  }
}
