RSpec.describe Controllers::Documents do

  def app
    Controllers::Documents.new
  end

  let!(:account) { create(:account) }
  let!(:gateway) { create(:gateway) }
  let!(:appli) { create(:application, creator: account) }
  let!(:session) { create(:session, account: account) }

  let!(:campaign) { create(:campaign, creator: account) }
  let!(:content) {'data:text/plain;base64,dGVzdApzYXV0IGRlIGxpZ25lIGV0IGVzcGFjZXM='}
  let!(:invalid_content) {'data:text/rtf;base64,dGVzdApzYXV0IGRlIGxpZ25lIGV0IGVzcGFjZXMK'}
  
  describe 'Nominal case' do
    before do
      post '/uploads/documents', {
        session_id: session.token,
        app_key: appli.key,
        token: gateway.token,
        name: 'test.txt',
        content: content,
        campaign_id: campaign.id.to_s
      }
    end
    it 'Returns a Created (201) status code' do
      expect(last_response.status).to be 201
    end
    it 'returns the correct body' do
      expect(last_response.body).to include_json({
        name: 'test.txt',
        type: 'text/plain'
      })
    end
    it 'has created a document in the campaign' do
      campaign.reload
      expect(campaign.documents.count).to be 1
    end

    describe 'document parameters' do
      it 'has created a document with the correct name' do
        expect(campaign.documents.first.name).to eq 'test.txt'
      end
      it 'has created a document with the correct MIME type' do
        expect(campaign.documents.first.mime_type).to eq 'text/plain'
      end
    end

    describe 'AWS created document' do
      let!(:document_id) { JSON.parse(last_response.body)['id'] }
      let!(:name) { "#{campaign.id}/documents/#{document_id}" }
      let(:file_content) { Services::Amazon.instance.content(name) }

      it 'has created the document on AWS' do
        expect(Services::Amazon.instance.stored?(name)).to be true
      end
      it 'has the correct content' do
        expect(file_content).to eq Base64.decode64(content.split(',', 2).last)
      end
    end
  end

  it_behaves_like 'a route', 'post', '/campaign_id/documents'

  describe :errors do

    describe '400 errors' do
      describe 'document content not given' do
        before do
          post '/uploads/documents',{
            session_id: session.token,
            app_key: appli.key,
            token: gateway.token,
            name: 'test.txt',
            campaign_id: campaign.id.to_s
          }
        end
        it 'Returns a Bad request (400) status code' do
          expect(last_response.status).to be 400
        end
        it 'Returns the correct body' do
          expect(last_response.body).to include_json({
            status: 400,
            field: 'content',
            error: 'required'
          })
        end
      end
      describe 'filename not given' do
        before do
          post '/uploads/documents', {
            session_id: session.token,
            app_key: appli.key,
            token: gateway.token,
            size: 30,
            content: content,
            campaign_id: campaign.id.to_s
          }
        end
        it 'Returns a Bad request (400) status code' do
          expect(last_response.status).to be 400
        end
        it 'Returns the correct body' do
          expect(last_response.body).to include_json({
            status: 400,
            field: 'name',
            error: 'required'
          })
        end
      end
      describe 'invalid MIME type' do
        before do
          post '/uploads/documents', {
            session_id: session.token,
            app_key: appli.key,
            token: gateway.token,
            size: 30,
            name: 'test.txt',
            content: invalid_content,
            campaign_id: campaign.id.to_s
          }
        end
        it 'Returns a Bad request (400) status code' do
          expect(last_response.status).to be 400
        end
        it 'Returns the correct body' do
          expect(last_response.body).to include_json({
            status: 400,
            field: 'mime_type',
            error: 'pattern'
          })
        end
      end
      describe 'Impossibility to store the document' do
        before do
          allow(Services::Amazon.instance).to receive(:store).and_raise(StandardError.new)
          post '/uploads/documents', {
            session_id: session.token,
            app_key: appli.key,
            token: gateway.token,
            size: 30,
            name: 'test.txt',
            content: content,
            campaign_id: campaign.id.to_s
          }
        end
        it 'Returns a Bad Request (400) status code' do
          expect(last_response.status).to be 400
        end
        it 'Returns the correct body' do
          expect(last_response.body).to include_json({
            status: 400,
            field: 'storage',
            error: 'failure'
          })
        end
      end
    end

    describe '403 errors' do
      describe 'user not creator' do
        let!(:other_account) { create(:account) }
        let!(:invitation) { create(:accepted_invitation, campaign: campaign, account: other_account) }
        let!(:other_session) { create(:session, account: other_account) }

        before do
          post '/uploads/documents', {
            session_id: other_session.token,
            app_key: appli.key,
            token: gateway.token,
            name: 'test.txt',
            content: content,
            campaign_id: campaign.id.to_s
          }
        end
        it 'Returns a Forbidden (403) status code' do
          expect(last_response.status).to be 403
        end
        it 'Returns the correct body' do
          expect(last_response.body).to include_json({
            status: 403,
            field: 'session_id',
            error: 'forbidden'
          })
        end
      end
    end
  end
end