import { application } from "./application"

import CarouselController from "./carousel_controller"
application.register("carousel", CarouselController)

import CollectionController from "./collection_controller"
application.register("collection", CollectionController)

import DismissController from "./dismiss_controller";
application.register("dismiss", DismissController);

import DropdownController from "./dropdown_controller";
application.register("dropdown", DropdownController);

import FilePreviewController from "./file_preview_controller"
application.register("file-preview", FilePreviewController)

import PasswordToggleController from "./password_toggle_controller"
application.register("password-toggle", PasswordToggleController)

import SearchBoxController from "./search_box_controller"
application.register("search-box", SearchBoxController)

import ShareUrlController from "./share_url_controller"
application.register("share-url", ShareUrlController)

import SortableController from "./sortable_controller"
application.register("sortable", SortableController)

import TabsController from "./tabs_controller"
application.register("tabs", TabsController)

import TimeframeController from "./timeframe_controller"
application.register("timeframe", TimeframeController)

import RhinoSourceController from "./rhino_source_controller"
application.register("rhino-source", RhinoSourceController)

import ToggleLockController from "./toggle_lock_controller"
application.register("toggle-lock", ToggleLockController)
