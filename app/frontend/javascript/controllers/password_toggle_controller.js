import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "eyeOpen", "eyeClosed"];

    toggle() {
        const isPassword = this.inputTarget.type === "password"
        this.inputTarget.type = isPassword ? "text" : "password"

        this.eyeOpenTarget.style.display = isPassword ? "none" : ""
        this.eyeClosedTarget.style.display = isPassword ? "" : "none"
    }
}
