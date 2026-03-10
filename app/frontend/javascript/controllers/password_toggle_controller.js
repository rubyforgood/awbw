import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "eyeOpen", "eyeClosed"];

  toggle() {
    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"

    this.eyeOpenTarget.classList.toggle("hidden", isPassword)
    this.eyeClosedTarget.classList.toggle("hidden", !isPassword)
  }
}
