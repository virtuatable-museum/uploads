module Controllers
  class Characters < Controllers::Base
    load_errors_from __FILE__

    # Creation of a character in a campaign.
    # @param campaign_id [String] MANDATORY - the ID of the campaign to create the file in.
    # @param content [String] MANDATORY - The base64 content of the XML file of the character.
    # @param name [String] MANDATORY - the display name for the file.
    declare_route 'post', '/characters' do
      action = 'character_creation'
      check_presence 'campaign_id', 'name', 'content', 'invitation_id', route: action
      session = check_session(action)
      check_campaign(action)
      check_invitation(action, invitation)
      check_privileges(session: session, campaign: campaign, action: action)

      character = service.persist(invitation, params['name'], params['content'])
      model_error(character, action) unless character.save
      
      begin
        service.store(campaign, character, params['content'])
        halt 201, Decorators::File.new(character).to_json
      rescue StandardError => exception
        service.down(character)
        custom_error 400, 'files_creation.storage.failure'
      end
    end

    declare_route 'get', '/characters/:character_id' do
      action = 'character_get'
      check_presence 'campaign_id', route: action
      session = check_session(action)
      check_campaign(action)

      campaign = Arkaan::Campaign.where(id: params['campaign_id']).first
      invitation = session_invitation(session)

      if invitation.nil? || ![:creator, :accepted].include?(invitation.status)
        custom_error 403, 'character_get.session_id.forbidden'
      end
      character = campaign.characters.find do |character|
        character.id.to_s == params['character_id']
      end
      custom_error 404, 'character_get.character_id.unknown' if character.nil?
      halt 200, Services::Amazon.instance.content("#{campaign.id.to_s}/characters/#{character.id.to_s}")
    end

    def service_class
      Services::Characters
    end

    def check_invitation(action, invitation)
      custom_error(404, "#{action}.invitation_id.unknown") if invitation.nil?
    end

    def invitation
      campaign.invitations.where(id: params['invitation_id']).first
    end

    def session_invitation(session)
      campaign.invitations.where(account: session.account).first
    end
  end
end