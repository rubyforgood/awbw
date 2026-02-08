class RenameProjectsToOrganizations < ActiveRecord::Migration[8.1]
  def up
    # ---- TABLE RENAMES ----
    rename_table :projects, :organizations if table_exists?(:projects)
    rename_table :project_statuses, :organization_statuses if table_exists?(:project_statuses)
    rename_table :project_obligations, :organization_obligations if table_exists?(:project_obligations)
    rename_table :project_users, :organization_users if table_exists?(:project_users)

    # ---- COLUMN RENAMES ----
    rename_column_if_exists :organization_users, :project_id, :organization_id
    rename_column_if_exists :organization_users, :agency_id, :organization_agency_id

    rename_column_if_exists :organizations, :project_status_id, :organization_status_id

    %i[
      community_news
      monthly_reports
      reports
      stories
      story_ideas
      workshop_logs
    ].each do |table|
      rename_column_if_exists table, :project_id, :organization_id
    end

    rename_column_if_exists :monthly_reports, :project_user_id, :organization_user_id

    # ---- INDEX RENAMES ----
    safe_rename_index :organization_users,
                      "index_project_users_on_project_id",
                      "index_organization_users_on_organization_id"

    safe_rename_index :organization_users,
                      "index_project_users_on_agency_id",
                      "index_organization_users_on_organization_agency_id"

    safe_rename_index :organization_users,
                      "index_project_users_on_user_id",
                      "index_organization_users_on_user_id"

    safe_rename_index :organizations,
                      "index_projects_on_location_id",
                      "index_organizations_on_location_id"

    safe_rename_index :organizations,
                      "index_projects_on_project_status_id",
                      "index_organizations_on_organization_status_id"

    safe_rename_index :organizations,
                      "index_projects_on_view_count",
                      "index_organizations_on_view_count"

    safe_rename_index :organizations,
                      "index_projects_on_windows_type_id",
                      "index_organizations_on_windows_type_id"

    safe_rename_index :community_news,
                      "index_community_news_on_project_id",
                      "index_community_news_on_organization_id"

    safe_rename_index :monthly_reports,
                      "index_monthly_reports_on_project_id",
                      "index_monthly_reports_on_organization_id"

    safe_rename_index :monthly_reports,
                      "index_monthly_reports_on_project_user_id",
                      "index_monthly_reports_on_organization_user_id"

    safe_rename_index :reports,
                      "index_reports_on_project_id",
                      "index_reports_on_organization_id"

    safe_rename_index :stories,
                      "index_stories_on_project_id",
                      "index_stories_on_organization_id"

    safe_rename_index :story_ideas,
                      "index_story_ideas_on_project_id",
                      "index_story_ideas_on_organization_id"

    safe_rename_index :workshop_logs,
                      "index_workshop_logs_on_project_id",
                      "index_workshop_logs_on_organization_id"
  end

  def down
    # ---- REVERSE INDEX RENAMES ----
    safe_rename_index :organization_users,
                      "index_organization_users_on_organization_id",
                      "index_project_users_on_project_id"

    safe_rename_index :organization_users,
                      "index_organization_users_on_organization_agency_id",
                      "index_project_users_on_agency_id"

    safe_rename_index :organization_users,
                      "index_organization_users_on_user_id",
                      "index_project_users_on_user_id"

    safe_rename_index :organizations,
                      "index_organizations_on_location_id",
                      "index_projects_on_location_id"

    safe_rename_index :organizations,
                      "index_organizations_on_organization_status_id",
                      "index_projects_on_project_status_id"

    safe_rename_index :organizations,
                      "index_organizations_on_view_count",
                      "index_projects_on_view_count"

    safe_rename_index :organizations,
                      "index_organizations_on_windows_type_id",
                      "index_projects_on_windows_type_id"

    safe_rename_index :community_news,
                      "index_community_news_on_organization_id",
                      "index_community_news_on_project_id"

    safe_rename_index :monthly_reports,
                      "index_monthly_reports_on_organization_id",
                      "index_monthly_reports_on_project_id"

    safe_rename_index :monthly_reports,
                      "index_monthly_reports_on_organization_user_id",
                      "index_monthly_reports_on_project_user_id"

    safe_rename_index :reports,
                      "index_reports_on_organization_id",
                      "index_reports_on_project_id"

    safe_rename_index :stories,
                      "index_stories_on_organization_id",
                      "index_stories_on_project_id"

    safe_rename_index :story_ideas,
                      "index_story_ideas_on_organization_id",
                      "index_story_ideas_on_project_id"

    safe_rename_index :workshop_logs,
                      "index_workshop_logs_on_organization_id",
                      "index_workshop_logs_on_project_id"

    # ---- REVERSE COLUMN RENAMES ----
    rename_column_if_exists :monthly_reports, :organization_user_id, :project_user_id

    %i[
      community_news
      monthly_reports
      reports
      stories
      story_ideas
      workshop_logs
    ].each do |table|
      rename_column_if_exists table, :organization_id, :project_id
    end

    rename_column_if_exists :organizations, :organization_status_id, :project_status_id

    rename_column_if_exists :organization_users, :organization_id, :project_id
    rename_column_if_exists :organization_users, :organization_agency_id, :agency_id

    # ---- REVERSE TABLE RENAMES ----
    rename_table :organization_users, :project_users if table_exists?(:organization_users)
    rename_table :organization_obligations, :project_obligations if table_exists?(:organization_obligations)
    rename_table :organization_statuses, :project_statuses if table_exists?(:organization_statuses)
    rename_table :organizations, :projects if table_exists?(:organizations)
  end

  private

  def rename_column_if_exists(table, from, to)
    return unless table_exists?(table)
    return unless column_exists?(table, from)
    rename_column table, from, to
  end

  def safe_rename_index(table, old_name, new_name)
    return unless table_exists?(table)
    return unless index_exists?(table, name: old_name)
    return if index_exists?(table, name: new_name)

    rename_index table, old_name, new_name
  end
end
