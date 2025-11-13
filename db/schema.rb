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

ActiveRecord::Schema[8.1].define(version: 2025_11_12_141449) do
  create_table "active_storage_attachments", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", charset: "utf8mb3", force: :cascade do |t|
    t.string "city", null: false
    t.string "country"
    t.string "county"
    t.datetime "created_at", null: false
    t.integer "la_city_council_district"
    t.integer "la_service_planning_area"
    t.integer "la_supervisorial_district"
    t.string "locality"
    t.integer "organization_id", null: false
    t.string "state", null: false
    t.string "street", null: false
    t.datetime "updated_at", null: false
    t.string "zip", null: false
    t.index ["organization_id"], name: "index_addresses_on_organization_id"
  end

  create_table "admins", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", precision: nil
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "age_ranges", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "windows_type_id"
    t.index ["windows_type_id"], name: "index_age_ranges_on_windows_type_id"
  end

  create_table "answer_options", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.integer "order"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "attachments", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "file_content_type"
    t.string "file_file_name"
    t.integer "file_file_size"
    t.datetime "file_updated_at", precision: nil
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "banners", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", precision: nil, null: false
    t.integer "created_by_id"
    t.boolean "show"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "updated_by_id"
    t.index ["created_by_id"], name: "index_banners_on_created_by_id"
    t.index ["updated_by_id"], name: "index_banners_on_updated_by_id"
  end

  create_table "bookmark_annotations", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "annotation", size: :medium
    t.integer "bookmark_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["bookmark_id"], name: "index_bookmark_annotations_on_bookmark_id"
  end

  create_table "bookmarks", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "bookmarkable_id"
    t.string "bookmarkable_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "categories", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "legacy_id"
    t.integer "metadatum_id"
    t.string "name"
    t.boolean "published", default: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["metadatum_id"], name: "index_categories_on_metadatum_id"
  end

  create_table "categorizable_items", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "categorizable_id"
    t.string "categorizable_type"
    t.integer "category_id"
    t.datetime "created_at", precision: nil, null: false
    t.boolean "inactive", default: true
    t.integer "legacy_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["categorizable_type", "categorizable_id"], name: "idx_on_categorizable_type_categorizable_id_ccce65d80c"
    t.index ["category_id"], name: "index_categorizable_items_on_category_id"
  end

  create_table "ckeditor_assets", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "actual_url"
    t.integer "assetable_id"
    t.string "assetable_type", limit: 30
    t.datetime "created_at", precision: nil, null: false
    t.string "data_content_type"
    t.string "data_file_name", null: false
    t.integer "data_file_size"
    t.integer "height"
    t.string "type", limit: 30
    t.datetime "updated_at", precision: nil, null: false
    t.integer "width"
    t.index ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type"
  end

  create_table "community_news", charset: "utf8mb3", force: :cascade do |t|
    t.integer "author_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.boolean "featured"
    t.integer "project_id"
    t.boolean "published"
    t.string "reference_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "updated_by_id", null: false
    t.integer "windows_type_id"
    t.string "youtube_url"
    t.index ["author_id"], name: "index_community_news_on_author_id"
    t.index ["created_by_id"], name: "index_community_news_on_created_by_id"
    t.index ["project_id"], name: "index_community_news_on_project_id"
    t.index ["updated_by_id"], name: "index_community_news_on_updated_by_id"
    t.index ["windows_type_id"], name: "index_community_news_on_windows_type_id"
  end

  create_table "event_registrations", charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "event_id"
    t.string "first_name"
    t.string "last_name"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_registrations_on_event_id"
  end

  create_table "events", charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.text "description"
    t.datetime "end_date", precision: nil
    t.boolean "publicly_visible", default: false, null: false
    t.datetime "registration_close_date", precision: nil
    t.datetime "start_date", precision: nil
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_events_on_created_by_id"
  end

  create_table "facilitator_organizations", charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "facilitator_id", null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["facilitator_id", "organization_id"], name: "index_facilitator_organizations_on_ids", unique: true
    t.index ["facilitator_id"], name: "index_facilitator_organizations_on_facilitator_id"
    t.index ["organization_id"], name: "index_facilitator_organizations_on_organization_id"
  end

  create_table "facilitators", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "bio"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.string "display_name_preference"
    t.string "facebook_url"
    t.string "first_name", null: false
    t.string "instagram_url"
    t.string "last_name", null: false
    t.string "linked_in_url"
    t.string "mailing_address_type"
    t.date "member_since"
    t.string "phone_number"
    t.string "phone_number_type"
    t.string "primary_email_address"
    t.string "primary_email_address_type"
    t.boolean "profile_is_searchable", default: true, null: false
    t.boolean "profile_show_bio", default: true, null: false
    t.boolean "profile_show_email", default: true, null: false
    t.boolean "profile_show_events_registered", default: true, null: false
    t.boolean "profile_show_member_since", default: true, null: false
    t.boolean "profile_show_organizations", default: true, null: false
    t.boolean "profile_show_phone", default: true, null: false
    t.boolean "profile_show_pronouns", default: true, null: false
    t.boolean "profile_show_sectors", default: true, null: false
    t.boolean "profile_show_social_media", default: true, null: false
    t.boolean "profile_show_stories", default: true, null: false
    t.boolean "profile_show_story_ideas", default: true, null: false
    t.boolean "profile_show_workshop_ideas", default: true, null: false
    t.boolean "profile_show_workshop_logs", default: true, null: false
    t.boolean "profile_show_workshop_variations", default: true, null: false
    t.boolean "profile_show_workshops", default: true, null: false
    t.string "pronouns"
    t.string "state"
    t.string "street_address"
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.integer "updated_by_id"
    t.string "youtube_url"
    t.string "zip"
    t.index ["created_by_id"], name: "index_facilitators_on_created_by_id"
    t.index ["updated_by_id"], name: "index_facilitators_on_updated_by_id"
  end

  create_table "faqs", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "answer", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.boolean "inactive"
    t.integer "ordering"
    t.string "question"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "footers", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "adult_program"
    t.string "children_program"
    t.datetime "created_at", precision: nil, null: false
    t.string "general_questions"
    t.string "phone"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "form_builders", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description", size: :medium
    t.string "name"
    t.integer "owner_type"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "windows_type_id"
    t.index ["windows_type_id"], name: "index_form_builders_on_windows_type_id"
  end

  create_table "form_field_answer_options", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "answer_option_id"
    t.datetime "created_at", precision: nil, null: false
    t.integer "form_field_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["answer_option_id"], name: "index_form_field_answer_options_on_answer_option_id"
    t.index ["form_field_id"], name: "index_form_field_answer_options_on_form_field_id"
  end

  create_table "form_fields", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "answer_datatype"
    t.integer "answer_type"
    t.datetime "created_at", precision: nil, null: false
    t.integer "form_id"
    t.string "instructional_hint"
    t.boolean "is_required", default: true
    t.integer "ordering"
    t.integer "parent_id"
    t.string "question"
    t.integer "status", default: 1
    t.datetime "updated_at", precision: nil, null: false
    t.index ["form_id"], name: "index_form_fields_on_form_id"
  end

  create_table "forms", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "form_builder_id"
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["form_builder_id"], name: "index_forms_on_form_builder_id"
  end

  create_table "images", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "file_content_type"
    t.string "file_file_name"
    t.integer "file_file_size"
    t.datetime "file_updated_at", precision: nil
    t.integer "owner_id"
    t.string "owner_type"
    t.integer "report_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["owner_id"], name: "index_images_on_owner_id"
  end

  create_table "locations", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "city"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.string "state"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "media_files", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "file_content_type"
    t.string "file_file_name"
    t.integer "file_file_size"
    t.datetime "file_updated_at", precision: nil
    t.integer "report_id"
    t.integer "workshop_log_id"
  end

  create_table "metadata", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "legacy_id"
    t.string "name"
    t.boolean "published", default: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "monthly_reports", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "best_call_time"
    t.boolean "call_requested"
    t.text "comments", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.text "goals", size: :medium
    t.text "goals_reached", size: :medium
    t.boolean "mail_evaluations"
    t.string "month"
    t.text "most_challenging", size: :medium
    t.text "most_effective", size: :medium
    t.string "name"
    t.string "num_new_participants"
    t.string "num_ongoing_participants"
    t.string "phone"
    t.string "position"
    t.integer "project_id"
    t.integer "project_user_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id"], name: "index_monthly_reports_on_project_id"
    t.index ["project_user_id"], name: "index_monthly_reports_on_project_user_id"
  end

  create_table "notifications", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "noticeable_id"
    t.string "noticeable_type"
    t.integer "notification_type"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "organization_workshops", charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.integer "workshop_id", null: false
    t.index ["organization_id", "workshop_id"], name: "index_organization_workshops_on_ids", unique: true
    t.index ["organization_id"], name: "index_organization_workshops_on_organization_id"
    t.index ["workshop_id"], name: "index_organization_workshops_on_workshop_id"
  end

  create_table "organizations", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "agency_type", null: false
    t.string "agency_type_other"
    t.date "close_date"
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true
    t.text "mission"
    t.string "name", null: false
    t.string "phone", null: false
    t.string "project_id"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.string "website_url"
  end

  create_table "permissions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "legacy_id"
    t.string "security_cat"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "project_obligations", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "project_statuses", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "project_users", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "agency_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "filemaker_code"
    t.boolean "inactive", default: false, null: false
    t.integer "position"
    t.integer "project_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["agency_id"], name: "index_project_users_on_agency_id"
    t.index ["project_id"], name: "index_project_users_on_project_id"
    t.index ["user_id"], name: "index_project_users_on_user_id"
  end

  create_table "projects", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description", size: :medium
    t.string "district"
    t.date "end_date"
    t.string "filemaker_code"
    t.boolean "inactive", default: false
    t.boolean "legacy", default: false
    t.integer "legacy_id"
    t.string "locality"
    t.integer "location_id"
    t.string "name"
    t.text "notes", size: :medium
    t.integer "project_status_id"
    t.date "start_date"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "windows_type_id"
    t.index ["location_id"], name: "index_projects_on_location_id"
    t.index ["project_status_id"], name: "index_projects_on_project_status_id"
    t.index ["windows_type_id"], name: "index_projects_on_windows_type_id"
  end

  create_table "quotable_item_quotes", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "legacy_id"
    t.integer "quotable_id"
    t.string "quotable_type"
    t.integer "quote_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["quote_id"], name: "index_quotable_item_quotes_on_quote_id"
  end

  create_table "quotes", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "age"
    t.datetime "created_at", precision: nil, null: false
    t.string "gender", limit: 1
    t.boolean "inactive", default: true
    t.boolean "legacy", default: false
    t.integer "legacy_id"
    t.text "quote", size: :medium
    t.string "speaker_name"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "workshop_id"
    t.index ["workshop_id"], name: "index_quotes_on_workshop_id"
  end

  create_table "report_form_field_answers", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "answer", size: :medium
    t.integer "answer_option_id"
    t.datetime "created_at", precision: nil
    t.integer "form_field_id"
    t.integer "report_id"
    t.datetime "updated_at", precision: nil
    t.index ["answer_option_id"], name: "index_report_form_field_answers_on_answer_option_id"
    t.index ["form_field_id"], name: "index_report_form_field_answers_on_form_field_id"
    t.index ["report_id"], name: "index_report_form_field_answers_on_report_id"
  end

  create_table "reports", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "adults_first_time", default: 0
    t.integer "adults_ongoing", default: 0
    t.integer "children_first_time", default: 0
    t.integer "children_ongoing", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.date "date"
    t.string "form_file_content_type"
    t.string "form_file_file_name"
    t.integer "form_file_file_size"
    t.datetime "form_file_updated_at", precision: nil
    t.boolean "has_attachment", default: false
    t.string "other_description"
    t.integer "owner_id"
    t.string "owner_type"
    t.integer "project_id"
    t.integer "rating", default: 0
    t.integer "teens_first_time", default: 0
    t.integer "teens_ongoing", default: 0
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.integer "windows_type_id"
    t.integer "workshop_id"
    t.string "workshop_name"
    t.index ["project_id"], name: "index_reports_on_project_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
    t.index ["windows_type_id"], name: "index_reports_on_windows_type_id"
  end

  create_table "resources", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "agency"
    t.string "author"
    t.datetime "created_at", precision: nil, null: false
    t.boolean "featured", default: false
    t.boolean "female", default: false
    t.string "filemaker_code"
    t.boolean "inactive", default: true
    t.string "kind"
    t.boolean "legacy"
    t.integer "legacy_id"
    t.boolean "male", default: false
    t.integer "ordering"
    t.text "text", size: :medium
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.integer "user_id"
    t.integer "windows_type_id"
    t.integer "workshop_id"
    t.index ["user_id"], name: "index_resources_on_user_id"
    t.index ["windows_type_id"], name: "index_resources_on_windows_type_id"
    t.index ["workshop_id"], name: "index_resources_on_workshop_id"
  end

  create_table "sectorable_items", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.boolean "inactive", default: true
    t.boolean "is_leader", default: false, null: false
    t.integer "sector_id"
    t.integer "sectorable_id"
    t.string "sectorable_type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["sector_id"], name: "index_sectorable_items_on_sector_id"
    t.index ["sectorable_type", "sectorable_id"], name: "index_sectorable_items_on_sectorable_type_and_sectorable_id"
  end

  create_table "sectors", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.boolean "published", default: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "stories", charset: "utf8mb3", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.boolean "permission_given"
    t.integer "project_id", null: false
    t.boolean "published", default: false, null: false
    t.integer "spotlighted_facilitator_id"
    t.bigint "story_idea_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "updated_by_id", null: false
    t.integer "windows_type_id", null: false
    t.integer "workshop_id", null: false
    t.string "youtube_url"
    t.index ["created_by_id"], name: "index_stories_on_created_by_id"
    t.index ["project_id"], name: "index_stories_on_project_id"
    t.index ["published"], name: "index_stories_on_published"
    t.index ["spotlighted_facilitator_id"], name: "index_stories_on_spotlighted_facilitator_id"
    t.index ["story_idea_id"], name: "index_stories_on_story_idea_id"
    t.index ["updated_by_id"], name: "index_stories_on_updated_by_id"
    t.index ["windows_type_id"], name: "index_stories_on_windows_type_id"
    t.index ["workshop_id"], name: "index_stories_on_workshop_id"
  end

  create_table "story_ideas", charset: "utf8mb3", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.boolean "permission_given"
    t.integer "project_id", null: false
    t.string "publish_preferences"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "updated_by_id", null: false
    t.integer "windows_type_id", null: false
    t.integer "workshop_id", null: false
    t.string "youtube_url"
    t.index ["created_by_id"], name: "index_story_ideas_on_created_by_id"
    t.index ["project_id"], name: "index_story_ideas_on_project_id"
    t.index ["updated_by_id"], name: "index_story_ideas_on_updated_by_id"
    t.index ["windows_type_id"], name: "index_story_ideas_on_windows_type_id"
    t.index ["workshop_id"], name: "index_story_ideas_on_workshop_id"
  end

  create_table "user_form_form_fields", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "form_field_id"
    t.text "text", size: :medium
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_form_id"
    t.index ["form_field_id"], name: "index_user_form_form_fields_on_form_field_id"
    t.index ["user_form_id"], name: "index_user_form_form_fields_on_user_form_id"
  end

  create_table "user_forms", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "form_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["form_id"], name: "index_user_forms_on_form_id"
    t.index ["user_id"], name: "index_user_forms_on_user_id"
  end

  create_table "user_permissions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "permission_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "users", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "address"
    t.string "address2"
    t.integer "agency_id"
    t.string "avatar_content_type"
    t.string "avatar_file_name"
    t.integer "avatar_file_size"
    t.datetime "avatar_updated_at", precision: nil
    t.string "best_time_to_call"
    t.date "birthday"
    t.string "city"
    t.string "city2"
    t.text "comment", size: :medium
    t.boolean "confirmed", default: true
    t.datetime "created_at", precision: nil
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "facilitator_id"
    t.string "first_name", default: ""
    t.boolean "inactive", default: false
    t.string "last_name", default: ""
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.boolean "legacy", default: false
    t.integer "legacy_id"
    t.text "notes", size: :medium
    t.string "phone"
    t.string "phone2"
    t.string "phone3"
    t.integer "primary_address"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "state"
    t.string "state2"
    t.string "subscribecode"
    t.boolean "super_user", default: false
    t.datetime "updated_at", precision: nil
    t.string "zip"
    t.string "zip2"
    t.index ["agency_id"], name: "index_users_on_agency_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["facilitator_id"], name: "index_users_on_facilitator_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "windows_types", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "legacy_id"
    t.string "name"
    t.string "short_name"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "workshop_age_ranges", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "age_range_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "workshop_id"
    t.index ["age_range_id"], name: "index_workshop_age_ranges_on_age_range_id"
    t.index ["workshop_id"], name: "index_workshop_age_ranges_on_workshop_id"
  end

  create_table "workshop_ideas", charset: "utf8mb3", force: :cascade do |t|
    t.text "age_range"
    t.text "age_range_spanish"
    t.text "closing"
    t.text "closing_spanish"
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.text "creation"
    t.text "creation_spanish"
    t.text "demonstration"
    t.text "demonstration_spanish"
    t.text "description"
    t.text "description_spanish"
    t.text "instructions"
    t.text "instructions_spanish"
    t.text "introduction"
    t.text "introduction_spanish"
    t.text "materials"
    t.text "materials_spanish"
    t.text "misc_instructions_spanish"
    t.text "notes"
    t.text "notes_spanish"
    t.text "objective"
    t.text "objective_spanish"
    t.text "opening_circle"
    t.text "opening_circle_spanish"
    t.text "optional_materials"
    t.text "optional_materials_spanish"
    t.text "setup"
    t.text "setup_spanish"
    t.text "staff_notes"
    t.integer "time_closing"
    t.integer "time_creation"
    t.integer "time_demonstration"
    t.integer "time_hours"
    t.integer "time_intro"
    t.integer "time_minutes"
    t.integer "time_opening"
    t.integer "time_opening_circle"
    t.integer "time_warm_up"
    t.text "timeframe"
    t.text "timeframe_spanish"
    t.text "tips"
    t.text "tips_spanish"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "updated_by_id", null: false
    t.text "visualization"
    t.text "visualization_spanish"
    t.text "warm_up"
    t.text "warm_up_spanish"
    t.integer "windows_type_id", null: false
    t.index ["created_by_id"], name: "index_workshop_ideas_on_created_by_id"
    t.index ["updated_by_id"], name: "index_workshop_ideas_on_updated_by_id"
    t.index ["windows_type_id"], name: "index_workshop_ideas_on_windows_type_id"
  end

  create_table "workshop_logs", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "challenges", size: :medium
    t.text "comments", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.date "date"
    t.text "differences", size: :medium
    t.boolean "is_embodied_art_workshop", default: false
    t.boolean "lead_similar"
    t.integer "num_participants_first_time", default: 0
    t.integer "num_participants_on_going", default: 0
    t.integer "project_id"
    t.text "questions", size: :medium
    t.integer "rating", default: 0
    t.text "reaction", size: :medium
    t.text "similarities", size: :medium
    t.text "successes", size: :medium
    t.text "suggestions", size: :medium
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.integer "workshop_id"
    t.index ["project_id"], name: "index_workshop_logs_on_project_id"
    t.index ["user_id"], name: "index_workshop_logs_on_user_id"
    t.index ["workshop_id"], name: "index_workshop_logs_on_workshop_id"
  end

  create_table "workshop_resources", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "resource_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "workshop_id"
    t.index ["resource_id"], name: "index_workshop_resources_on_resource_id"
    t.index ["workshop_id"], name: "index_workshop_resources_on_workshop_id"
  end

  create_table "workshop_series_memberships", charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "series_description"
    t.string "series_description_spanish"
    t.integer "series_order", default: 1, null: false
    t.string "theme_name"
    t.datetime "updated_at", null: false
    t.integer "workshop_child_id", null: false
    t.integer "workshop_parent_id", null: false
    t.index ["workshop_child_id"], name: "fk_rails_c3357d1053"
    t.index ["workshop_parent_id", "workshop_child_id"], name: "index_workshop_series_memberships_on_parent_and_child", unique: true
  end

  create_table "workshop_variations", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "code", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.integer "created_by_id"
    t.boolean "inactive", default: true
    t.boolean "legacy", default: false
    t.string "name"
    t.integer "ordering"
    t.string "reference_url"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "variation_id"
    t.integer "workshop_id"
    t.index ["created_by_id"], name: "index_workshop_variations_on_created_by_id"
    t.index ["workshop_id"], name: "index_workshop_variations_on_workshop_id"
  end

  create_table "workshops", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "age_range", size: :medium
    t.text "age_range_spanish", size: :medium
    t.string "author_location"
    t.text "closing", size: :medium
    t.text "closing_spanish", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.text "creation", size: :medium
    t.text "creation_spanish", size: :medium
    t.text "demonstration", size: :medium
    t.text "demonstration_spanish", size: :medium
    t.text "description", size: :medium
    t.text "description_spanish", size: :medium
    t.text "extra_field"
    t.text "extra_field_spanish"
    t.boolean "featured", default: false
    t.string "filemaker_code"
    t.string "full_name"
    t.string "header_content_type"
    t.string "header_file_name"
    t.integer "header_file_size"
    t.datetime "header_updated_at", precision: nil
    t.boolean "inactive", default: true
    t.text "instructions", size: :medium
    t.text "instructions_spanish", size: :medium
    t.text "introduction", size: :medium
    t.text "introduction_spanish", size: :medium
    t.integer "led_count", default: 0
    t.boolean "legacy", default: false
    t.integer "legacy_id"
    t.text "materials", size: :medium
    t.text "materials_spanish", size: :medium
    t.string "misc1"
    t.text "misc1_spanish", size: :medium
    t.string "misc2"
    t.text "misc2_spanish", size: :medium
    t.text "misc_instructions", size: :medium
    t.text "misc_instructions_spanish", size: :medium
    t.integer "month"
    t.text "notes", size: :medium
    t.text "notes_spanish", size: :medium
    t.text "objective", size: :medium
    t.text "objective_spanish", size: :medium
    t.text "opening_circle", size: :medium
    t.text "opening_circle_spanish", size: :medium
    t.text "optional_materials", size: :medium
    t.text "optional_materials_spanish", size: :medium
    t.string "photo_caption"
    t.text "project", size: :medium
    t.text "project_spanish", size: :medium
    t.string "pub_issue"
    t.boolean "searchable", default: false
    t.text "setup", size: :medium
    t.text "setup_spanish", size: :medium
    t.string "thumbnail_content_type"
    t.string "thumbnail_file_name"
    t.integer "thumbnail_file_size"
    t.datetime "thumbnail_updated_at", precision: nil
    t.integer "time_closing"
    t.integer "time_creation"
    t.integer "time_demonstration"
    t.integer "time_intro"
    t.integer "time_opening"
    t.integer "time_opening_circle"
    t.integer "time_warm_up"
    t.text "timeframe", size: :medium
    t.text "timeframe_spanish", size: :medium
    t.text "timestamps", size: :medium
    t.text "tips", size: :medium
    t.text "tips_spanish", size: :medium
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.text "visualization", size: :medium
    t.text "visualization_spanish", size: :medium
    t.text "warm_up", size: :medium
    t.text "warm_up_spanish", size: :medium
    t.integer "windows_type_id"
    t.bigint "workshop_idea_id"
    t.integer "year"
    t.index ["created_at"], name: "index_workshops_on_created_at"
    t.index ["inactive", "led_count", "title"], name: "index_workshops_on_inactive_and_led_count_and_title"
    t.index ["led_count"], name: "index_workshops_on_led_count"
    t.index ["title", "full_name", "objective", "materials", "introduction", "demonstration", "opening_circle", "warm_up", "creation", "closing", "notes", "tips", "misc1", "misc2"], name: "workshop_fullsearch", type: :fulltext
    t.index ["title"], name: "index_workshops_on_title", type: :fulltext
    t.index ["title"], name: "workshop_fullsearch_title", type: :fulltext
    t.index ["user_id"], name: "index_workshops_on_user_id"
    t.index ["windows_type_id"], name: "index_workshops_on_windows_type_id"
    t.index ["workshop_idea_id"], name: "index_workshops_on_workshop_idea_id"
    t.index ["year", "month"], name: "index_workshops_on_year_and_month"
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "organizations"
  add_foreign_key "age_ranges", "windows_types"
  add_foreign_key "banners", "users", column: "created_by_id"
  add_foreign_key "banners", "users", column: "updated_by_id"
  add_foreign_key "bookmark_annotations", "bookmarks"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "categories", "metadata"
  add_foreign_key "community_news", "projects"
  add_foreign_key "community_news", "users", column: "author_id"
  add_foreign_key "community_news", "users", column: "created_by_id"
  add_foreign_key "community_news", "users", column: "updated_by_id"
  add_foreign_key "community_news", "windows_types"
  add_foreign_key "event_registrations", "events"
  add_foreign_key "events", "users", column: "created_by_id"
  add_foreign_key "facilitator_organizations", "facilitators"
  add_foreign_key "facilitator_organizations", "organizations"
  add_foreign_key "facilitators", "users", column: "created_by_id"
  add_foreign_key "facilitators", "users", column: "updated_by_id"
  add_foreign_key "form_builders", "windows_types"
  add_foreign_key "form_field_answer_options", "answer_options"
  add_foreign_key "form_field_answer_options", "form_fields"
  add_foreign_key "form_fields", "forms"
  add_foreign_key "forms", "form_builders"
  add_foreign_key "monthly_reports", "project_users"
  add_foreign_key "monthly_reports", "projects"
  add_foreign_key "organization_workshops", "organizations"
  add_foreign_key "organization_workshops", "workshops"
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
  add_foreign_key "stories", "facilitators", column: "spotlighted_facilitator_id"
  add_foreign_key "stories", "projects"
  add_foreign_key "stories", "story_ideas"
  add_foreign_key "stories", "users", column: "created_by_id"
  add_foreign_key "stories", "users", column: "updated_by_id"
  add_foreign_key "stories", "windows_types"
  add_foreign_key "stories", "workshops"
  add_foreign_key "story_ideas", "projects"
  add_foreign_key "story_ideas", "users", column: "created_by_id"
  add_foreign_key "story_ideas", "users", column: "updated_by_id"
  add_foreign_key "story_ideas", "windows_types"
  add_foreign_key "story_ideas", "workshops"
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
  add_foreign_key "workshop_ideas", "users", column: "created_by_id"
  add_foreign_key "workshop_ideas", "users", column: "updated_by_id"
  add_foreign_key "workshop_ideas", "windows_types"
  add_foreign_key "workshop_logs", "projects"
  add_foreign_key "workshop_logs", "users"
  add_foreign_key "workshop_logs", "workshops"
  add_foreign_key "workshop_resources", "resources"
  add_foreign_key "workshop_resources", "workshops"
  add_foreign_key "workshop_series_memberships", "workshops", column: "workshop_child_id"
  add_foreign_key "workshop_series_memberships", "workshops", column: "workshop_parent_id"
  add_foreign_key "workshop_variations", "users", column: "created_by_id"
  add_foreign_key "workshop_variations", "workshops"
  add_foreign_key "workshops", "users"
  add_foreign_key "workshops", "windows_types"
  add_foreign_key "workshops", "workshop_ideas"
end
