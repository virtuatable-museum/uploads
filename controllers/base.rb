module Controllers
  class Base < Arkaan::Utils::Controllers::Checked
    load_errors_from __FILE__

    attr_accessor :service

    before do
      @service = service_class.new(campaign: campaign, session: session)
    end

    # @abstract The subclassing controllers are expected to implement #service_class
    # @!method service_class
    #   The class service linked to this kind of files.
    #   @return [Class] the class representing the service used to store the file.

    # Checks the privileges of the account regarding the campaign he tries to access/insert into
    # @param session [Arkaan::Authencation::Session] the session the user is connected to.
    # @oaram campaign [Arkaan::Campaign] the campaign the user is trying to manipulate.
    # @return [Boolean] TRUE if the user has privileges to access/insert. Halts otherwise with a 403.
    def check_privileges(session:, action:, campaign:)
      if campaign.creator.id != session.account.id
        custom_error(403, 'character_creation.session_id.forbidden')
      end
    end

    def campaign
      Arkaan::Campaign.where(id: params['campaign_id']).first
    end

    def session
      check_session(action)
    end

    def check_campaign(action)
      custom_error(404, "#{action}.campaign_id.unknown") if campaign.nil?
    end
  end
end