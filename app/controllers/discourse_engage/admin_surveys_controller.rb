# frozen_string_literal: true

require "csv"

module DiscourseEngage
  class AdminSurveysController < ::Admin::AdminController
    requires_plugin DiscourseEngage::PLUGIN_NAME
    skip_before_action :check_xhr, only: [:export]

    def index
      surveys = DiscourseEngage::Store.list_surveys
      survey_ids = surveys.map { |s| s["id"] || s[:id] }

      entry_counts =
        survey_ids.each_with_object({}) do |sid, h|
          h[sid] = DiscourseEngage::Store.count_responses(sid)
        end

      state_counts = DiscourseEngage::Store.count_states_by_status

      render_json_dump(
        surveys: surveys,
        entry_counts: entry_counts,
        state_counts: state_counts,
      )
    end

    def show
      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      render_json_dump(survey: survey)
    end

    def create
      payload = survey_payload
      survey = DiscourseEngage::Store.upsert_survey(payload)
      render_json_dump(survey: survey)
    rescue Discourse::InvalidParameters => e
      render_json_error(e.message)
    end

    def update
      raise Discourse::InvalidParameters.new(:id) if params[:id].blank?

      existing = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if existing.blank?

      payload = survey_payload(existing: existing).merge(id: params[:id])
      survey = DiscourseEngage::Store.upsert_survey(payload)
      render_json_dump(survey: survey)
    rescue Discourse::InvalidParameters => e
      render_json_error(e.message)
    end

    def destroy
      raise Discourse::InvalidParameters.new(:id) if params[:id].blank?

      DiscourseEngage::Store.delete_survey(params[:id])
      render json: success_json
    end

    def destroy_entry
      raise Discourse::InvalidParameters.new(:id) if params[:id].blank?
      raise Discourse::InvalidParameters.new(:participant_key) if params[:participant_key].blank?
      raise Discourse::InvalidParameters.new(:response_id) if params[:response_id].blank?

      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      participant = parse_participant_key!(params[:participant_key])
      DiscourseEngage::Store.delete_response(
        params[:id],
        participant[:type],
        participant[:id],
        params[:response_id],
      )

      if params[:reset].to_s == "true"
        DiscourseEngage::Store.reset_user_state(
          params[:id],
          participant[:type],
          participant[:id],
        )
      end

      render json: success_json
    end

    def entries
      raise Discourse::InvalidParameters.new(:id) if params[:id].blank?

      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      responses = DiscourseEngage::Store.list_responses(params[:id])
      user_ids = responses.filter_map { |r| response_identity(r)[:user_id] }.uniq
      users_by_id = User.where(id: user_ids).index_by(&:id)

      entries =
        responses.map do |r|
          identity = response_identity(r)
          user = identity[:user_id].present? ? users_by_id[identity[:user_id]] : nil
          {
            entry_id: "#{identity[:participant_key] || 'unknown'}:#{r["response_id"] || r[:response_id]}",
            response_id: r["response_id"] || r[:response_id],
            participant_key: identity[:participant_key],
            participant_type: identity[:participant_type],
            user_id: identity[:user_id],
            username: display_name_for(identity, user),
            submitted_at: r["submitted_at"] || r[:submitted_at],
            answers: r["answers"] || r[:answers] || {},
          }
        end

      render_json_dump(survey: survey, entries: entries)
    end

    def export
      raise Discourse::InvalidParameters.new(:id) if params[:id].blank?

      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      responses = DiscourseEngage::Store.list_responses(params[:id])
      user_ids = responses.filter_map { |r| response_identity(r)[:user_id] }.uniq
      users_by_id = User.where(id: user_ids).index_by(&:id)

      csv_data = CSV.generate do |csv|
        csv << ["Participant", "Participant Type", "Submitted At", "Answers"]

        responses.each do |r|
          identity = response_identity(r)
          user = identity[:user_id].present? ? users_by_id[identity[:user_id]] : nil
          csv << [
            display_name_for(identity, user),
            identity[:participant_type] || "unknown",
            r["submitted_at"] || r[:submitted_at] || "",
            JSON.generate(r["answers"] || r[:answers] || {}),
          ]
        end
      end

      send_data(
        csv_data,
        type: "text/csv; charset=utf-8",
        disposition: "attachment",
        filename: "survey-#{params[:id]}-entries.csv"
      )
    end

    private

    def survey_payload(existing: nil)
      if params[:survey_blob].present?
        blob = parse_json_value(params[:survey_blob], :survey_blob).with_indifferent_access
        survey_json_raw = blob[:survey_json]
        rules_raw = blob[:rules_json] || blob[:rules]
        survey_json = parse_json_value(survey_json_raw, :survey_json)
        rules = parse_json_value(rules_raw, :rules)

        if existing.present?
          if survey_json_raw.blank? && existing["survey_json"].present?
            survey_json = existing["survey_json"]
          end

          if rules_raw.blank? && existing["rules"].present?
            rules = existing["rules"]
          end
        end

        title = blob[:title].presence || survey_json["title"].presence || survey_json[:title].presence
        raise Discourse::InvalidParameters.new(:title) if title.blank?

        return {
          title: title,
          status: blob[:status].presence || "draft",
          priority: blob[:priority].presence || 0,
          allow_decline: coerce_bool(blob[:allow_decline], default: true),
          allow_defer: coerce_bool(blob[:allow_defer], default: true),
          start_at: blob[:start_at],
          end_at: blob[:end_at],
          rules: rules,
          survey_json: survey_json,
          updated_by_id: current_user.id,
          created_by_id: blob[:created_by_id] || current_user.id,
        }
      end

      rules = parse_json_param(:rules)
      survey_json = parse_json_param(:survey_json)
      title = params[:title].presence || survey_json["title"].presence || survey_json[:title].presence
      raise Discourse::InvalidParameters.new(:title) if title.blank?

      {
        title: title,
        status: params[:status].presence || "draft",
        priority: params[:priority].presence || 0,
        allow_decline: coerce_bool(params[:allow_decline], default: true),
        allow_defer: coerce_bool(params[:allow_defer], default: true),
        start_at: params[:start_at],
        end_at: params[:end_at],
        rules: rules,
        survey_json: survey_json,
        updated_by_id: current_user.id,
        created_by_id: params[:created_by_id] || current_user.id,
      }
    end

    def parse_json_param(key)
      value = params[key]
      parse_json_value(value, key)
    rescue JSON::ParserError
      raise Discourse::InvalidParameters.new(key)
    end

    def parse_json_value(value, key)
      return {} if value.blank?
      return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      return value if value.is_a?(Hash)

      JSON.parse(value)
    rescue JSON::ParserError
      raise Discourse::InvalidParameters.new(key)
    end

    def coerce_bool(value, default: true)
      return default if value.nil?
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

    def response_identity(response)
      response = response.with_indifferent_access
      participant_type = response[:participant_type].presence
      participant_id = response[:participant_id].presence
      user_id = response[:user_id].presence

      if participant_type.blank? && user_id.present?
        participant_type = "user"
        participant_id = user_id.to_s
      end

      participant_key = response[:participant_key].presence
      participant_key ||= DiscourseEngage::Participant.key_for(participant_type, participant_id)

      {
        participant_type: participant_type,
        participant_id: participant_id,
        participant_key: participant_key,
        user_id: user_id&.to_i,
      }
    end

    def display_name_for(identity, user)
      return user.username if user.present?
      return "Anonymous (#{identity[:participant_id]})" if identity[:participant_type] == "anon"

      "unknown"
    end

    def parse_participant_key!(value)
      parsed = DiscourseEngage::Participant.parse_key(value)
      raise Discourse::InvalidParameters.new(:participant_key) if parsed.blank?

      parsed
    end
  end
end
