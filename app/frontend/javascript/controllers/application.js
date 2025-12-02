import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Optional: enable debug mode and console access
application.debug = true
window.Stimulus = application

export { application }
