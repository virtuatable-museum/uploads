RSpec.describe Controllers::Characters do

  def app
    Controllers::Characters.new
  end

  let!(:account) { create(:account) }
  let!(:gateway) { create(:gateway) }
  let!(:appli) { create(:application, creator: account) }
  let!(:session) { create(:session, account: account) }
  let!(:amazon) { Services::Amazon.instance }

  let!(:campaign) { create(:campaign, creator: account) }
  let!(:base_content) { 'dGVzdApzYXV0IGRlIGxpZ25lIGV0IGVzcGFjZXM=' }
  let!(:content) { "data:application/xml;base64,#{base_content}" }

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
      describe 'Created file on AWS' do
        let!(:character_id) { JSON.parse(last_response.body)['id'] }
        let!(:name) { "#{campaign.id}/characters/#{character_id}" }

        it 'Creates the character in AWS S3' do
          expect(amazon.stored?(name)).to be true
        end
        it 'Has the correct content' do
          expect(amazon.content(name)).to eq Base64.decode64(base_content)
        end
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

  # Getting the file content for the character as raw text
  describe 'GET /uploads/characters/:id' do
    let!(:jacques) { create(:account, username: 'Jacques', email: 'jacques@test.com') }
    let!(:session_jacques) { create(:session, account: jacques, token: 'token_jacques') }

    describe 'Nominal case' do
      let!(:invitation) { create(:invitation, campaign: campaign, enum_status: :accepted, account: jacques) }
      let!(:character) { create(:character, invitation: invitation) }
      before do
        amazon.store("#{campaign.id.to_s}/characters/#{character.id.to_s}", Base64.decode64(base_content))
        get "/uploads/characters/#{character.id.to_s}", {
          token: gateway.token,
          app_key: appli.key,
          session_id: 'token_jacques',
          campaign_id: campaign.id.to_s
        }
      end
      it 'Returns a OK (200) status code' do
        expect(last_response.status).to be 200
      end
      it 'Returns the correct body' do
        expect(last_response.body).to eq Base64.decode64(base_content)
      end
    end
    describe 'errors' do
      describe '400 errors' do
        let!(:invitation) { create(:invitation, campaign: campaign, enum_status: :accepted, account: jacques) }
        let!(:character) { create(:character, invitation: invitation) }
        describe 'Campaign ID not given' do
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              token: gateway.token,
              app_key: appli.key,
              session_id: 'token_jacques'
            }
          end
          it 'Returns a 400 (Bad Request) status code' do
            expect(last_response.status).to be 400
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json({
              status: 400,
              field: 'campaign_id',
              error: 'required'
            })
          end
        end
        describe 'Session ID not given' do
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              token: gateway.token,
              app_key: appli.key,
              campaign_id: campaign.id.to_s
            }
          end
          it 'Returns a 400 (Bad Request) status code' do
            expect(last_response.status).to be 400
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json({
              status: 400,
              field: 'session_id',
              error: 'required'
            })
          end
        end
      end
      describe '403 errors' do
        let!(:ferdinand) { create(:account, username: 'ferdinand', email: 'ferdinand@test.com') }
        let!(:session_ferdinand) { create(:session, token: 'session_ferdinand', account: ferdinand) }

        describe 'When the invitation is :expelled' do
          let!(:invitation) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :expelled) }
          let!(:character) { create(:character, invitation: invitation) }
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              session_id: 'session_ferdinand',
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
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
        describe 'When the invitation is :pending' do
          let!(:invitation) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :pending) }
          let!(:character) { create(:character, invitation: invitation) }
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              session_id: 'session_ferdinand',
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
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
        describe 'When the invitation is :request' do
          let!(:invitation) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :request) }
          let!(:character) { create(:character, invitation: invitation) }
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              session_id: 'session_ferdinand',
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
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
        describe 'When the invitation is :left' do
          let!(:invitation) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :left) }
          let!(:character) { create(:character, invitation: invitation) }
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              session_id: 'session_ferdinand',
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
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
        describe 'When the invitation is :blocked' do
          let!(:invitation) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :blocked) }
          let!(:character) { create(:character, invitation: invitation) }
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              session_id: 'session_ferdinand',
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
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
        describe 'When the invitation is :ignored' do
          let!(:invitation) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :ignored) }
          let!(:character) { create(:character, invitation: invitation) }
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              session_id: 'session_ferdinand',
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
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
        describe 'When the invitation is :refused' do
          let!(:invitation) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :refused) }
          let!(:character) { create(:character, invitation: invitation) }
          before do
            get "/uploads/characters/#{character.id.to_s}", {
              session_id: 'session_ferdinand',
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key
            }
          end
          it 'Returns a 403 (Forbidden) status code' do
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
      describe '404 errors' do
        let!(:ferdinand) { create(:account, username: 'ferdinand', email: 'ferdinand@test.com') }
        let!(:session_ferdinand) { create(:session, token: 'session_ferdinand', account: ferdinand) }
        let!(:ferdinand_inv) { create(:invitation, campaign: campaign, account: ferdinand, enum_status: :accepted) }
        let!(:character) { create(:character, invitation: ferdinand_inv) }
        
        describe 'When the campaign is not found' do
          before do
            get "/uploads/characters/#{character.id}", {
              campaign_id: 'test unknown',
              token: gateway.token,
              app_key: appli.key,
              session_id: session_ferdinand.token
            }
          end
          it 'Returns a 404 (Not Found) status code' do
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
        describe 'When the session is not found' do
          before do
            get "/uploads/characters/#{character.id}", {
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key,
              session_id: 'token unknown'
            }
          end
          it 'Returns a 404 (Not Found) status code' do
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
        describe 'When the character is not found' do
          before do
            get "/uploads/characters/unknown", {
              campaign_id: campaign.id.to_s,
              token: gateway.token,
              app_key: appli.key,
              session_id: session_ferdinand.token
            }
          end
          it 'Returns a 404 (Not Found) status code' do
            expect(last_response.status).to be 404
          end
          it 'Returns the correct body' do
            expect(last_response.body).to include_json(
              status: 404,
              field: 'character_id',
              error: 'unknown'
            )
          end
        end
      end
    end
  end
end