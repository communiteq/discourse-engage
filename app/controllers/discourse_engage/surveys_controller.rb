# frozen_string_literal: true

module DiscourseEngage
  class SurveysController < ::ApplicationController
    requires_plugin DiscourseEngage::PLUGIN_NAME
    requires_login

    def eligible
      survey = DiscourseEngage::EligibilityService.first_eligible_for(current_user)

      if survey.blank?
        render_json_dump(survey: nil)
        return
      end

      allow_decline = bool_setting(survey, "allow_decline", default: true)
      allow_defer = bool_setting(survey, "allow_defer", default: true)
      skip_prompt = !allow_decline && !allow_defer

      render_json_dump(
        survey: {
          id: survey["id"],
          title: survey["title"],
          allow_decline: allow_decline,
          allow_defer: allow_defer,
          skip_prompt: skip_prompt,
          survey_json: survey["survey_json"],
        },
      )
    end

    def decision
      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      action = params.require(:decision)
      now = Time.zone.now

      case action
      when "start"
        DiscourseEngage::Store.set_state(
          survey["id"],
          current_user.id,
          status: "started",
          last_prompted_at: now.iso8601,
        )
      when "defer"
        raise Discourse::InvalidAccess.new unless bool_setting(survey, "allow_defer", default: true)

        tomorrow = now + 1.day
        DiscourseEngage::Store.set_state(
          survey["id"],
          current_user.id,
          status: "deferred",
          next_eligible_at: tomorrow.iso8601,
        )
      when "decline"
        raise Discourse::InvalidAccess.new unless bool_setting(survey, "allow_decline", default: true)

        DiscourseEngage::Store.set_state(survey["id"], current_user.id, status: "declined")
      else
        raise Discourse::InvalidParameters.new(:decision)
      end

      render json: success_json
    end

    def submit_response
      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      answers = params.require(:answers)
      metadata = params[:metadata] || {}

      if !DiscourseEngage::EligibilityService.eligible_for_survey?(survey, current_user)
        state = DiscourseEngage::Store.get_state(survey["id"], current_user.id)
        raise Discourse::InvalidAccess.new if state["status"] != "started"
      end

      response =
        DiscourseEngage::Store.store_response(
          survey_id: survey["id"],
          user_id: current_user.id,
          answers: answers,
          metadata: metadata,
        )

      DiscourseEngage::Store.set_state(survey["id"], current_user.id, status: "completed")

      render_json_dump(response: response)
    end

    private

    def bool_setting(hash, key, default: true)
      # Use .key? to check for presence without being fooled by falsy values
      value = if hash.key?(key)
        hash[key]
      elsif hash.key?(key.to_sym)
        hash[key.to_sym]
      else
        return default
      end

      return value if value == true || value == false

      case value.to_s.strip.downcase
      when "true", "1", "yes", "on"
        true
      when "false", "0", "no", "off"
        false
      else
        default
      end
    end
  end
end
