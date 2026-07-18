# frozen_string_literal: true

DiscourseEngage::Engine.routes.draw do
end

Discourse::Application.routes.append do
  namespace :admin, constraints: StaffConstraint.new do
    get "plugins/discourse-engage/surveys" => "plugins#show",
        :defaults => {
          plugin_id: "discourse-engage",
        }
  end

  scope "/admin/plugins/discourse-engage", constraints: StaffConstraint.new do
    get "/api/surveys" => "discourse_engage/admin_surveys#index"
    get "/api/surveys/:id/entries" => "discourse_engage/admin_surveys#entries"
    get "/api/surveys/:id/export" => "discourse_engage/admin_surveys#export"
    get "/api/surveys/:id" => "discourse_engage/admin_surveys#show"
    post "/api/surveys" => "discourse_engage/admin_surveys#create"
    put "/api/surveys/:id" => "discourse_engage/admin_surveys#update"
    delete "/api/surveys/:id" => "discourse_engage/admin_surveys#destroy"
    delete "/api/surveys/:id/entries/:user_id/:response_id" => "discourse_engage/admin_surveys#destroy_entry"
  end

  scope "/discourse-engage" do
    get "/eligible" => "discourse_engage/surveys#eligible"
    post "/surveys/:id/decision" => "discourse_engage/surveys#decision"
    post "/surveys/:id/responses" => "discourse_engage/surveys#submit_response"
  end
end
