import { application } from "./application";

import DropdownController from "./dropdown_controller";
application.register("dropdown", DropdownController);

import SortableController from "./sortable_controller"
application.register("sortable", SortableController)
