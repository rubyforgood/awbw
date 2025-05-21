FeatureFlipper.features do
    in_state :development do
    end

    in_state :live do
      feature :new_workshop_log, description: "If users should be shown the new unified Workshop Log"
      feature :no_monthly_reports, description: "If the users are not shown the monthly reports"
      feature :workshop_log_summary, description: "If the workshop log summary should be shown as a separate page"
    end
  end

  FeatureFlipper.states do
    state :development, ['development', 'test'].include?(Rails.env)
    state :live, true
  end
