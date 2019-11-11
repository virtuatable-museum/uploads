RSpec.describe Controllers::Characters do

  def app
    Controllers::Characters.new
  end

  let!(:account) { create(:account) }
  let!(:gateway) { create(:gateway) }
  let!(:appli) { create(:application, creator: account) }
  let!(:session) { create(:session, account: account) }

  let!(:campaign) { create(:campaign, creator: account) }
  let!(:content) { 'data:application/xml;base64,dGVzdApzYXV0IGRlIGxpZ25lIGV0IGVzcGFjZXM=' }

  let!(:michel) { create(:account, username: 'Michel', email: 'michel@mail.com') }
  let!(:invitation) { create(:invitation, campaign: campaign, account: michel, enum_status: :accepted) }

  # Creation of a new character in a campaign.
  describe 'POST /uploads/characters' do
    describe 'Nominal case' do
      before do
        post '/uploads/characters', {
          campaign_id: campaign.id.to_s,
          content: content,
          name: 'test.dnd4e',
          token: gateway.token,
          app_key: appli.key,
          session_id: session.token,
          invitation_id: invitation.id
        }
      end
      it 'Returns a 201 (created) Status code ' do
        expect(last_response.status).to be 201
      end
      it 'Returns the correct body' do
        expect(last_response.body).to include_json(message: 'created')
      end
      it 'Creates the character in the database' do
        expect(campaign.characters.count).to be 1
      end
      it 'Creates the character in AWS S3' do
        name = "#{campaign.id}/characters/test.dnd4e"
        expect(Services::Amazon.instance.stored?(name)).to be true
      end
    end

    it_should_behave_like 'a route', 'post', '/campaigns/upload'

    describe 'errors' do
      describe '400 errors' do
        describe 'Invitation ID not given' do
          before do
            post '/uploads/characters', {
              campaign_id: campaign.id.to_s,
              content: content,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: session.token
            }
          end
          it 'Returns a 400 (Bad Request) Status code' do
            expect(last_response.status).to be 400
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 400,
              field: 'invitation_id',
              error: 'required'
            )
          end
          it 'Has not created the character in the database' do
            expect(campaign.characters.count).to be 0
          end
        end
        describe 'Name not given' do
          before do
            post '/uploads/characters', {
              campaign_id: campaign.id.to_s,
              content: content,
              token: gateway.token,
              app_key: appli.key,
              session_id: session.token,
              invitation_id: invitation.id
            }
          end
          it 'Returns a Bad Request (400) status code' do
            expect(last_response.status).to be 400
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 400,
              field: 'name',
              error: 'required'
            )
          end
          it 'Did not create the file in the database' do
            expect(campaign.characters.count).to be 0
          end
        end
        describe 'Content not given' do
          before do
            post '/uploads/characters', {
              campaign_id: campaign.id.to_s,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: session.token,
              invitation_id: invitation.id
            }
          end
          it 'Returns a Bad Request (400) status code' do
            expect(last_response.status).to be 400
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 400,
              field: 'content',
              error: 'required'
            )
          end
          it 'Did not create the file in the database' do
            expect(campaign.characters.count).to be 0
          end
        end
        describe 'Campaign ID not given' do
          before do
            post '/uploads/characters', {
              content: content,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: session.token,
              invitation_id: invitation.id
            }
          end
          it 'Returns a Bad Request (400) status code' do
            expect(last_response.status).to be 400
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 400,
              field: 'campaign_id',
              error: 'required'
            )
          end
          it 'Did not create the file in the database' do
            expect(campaign.characters.count).to be 0
          end
        end
        # This error is a bit tricky to trigger as the campaign needs to be in a ruleset
        # that has a sheet template only allowing a MIME type not corresponding to the
        # MIME type of the uploaded file (inferred from its base 64 content)
        describe 'Wrong MIME type' do
          let!(:ruleset) { create(:ruleset, creator: account, mime_types: ['application/xml']) }
          let!(:sheet) { create(:sheet, creator: account, ruleset: ruleset) }
          let!(:campaign) { create(:campaign, creator: account, ruleset: ruleset) }
          let!(:content) { 'data:text/plain;base64,dGVzdApzYXV0IGRlIGxpZ25lIGV0IGVzcGFjZXM=' }
          before do
            post '/uploads/characters', {
              campaign_id: campaign.id.to_s,
              content: content,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: session.token,
              invitation_id: invitation.id
            }
          end
          it 'Returns a 400 (Bad Request) error' do
            expect(last_response.status).to be 400
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 400,
              field: 'mime_type',
              error: 'pattern'
            )
          end
          it 'Did not create the file in the database' do
            expect(campaign.characters.count).to be 0
          end
        end
      end
      describe '403 errors' do
        let!(:michel_session) { create(:session, account: michel, token: 'michel token') }

        describe 'When the account is not invited in the campaign' do
          before do
            post '/uploads/characters', {
              campaign_id: campaign.id.to_s,
              content: content,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: michel_session.token,
              invitation_id: invitation.id
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
            expect(last_response.status).to be 403
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 403,
              field: 'session_id',
              error: 'forbidden'
            )
          end
          it 'Did not create the character in the campaign' do
            expect(campaign.characters.count).to be 0
          end
        end
        describe 'When the account is not creator of the campaign' do
          let!(:invitation) { create(:invitation, enum_status: :accepted, account: michel, campaign: campaign) }

          before do
            post '/uploads/characters', {
              campaign_id: campaign.id.to_s,
              content: content,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: michel_session.token,
              invitation_id: invitation.id
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
            expect(last_response.status).to be 403
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 403,
              field: 'session_id',
              error: 'forbidden'
            )
          end
          it 'Did not create the character in the campaign' do
            expect(campaign.characters.count).to be 0
          end
        end
      end
      describe '404 errors' do
        describe 'When the invitation does not exist in the campaign' do
          before do
            post '/uploads/characters', {
              content: content,
              campaign_id: campaign.id.to_s,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: session.token,
              invitation_id: 'pouet pouet'
            }
          end
          it 'Returns a 404 (Not Found) Status code' do
            expect(last_response.status).to be 404
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 404,
              field: 'invitation_id',
              error: 'unknown'
            )
          end
        end
        describe 'When the session does not exist' do
          before do
            post '/uploads/characters', {
              content: content,
              campaign_id: campaign.id.to_s,
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: 'pouet pouet',
              invitation_id: invitation.id
            }
          end
          it 'Returns a 404 (Not Found) Status code' do
            expect(last_response.status).to be 404
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 404,
              field: 'session_id',
              error: 'unknown'
            )
          end
        end
        describe 'When the campaign does not exist' do
          before do
            post '/uploads/characters', {
              content: content,
              campaign_id: 'pouet pouet',
              name: 'test.dnd4e',
              token: gateway.token,
              app_key: appli.key,
              session_id: session.token,
              invitation_id: invitation.id
            }
          end
          it 'Returns a 404 (Not Found) Status code' do
            expect(last_response.status).to be 404
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 404,
              field: 'campaign_id',
              error: 'unknown'
            )
          end
        end
      end
    end
  end
end