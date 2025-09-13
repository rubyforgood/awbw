class WorkshopIdea < Workshop

  default_scope { where(inactive: true) }

end
