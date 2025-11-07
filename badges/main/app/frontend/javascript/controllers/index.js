import { application } from "./application";

import DropdownController from "./dropdown_controller";
application.register("dropdown", DropdownController);

import SortableController from "./sortable_controller"
application.register("sortable", SortableController)

import TimeframeController from "./timeframe_controller"
application.register("timeframe", TimeframeController)
