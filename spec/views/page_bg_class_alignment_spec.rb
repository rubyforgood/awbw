# frozen_string_literal: true

require "rails_helper"

# This test ensures every view's content_for(:page_bg_class, ...) value
# accurately reflects its corresponding policy authorization level.
#
# When adding a new page with content_for(:page_bg_class, ...),
# add it to EXPECTED_MAPPINGS below with the correct bg class.

RSpec.describe "page_bg_class alignment with policies" do
  # Views intentionally skipped (with reason)
  SKIPS = [].freeze

  # Expected mapping: view path => expected page_bg_class value
  # Bg class values and their policy meanings:
  #   "public"                                        → true
  #   "admin-or-auth"                                 → authenticated?
  #   "admin-or-public-or-authpublished"              → admin? || publicly_visible? || (authenticated? && published?)
  #   "admin-or-owner"                                → admin? || owner?
  #   "admin-only bg-blue-100"                        → admin?

  EXPECTED_MAPPINGS = {
    # ─── public (policy action returns true) ───
    "app/views/community_news/index.html.erb"          => "public",
    "app/views/events/index.html.erb"                  => "public",
    "app/views/faqs/index.html.erb"                    => "public",
    "app/views/resources/index.html.erb"               => "public",
    "app/views/stories/index.html.erb"                 => "public",
    "app/views/story_shares/index.html.erb"            => "public",
    "app/views/tags/index.html.erb"                    => "public",
    "app/views/taggings/index.html.erb"                => "public",
    "app/views/tutorials/index.html.erb"               => "public",
    "app/views/workshop_variations/index.html.erb"     => "public",
    "app/views/workshops/index.html.erb"               => "public",

    # ─── admin-or-auth (policy: authenticated?) ───
    "app/views/organizations/index.html.erb"           => "admin-or-auth",
    "app/views/people/index.html.erb"                  => "admin-or-auth",
    "app/views/workshop_logs/index.html.erb"           => "admin-or-auth",

    "app/views/story_ideas/new.html.erb"               => "admin-or-auth",
    "app/views/workshop_ideas/new.html.erb"            => "admin-or-auth",
    "app/views/workshop_variation_ideas/new.html.erb"  => "admin-or-auth",

    "app/views/workshop_logs/new.html.erb"             => "admin-or-auth",
    "app/views/monthly_reports/new.html.erb"           => "admin-or-auth",
    "app/views/reports/new.html.erb"                   => "admin-or-auth",

    # ─── admin-or-public-or-authpublished ───
    # (policy: admin? || publicly_visible? || (authenticated? && published?))
    "app/views/community_news/show.html.erb"           => "admin-or-public-or-authpublished",
    "app/views/events/show.html.erb"                   => "admin-or-public-or-authpublished",
    "app/views/faqs/show.html.erb"                     => "admin-or-public-or-authpublished",
    "app/views/resources/show.html.erb"                => "admin-or-public-or-authpublished",
    "app/views/stories/show.html.erb"                  => "admin-or-public-or-authpublished",
    "app/views/tutorials/show.html.erb"                => "admin-or-public-or-authpublished",
    "app/views/workshop_variations/show.html.erb"      => "admin-or-public-or-authpublished",
    "app/views/workshops/show.html.erb"                => "admin-or-public-or-authpublished",
    "app/views/story_shares/show.html.erb"             => "admin-or-public-or-authpublished",

    "app/views/organizations/populations_served.html.erb" => "admin-or-authpublished",

    # ─── admin-or-owner (policy: admin? || owner?) ───
    "app/views/event_registrations/show.html.erb"      => "admin-or-owner",
    "app/views/quotes/show.html.erb"                   => "admin-or-owner",
    "app/views/story_ideas/show.html.erb"              => "admin-or-owner",
    "app/views/workshop_variation_ideas/show.html.erb" => "admin-or-owner",
    "app/views/workshop_ideas/show.html.erb"           => "admin-or-owner",

    "app/views/reports/edit.html.erb"                  => "admin-or-owner",
    "app/views/workshop_logs/edit.html.erb"            => "admin-or-owner",
    "app/views/monthly_reports/edit.html.erb"          => "admin-or-owner",

    "app/views/notifications/show.html.erb"            => "admin-or-owner",
    "app/views/organizations/show.html.erb"            => "admin-or-auth",
    "app/views/people/show.html.erb"                   => "admin-or-owner-or-authsearchable",
    "app/views/organizations/edit.html.erb"            => "admin-or-owner",
    "app/views/people/edit.html.erb"                   => "admin-or-owner",

    "app/views/reports/show.html.erb"                  => "admin-or-owner-or-member",
    "app/views/workshop_logs/show.html.erb"            => "admin-or-owner-or-member",
    "app/views/monthly_reports/show.html.erb"          => "admin-or-owner-or-member",

    # ─── admin-only bg-blue-100 (policy: admin?) ───
    # custom actions
    "app/views/admin/home/index.html.erb"              => "admin-only bg-blue-100",
    "app/views/admin/ahoy_activities/charts.html.erb"  => "admin-only bg-blue-100",
    "app/views/admin/ahoy_activities/visits.html.erb"  => "admin-only bg-blue-100",
    "app/views/admin/ahoy_activities/index.html.erb"   => "admin-only bg-blue-100",
    "app/views/admin/analytics/index.html.erb"         => "admin-only bg-blue-100",
    "app/views/bookmarks/tally.html.erb"               => "admin-only bg-blue-100",
    "app/views/dedupes/index.html.erb"                 => "admin-only bg-blue-100",
    "app/views/dedupes/preview.html.erb"               => "admin-only bg-blue-100",
    "app/views/taggings/matrix.html.erb"               => "admin-only bg-blue-100",
    # index
    "app/views/banners/index.html.erb"                 => "admin-only bg-blue-100",
    "app/views/comments/index.html.erb"                => "admin-only bg-blue-100",
    "app/views/bookmarks/index.html.erb"               => "admin-only bg-blue-100",
    "app/views/categories/index.html.erb"              => "admin-only bg-blue-100",
    "app/views/category_types/index.html.erb"          => "admin-only bg-blue-100",
    "app/views/event_registrations/index.html.erb"     => "admin-only bg-blue-100",
    "app/views/notifications/index.html.erb"           => "admin-only bg-blue-100",
    "app/views/organization_statuses/index.html.erb"   => "admin-only bg-blue-100",
    "app/views/quotes/index.html.erb"                  => "admin-only bg-blue-100",
    "app/views/sectors/index.html.erb"                 => "admin-only bg-blue-100",
    "app/views/story_ideas/index.html.erb"             => "admin-only bg-blue-100",
    "app/views/users/index.html.erb"                   => "admin-only bg-blue-100",
    "app/views/windows_types/index.html.erb"           => "admin-only bg-blue-100",
    "app/views/workshop_ideas/index.html.erb"          => "admin-only bg-blue-100",
    "app/views/workshop_variation_ideas/index.html.erb" => "admin-only bg-blue-100",
    # show
    "app/views/banners/show.html.erb"                  => "admin-only bg-blue-100",
    "app/views/categories/show.html.erb"               => "admin-only bg-blue-100",
    "app/views/category_types/show.html.erb"           => "admin-only bg-blue-100",
    "app/views/organization_statuses/show.html.erb"    => "admin-only bg-blue-100",
    "app/views/sectors/show.html.erb"                  => "admin-only bg-blue-100",
    "app/views/users/show.html.erb"                    => "admin-only bg-blue-100",
    "app/views/windows_types/show.html.erb"            => "admin-only bg-blue-100",
    "app/views/bookmarks/show.html.erb"               => "admin-only bg-blue-100",
    # new
    "app/views/banners/new.html.erb"                   => "admin-only bg-blue-100",
    "app/views/categories/new.html.erb"                => "admin-only bg-blue-100",
    "app/views/category_types/new.html.erb"            => "admin-only bg-blue-100",
    "app/views/community_news/new.html.erb"            => "admin-only bg-blue-100",
    "app/views/event_registrations/new.html.erb"       => "admin-only bg-blue-100",
    "app/views/events/new.html.erb"                    => "admin-only bg-blue-100",
    "app/views/faqs/new.html.erb"                      => "admin-only bg-blue-100",
    "app/views/organizations/new.html.erb"             => "admin-only bg-blue-100",
    "app/views/organization_statuses/new.html.erb"     => "admin-only bg-blue-100",
    "app/views/people/new.html.erb"                    => "admin-only bg-blue-100",
    "app/views/quotes/new.html.erb"                    => "admin-only bg-blue-100",
    "app/views/resources/new.html.erb"                 => "admin-only bg-blue-100",
    "app/views/sectors/new.html.erb"                   => "admin-only bg-blue-100",
    "app/views/stories/new.html.erb"                   => "admin-only bg-blue-100",
    "app/views/tutorials/new.html.erb"                 => "admin-only bg-blue-100",
    "app/views/users/new.html.erb"                     => "admin-only bg-blue-100",
    "app/views/windows_types/new.html.erb"             => "admin-only bg-blue-100",
    "app/views/workshop_variations/new.html.erb"       => "admin-only bg-blue-100",
    "app/views/workshops/new.html.erb"                 => "admin-only bg-blue-100",
    # edit
    "app/views/banners/edit.html.erb"                  => "admin-only bg-blue-100",
    "app/views/categories/edit.html.erb"               => "admin-only bg-blue-100",
    "app/views/category_types/edit.html.erb"           => "admin-only bg-blue-100",
    "app/views/community_news/edit.html.erb"           => "admin-only bg-blue-100",
    "app/views/event_registrations/edit.html.erb"      => "admin-only bg-blue-100",
    "app/views/events/edit.html.erb"                   => "admin-only bg-blue-100",
    "app/views/faqs/edit.html.erb"                     => "admin-only bg-blue-100",
    "app/views/organization_statuses/edit.html.erb"    => "admin-only bg-blue-100",
    "app/views/quotes/edit.html.erb"                   => "admin-only bg-blue-100",
    "app/views/resources/edit.html.erb"                => "admin-only bg-blue-100",
    "app/views/sectors/edit.html.erb"                  => "admin-only bg-blue-100",
    "app/views/stories/edit.html.erb"                  => "admin-only bg-blue-100",
    "app/views/story_ideas/edit.html.erb"              => "admin-only bg-blue-100",
    "app/views/tutorials/edit.html.erb"                => "admin-only bg-blue-100",
    "app/views/users/edit.html.erb"                    => "admin-only bg-blue-100",
    "app/views/windows_types/edit.html.erb"            => "admin-only bg-blue-100",
    "app/views/workshop_ideas/edit.html.erb"           => "admin-only bg-blue-100",
    "app/views/workshop_variation_ideas/edit.html.erb" => "admin-only bg-blue-100",
    "app/views/workshop_variations/edit.html.erb"      => "admin-only bg-blue-100",
    "app/views/workshops/edit.html.erb"                => "admin-only bg-blue-100"
  }.freeze

  EXPECTED_MAPPINGS.each do |view_path, expected_bg_class|
    it "#{view_path} has page_bg_class '#{expected_bg_class}'" do
      full_path = Rails.root.join(view_path)
      expect(File).to exist(full_path), "View file not found: #{view_path}"

      content = File.read(full_path)
      match = content.match(/content_for\(:page_bg_class,\s*"([^"]+)"\)/)
      actual_bg_class = match&.captures&.first

      expect(actual_bg_class).to eq(expected_bg_class),
        "#{view_path}: expected page_bg_class '#{expected_bg_class}' but got '#{actual_bg_class || '(none)'}'"
    end
  end

  it "every view with content_for(:page_bg_class) is accounted for" do
    all_view_files = Dir.glob(Rails.root.join("app/views/**/*.html.erb"))
    untracked = []

    all_view_files.each do |full_path|
      relative_path = full_path.sub("#{Rails.root}/", "")
      content = File.read(full_path)
      next unless content.match?(/content_for\(:page_bg_class,/)
      next if SKIPS.include?(relative_path)
      next if EXPECTED_MAPPINGS.key?(relative_path)

      match = content.match(/content_for\(:page_bg_class,\s*"([^"]+)"\)/)
      untracked << "#{relative_path} (#{match&.captures&.first || 'unknown'})"
    end

    expect(untracked).to be_empty,
      "Views with content_for(:page_bg_class) not in EXPECTED_MAPPINGS or SKIPS:\n  #{untracked.join("\n  ")}"
  end
end
