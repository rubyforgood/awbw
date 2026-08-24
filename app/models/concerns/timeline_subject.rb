module TimelineSubject
  extend ActiveSupport::Concern

  def timeline_label
    model_name.human
  end
end
