import { Turbo } from "@hotwired/turbo-rails";
import "@rails/actiontext";
import "rhino-editor";
import "rhino-editor/exports/styles/trix.css";

import "chartkick/chart.js"

import "@rails/activestorage"
import * as ActiveStorage from "@rails/activestorage";
ActiveStorage.start();

import "./controllers";
import "./rhino/extend-editor.js";
import "./turbo-events";
import { confirmModal } from "./confirm_modal";

// Route Turbo's data-turbo-confirm prompts through the styled in-page modal
// instead of the browser's native confirm() dialog.
Turbo.setConfirmMethod((message) => confirmModal(message));
