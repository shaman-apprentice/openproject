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

RSpec.describe "OAuth Client /status endpoint", :webmock do
  shared_let(:user) { create(:user) }
  shared_let(:storage) { create(:nextcloud_storage, :with_oauth_client) }
  shared_let(:oauth_client) { storage.oauth_client }

  describe '#status' do
    context 'when user is not logged in' do
      it 'requires login' do
        get oauth_clients_status_url(oauth_client_id: oauth_client.client_id)
        expect(last_response.status).to eq(401)
      end
    end

    context 'when user is logged in' do
      before { login_as(user) }

      it '' do
        get oauth_clients_status_url(oauth_client_id: oauth_client.client_id)

        storage.oauth_client
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("<h1>\n    #{oauth_client.client_id} failed_authorization\n</h1>\n")
      end
    end
  end
end
