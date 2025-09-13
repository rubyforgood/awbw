# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_09_13_171135) do

  create_table "admins", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "age_ranges", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "windows_type_id"
    t.index ["windows_type_id"], name: "index_age_ranges_on_windows_type_id"
  end

  create_table "answer_options", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.integer "order"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "attachments", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at", precision: nil
  end

  create_table "banners", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "content"
    t.boolean "show"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "bookmark_annotations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "bookmark_id"
    t.text "annotation", size: :medium
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bookmark_id"], name: "index_bookmark_annotations_on_bookmark_id"
  end

  create_table "bookmarks", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "user_id"
    t.string "bookmarkable_type"
    t.integer "bookmarkable_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "categories", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "metadatum_id"
    t.string "name"
    t.integer "legacy_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "published", default: false
    t.index ["metadatum_id"], name: "index_categories_on_metadatum_id"
  end

  create_table "categorizable_items", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "categorizable_id"
    t.string "categorizable_type"
    t.integer "category_id"
    t.integer "legacy_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "inactive", default: true
    t.index ["category_id"], name: "index_categorizable_items_on_category_id"
  end

  create_table "ckeditor_assets", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "data_file_name", null: false
    t.string "data_content_type"
    t.integer "data_file_size"
    t.integer "assetable_id"
    t.string "assetable_type", limit: 30
    t.string "type", limit: 30
    t.integer "width"
    t.integer "height"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "actual_url"
    t.index ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type"
  end

  create_table "event_registrations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.bigint "event_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["event_id"], name: "index_event_registrations_on_event_id"
  end

  create_table "events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "registration_close_date"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "publicly_visible", default: false, null: false
  end

  create_table "facilitators", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "primary_email_address", null: false
    t.string "primary_email_address_type", null: false
    t.string "street_address", null: false
    t.string "city", null: false
    t.string "state", null: false
    t.string "zip", null: false
    t.string "country", null: false
    t.string "mailing_address_type", null: false
    t.string "phone_number", null: false
    t.string "phone_number_type", null: false
  end

  create_table "faqs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "question"
    t.text "answer", size: :medium
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "inactive"
    t.integer "ordering"
  end

  create_table "footers", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "phone"
    t.string "children_program"
    t.string "adult_program"
    t.string "general_questions"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "form_builders", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.integer "owner_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description", size: :medium
    t.integer "windows_type_id"
    t.index ["windows_type_id"], name: "index_form_builders_on_windows_type_id"
  end

  create_table "form_field_answer_options", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "form_field_id"
    t.integer "answer_option_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["answer_option_id"], name: "index_form_field_answer_options_on_answer_option_id"
    t.index ["form_field_id"], name: "index_form_field_answer_options_on_form_field_id"
  end

  create_table "form_fields", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "form_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
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

  create_table "forms", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "owner_type"
    t.integer "owner_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "form_builder_id"
    t.index ["form_builder_id"], name: "index_forms_on_form_builder_id"
  end

  create_table "images", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at", precision: nil
    t.integer "report_id"
    t.index ["owner_id"], name: "index_images_on_owner_id"
  end

  create_table "locations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "city"
    t.string "state"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "media_files", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at", precision: nil
    t.integer "report_id"
    t.integer "workshop_log_id"
  end

  create_table "metadata", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "legacy_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "published", default: false
  end

  create_table "monthly_reports", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "month"
    t.integer "project_id"
    t.integer "project_user_id"
    t.string "name"
    t.string "position"
    t.boolean "mail_evaluations"
    t.string "num_ongoing_participants"
    t.string "num_new_participants"
    t.text "most_effective", size: :medium
    t.text "most_challenging", size: :medium
    t.text "goals_reached", size: :medium
    t.text "goals", size: :medium
    t.text "comments", size: :medium
    t.boolean "call_requested"
    t.string "best_call_time"
    t.string "phone"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id"], name: "index_monthly_reports_on_project_id"
    t.index ["project_user_id"], name: "index_monthly_reports_on_project_user_id"
  end

  create_table "notifications", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "notification_type"
    t.string "noticeable_type"
    t.integer "noticeable_id"
  end

  create_table "permissions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "security_cat"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "legacy_id"
  end

  create_table "project_obligations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "project_statuses", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "project_users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "agency_id"
    t.integer "user_id"
    t.integer "position"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "project_id"
    t.string "filemaker_code"
    t.index ["agency_id"], name: "index_project_users_on_agency_id"
    t.index ["project_id"], name: "index_project_users_on_project_id"
    t.index ["user_id"], name: "index_project_users_on_user_id"
  end

  create_table "projects", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.integer "location_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "windows_type_id"
    t.string "district"
    t.date "start_date"
    t.date "end_date"
    t.string "locality"
    t.text "description", size: :medium
    t.text "notes", size: :medium
    t.string "filemaker_code"
    t.boolean "inactive", default: false
    t.integer "legacy_id"
    t.boolean "legacy", default: false
    t.integer "project_status_id"
    t.index ["location_id"], name: "index_projects_on_location_id"
    t.index ["project_status_id"], name: "index_projects_on_project_status_id"
    t.index ["windows_type_id"], name: "index_projects_on_windows_type_id"
  end

  create_table "quotable_item_quotes", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "quotable_type"
    t.integer "quotable_id"
    t.integer "legacy_id"
    t.integer "quote_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["quote_id"], name: "index_quotable_item_quotes_on_quote_id"
  end

  create_table "quotes", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "quote", size: :medium
    t.boolean "inactive", default: true
    t.integer "legacy_id"
    t.boolean "legacy", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "workshop_id"
    t.string "age"
    t.string "gender", limit: 1
    t.string "speaker_name"
    t.index ["workshop_id"], name: "index_quotes_on_workshop_id"
  end

  create_table "report_form_field_answers", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "report_id"
    t.integer "form_field_id"
    t.text "answer", size: :medium
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "answer_option_id"
    t.index ["answer_option_id"], name: "index_report_form_field_answers_on_answer_option_id"
    t.index ["form_field_id"], name: "index_report_form_field_answers_on_form_field_id"
    t.index ["report_id"], name: "index_report_form_field_answers_on_report_id"
  end

  create_table "reports", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "type"
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.integer "project_id"
    t.date "date"
    t.integer "rating", default: 0
    t.integer "windows_type_id"
    t.string "form_file_file_name"
    t.string "form_file_content_type"
    t.integer "form_file_file_size"
    t.datetime "form_file_updated_at", precision: nil
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

  create_table "resources", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title"
    t.string "author"
    t.integer "user_id"
    t.text "text", size: :medium
    t.boolean "featured", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
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

  create_table "sectorable_items", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "sectorable_id"
    t.string "sectorable_type"
    t.integer "sector_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "inactive", default: true
    t.index ["sector_id"], name: "index_sectorable_items_on_sector_id"
  end

  create_table "sectors", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "published", default: false
  end

  create_table "user_form_form_fields", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "form_field_id"
    t.integer "user_form_id"
    t.text "text", size: :medium
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_field_id"], name: "index_user_form_form_fields_on_form_field_id"
    t.index ["user_form_id"], name: "index_user_form_form_fields_on_user_form_id"
  end

  create_table "user_forms", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "form_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["form_id"], name: "index_user_forms_on_form_id"
    t.index ["user_id"], name: "index_user_forms_on_user_id"
  end

  create_table "user_permissions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "permission_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: ""
    t.string "last_name", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "agency_id"
    t.string "phone"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.date "birthday"
    t.string "subscribecode"
    t.text "comment", size: :medium
    t.text "notes", size: :medium
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
    t.datetime "avatar_updated_at", precision: nil
    t.boolean "super_user", default: false
    t.bigint "facilitator_id"
    t.index ["agency_id"], name: "index_users_on_agency_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["facilitator_id"], name: "index_users_on_facilitator_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "windows_types", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "legacy_id"
    t.string "short_name"
  end

  create_table "workshop_age_ranges", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "workshop_id"
    t.integer "age_range_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["age_range_id"], name: "index_workshop_age_ranges_on_age_range_id"
    t.index ["workshop_id"], name: "index_workshop_age_ranges_on_workshop_id"
  end

  create_table "workshop_logs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "workshop_id"
    t.integer "user_id"
    t.date "date"
    t.integer "rating", default: 0
    t.text "reaction", size: :medium
    t.text "successes", size: :medium
    t.text "challenges", size: :medium
    t.text "suggestions", size: :medium
    t.text "questions", size: :medium
    t.boolean "lead_similar"
    t.text "similarities", size: :medium
    t.text "differences", size: :medium
    t.text "comments", size: :medium
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

  create_table "workshop_resources", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "workshop_id"
    t.integer "resource_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["resource_id"], name: "index_workshop_resources_on_resource_id"
    t.index ["workshop_id"], name: "index_workshop_resources_on_workshop_id"
  end

  create_table "workshop_variations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "workshop_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "code", size: :medium
    t.boolean "inactive", default: true
    t.integer "ordering"
    t.string "name"
    t.boolean "legacy", default: false
    t.integer "variation_id"
    t.index ["workshop_id"], name: "index_workshop_variations_on_workshop_id"
  end

  create_table "workshops", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title"
    t.string "full_name"
    t.string "author_location"
    t.integer "month"
    t.integer "year"
    t.text "objective", size: :medium
    t.text "materials", size: :medium
    t.text "timeframe", size: :medium
    t.text "age_range", size: :medium
    t.text "setup", size: :medium
    t.text "instructions", size: :medium
    t.text "warm_up", size: :medium
    t.text "creation", size: :medium
    t.text "closing", size: :medium
    t.text "misc_instructions", size: :medium
    t.text "project", size: :medium
    t.text "description", size: :medium
    t.text "notes", size: :medium
    t.text "timestamps", size: :medium
    t.text "tips", size: :medium
    t.string "pub_issue"
    t.string "misc1"
    t.string "misc2"
    t.boolean "inactive", default: true
    t.boolean "searchable", default: false
    t.boolean "featured", default: false
    t.string "photo_caption"
    t.string "filemaker_code"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "legacy", default: false
    t.integer "legacy_id"
    t.integer "windows_type_id"
    t.integer "user_id"
    t.integer "led_count", default: 0
    t.text "objective_spanish", size: :medium
    t.text "materials_spanish", size: :medium
    t.text "timeframe_spanish", size: :medium
    t.text "age_range_spanish", size: :medium
    t.text "setup_spanish", size: :medium
    t.text "instructions_spanish", size: :medium
    t.text "project_spanish", size: :medium
    t.text "warm_up_spanish", size: :medium
    t.text "creation_spanish", size: :medium
    t.text "closing_spanish", size: :medium
    t.text "misc_instructions_spanish", size: :medium
    t.text "description_spanish", size: :medium
    t.text "notes_spanish", size: :medium
    t.text "tips_spanish", size: :medium
    t.string "thumbnail_file_name"
    t.string "thumbnail_content_type"
    t.integer "thumbnail_file_size"
    t.datetime "thumbnail_updated_at"
    t.text "optional_materials", size: :medium
    t.text "optional_materials_spanish", size: :medium
    t.text "introduction", size: :medium
    t.text "introduction_spanish", size: :medium
    t.text "demonstration", size: :medium
    t.text "demonstration_spanish", size: :medium
    t.text "opening_circle", size: :medium
    t.text "opening_circle_spanish", size: :medium
    t.text "visualization", size: :medium
    t.text "visualization_spanish", size: :medium
    t.text "misc1_spanish", size: :medium
    t.text "misc2_spanish", size: :medium
    t.integer "time_intro"
    t.integer "time_demonstration"
    t.integer "time_warm_up"
    t.integer "time_creation"
    t.integer "time_closing"
    t.integer "time_opening"
    t.string "header_file_name"
    t.string "header_content_type"
    t.integer "header_file_size"
    t.datetime "header_updated_at", precision: nil
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
  add_foreign_key "event_registrations", "events"
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
