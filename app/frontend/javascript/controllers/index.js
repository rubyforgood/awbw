import { application } from "./application";

import HelloController from "./hello_controller";
application.register("hello", HelloController);

import DropdownController from "./dropdown_controller";
application.register("dropdown", DropdownController);
