import "@hotwired/turbo-rails"

// Turbo drive breaks the ui when navigating due to our migraiton from bootstrap to tailwind.
// This should be set to true when the migration is complete.
Turbo.session.drive = false;

import "./controllers"
