# frozen_string_literal: true

module FmArchive
  extend ActiveSupport::Concern

  included do
    before_validation :set_defaults
  end

  class_methods do
    def find_by_fm_id(id)
      find_by(fm_id: id)
    end
  end

  private

  def set_defaults
    self.data ||= {}
  end
end
