# STI subclass for the standing "Facilitator" affiliation — the one that confers
# AWBW Art Program status on an organization. Affiliation assigns this type from
# the title (exactly "Facilitator") in a before_validation, so the type always
# tracks the title; see Affiliation#set_type_from_title.
class FacilitatorAffiliation < Affiliation
end
