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

module Meetings
  class SidebarComponent < ApplicationComponent
    include ApplicationHelper
    include OpTurbo::Streamable
    include OpPrimer::ComponentHelpers

    def initialize(meeting:)
      super

      @meeting = meeting
    end

    def call
      component_wrapper do
        flex_layout(pl: 1) do |flex|
          flex.with_row(border: :bottom, pb: 2) do
            details_partial
          end
          flex.with_row(mt: 3, border: :bottom, pb: 2) do
            state_partial
          end
          flex.with_row(mt: 3) do
            participants_partial
          end
        end
      end
    end

    private

    def details_partial
      render(Meetings::Sidebar::DetailsComponent.new(meeting: @meeting))
    end

    def state_partial
      render(Meetings::Sidebar::StateComponent.new(meeting: @meeting))
    end

    def participants_partial
      render(Primer::Beta::Heading.new(tag: :h4)) { "Invitees (to-do)" }
    end
  end
end
