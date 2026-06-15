class PersonArchivalService
  def initialize(person)
    @person = person
  end

  # Soft-delete (archive) the person and their user together. A discarded user
  # is blocked from authenticating and hidden from default listings.
  def archive!
    ActiveRecord::Base.transaction do
      @person.user&.discard!
      @person.discard!
    end
  end

  # Reverse an archive, bringing the person and their user back.
  def restore!
    ActiveRecord::Base.transaction do
      @person.user&.undiscard!
      @person.undiscard!
    end
  end
end
