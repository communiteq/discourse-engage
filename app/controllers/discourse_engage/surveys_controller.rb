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

      render_json_dump(
        survey: {
          id: survey["id"],
          title: survey["title"],
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
        tomorrow = now + 1.day
        DiscourseEngage::Store.set_state(
          survey["id"],
          current_user.id,
          status: "deferred",
          next_eligible_at: tomorrow.iso8601,
        )
        current_user.custom_fields[next_field(survey["id"])] = tomorrow.iso8601
        current_user.save_custom_fields(true)
      when "decline"
        DiscourseEngage::Store.set_state(survey["id"], current_user.id, status: "declined")
        current_user.custom_fields[declined_field(survey["id"])] = "true"
        current_user.save_custom_fields(true)
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
      current_user.custom_fields[completed_field(survey["id"])] = "true"
      current_user.save_custom_fields(true)

      render_json_dump(response: response)
    end

    private

    def completed_field(survey_id)
      "engage_completed_#{survey_id}"
    end

    def declined_field(survey_id)
      "engage_declined_#{survey_id}"
    end

    def next_field(survey_id)
      "engage_next_#{survey_id}"
    end
  end
end
