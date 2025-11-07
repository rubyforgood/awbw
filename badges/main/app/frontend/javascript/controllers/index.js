import { application } from "./application"

import DropdownController from "./dropdown_controller";
application.register("dropdown", DropdownController);

import FilePreviewController from "./file_preview_controller"
application.register("file-preview", FilePreviewController)

import SearchBoxController from "./search_box_controller"
application.register("search-box", SearchBoxController)

import SortableController from "./sortable_controller"
application.register("sortable", SortableController)

import TimeframeController from "./timeframe_controller"
application.register("timeframe", TimeframeController)
