module Analytics
  # Counts content created in a time range, credited to the user or admin side by
  # the author's account when an author is set, else by the creating account.
  # Ideas promoted into published content count once, as the published record.
  class ContentCreationBreakdown
    Tally = Data.define(:count, :promoted_ideas, :unpromoted_ideas) do
      def self.of(count) = new(count: count, promoted_ideas: 0, unpromoted_ideas: 0)

      def +(other)
        Tally.new(count: count + other.count,
                  promoted_ideas: promoted_ideas + other.promoted_ideas,
                  unpromoted_ideas: unpromoted_ideas + other.unpromoted_ideas)
      end
    end

    Row = Data.define(:label, :user, :admin) do
      def total = user + admin
    end

    SIDES = %i[user admin].freeze

    def initialize(time_range:)
      @time_range = time_range
    end

    def groups
      [
        [
          simple_row("Bookmarks", Bookmark),
          simple_row("Quotes", Quote),
          idea_row("Stories", Story, StoryIdea, :stories),
          idea_row("Workshops", Workshop, WorkshopIdea, :workshops),
          idea_row("Variations", WorkshopVariation, WorkshopVariationIdea, :workshop_variations),
          simple_row("Workshop logs", WorkshopLog)
        ],
        [
          simple_row("Resources", Resource),
          simple_row("Community news", CommunityNews),
          simple_row("Events", Event),
          simple_row("Video recordings", VideoRecording)
        ]
      ]
    end

    private

    def simple_row(label, model)
      Row.new(label: label, **SIDES.index_with { |side| Tally.of(credited(model, side).count) })
    end

    def idea_row(label, model, idea_model, promoted_association)
      idea_fk = idea_model.model_name.singular.foreign_key
      sides = SIDES.index_with do |side|
        published = credited(model, side)
        unpromoted = credited(idea_model, side).where.missing(promoted_association).count
        Tally.new(count: published.count + unpromoted,
                  promoted_ideas: published.where.not(idea_fk => nil).count,
                  unpromoted_ideas: unpromoted)
      end
      Row.new(label: label, **sides)
    end

    def credited(model, side)
      scope = @time_range ? model.where(created_at: @time_range) : model.all
      side == :admin ? scope.where(admin_credit(model)) : scope.where.not(admin_credit(model))
    end

    def admin_credit(model)
      table = model.arel_table
      creator_column = model.column_names.include?("created_by_id") ? :created_by_id : :user_id
      creator_is_admin = admin_users.where(users[:id].eq(table[creator_column])).arel.exists
      return creator_is_admin unless model.column_names.include?("author_id")

      author_is_admin = admin_users.where(users[:person_id].eq(table[:author_id])).arel.exists
      table[:author_id].eq(nil).and(creator_is_admin).or(table[:author_id].not_eq(nil).and(author_is_admin))
    end

    def admin_users = User.where(super_user: true)

    def users = User.arel_table
  end
end
