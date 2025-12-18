import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="rhino-source"

export default class extends Controller {
  static targets = ["modal", "textarea"]

  connect() {
    this.modalTarget.classList.add("hidden")
    this._editor = null
  }

  registerEditor(editor) {
    this._editor = editor
  }

  show(event) {
    event?.preventDefault()
    if (!this._editor) return
    this.textareaTarget.value = this._editor.getHTML()
    this.modalTarget.classList.remove("hidden")
  }

  hide(event) {
    event?.preventDefault()
    this.modalTarget.classList.add("hidden")
  }

  save(event) {
    event.preventDefault()
    if (!this._editor) return
    this._editor.chain().focus().setContent(this.textareaTarget.value).run()
    this.hide()
  }
}
