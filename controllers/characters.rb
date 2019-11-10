module Controllers
  class Characters < Arkaan::Utils::Controllers::Checked
    load_errors_from __FILE__

    # Creation of a character in a campaign.
    # @param campaign_id [String] MANDATORY - the ID of the campaign to create the file in.
    # @param content [String] MANDATORY - The base64 content of the XML file of the character.
    # @param name [String] MANDATORY - the display name for the file.
    declare_route 'post', '/characters' do
      check_presence 'campaign_id', 'name', 'content', route: 'character_creation'
      session = check_session('character_creation')
      campaign = check_campaign('character_creation')
      check_privileges(session: session, campaign: campaign, action: 'character_creation')

      character = Services::Characters.create(campaign, session, params['name'], params['content'])
      if character.save
        halt 201, {message: 'created'}.to_json
      else
        model_error character, 'character_creation'
      end
    end

    # Checks the privileges of the account regarding the campaign he tries to access/insert into
    # @param session [Arkaan::Authencation::Session] the session the user is connected to.
    # @oaram campaign [Arkaan::Campaign] the campaign the user is trying to manipulate.
    # @return [Boolean] TRUE if the user has privileges to access/insert. Halts otherwise with a 403.
    def check_privileges(session:, action:, campaign:)
      if campaign.creator.id != session.account.id
        custom_error(403, 'character_creation.session_id.forbidden')
      end
    end

    def check_campaign(action)
      campaign = Arkaan::Campaign.where(id: params['campaign_id']).first
      custom_error(404, "#{action}.campaign_id.unknown") if campaign.nil?
      return campaign
    end
  end
end