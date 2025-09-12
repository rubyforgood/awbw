# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_09_12_144532) do

  create_table "admins", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "age_ranges", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "windows_type_id"
    t.index ["windows_type_id"], name: "index_age_ranges_on_windows_type_id"
  end

  create_table "answer_options", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "attachments", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at"
  end

  create_table "banners", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.text "content"
    t.boolean "show"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bookmark_annotations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "bookmark_id"
    t.text "annotation", limit: 16777215
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bookmark_id"], name: "index_bookmark_annotations_on_bookmark_id"
  end

  create_table "bookmarks", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "user_id"
    t.string "bookmarkable_type"
    t.integer "bookmarkable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "categories", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "metadatum_id"
    t.string "name"
    t.integer "legacy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published", default: false
    t.index ["metadatum_id"], name: "index_categories_on_metadatum_id"
  end

  create_table "categorizable_items", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "categorizable_id"
    t.string "categorizable_type"
    t.integer "category_id"
    t.integer "legacy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "inactive", default: true
    t.index ["category_id"], name: "index_categorizable_items_on_category_id"
  end

  create_table "ckeditor_assets", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "data_file_name", null: false
    t.string "data_content_type"
    t.integer "data_file_size"
    t.integer "assetable_id"
    t.string "assetable_type", limit: 30
    t.string "type", limit: 30
    t.integer "width"
    t.integer "height"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "actual_url"
    t.index ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type"
  end

  create_table "facilitators", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "faqs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "question"
    t.text "answer", limit: 16777215
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "inactive"
    t.integer "ordering"
  end

  create_table "footers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "phone"
    t.string "children_program"
    t.string "adult_program"
    t.string "general_questions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "form_builders", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.integer "owner_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description", limit: 16777215
    t.integer "windows_type_id"
    t.index ["windows_type_id"], name: "index_form_builders_on_windows_type_id"
  end

  create_table "form_field_answer_options", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "form_field_id"
    t.integer "answer_option_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_option_id"], name: "index_form_field_answer_options_on_answer_option_id"
    t.index ["form_field_id"], name: "index_form_field_answer_options_on_form_field_id"
  end

  create_table "form_fields", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "form_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "question"
    t.string "instructional_hint"
    t.integer "answer_type"
    t.integer "answer_datatype"
    t.integer "ordering"
    t.boolean "is_required", default: true
    t.integer "status", default: 1
    t.integer "parent_id"
    t.index ["form_id"], name: "index_form_fields_on_form_id"
  end

  create_table "forms", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "owner_type"
    t.integer "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "form_builder_id"
    t.index ["form_builder_id"], name: "index_forms_on_form_builder_id"
  end

  create_table "images", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at"
    t.integer "report_id"
    t.index ["owner_id"], name: "index_images_on_owner_id"
  end

  create_table "locations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "city"
    t.string "state"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_files", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at"
    t.integer "report_id"
    t.integer "workshop_log_id"
  end

  create_table "metadata", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.string "legacy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published", default: false
  end

  create_table "monthly_reports", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "month"
    t.integer "project_id"
    t.integer "project_user_id"
    t.string "name"
    t.string "position"
    t.boolean "mail_evaluations"
    t.string "num_ongoing_participants"
    t.string "num_new_participants"
    t.text "most_effective", limit: 16777215
    t.text "most_challenging", limit: 16777215
    t.text "goals_reached", limit: 16777215
    t.text "goals", limit: 16777215
    t.text "comments", limit: 16777215
    t.boolean "call_requested"
    t.string "best_call_time"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_monthly_reports_on_project_id"
    t.index ["project_user_id"], name: "index_monthly_reports_on_project_user_id"
  end

  create_table "notifications", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "notification_type"
    t.string "noticeable_type"
    t.integer "noticeable_id"
  end

  create_table "permissions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "security_cat"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "legacy_id"
  end

  create_table "project_obligations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "project_statuses", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "project_users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "agency_id"
    t.integer "user_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "project_id"
    t.string "filemaker_code"
    t.index ["agency_id"], name: "index_project_users_on_agency_id"
    t.index ["project_id"], name: "index_project_users_on_project_id"
    t.index ["user_id"], name: "index_project_users_on_user_id"
  end

  create_table "projects", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.integer "location_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "windows_type_id"
    t.string "district"
    t.date "start_date"
    t.date "end_date"
    t.string "locality"
    t.text "description", limit: 16777215
    t.text "notes", limit: 16777215
    t.string "filemaker_code"
    t.boolean "inactive", default: false
    t.integer "legacy_id"
    t.boolean "legacy", default: false
    t.integer "project_status_id"
    t.index ["location_id"], name: "index_projects_on_location_id"
    t.index ["project_status_id"], name: "index_projects_on_project_status_id"
    t.index ["windows_type_id"], name: "index_projects_on_windows_type_id"
  end

  create_table "quotable_item_quotes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "quotable_type"
    t.integer "quotable_id"
    t.integer "legacy_id"
    t.integer "quote_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quote_id"], name: "index_quotable_item_quotes_on_quote_id"
  end

  create_table "quotes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.text "quote", limit: 16777215
    t.boolean "inactive", default: true
    t.integer "legacy_id"
    t.boolean "legacy", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "workshop_id"
    t.string "age"
    t.string "gender", limit: 1
    t.string "speaker_name"
    t.index ["workshop_id"], name: "index_quotes_on_workshop_id"
  end

  create_table "report_form_field_answers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "report_id"
    t.integer "form_field_id"
    t.text "answer", limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "answer_option_id"
    t.index ["answer_option_id"], name: "index_report_form_field_answers_on_answer_option_id"
    t.index ["form_field_id"], name: "index_report_form_field_answers_on_form_field_id"
    t.index ["report_id"], name: "index_report_form_field_answers_on_report_id"
  end

  create_table "reports", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "type"
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "project_id"
    t.date "date"
    t.integer "rating", default: 0
    t.integer "windows_type_id"
    t.string "form_file_file_name"
    t.string "form_file_content_type"
    t.integer "form_file_file_size"
    t.datetime "form_file_updated_at"
    t.integer "workshop_id"
    t.string "workshop_name"
    t.string "other_description"
    t.boolean "has_attachment", default: false
    t.integer "children_first_time", default: 0
    t.integer "children_ongoing", default: 0
    t.integer "teens_first_time", default: 0
    t.integer "teens_ongoing", default: 0
    t.integer "adults_first_time", default: 0
    t.integer "adults_ongoing", default: 0
    t.index ["project_id"], name: "index_reports_on_project_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
    t.index ["windows_type_id"], name: "index_reports_on_windows_type_id"
  end

  create_table "resources", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "title"
    t.string "author"
    t.integer "user_id"
    t.text "text", limit: 16777215
    t.boolean "featured", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind"
    t.integer "workshop_id"
    t.boolean "male", default: false
    t.boolean "female", default: false
    t.string "url"
    t.boolean "inactive", default: true
    t.string "agency"
    t.boolean "legacy"
    t.integer "windows_type_id"
    t.string "filemaker_code"
    t.integer "ordering"
    t.integer "legacy_id"
    t.index ["user_id"], name: "index_resources_on_user_id"
    t.index ["windows_type_id"], name: "index_resources_on_windows_type_id"
    t.index ["workshop_id"], name: "index_resources_on_workshop_id"
  end

  create_table "sectorable_items", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "sectorable_id"
    t.string "sectorable_type"
    t.integer "sector_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "inactive", default: true
    t.index ["sector_id"], name: "index_sectorable_items_on_sector_id"
  end

  create_table "sectors", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published", default: false
  end

  create_table "user_form_form_fields", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "form_field_id"
    t.integer "user_form_id"
    t.text "text", limit: 16777215
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_field_id"], name: "index_user_form_form_fields_on_form_field_id"
    t.index ["user_form_id"], name: "index_user_form_form_fields_on_user_form_id"
  end

  create_table "user_forms", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "user_id"
    t.integer "form_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_id"], name: "index_user_forms_on_form_id"
    t.index ["user_id"], name: "index_user_forms_on_user_id"
  end

  create_table "user_permissions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "user_id"
    t.integer "permission_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: ""
    t.string "last_name", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "agency_id"
    t.string "phone"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.date "birthday"
    t.string "subscribecode"
    t.text "comment", limit: 16777215
    t.text "notes", limit: 16777215
    t.boolean "legacy", default: false
    t.boolean "inactive", default: false
    t.boolean "confirmed", default: true
    t.integer "legacy_id"
    t.string "phone2"
    t.string "phone3"
    t.string "best_time_to_call"
    t.string "address2"
    t.string "city2"
    t.string "state2"
    t.string "zip2"
    t.integer "primary_address"
    t.string "avatar_file_name"
    t.string "avatar_content_type"
    t.integer "avatar_file_size"
    t.datetime "avatar_updated_at"
    t.boolean "super_user", default: false
    t.bigint "facilitator_id"
    t.index ["agency_id"], name: "index_users_on_agency_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["facilitator_id"], name: "index_users_on_facilitator_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "windows_types", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "legacy_id"
    t.string "short_name"
  end

  create_table "workshop_age_ranges", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "workshop_id"
    t.integer "age_range_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["age_range_id"], name: "index_workshop_age_ranges_on_age_range_id"
    t.index ["workshop_id"], name: "index_workshop_age_ranges_on_workshop_id"
  end

  create_table "workshop_logs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "workshop_id"
    t.integer "user_id"
    t.date "date"
    t.integer "rating", default: 0
    t.text "reaction", limit: 16777215
    t.text "successes", limit: 16777215
    t.text "challenges", limit: 16777215
    t.text "suggestions", limit: 16777215
    t.text "questions", limit: 16777215
    t.boolean "lead_similar"
    t.text "similarities", limit: 16777215
    t.text "differences", limit: 16777215
    t.text "comments", limit: 16777215
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "project_id"
    t.boolean "is_embodied_art_workshop", default: false
    t.integer "num_participants_on_going", default: 0
    t.integer "num_participants_first_time", default: 0
    t.index ["project_id"], name: "index_workshop_logs_on_project_id"
    t.index ["user_id"], name: "index_workshop_logs_on_user_id"
    t.index ["workshop_id"], name: "index_workshop_logs_on_workshop_id"
  end

  create_table "workshop_resources", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "workshop_id"
    t.integer "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id"], name: "index_workshop_resources_on_resource_id"
    t.index ["workshop_id"], name: "index_workshop_resources_on_workshop_id"
  end

  create_table "workshop_variations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.integer "workshop_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "code", limit: 16777215
    t.boolean "inactive", default: true
    t.integer "ordering"
    t.string "name"
    t.boolean "legacy", default: false
    t.integer "variation_id"
    t.index ["workshop_id"], name: "index_workshop_variations_on_workshop_id"
  end

  create_table "workshops", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3", force: :cascade do |t|
    t.string "title"
    t.string "full_name"
    t.string "author_location"
    t.integer "month"
    t.integer "year"
    t.text "objective", limit: 16777215
    t.text "materials", limit: 16777215
    t.text "timeframe", limit: 16777215
    t.text "age_range", limit: 16777215
    t.text "setup", limit: 16777215
    t.text "instructions", limit: 16777215
    t.text "warm_up", limit: 16777215
    t.text "creation", limit: 16777215
    t.text "closing", limit: 16777215
    t.text "misc_instructions", limit: 16777215
    t.text "project", limit: 16777215
    t.text "description", limit: 16777215
    t.text "notes", limit: 16777215
    t.text "timestamps", limit: 16777215
    t.text "tips", limit: 16777215
    t.string "pub_issue"
    t.string "misc1"
    t.string "misc2"
    t.boolean "inactive", default: true
    t.boolean "searchable", default: false
    t.boolean "featured", default: false
    t.string "photo_caption"
    t.string "filemaker_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "legacy", default: false
    t.integer "legacy_id"
    t.integer "windows_type_id"
    t.integer "user_id"
    t.integer "led_count", default: 0
    t.text "objective_spanish", limit: 16777215
    t.text "materials_spanish", limit: 16777215
    t.text "timeframe_spanish", limit: 16777215
    t.text "age_range_spanish", limit: 16777215
    t.text "setup_spanish", limit: 16777215
    t.text "instructions_spanish", limit: 16777215
    t.text "project_spanish", limit: 16777215
    t.text "warm_up_spanish", limit: 16777215
    t.text "creation_spanish", limit: 16777215
    t.text "closing_spanish", limit: 16777215
    t.text "misc_instructions_spanish", limit: 16777215
    t.text "description_spanish", limit: 16777215
    t.text "notes_spanish", limit: 16777215
    t.text "tips_spanish", limit: 16777215
    t.string "thumbnail_file_name"
    t.string "thumbnail_content_type"
    t.integer "thumbnail_file_size"
    t.datetime "thumbnail_updated_at"
    t.text "optional_materials", limit: 16777215
    t.text "optional_materials_spanish", limit: 16777215
    t.text "introduction", limit: 16777215
    t.text "introduction_spanish", limit: 16777215
    t.text "demonstration", limit: 16777215
    t.text "demonstration_spanish", limit: 16777215
    t.text "opening_circle", limit: 16777215
    t.text "opening_circle_spanish", limit: 16777215
    t.text "visualization", limit: 16777215
    t.text "visualization_spanish", limit: 16777215
    t.text "misc1_spanish", limit: 16777215
    t.text "misc2_spanish", limit: 16777215
    t.integer "time_intro"
    t.integer "time_demonstration"
    t.integer "time_warm_up"
    t.integer "time_creation"
    t.integer "time_closing"
    t.integer "time_opening"
    t.string "header_file_name"
    t.string "header_content_type"
    t.integer "header_file_size"
    t.datetime "header_updated_at"
    t.text "extra_field"
    t.text "extra_field_spanish"
    t.index ["title", "full_name", "objective", "materials", "introduction", "demonstration", "opening_circle", "warm_up", "creation", "closing", "notes", "tips", "misc1", "misc2"], name: "workshop_fullsearch", type: :fulltext
    t.index ["title"], name: "workshop_fullsearch_title", type: :fulltext
    t.index ["user_id"], name: "index_workshops_on_user_id"
    t.index ["windows_type_id"], name: "index_workshops_on_windows_type_id"
  end

  add_foreign_key "age_ranges", "windows_types"
  add_foreign_key "bookmark_annotations", "bookmarks"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "categories", "metadata"
  add_foreign_key "form_builders", "windows_types"
  add_foreign_key "form_field_answer_options", "answer_options"
  add_foreign_key "form_field_answer_options", "form_fields"
  add_foreign_key "form_fields", "forms"
  add_foreign_key "forms", "form_builders"
  add_foreign_key "monthly_reports", "project_users"
  add_foreign_key "monthly_reports", "projects"
  add_foreign_key "project_users", "projects"
  add_foreign_key "project_users", "projects", column: "agency_id"
  add_foreign_key "project_users", "users"
  add_foreign_key "projects", "locations"
  add_foreign_key "projects", "project_statuses"
  add_foreign_key "projects", "windows_types"
  add_foreign_key "quotable_item_quotes", "quotes"
  add_foreign_key "quotes", "workshops"
  add_foreign_key "report_form_field_answers", "answer_options"
  add_foreign_key "report_form_field_answers", "form_fields"
  add_foreign_key "report_form_field_answers", "reports"
  add_foreign_key "reports", "projects"
  add_foreign_key "reports", "users"
  add_foreign_key "reports", "windows_types"
  add_foreign_key "resources", "users"
  add_foreign_key "resources", "windows_types"
  add_foreign_key "resources", "workshops"
  add_foreign_key "sectorable_items", "sectors"
  add_foreign_key "user_form_form_fields", "form_fields"
  add_foreign_key "user_form_form_fields", "user_forms"
  add_foreign_key "user_forms", "forms"
  add_foreign_key "user_forms", "users"
  add_foreign_key "user_permissions", "permissions"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "users", "facilitators"
  add_foreign_key "users", "projects", column: "agency_id"
  add_foreign_key "workshop_age_ranges", "age_ranges"
  add_foreign_key "workshop_age_ranges", "workshops"
  add_foreign_key "workshop_logs", "projects"
  add_foreign_key "workshop_logs", "users"
  add_foreign_key "workshop_logs", "workshops"
  add_foreign_key "workshop_resources", "resources"
  add_foreign_key "workshop_resources", "workshops"
  add_foreign_key "workshop_variations", "workshops"
  add_foreign_key "workshops", "users"
  add_foreign_key "workshops", "windows_types"
end
