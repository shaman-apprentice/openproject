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

# A ProjectStorage is a kind of relation between a Storage and
# a Project in order to enable or disable a Storage for a specific
# WorkPackages in the project.
# See also: file_link.rb and storage.rb
class Storages::ProjectStorage < ApplicationRecord
  using Storages::Peripherals::ServiceResultRefinements

  belongs_to :project, touch: true
  belongs_to :storage, touch: true, class_name: 'Storages::Storage'
  belongs_to :creator, class_name: 'User'

  has_many :last_project_folders,
           class_name: 'Storages::LastProjectFolder',
           dependent: :destroy

  # There should be only one ProjectStorage per project and storage.
  validates :project, uniqueness: { scope: :storage }

  enum project_folder_mode: {
    inactive: 'inactive',
    manual: 'manual',
    automatic: 'automatic'
  }.freeze, _prefix: 'project_folder'

  scope :automatic, -> { where(project_folder_mode: 'automatic') }

  def automatic_management_possible?
    storage.present? && storage.provider_type_nextcloud? && storage.automatically_managed?
  end

  def project_folder_path
    "#{storage.group_folder}/#{project.name.tr('/', '|')} (#{project.id})/"
  end

  def project_folder_path_escaped
    escape_path(project_folder_path)
  end

  def file_inside_project_folder?(escaped_file_path)
    escaped_file_path.match?(%r|^/#{project_folder_path_escaped}|)
  end

  def open_link
    if project_folder_inactive?
      storage.open_link
    else
      call = ::Storages::Peripherals::Registry.resolve("queries.#{storage.short_provider_type}.open_link")
                                              .call(storage:, user: User.current, file_id: project_folder_id)
      call.match(
        on_success: ->(url) { url },
        on_failure: ->(*) { storage.open_link }
      )
    end
  end

  private

  def escape_path(path)
    ::Storages::Peripherals::StorageInteraction::Nextcloud::Util.escape_path(path)
  end
end
