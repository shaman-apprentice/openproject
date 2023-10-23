# frozen_string_literal: true

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

# Purpose: CRUD the global admin page of Storages (=Nextcloud servers)
class Storages::Admin::StoragesController < ApplicationController
  using Storages::Peripherals::ServiceResultRefinements

  # See https://guides.rubyonrails.org/layouts_and_rendering.html for reference on layout
  layout 'admin'

  # specify which model #find_model_object should look up
  model_object Storages::Storage

  # Before executing any action below: Make sure the current user is an admin
  # and set the @<controller_name> variable to the object referenced in the URL.
  before_action :require_admin
  before_action :find_model_object, only: %i[show destroy edit update replace_oauth_application]

  # menu_item is defined in the Redmine::MenuManager::MenuController
  # module, included from ApplicationController.
  # The menu item is defined in the engine.rb
  menu_item :storages_admin_settings

  # Index page with a list of Storages objects
  # Called by: Global app/config/routes.rb to serve Web page
  def index
    @storages = Storages::Storage.all
  end

  # Show the admin page to create a new Storage object.
  # Sets the attributes provider_type and name as default values and then
  # renders the new page (allowing the user to overwrite these values and to
  # fill in other attributes).
  # Used by: The index page above, when the user presses the (+) button.
  # Called by: Global app/config/routes.rb to serve Web page
  def new
    # Set default parameters using a "service".
    # See also: storages/services/storages/storages/set_attributes_services.rb
    # That service inherits from ::BaseServices::SetAttributes
    @storage = ::Storages::Storages::SetAttributesService
                 .new(user: current_user,
                      model: Storages::NextcloudStorage.new,
                      contract_class: EmptyContract)
                 .call
                 .result
  end

  # rubocop:disable Metrics/AbcSize
  def create
    service_result = Storages::Storages::CreateService.new(user: current_user).call(permitted_storage_params)

    @storage = service_result.result
    @oauth_application = oauth_application(service_result)

    service_result.on_failure do
      @errors = service_result.errors
      render :new
    end

    service_result.on_success do
      case @storage.provider_type
      when ::Storages::Storage::PROVIDER_TYPE_ONE_DRIVE
        flash[:notice] = I18n.t(:notice_successful_create)
        render '/storages/admin/storages/one_drive/edit'
      when ::Storages::Storage::PROVIDER_TYPE_NEXTCLOUD
        if @oauth_application.present?
          flash.now[:notice] = I18n.t(:notice_successful_create)
          render :show_oauth_application
        end
      else
        raise "Unknown provider type: #{storage_params['provider_type']}"
      end
    end
  end

  # rubocop:enable Metrics/AbcSize

  # Edit page is very similar to new page, except that we don't need to set
  # default attribute values because the object already exists;
  # Called by: Global app/config/routes.rb to serve Web page
  def edit; end

  # Update is similar to create above
  # See also: create above
  # Called by: Global app/config/routes.rb to serve Web page
  def update
    storage_params = permitted_storage_params
    parts = storage_params[:drive_id].split(',')

    storage_params[:drive_id] = parts.count > 1 ? parts[1] : parts[0]

    service_result = ::Storages::Storages::UpdateService
                       .new(user: current_user, model: @storage)
                       .call(storage_params)

    if service_result.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to edit_admin_settings_storage_path(@storage)
    else
      @errors = service_result.errors
      render :edit
    end
  end

  def destroy
    Storages::Storages::DeleteService
      .new(user: User.current, model: @storage)
      .call
      .match(
        # rubocop:disable Rails/ActionControllerFlashBeforeRender
        on_success: ->(*) { flash[:notice] = I18n.t(:notice_successful_delete) },
        on_failure: ->(error) { flash[:error] = error.full_messages }
        # rubocop:enable Rails/ActionControllerFlashBeforeRender
      )

    redirect_to admin_settings_storages_path
  end

  def replace_oauth_application
    @storage.oauth_application.destroy
    service_result = ::Storages::OAuthApplications::CreateService.new(storage: @storage, user: current_user).call

    if service_result.success?
      flash[:notice] = I18n.t('storages.notice_oauth_application_replaced')
      @oauth_application = service_result.result
      render :show_oauth_application
    else
      @errors = service_result.errors
      render :edit
    end
  end

  # Used by: admin layout
  # Breadcrumbs is something like OpenProject > Admin > Storages.
  # This returns the name of the last part (Storages admin page)
  def default_breadcrumb
    if action_name == 'index'
      t(:project_module_storages)
    else
      ActionController::Base.helpers.link_to(t(:project_module_storages), admin_settings_storages_path)
    end
  end

  # See: default_breadcrum above
  # Defines whether to show breadcrumbs on the page or not.
  def show_local_breadcrumb
    !OpenProject::FeatureDecisions.storage_primer_design_active?
  end

  private

  def oauth_application(service_result)
    service_result.dependent_results&.first&.result
  end

  # Called by create and update above in order to check if the
  # update parameters are correctly set.
  def permitted_storage_params
    params
      .require(:storages_storage)
      .permit('name', 'provider_type', 'host', 'oauth_client_id', 'oauth_client_secret', 'tenant_id', 'drive_id')
  end
end
