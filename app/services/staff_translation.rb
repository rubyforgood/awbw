# Turns a FileMaker EnteredBy/ModifiedBy value into the portal user it names, through the
# recorded StaffAlias rows. Built once and reused — it reads every alias up front, so a
# 39,000-row import doesn't query per value. A name nothing answers to is counted in
# #unmatched rather than guessed at, unless it's recorded as ignored.
class StaffTranslation
  attr_reader :unmatched

  def initialize
    @user_ids = StaffAlias.resolving.pluck(:name, :user_id).to_h { |name, user_id| [ key(name), user_id ] }
    @ignored = StaffAlias.ignored.pluck(:name).to_set { |name| key(name) }
    @unmatched = Hash.new(0)
  end

  def user_id_for(value)
    name = value.to_s.squish.presence
    return unless name

    @user_ids.fetch(key(name)) do
      @unmatched[name] += 1 unless @ignored.include?(key(name))
      nil
    end
  end

  private

  def key(value)
    value.to_s.squish.downcase
  end
end
