module EventRegistrationServices
  # The affiliations an imported registration must carry (ADR-0012 D6–D8), shared by every
  # attendance import so a FileMaker row and a CSV row leave the same result. It fixes what
  # the person already holds before adding anything, and lists what it can't decide rather
  # than guessing. Rerunning it changes nothing.
  #
  # - Job affiliation (D6): kept when held with the title, titled when an untitled one is held,
  #   listed when a different title is held, else added. A blank or placeholder start becomes
  #   the training date. Only one this training adds is tied to the registration.
  # - Facilitator affiliation (D7): only for someone who completed a facilitator training. One
  #   active one is tied to this registration and dated to the training; none is added; more
  #   than one, one tied to another registration, an ended one, or one held without completing
  #   is listed.
  # - FileMaker codes (D8): both carry the person's Personnel codes at the organization, added
  #   to any already there.
  class HydrateAffiliations
    Result = Struct.new(:changes, :for_a_look, :autofill, keyword_init: true)

    # job_title_code: the FileMaker person-to-organization link the title came from, if any.
    # completed: defaults to the registration being attended.
    def self.call(registration:, organization:, job_title: nil, job_title_code: nil, organization_address: nil,
                  completed: nil)
      new(registration:, organization:, job_title:, job_title_code:, organization_address:, completed:).call
    end

    def initialize(registration:, organization:, job_title: nil, job_title_code: nil, organization_address: nil,
                   completed: nil)
      @registration = registration
      @person = registration.registrant
      @event = registration.event
      @organization = organization
      @job_title = job_title.to_s.strip.presence
      @job_title_code = job_title_code
      @organization_address = organization_address
      @completed = completed.nil? ? registration.attended? : completed
    end

    def call
      @changes = []
      @for_a_look = []
      autofill = ActiveRecord::Base.transaction do
        hydrate_job if @job_title && @job_title != Affiliation::FACILITATOR_TITLE
        hydrate_facilitator if @event.facilitator_training?
        AffiliationServices::PointAtAddress.call(person: @person, organization: @organization,
                                                 address: @organization_address)
      end
      Result.new(changes: @changes, for_a_look: @for_a_look, autofill: autofill)
    end

    private

    def hydrate_job
      jobs = held.jobs
      job = jobs.find_by(title: @job_title)
      if job.nil? && (job = jobs.where(title: [ nil, "" ]).first)
        job.title = @job_title
      elsif job.nil? && jobs.exists?
        look("holds #{jobs.pluck(:title).to_sentence} at #{@organization.name}, not “#{@job_title}”; left as is")
        return
      elsif job.nil?
        job = new_affiliation(@job_title)
        job.event_registration = @registration
        note("added job affiliation “#{@job_title}”")
      end

      job.start_date = training_date if placeholder_start?(job.start_date)
      finish(job, job_codes)
    end

    def hydrate_facilitator
      facilitators = held.facilitators.to_a
      return look_at_uncompleted(facilitators) unless @completed

      case facilitators.size
      when 0 then add_facilitator
      when 1 then tie_facilitator(facilitators.first)
      else look("holds #{facilitators.size} active facilitator affiliations at #{@organization.name}; staff choose which stays")
      end
    end

    def look_at_uncompleted(facilitators)
      return if facilitators.empty?

      look("holds an active facilitator affiliation at #{@organization.name} but didn't complete this training; left as is")
    end

    def add_facilitator
      if @person.affiliations.facilitators.where(organization: @organization).exists?
        look("only an ended facilitator affiliation at #{@organization.name}; left ended")
        return
      end

      affiliation = new_affiliation(Affiliation::FACILITATOR_TITLE, start_date: training_date)
      note("added facilitator affiliation from #{training_date}")
      tie(affiliation)
    end

    def tie_facilitator(affiliation)
      tied_elsewhere = affiliation.event_registration_id && affiliation.event_registration_id != @registration.id
      if tied_elsewhere
        look("facilitator affiliation at #{@organization.name} is tied to registration ##{affiliation.event_registration_id}; left as is")
        return
      end

      affiliation.start_date = training_date
      tie(affiliation)
    end

    def tie(facilitator)
      facilitator.event_registration = @registration
      finish(facilitator, personnel_codes)
    end

    def placeholder_start?(start_date)
      start_date.nil? || start_date == training_date.beginning_of_month
    end

    def finish(affiliation, codes)
      affiliation.filemaker_code = Affiliation.join_filemaker_codes(affiliation.filemaker_code, codes)
      return unless affiliation.new_record? || affiliation.changed?

      note("updated #{affiliation.title} affiliation: #{affiliation.changed.to_sentence}") if affiliation.persisted?
      affiliation.save!
    end

    def new_affiliation(title, start_date: nil)
      @person.affiliations.build(organization: @organization, title: title, start_date: start_date,
                                 organization_address: @organization_address)
    end

    def held
      @person.affiliations.active_or_pending.where(organization: @organization)
    end

    def training_date
      @training_date ||= @registration.facilitator_start_on || @event.starts_on
    end

    def job_codes
      personnel_codes + Array(@job_title_code)
    end

    # Personnel rows for this person on a project that is the organization's: the project's own
    # code, or the code of the FileMaker organization it belongs to, is on the portal organization.
    def personnel_codes
      @personnel_codes ||= begin
        person_codes = @person.filemaker_codes
        org_codes = @organization.filemaker_codes
        if person_codes.empty? || org_codes.empty?
          []
        else
          projects = org_codes + FmProject.find_by_data("OrgID", org_codes).pluck(:fm_id)
          FmPersonnel.find_by_data("PersonID", person_codes)
            .select { |row| projects.include?(row.data["ProjectID"].to_s.strip) }.map(&:fm_id)
        end
      end
    end

    def note(message)
      @changes << message
    end

    def look(message)
      @for_a_look << message
    end
  end
end
