import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="callout-preview"
// Tints a registration ticket callout's editor card with its selected colour
// theme — falling back to the per-type default when no colour is chosen — so the
// admin sees how the call-out will look on the ticket while editing. Recomputes
// whenever the type or colour select changes.
export default class extends Controller {
  static targets = ["typeSelect", "colorSelect", "arrow", "iconInput", "leadingIcon"]
  static values = { themes: Object, defaults: Object }

  connect() {
    this.element.classList.remove("bg-white", "border-gray-200")
    if (this.hasArrowTarget) this.arrowTarget.classList.remove("text-gray-300")
    this.applied = []
    this.update()
  }

  update() {
    const theme = this.themesValue[this.themeKey()] || this.themesValue["indigo"]

    this.element.classList.remove(...this.applied)
    this.applied = [theme.border, theme.bg]
    this.element.classList.add(...this.applied)

    if (this.hasArrowTarget) {
      this.arrowTarget.classList.remove(...this.arrowApplied || [])
      this.arrowApplied = [theme.icon]
      this.arrowTarget.classList.add(...this.arrowApplied)
    }

    this.updateLeadingIcon(theme)
  }

  // Mirror the call-out's leading icon on the left of the card — shown only when
  // the admin has entered a Font Awesome class — tinted to match the theme.
  updateLeadingIcon(theme) {
    if (!this.hasLeadingIconTarget || !this.hasIconInputTarget) return
    const glyph = this.iconInputTarget.value.trim()
    this.leadingIconTarget.className = glyph
      ? `${glyph} ${theme.icon} shrink-0 text-xl`
      : "hidden"
  }

  themeKey() {
    if (this.hasColorSelectTarget && this.colorSelectTarget.value) {
      return this.colorSelectTarget.value
    }
    const type = this.hasTypeSelectTarget ? this.typeSelectTarget.value : ""
    return this.defaultsValue[type] || "indigo"
  }
}
