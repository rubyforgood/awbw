# STI subclass for a person's role/job at an organization (any title other than
# exactly "Facilitator"). This is the default affiliation type; Affiliation
# assigns it from the title in a before_validation. See Affiliation#set_type_from_title.
class JobAffiliation < Affiliation
end
