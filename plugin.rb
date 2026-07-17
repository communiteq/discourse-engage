# frozen_string_literal: true

# name: discourse-engage
# about: Rule-based SurveyJS engagement prompts for Discourse.
# version: 0.1
# authors: Communiteq
# url: https://github.com/communiteq/discourse-engage

enabled_site_setting :discourse_engage_enabled

register_asset "stylesheets/common/discourse-engage.scss"

module ::DiscourseEngage
  PLUGIN_NAME = "discourse-engage"
end

require_relative "lib/discourse_engage/engine"

after_initialize do
  add_admin_route(
    "discourse_engage.admin.title",
    "discourse-engage",
    { use_new_show_route: true },
  )

  require_relative "lib/discourse_engage/store"
  require_relative "lib/discourse_engage/rule_evaluator"
  require_relative "lib/discourse_engage/eligibility_service"
  require_relative "app/controllers/discourse_engage/admin_surveys_controller"
  require_relative "app/controllers/discourse_engage/surveys_controller"
  require_relative "config/routes"
end
