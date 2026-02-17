import { application } from "./application"

import AssetPickerController from "./asset_picker_controller"
application.register("asset-picker", AssetPickerController)

import AutosaveController from "./autosave_controller"
application.register("autosave", AutosaveController)

import CarouselController from "./carousel_controller"
application.register("carousel", CarouselController)

import CocoonController from "./cocoon_controller"
application.register("cocoon", CocoonController)

import CollectionController from "./collection_controller"
application.register("collection", CollectionController)

import ConfirmEmailController from "./confirm_email_controller"
application.register("confirm-email", ConfirmEmailController)

import CommentEditToggleController from "./comment_edit_toggle_controller"
application.register("comment-edit-toggle", CommentEditToggleController)

import DirtyFormController from "./dirty_form_controller"
application.register("dirty-form", DirtyFormController)

import DismissController from "./dismiss_controller"
application.register("dismiss", DismissController)

import DropdownController from "./dropdown_controller"
application.register("dropdown", DropdownController)

import FilePreviewController from "./file_preview_controller"
application.register("file-preview", FilePreviewController)

import InactiveToggleController from "./inactive_toggle_controller"
application.register("inactive-toggle", InactiveToggleController)

import OptimisticBookmarkController from "./optimistic_bookmark_controller"
application.register("optimistic-bookmark", OptimisticBookmarkController)

import PaginatedFieldsController from "./paginated_fields_controller"
application.register("paginated-fields", PaginatedFieldsController)

import PasswordToggleController from "./password_toggle_controller"
application.register("password-toggle", PasswordToggleController)

import PrefetchLazyController from "./prefetch_lazy_controller"
application.register("prefetch-lazy", PrefetchLazyController)

import PrintOptionsController from "./print_options_controller"
application.register("print-options", PrintOptionsController)

import RhinoSourceController from "./rhino_source_controller"
application.register("rhino-source", RhinoSourceController)

import SearchBoxController from "./search_box_controller"
application.register("search-box", SearchBoxController)

import SearchableSelectController from "./searchable_select_controller"
application.register("searchable-select", SearchableSelectController)

import ShareUrlController from "./share_url_controller"
application.register("share-url", ShareUrlController)

import SortableController from "./sortable_controller"
application.register("sortable", SortableController)

import TabsController from "./tabs_controller"
application.register("tabs", TabsController)

import TagsSyncListHeightsController from "./tags_sync_list_heights_controller"
application.register("tags-sync-list-heights", TagsSyncListHeightsController)

import TimeframeController from "./timeframe_controller"
application.register("timeframe", TimeframeController)

import ToggleLockController from "./toggle_lock_controller"
application.register("toggle-lock", ToggleLockController)

import ToggleUserIconController from "./toggle_user_icon_controller"
application.register("toggle-user-icon", ToggleUserIconController)
