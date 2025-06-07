class CreateDatabase < ActiveRecord::Migration[4.2]
  # sure we could just run raw sql, but at this point I am not even 100% sure 
  # what DB we will be using in a two weeks.
  class SchemaMigration < ActiveRecord::Base
  end

  def up
    # 20210823001213 is the version of the last archived migration. If that 
    # migration is present then we can assume the schema is already up to date 
    # and we don't need to run anything.
    #
    # If some migrations are missing, then running this migration is going to
    # ruin your day because it likely already includes DB objects that are 
    # already present in your target DB.
    #
    # This really only works well if you are working with a fresh DB or the
    # DB is completely up to date.
    if SchemaMigration.find_by(version: '20210823001213').present?
      say "SchemaMigration 20210823001213 already present, skipping InitSchema"

      return
    end

    create_table "admins", force: :cascade do |t|
      t.string   "email",                  limit: 255, default: "", null: false
      t.string   "encrypted_password",     limit: 255, default: "", null: false
      t.string   "first_name",             limit: 255, default: "", null: false
      t.string   "last_name",              limit: 255, default: "", null: false
      t.string   "reset_password_token",   limit: 255
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.integer  "sign_in_count",          limit: 4,   default: 0,  null: false
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.string   "current_sign_in_ip",     limit: 255
      t.string   "last_sign_in_ip",        limit: 255
      t.datetime "created_at"
      t.datetime "updated_at"
    end
  
    add_index "admins", ["email"], name: "index_admins_on_email", unique: true, using: :btree
    add_index "admins", ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true, using: :btree
  
    create_table "age_ranges", force: :cascade do |t|
      t.string   "name",            limit: 255
      t.datetime "created_at",                  null: false
      t.datetime "updated_at",                  null: false
      t.integer  "windows_type_id", limit: 4
    end
  
    add_index "age_ranges", ["windows_type_id"], name: "index_age_ranges_on_windows_type_id", using: :btree
  
    create_table "answer_options", force: :cascade do |t|
      t.string   "name",       limit: 255
      t.integer  "order",      limit: 4
      t.datetime "created_at",             null: false
      t.datetime "updated_at",             null: false
    end
  
    create_table "attachments", force: :cascade do |t|
      t.integer  "owner_id",          limit: 4
      t.string   "owner_type",        limit: 255
      t.datetime "created_at",                    null: false
      t.datetime "updated_at",                    null: false
      t.string   "file_file_name",    limit: 255
      t.string   "file_content_type", limit: 255
      t.integer  "file_file_size",    limit: 4
      t.datetime "file_updated_at"
    end
  
    create_table "banners", force: :cascade do |t|
      t.text     "content",    limit: 65535
      t.boolean  "show"
      t.datetime "created_at",               null: false
      t.datetime "updated_at",               null: false
    end
  
    create_table "bookmark_annotations", force: :cascade do |t|
      t.integer  "bookmark_id", limit: 4
      t.text     "annotation",  limit: 16777215
      t.datetime "created_at",                   null: false
      t.datetime "updated_at",                   null: false
    end
  
    add_index "bookmark_annotations", ["bookmark_id"], name: "index_bookmark_annotations_on_bookmark_id", using: :btree
  
    create_table "bookmarks", force: :cascade do |t|
      t.integer  "user_id",           limit: 4
      t.string   "bookmarkable_type", limit: 255
      t.integer  "bookmarkable_id",   limit: 4
      t.datetime "created_at",                    null: false
      t.datetime "updated_at",                    null: false
    end
  
    add_index "bookmarks", ["user_id"], name: "index_bookmarks_on_user_id", using: :btree
  
    create_table "categories", force: :cascade do |t|
      t.integer  "metadatum_id", limit: 4
      t.string   "name",         limit: 255
      t.integer  "legacy_id",    limit: 4
      t.datetime "created_at",                               null: false
      t.datetime "updated_at",                               null: false
      t.boolean  "published",                default: false
    end
  
    add_index "categories", ["metadatum_id"], name: "index_categories_on_metadatum_id", using: :btree
  
    create_table "categorizable_items", force: :cascade do |t|
      t.integer  "categorizable_id",   limit: 4
      t.string   "categorizable_type", limit: 255
      t.integer  "category_id",        limit: 4
      t.integer  "legacy_id",          limit: 4
      t.datetime "created_at",                                    null: false
      t.datetime "updated_at",                                    null: false
      t.boolean  "inactive",                       default: true
    end
  
    add_index "categorizable_items", ["category_id"], name: "index_categorizable_items_on_category_id", using: :btree
  
    create_table "ckeditor_assets", force: :cascade do |t|
      t.string   "data_file_name",    limit: 255, null: false
      t.string   "data_content_type", limit: 255
      t.integer  "data_file_size",    limit: 4
      t.integer  "assetable_id",      limit: 4
      t.string   "assetable_type",    limit: 30
      t.string   "type",              limit: 30
      t.integer  "width",             limit: 4
      t.integer  "height",            limit: 4
      t.datetime "created_at",                    null: false
      t.datetime "updated_at",                    null: false
      t.string   "actual_url",        limit: 255
    end
  
    add_index "ckeditor_assets", ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable", using: :btree
    add_index "ckeditor_assets", ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type", using: :btree
  
    create_table "faqs", force: :cascade do |t|
      t.string   "question",   limit: 255
      t.text     "answer",     limit: 16777215
      t.datetime "created_at",                  null: false
      t.datetime "updated_at",                  null: false
      t.boolean  "inactive"
      t.integer  "ordering",   limit: 4
    end
  
    create_table "footers", force: :cascade do |t|
      t.string   "phone",             limit: 255
      t.string   "children_program",  limit: 255
      t.string   "adult_program",     limit: 255
      t.string   "general_questions", limit: 255
      t.datetime "created_at",                    null: false
      t.datetime "updated_at",                    null: false
    end
  
    create_table "form_builders", force: :cascade do |t|
      t.string   "name",            limit: 255
      t.integer  "owner_type",      limit: 4
      t.datetime "created_at",                       null: false
      t.datetime "updated_at",                       null: false
      t.text     "description",     limit: 16777215
      t.integer  "windows_type_id", limit: 4
    end
  
    add_index "form_builders", ["windows_type_id"], name: "index_form_builders_on_windows_type_id", using: :btree
  
    create_table "form_field_answer_options", force: :cascade do |t|
      t.integer  "form_field_id",    limit: 4
      t.integer  "answer_option_id", limit: 4
      t.datetime "created_at",                 null: false
      t.datetime "updated_at",                 null: false
    end
  
    add_index "form_field_answer_options", ["answer_option_id"], name: "index_form_field_answer_options_on_answer_option_id", using: :btree
    add_index "form_field_answer_options", ["form_field_id"], name: "index_form_field_answer_options_on_form_field_id", using: :btree
  
    create_table "form_fields", force: :cascade do |t|
      t.integer  "form_id",            limit: 4
      t.datetime "created_at",                                    null: false
      t.datetime "updated_at",                                    null: false
      t.string   "question",           limit: 255
      t.string   "instructional_hint", limit: 255
      t.integer  "answer_type",        limit: 4
      t.integer  "answer_datatype",    limit: 4
      t.integer  "ordering",           limit: 4
      t.boolean  "is_required",                    default: true
      t.integer  "status",             limit: 4,   default: 1
      t.integer  "parent_id",          limit: 4
    end
  
    add_index "form_fields", ["form_id"], name: "index_form_fields_on_form_id", using: :btree
  
    create_table "forms", force: :cascade do |t|
      t.string   "owner_type",      limit: 255
      t.integer  "owner_id",        limit: 4
      t.datetime "created_at",                  null: false
      t.datetime "updated_at",                  null: false
      t.integer  "form_builder_id", limit: 4
    end
  
    add_index "forms", ["form_builder_id"], name: "index_forms_on_form_builder_id", using: :btree
  
    create_table "images", force: :cascade do |t|
      t.integer  "owner_id",          limit: 4
      t.string   "owner_type",        limit: 255
      t.datetime "created_at",                    null: false
      t.datetime "updated_at",                    null: false
      t.string   "file_file_name",    limit: 255
      t.string   "file_content_type", limit: 255
      t.integer  "file_file_size",    limit: 4
      t.datetime "file_updated_at"
      t.integer  "report_id",         limit: 4
    end
  
    add_index "images", ["owner_id"], name: "index_images_on_owner_id", using: :btree
  
    create_table "locations", force: :cascade do |t|
      t.string   "city",       limit: 255
      t.string   "state",      limit: 255
      t.string   "country",    limit: 255
      t.datetime "created_at",             null: false
      t.datetime "updated_at",             null: false
    end
  
    create_table "media_files", force: :cascade do |t|
      t.string   "file_file_name",    limit: 255
      t.string   "file_content_type", limit: 255
      t.integer  "file_file_size",    limit: 4
      t.datetime "file_updated_at"
      t.integer  "report_id",         limit: 4
      t.integer  "workshop_log_id",   limit: 4
    end
  
    create_table "metadata", force: :cascade do |t|
      t.string   "name",       limit: 255
      t.string   "legacy_id",  limit: 255
      t.datetime "created_at",                             null: false
      t.datetime "updated_at",                             null: false
      t.boolean  "published",              default: false
    end
  
    create_table "monthly_reports", force: :cascade do |t|
      t.string   "month",                    limit: 255
      t.integer  "project_id",               limit: 4
      t.integer  "project_user_id",          limit: 4
      t.string   "name",                     limit: 255
      t.string   "position",                 limit: 255
      t.boolean  "mail_evaluations"
      t.string   "num_ongoing_participants", limit: 255
      t.string   "num_new_participants",     limit: 255
      t.text     "most_effective",           limit: 16777215
      t.text     "most_challenging",         limit: 16777215
      t.text     "goals_reached",            limit: 16777215
      t.text     "goals",                    limit: 16777215
      t.text     "comments",                 limit: 16777215
      t.boolean  "call_requested"
      t.string   "best_call_time",           limit: 255
      t.string   "phone",                    limit: 255
      t.datetime "created_at",                                null: false
      t.datetime "updated_at",                                null: false
    end
  
    add_index "monthly_reports", ["project_id"], name: "index_monthly_reports_on_project_id", using: :btree
    add_index "monthly_reports", ["project_user_id"], name: "index_monthly_reports_on_project_user_id", using: :btree
  
    create_table "notifications", force: :cascade do |t|
      t.datetime "created_at",                    null: false
      t.datetime "updated_at",                    null: false
      t.integer  "notification_type", limit: 4
      t.string   "noticeable_type",   limit: 255
      t.integer  "noticeable_id",     limit: 4
    end
  
    create_table "permissions", force: :cascade do |t|
      t.string   "security_cat", limit: 255
      t.datetime "created_at",               null: false
      t.datetime "updated_at",               null: false
      t.integer  "legacy_id",    limit: 4
    end
  
    create_table "project_obligations", force: :cascade do |t|
      t.string   "name",       limit: 255
      t.datetime "created_at",             null: false
      t.datetime "updated_at",             null: false
    end
  
    create_table "project_statuses", force: :cascade do |t|
      t.string   "name",       limit: 255
      t.datetime "created_at",             null: false
      t.datetime "updated_at",             null: false
    end
  
    create_table "project_users", force: :cascade do |t|
      t.integer  "agency_id",      limit: 4
      t.integer  "user_id",        limit: 4
      t.integer  "position",       limit: 4
      t.datetime "created_at",                 null: false
      t.datetime "updated_at",                 null: false
      t.integer  "project_id",     limit: 4
      t.string   "filemaker_code", limit: 255
    end
  
    add_index "project_users", ["agency_id"], name: "index_project_users_on_agency_id", using: :btree
    add_index "project_users", ["project_id"], name: "index_project_users_on_project_id", using: :btree
    add_index "project_users", ["user_id"], name: "index_project_users_on_user_id", using: :btree
  
    create_table "projects", force: :cascade do |t|
      t.string   "name",              limit: 255
      t.integer  "location_id",       limit: 4
      t.datetime "created_at",                                         null: false
      t.datetime "updated_at",                                         null: false
      t.integer  "windows_type_id",   limit: 4
      t.string   "district",          limit: 255
      t.date     "start_date"
      t.date     "end_date"
      t.string   "locality",          limit: 255
      t.text     "description",       limit: 16777215
      t.text     "notes",             limit: 16777215
      t.string   "filemaker_code",    limit: 255
      t.boolean  "inactive",                           default: false
      t.integer  "legacy_id",         limit: 4
      t.boolean  "legacy",                             default: false
      t.integer  "project_status_id", limit: 4
    end
  
    add_index "projects", ["location_id"], name: "index_projects_on_location_id", using: :btree
    add_index "projects", ["project_status_id"], name: "index_projects_on_project_status_id", using: :btree
    add_index "projects", ["windows_type_id"], name: "index_projects_on_windows_type_id", using: :btree
  
    create_table "quotable_item_quotes", force: :cascade do |t|
      t.string   "quotable_type", limit: 255
      t.integer  "quotable_id",   limit: 4
      t.integer  "legacy_id",     limit: 4
      t.integer  "quote_id",      limit: 4
      t.datetime "created_at",                null: false
      t.datetime "updated_at",                null: false
    end
  
    add_index "quotable_item_quotes", ["quote_id"], name: "index_quotable_item_quotes_on_quote_id", using: :btree
  
    create_table "quotes", force: :cascade do |t|
      t.text     "quote",        limit: 16777215
      t.boolean  "inactive",                      default: true
      t.integer  "legacy_id",    limit: 4
      t.boolean  "legacy",                        default: false
      t.datetime "created_at",                                    null: false
      t.datetime "updated_at",                                    null: false
      t.integer  "workshop_id",  limit: 4
      t.string   "age",          limit: 255
      t.string   "gender",       limit: 1
      t.string   "speaker_name", limit: 255
    end
  
    add_index "quotes", ["workshop_id"], name: "index_quotes_on_workshop_id", using: :btree
  
    create_table "report_form_field_answers", force: :cascade do |t|
      t.integer  "report_id",        limit: 4
      t.integer  "form_field_id",    limit: 4
      t.text     "answer",           limit: 16777215
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "answer_option_id", limit: 4
    end
  
    add_index "report_form_field_answers", ["answer_option_id"], name: "index_report_form_field_answers_on_answer_option_id", using: :btree
    add_index "report_form_field_answers", ["form_field_id"], name: "index_report_form_field_answers_on_form_field_id", using: :btree
    add_index "report_form_field_answers", ["report_id"], name: "index_report_form_field_answers_on_report_id", using: :btree
  
    create_table "reports", force: :cascade do |t|
      t.string   "type",                   limit: 255
      t.integer  "owner_id",               limit: 4
      t.string   "owner_type",             limit: 255
      t.datetime "created_at",                                         null: false
      t.datetime "updated_at",                                         null: false
      t.integer  "user_id",                limit: 4
      t.integer  "project_id",             limit: 4
      t.date     "date"
      t.integer  "rating",                 limit: 4,   default: 0
      t.integer  "windows_type_id",        limit: 4
      t.string   "form_file_file_name",    limit: 255
      t.string   "form_file_content_type", limit: 255
      t.integer  "form_file_file_size",    limit: 4
      t.datetime "form_file_updated_at"
      t.integer  "workshop_id",            limit: 4
      t.string   "workshop_name",          limit: 255
      t.string   "other_description",      limit: 255
      t.boolean  "has_attachment",                     default: false
      t.integer  "children_first_time",    limit: 4,   default: 0
      t.integer  "children_ongoing",       limit: 4,   default: 0
      t.integer  "teens_first_time",       limit: 4,   default: 0
      t.integer  "teens_ongoing",          limit: 4,   default: 0
      t.integer  "adults_first_time",      limit: 4,   default: 0
      t.integer  "adults_ongoing",         limit: 4,   default: 0
    end
  
    add_index "reports", ["project_id"], name: "index_reports_on_project_id", using: :btree
    add_index "reports", ["user_id"], name: "index_reports_on_user_id", using: :btree
    add_index "reports", ["windows_type_id"], name: "index_reports_on_windows_type_id", using: :btree
  
    create_table "resources", force: :cascade do |t|
      t.string   "title",           limit: 255
      t.string   "author",          limit: 255
      t.integer  "user_id",         limit: 4
      t.text     "text",            limit: 16777215
      t.boolean  "featured",                         default: false
      t.datetime "created_at",                                       null: false
      t.datetime "updated_at",                                       null: false
      t.string   "kind",            limit: 255
      t.integer  "workshop_id",     limit: 4
      t.boolean  "male",                             default: false
      t.boolean  "female",                           default: false
      t.string   "url",             limit: 255
      t.boolean  "inactive",                         default: true
      t.string   "agency",          limit: 255
      t.boolean  "legacy"
      t.integer  "windows_type_id", limit: 4
      t.string   "filemaker_code",  limit: 255
      t.integer  "ordering",        limit: 4
      t.integer  "legacy_id",       limit: 4
    end
  
    add_index "resources", ["user_id"], name: "index_resources_on_user_id", using: :btree
    add_index "resources", ["windows_type_id"], name: "index_resources_on_windows_type_id", using: :btree
    add_index "resources", ["workshop_id"], name: "index_resources_on_workshop_id", using: :btree
  
    create_table "sectorable_items", force: :cascade do |t|
      t.integer  "sectorable_id",   limit: 4
      t.string   "sectorable_type", limit: 255
      t.integer  "sector_id",       limit: 4
      t.datetime "created_at",                                 null: false
      t.datetime "updated_at",                                 null: false
      t.boolean  "inactive",                    default: true
    end
  
    add_index "sectorable_items", ["sector_id"], name: "index_sectorable_items_on_sector_id", using: :btree
  
    create_table "sectors", force: :cascade do |t|
      t.string   "name",       limit: 255
      t.datetime "created_at",                             null: false
      t.datetime "updated_at",                             null: false
      t.boolean  "published",              default: false
    end
  
    create_table "user_form_form_fields", force: :cascade do |t|
      t.integer  "form_field_id", limit: 4
      t.integer  "user_form_id",  limit: 4
      t.text     "text",          limit: 16777215
      t.datetime "created_at",                     null: false
      t.datetime "updated_at",                     null: false
    end
  
    add_index "user_form_form_fields", ["form_field_id"], name: "index_user_form_form_fields_on_form_field_id", using: :btree
    add_index "user_form_form_fields", ["user_form_id"], name: "index_user_form_form_fields_on_user_form_id", using: :btree
  
    create_table "user_forms", force: :cascade do |t|
      t.integer  "user_id",    limit: 4
      t.integer  "form_id",    limit: 4
      t.datetime "created_at",           null: false
      t.datetime "updated_at",           null: false
    end
  
    add_index "user_forms", ["form_id"], name: "index_user_forms_on_form_id", using: :btree
    add_index "user_forms", ["user_id"], name: "index_user_forms_on_user_id", using: :btree
  
    create_table "user_permissions", force: :cascade do |t|
      t.integer  "user_id",       limit: 4
      t.integer  "permission_id", limit: 4
      t.datetime "created_at",              null: false
      t.datetime "updated_at",              null: false
    end
  
    add_index "user_permissions", ["permission_id"], name: "index_user_permissions_on_permission_id", using: :btree
    add_index "user_permissions", ["user_id"], name: "index_user_permissions_on_user_id", using: :btree
  
    create_table "users", force: :cascade do |t|
      t.string   "email",                  limit: 255,      default: "",    null: false
      t.string   "encrypted_password",     limit: 255,      default: "",    null: false
      t.string   "first_name",             limit: 255,      default: ""
      t.string   "last_name",              limit: 255,      default: ""
      t.string   "reset_password_token",   limit: 255
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.integer  "sign_in_count",          limit: 4,        default: 0,     null: false
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.string   "current_sign_in_ip",     limit: 255
      t.string   "last_sign_in_ip",        limit: 255
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "agency_id",              limit: 4
      t.string   "phone",                  limit: 255
      t.string   "address",                limit: 255
      t.string   "city",                   limit: 255
      t.string   "state",                  limit: 255
      t.string   "zip",                    limit: 255
      t.date     "birthday"
      t.string   "subscribecode",          limit: 255
      t.text     "comment",                limit: 16777215
      t.text     "notes",                  limit: 16777215
      t.boolean  "legacy",                                  default: false
      t.boolean  "inactive",                                default: false
      t.boolean  "confirmed",                               default: true
      t.integer  "legacy_id",              limit: 4
      t.string   "phone2",                 limit: 255
      t.string   "phone3",                 limit: 255
      t.string   "best_time_to_call",      limit: 255
      t.string   "address2",               limit: 255
      t.string   "city2",                  limit: 255
      t.string   "state2",                 limit: 255
      t.string   "zip2",                   limit: 255
      t.integer  "primary_address",        limit: 4
      t.string   "avatar_file_name",       limit: 255
      t.string   "avatar_content_type",    limit: 255
      t.integer  "avatar_file_size",       limit: 4
      t.datetime "avatar_updated_at"
      t.boolean  "super_user",                              default: false
    end
  
    add_index "users", ["agency_id"], name: "index_users_on_agency_id", using: :btree
    add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
    add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  
    create_table "windows_types", force: :cascade do |t|
      t.string   "name",       limit: 255
      t.datetime "created_at",             null: false
      t.datetime "updated_at",             null: false
      t.integer  "legacy_id",  limit: 4
      t.string   "short_name", limit: 255
    end
  
    create_table "workshop_age_ranges", force: :cascade do |t|
      t.integer  "workshop_id",  limit: 4
      t.integer  "age_range_id", limit: 4
      t.datetime "created_at",             null: false
      t.datetime "updated_at",             null: false
    end
  
    add_index "workshop_age_ranges", ["age_range_id"], name: "index_workshop_age_ranges_on_age_range_id", using: :btree
    add_index "workshop_age_ranges", ["workshop_id"], name: "index_workshop_age_ranges_on_workshop_id", using: :btree
  
    create_table "workshop_logs", force: :cascade do |t|
      t.integer  "workshop_id",                 limit: 4
      t.integer  "user_id",                     limit: 4
      t.date     "date"
      t.integer  "rating",                      limit: 4,        default: 0
      t.text     "reaction",                    limit: 16777215
      t.text     "successes",                   limit: 16777215
      t.text     "challenges",                  limit: 16777215
      t.text     "suggestions",                 limit: 16777215
      t.text     "questions",                   limit: 16777215
      t.boolean  "lead_similar"
      t.text     "similarities",                limit: 16777215
      t.text     "differences",                 limit: 16777215
      t.text     "comments",                    limit: 16777215
      t.datetime "created_at",                                                   null: false
      t.datetime "updated_at",                                                   null: false
      t.integer  "project_id",                  limit: 4
      t.boolean  "is_embodied_art_workshop",                     default: false
      t.integer  "num_participants_on_going",   limit: 4,        default: 0
      t.integer  "num_participants_first_time", limit: 4,        default: 0
    end
  
    add_index "workshop_logs", ["project_id"], name: "index_workshop_logs_on_project_id", using: :btree
    add_index "workshop_logs", ["user_id"], name: "index_workshop_logs_on_user_id", using: :btree
    add_index "workshop_logs", ["workshop_id"], name: "index_workshop_logs_on_workshop_id", using: :btree
  
    create_table "workshop_resources", force: :cascade do |t|
      t.integer  "workshop_id", limit: 4
      t.integer  "resource_id", limit: 4
      t.datetime "created_at",            null: false
      t.datetime "updated_at",            null: false
    end
  
    add_index "workshop_resources", ["resource_id"], name: "index_workshop_resources_on_resource_id", using: :btree
    add_index "workshop_resources", ["workshop_id"], name: "index_workshop_resources_on_workshop_id", using: :btree
  
    create_table "workshop_variations", force: :cascade do |t|
      t.integer  "workshop_id",  limit: 4
      t.datetime "created_at",                                    null: false
      t.datetime "updated_at",                                    null: false
      t.text     "code",         limit: 16777215
      t.boolean  "inactive",                      default: true
      t.integer  "ordering",     limit: 4
      t.string   "name",         limit: 255
      t.boolean  "legacy",                        default: false
      t.integer  "variation_id", limit: 4
    end
  
    add_index "workshop_variations", ["workshop_id"], name: "index_workshop_variations_on_workshop_id", using: :btree
  
    create_table "workshops", force: :cascade do |t|
      t.string   "title",                      limit: 255
      t.string   "full_name",                  limit: 255
      t.string   "author_location",            limit: 255
      t.integer  "month",                      limit: 4
      t.integer  "year",                       limit: 4
      t.text     "objective",                  limit: 16777215
      t.text     "materials",                  limit: 16777215
      t.text     "timeframe",                  limit: 16777215
      t.text     "age_range",                  limit: 16777215
      t.text     "setup",                      limit: 16777215
      t.text     "instructions",               limit: 16777215
      t.text     "warm_up",                    limit: 16777215
      t.text     "creation",                   limit: 16777215
      t.text     "closing",                    limit: 16777215
      t.text     "misc_instructions",          limit: 16777215
      t.text     "project",                    limit: 16777215
      t.text     "description",                limit: 16777215
      t.text     "notes",                      limit: 16777215
      t.text     "timestamps",                 limit: 16777215
      t.text     "tips",                       limit: 16777215
      t.string   "pub_issue",                  limit: 255
      t.string   "misc1",                      limit: 255
      t.string   "misc2",                      limit: 255
      t.boolean  "inactive",                                    default: true
      t.boolean  "searchable",                                  default: false
      t.boolean  "featured",                                    default: false
      t.string   "photo_caption",              limit: 255
      t.string   "filemaker_code",             limit: 255
      t.datetime "created_at",                                                  null: false
      t.datetime "updated_at",                                                  null: false
      t.boolean  "legacy",                                      default: false
      t.integer  "legacy_id",                  limit: 4
      t.integer  "windows_type_id",            limit: 4
      t.integer  "user_id",                    limit: 4
      t.integer  "led_count",                  limit: 4,        default: 0
      t.text     "objective_spanish",          limit: 16777215
      t.text     "materials_spanish",          limit: 16777215
      t.text     "timeframe_spanish",          limit: 16777215
      t.text     "age_range_spanish",          limit: 16777215
      t.text     "setup_spanish",              limit: 16777215
      t.text     "instructions_spanish",       limit: 16777215
      t.text     "project_spanish",            limit: 16777215
      t.text     "warm_up_spanish",            limit: 16777215
      t.text     "creation_spanish",           limit: 16777215
      t.text     "closing_spanish",            limit: 16777215
      t.text     "misc_instructions_spanish",  limit: 16777215
      t.text     "description_spanish",        limit: 16777215
      t.text     "notes_spanish",              limit: 16777215
      t.text     "tips_spanish",               limit: 16777215
      t.string   "thumbnail_file_name",        limit: 255
      t.string   "thumbnail_content_type",     limit: 255
      t.integer  "thumbnail_file_size",        limit: 4
      t.datetime "thumbnail_updated_at"
      t.text     "optional_materials",         limit: 16777215
      t.text     "optional_materials_spanish", limit: 16777215
      t.text     "introduction",               limit: 16777215
      t.text     "introduction_spanish",       limit: 16777215
      t.text     "demonstration",              limit: 16777215
      t.text     "demonstration_spanish",      limit: 16777215
      t.text     "opening_circle",             limit: 16777215
      t.text     "opening_circle_spanish",     limit: 16777215
      t.text     "visualization",              limit: 16777215
      t.text     "visualization_spanish",      limit: 16777215
      t.text     "misc1_spanish",              limit: 16777215
      t.text     "misc2_spanish",              limit: 16777215
      t.integer  "time_intro",                 limit: 4
      t.integer  "time_demonstration",         limit: 4
      t.integer  "time_warm_up",               limit: 4
      t.integer  "time_creation",              limit: 4
      t.integer  "time_closing",               limit: 4
      t.integer  "time_opening",               limit: 4
      t.string   "header_file_name",           limit: 255
      t.string   "header_content_type",        limit: 255
      t.integer  "header_file_size",           limit: 4
      t.datetime "header_updated_at"
      t.text     "extra_field",                limit: 65535
      t.text     "extra_field_spanish",        limit: 65535
    end
  
    add_index "workshops", ["title", "full_name", "objective", "materials", "introduction", "demonstration", "opening_circle", "warm_up", "creation", "closing", "notes", "tips", "misc1", "misc2"], name: "workshop_fullsearch", type: :fulltext
    add_index "workshops", ["title"], name: "workshop_fullsearch_title", type: :fulltext
    add_index "workshops", ["user_id"], name: "index_workshops_on_user_id", using: :btree
    add_index "workshops", ["windows_type_id"], name: "index_workshops_on_windows_type_id", using: :btree
  
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

  def down
    raise ActiveRecord::IrreversibleMigration, "The initial migration is not revertable"
  end
end
