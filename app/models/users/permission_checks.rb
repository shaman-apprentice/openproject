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

module Users::PermissionChecks
  extend ActiveSupport::Concern

  included do
    delegate :preload_projects_allowed_to, to: :user_allowed_service

    # Some Ruby magic. Create methods for each entity we can have memberships on automatically
    # i.e. allowed_in_work_package? and allowed_in_any_work_package?
    Member::ALLOWED_ENTITIES.each do |entity_model_name|
      entity_name_underscored = entity_model_name.underscore
      entity_class = entity_model_name.constantize

      define_method "allowed_in_#{entity_name_underscored}?" do |permission, entity|
        allowed_in_entity?(permission, entity, entity_class)
      end

      define_method "allowed_in_any_#{entity_name_underscored}?" do |permission, in_project: nil|
        allowed_in_any_entity?(permission, entity_class, in_project:)
      end
    end
  end

  class_methods do
    def allowed(action, project)
      Authorization.users(action, project)
    end

    def allowed_members(action, project)
      Authorization.users(action, project).where.not(members: { id: nil })
    end
  end

  def reload(*args)
    @user_permissible_service = nil
    @user_allowed_service = nil
    @project_role_cache = nil

    super
  end

  # All the new methods to check for permissions. This will completely replace the old interface:
  delegate :allowed_globally?,
           :allowed_in_project?,
           :allowed_in_any_project?,
           :allowed_in_entity?,
           :allowed_in_any_entity?,
           to: :user_permissible_service

  # Return user's roles for project
  def roles_for_project(project)
    project_role_cache.fetch(project)
  end
  alias :roles :roles_for_project

  # Return true if the user is a member of project
  def member_of?(project)
    roles_for_project(project).any?(&:member?)
  end

  def all_permissions_for(context)
    Authorization
      .roles(self, context)
      .includes(:role_permissions)
      .pluck(:permission)
      .compact
      .uniq
      .map(&:to_sym)
  end

  # Old allowed_to? interface. Marked as deprecated, should be removed at some point ... Guessing 14.0?

  def allowed_to?(action, context, global: false)
    # OpenProject::Deprecation.deprecate_method(User, :allowed_to?)
    user_allowed_service.call(action, context, global:)
  end

  def allowed_to_in_project?(action, project)
    # OpenProject::Deprecation.replaced(:allowed_to_in_project?, :allowed_in_project?, caller)
    allowed_to?(action, project)
  end

  def allowed_to_globally?(action)
    OpenProject::Deprecation.replaced(:allowed_to_globally?, :allowed_globally?, caller)
    allowed_to?(action, nil, global: true)
  end

  private

  def user_allowed_service
    @user_allowed_service ||= ::Authorization::UserAllowedService.new(self, role_cache: project_role_cache)
  end

  def user_permissible_service
    @user_permissible_service ||= ::Authorization::UserPermissibleService.new(self)
  end

  def project_role_cache
    @project_role_cache ||= ::Users::ProjectRoleCache.new(self)
  end
end
