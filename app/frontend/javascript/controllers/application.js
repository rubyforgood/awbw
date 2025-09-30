import { Application } from "@hotwired/stimulus"
import TabsController from "./tabs_controller"

const application = Application.start()

// Register your controller
application.register("tabs", TabsController)

// Optional: enable debug mode and console access
application.debug = true
window.Stimulus = application

export { application }
