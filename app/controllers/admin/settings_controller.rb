module Admin
  # The single row of app-wide settings. See Setting for how each value falls back
  # to ENV, which is why the form shows the effective value as a placeholder.
  class SettingsController < ApplicationController
    def show
      @setting = Setting.current
      authorize! @setting, to: :show?
    end

    def update
      @setting = Setting.current
      authorize! @setting, to: :update?

      if @setting.update(setting_params)
        redirect_to admin_settings_path, status: :see_other, notice: "Settings saved."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def setting_params
      params.require(:setting).permit(:organization_id, :info_email, :reply_to_email, :invoice_prefix,
                                      :return_address_id, :remittance_address_id,
                                      :programs_email, :no_reply_email,
                                      :annual_membership_cents, :membership_renewal_window_days,
                                      :membership_grace_period_days)
    end
  end
end
