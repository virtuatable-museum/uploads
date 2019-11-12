module Services
  class Documents < Services::Uploaders::Base

    def initialize(campaign:, session:)
      super(campaign: campaign, session: session)
      @directory = 'documents'
    end

    def persist(name, content)
      invitation = campaign.invitations.where(account: session.account).first
      Arkaan::Campaigns::Files::Document.new(
        creator: invitation,
        mime_type: mime_type(content),
        name: name
      )
    end

    def update_size(document)
      size = amazon.size(fullname(campaign, document))
      document.update_attribute(:size, size)
    end

    def down(document)
      document.permissions.each(&:delete)
      document.delete
      return false
    end
  end
end