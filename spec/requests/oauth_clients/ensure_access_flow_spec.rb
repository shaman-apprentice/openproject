#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'
require_module_spec_helper

RSpec.describe "OAuth Client /ensure_access endpoint", :webmock do
  shared_let(:user) { create(:user) }
  shared_let(:storage) { create(:nextcloud_storage, :with_oauth_client) }
  shared_let(:oauth_client) { storage.oauth_client }

  describe '#ensure_access' do
    context 'when user is not logged in' do
      it 'requires login' do
        get oauth_clients_ensure_access_url(oauth_client_id: oauth_client.client_id)
        expect(last_response.status).to eq(401)
      end
    end

    context 'when user is logged in' do
      before { login_as(user) }

      context 'when storage has oauth client configured' do
        context 'when user is not "connected"' do
          let(:nonce) { '57a17c3f-b2ed-446e-9dd8-651ba3aec37d' }

          before do
            allow(SecureRandom).to receive(:uuid).and_call_original.ordered
            allow(SecureRandom).to receive(:uuid).and_return(nonce).ordered
          end

          context 'when redirect_url parameter is absent' do
            it 'redirects to storage authorization_uri with ensure_access_success_url in oauth_state_* cookie' do
              get oauth_clients_ensure_access_url(oauth_client_id: oauth_client.client_id)

              oauth_client = storage.oauth_client
              expect(last_response.status).to eq(302)
              expect(last_response.cookies["oauth_state_#{nonce}"]).to eq(["http%3A%2F%2Fwww.example.com%2Foauth_clients%2F#{oauth_client.client_id}%2Fstatus"])
              expect(last_response.body).to eq(
                "<html><body>You are being <a href=\"#{storage.host}/index.php/apps/oauth2/authorize?client_id=" \
                "#{oauth_client.client_id}&amp;redirect_uri=#{CGI.escape(OpenProject::Application.root_url)}%2Foauth_clients%2F#{oauth_client.client_id}%2F" \
                "callback&amp;response_type=code&amp;state=#{nonce}\">redirected</a>." \
                "</body></html>"
              )
            end
          end

          context 'when redirect_url parameter is present' do
            it 'redirects to storage authorization_uri with redirect_url in oauth_state_* cookie',
               skip: "waiting for static redirect url to be implemented" do
              get oauth_clients_ensure_access_url(oauth_client_id: storage.oauth_client.id)
              # get storage_ensure_access_url(id: storage.id, redirect_url: "#{storage.host}/index.php/f/131?openfile=1")

              oauth_client = storage.oauth_client
              expect(last_response.status).to eq(302)
              expect(last_response.body).to eq(
                "<html><body>You are being <a href=\"#{storage.host}/index.php/apps/oauth2/authorize?client_id=" \
                "#{oauth_client.client_id}&amp;redirect_uri=#{CGI.escape(OpenProject::Application.root_url)}%2Foauth_clients%2F#{oauth_client.client_id}%2F" \
                "callback&amp;response_type=code&amp;state=#{nonce}\">redirected</a>." \
                "</body></html>"
              )
              expect(last_response.cookies["oauth_state_#{nonce}"]).to eq(["https%3A%2F%2Fhost1.example.com%2Findex.php%2Ff%2F131%3Fopenfile%3D1"])
            end
          end
        end

        context 'when user is "connected"' do
          let!(:oauth_client_token) do
            create(:oauth_client_token, oauth_client:, user:)
          end

          before do
            stub_request(:get, "#{storage.host}/ocs/v1.php/cloud/user")
              .with(
                headers: {
                  'Accept' => 'application/json',
                  'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                  'Authorization' => "Bearer #{oauth_client_token.access_token}",
                  'Ocs-Apirequest' => 'true',
                  'User-Agent' => 'Ruby'
                }
              )
              .to_return(status: 200, body: "", headers: {})
          end

          context 'when redirect_url parameter is absent' do
            it 'redirects to ensure_access_success_url' do
              get oauth_clients_ensure_access_url(oauth_client_id: oauth_client.client_id)

              expect(last_response.status).to eq(302)
              expect(last_response.body).to eq(
                "<html><body>You are being <a href=\"http://www.example.com/oauth_clients/#{oauth_client.client_id}/status\">redirected</a>.</body></html>"
              )
              expect(last_response.cookies.keys).to eq(["_open_project_session"])
            end
          end

          context 'when redirect_url parameter is present' do
            it 'redirects to redirect_url', skip: "waiting for static redirect url to be implemented" do
              get oauth_clients_ensure_access_url(oauth_client_id: storage.oauth_client.id)
              # get storage_ensure_access_url(id: storage.id, redirect_url: "#{storage.host}/index.php/f/131?openfile=1")

              expect(last_response.status).to eq(302)
              expect(last_response.body).to eq(
                "<html><body>You are being <a href=\"#{storage.host}/index.php/f/131?openfile=1\">redirected</a>.</body></html>"
              )
            end
          end
        end
      end
    end
  end

  # describe '#ensure_access_success' do
  #   it 'requires login when user is not logged in' do
  #     get storage_ensure_access_success_url(id: storage.id)
  #     expect(last_response.status).to eq(401)
  #   end

  #   it 'renders ensure_access_success page when user is logged in' do
  #     login_as(user)

  #     get storage_ensure_access_success_url(id: storage.id)
  #     expect(last_response.status).to eq(200)
  #     expect(last_response.body).to eq("<h1>\n    The connection to #{storage.host} has been established successfully.\n</h1>\n")
  #   end
  # end
end
