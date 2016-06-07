require 'mandrill'

class MandrillAccount < Account

  after_create :create_mandrill_sub_account
  # initialize mandrill account
  def create_mandrill_sub_account
    mandrill = Mandrill::API.new Rails.application.secrets.mandrill_key
    begin
      mandrill.subaccounts.add mandrill_client_id, name, "#{site.name} user"
    rescue Mandrill::Error => e
      logger.info "Unable to create Mandrill Account for #{id}"
      Airbrake.notify_or_ignore(e)
    end
  end

  after_update :update_mandrill_sub_account
  # update mandrill account
  def update_mandrill_sub_account
    if name_changed?
      mandrill = Mandrill::API.new Rails.application.secrets.mandrill_key
      begin
        mandrill.subaccounts.update mandrill_client_id, name
      rescue Mandrill::Error => e
        logger.info "Unable to create Mandrill Account for #{id}"
        Airbrake.notify_or_ignore(e)
      end
    end
  end
end
