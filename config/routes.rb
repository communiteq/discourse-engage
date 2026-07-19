# frozen_string_literal: true

DiscourseEngage::Engine.routes.draw do
  scope "/admin/plugins/discourse-engage", constraints: StaffConstraint.new do
    get "/api/surveys" => "admin_surveys#index"
    get "/api/surveys/:id/entries" => "admin_surveys#entries"
    get "/api/surveys/:id/export" => "admin_surveys#export"
    get "/api/surveys/:id" => "admin_surveys#show"
    post "/api/surveys" => "admin_surveys#create"
    put "/api/surveys/:id" => "admin_surveys#update"
    delete "/api/surveys/:id" => "admin_surveys#destroy"
    delete "/api/surveys/:id/entries/:user_id/:response_id" => "admin_surveys#destroy_entry"
  end

  scope "/discourse-engage" do
    get "/eligible" => "surveys#eligible"
    post "/surveys/:id/decision" => "surveys#decision"
    post "/surveys/:id/responses" => "surveys#submit_response"
  end
end
