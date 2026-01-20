class RenameProjectsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    # Rename main projects table to organizations
    rename_table :projects, :organizations

    # Rename project_statuses table
    rename_table :project_statuses, :organization_statuses

    # Rename project_obligations table
    rename_table :project_obligations, :organization_obligations

    # Rename project_users table
    rename_table :project_users, :organization_users

    # Update foreign key columns
    rename_column :organization_users, :project_id, :organization_id
    rename_column :organization_users, :agency_id, :organization_agency_id

    # Update foreign key in organizations table
    rename_column :organizations, :project_status_id, :organization_status_id

    # Update project_id foreign keys in other tables
    rename_column :community_news, :project_id, :organization_id
    rename_column :monthly_reports, :project_id, :organization_id
    rename_column :reports, :project_id, :organization_id
    rename_column :stories, :project_id, :organization_id
    rename_column :story_ideas, :project_id, :organization_id
    rename_column :workshop_logs, :project_id, :organization_id

    # Rename project_user_id foreign key
    rename_column :monthly_reports, :project_user_id, :organization_user_id

    # Rename indexes
    rename_index :organization_users, 'index_project_users_on_project_id', 'index_organization_users_on_organization_id'
    rename_index :organization_users, 'index_project_users_on_agency_id', 'index_organization_users_on_organization_agency_id'
    rename_index :organization_users, 'index_project_users_on_user_id', 'index_organization_users_on_user_id'

    rename_index :organizations, 'index_projects_on_location_id', 'index_organizations_on_location_id'
    rename_index :organizations, 'index_projects_on_project_status_id', 'index_organizations_on_organization_status_id'
    rename_index :organizations, 'index_projects_on_view_count', 'index_organizations_on_view_count'
    rename_index :organizations, 'index_projects_on_windows_type_id', 'index_organizations_on_windows_type_id'

    rename_index :community_news, 'index_community_news_on_project_id', 'index_community_news_on_organization_id'
    rename_index :monthly_reports, 'index_monthly_reports_on_project_id', 'index_monthly_reports_on_organization_id'
    rename_index :monthly_reports, 'index_monthly_reports_on_project_user_id', 'index_monthly_reports_on_organization_user_id'
    rename_index :reports, 'index_reports_on_project_id', 'index_reports_on_organization_id'
    rename_index :stories, 'index_stories_on_project_id', 'index_stories_on_organization_id'
    rename_index :story_ideas, 'index_story_ideas_on_project_id', 'index_story_ideas_on_organization_id'
    rename_index :workshop_logs, 'index_workshop_logs_on_project_id', 'index_workshop_logs_on_organization_id'

    # Rename foreign key constraints
    # Note: Rails will handle updating foreign key references automatically when we rename the columns
    # However, we need to explicitly update any named foreign key constraints

    # For users table that references projects as agency_id
    # The existing foreign key is already named correctly as it references projects.id
    # Rails will automatically update this when we rename the table
  end
end
