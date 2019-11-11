module Controllers
  class Documents < Controllers::Base
    load_errors_from __FILE__

    # Creation of a document in a campaign.
    # @param campaign_id [String] MANDATORY - the ID of the campaign to create the document in.
    # @param content [String] MANDATORY - The base64 content of the uploaded document.
    # @param name [String] MANDATORY - the display name for the document.
    declare_route 'post', '/documents' do
      check_presence 'campaign_id', 'name', 'content', route: action
      check_campaign(action)
      check_privileges(session: session, campaign: campaign, action: action)

      document = service.persist(params['name'], params['content'])
      model_error(document, action) unless document.save
      
      begin
        service.store(campaign, params['name'], params['content'])
        service.update_size(document)
        halt 201, Decorators::File.new(document).to_json
      rescue StandardError => exception
        service.down(document)
        custom_error 400, 'files_creation.storage.failure'
      end
    end

    def service_class
      Services::Documents
    end

    def action
      'document_creation'
    end
  end
end