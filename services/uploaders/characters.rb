module Services
  class Characters < Services::Uploaders::Base

    def initialize(campaign:, session:)
      super(campaign: campaign, session: session)
      @directory = 'characters'
    end

    def persist(invitation, name, content)
      Arkaan::Campaigns::Character.new(
        invitation: invitation,
        mime_type: mime_type(content),
        name: name
      )
    end

    def down(character)
      character.delete
    end
  end
end