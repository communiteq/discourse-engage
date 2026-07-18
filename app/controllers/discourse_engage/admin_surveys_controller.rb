# frozen_string_literal: true

require "csv"

module DiscourseEngage
  class AdminSurveysController < ::Admin::AdminController
    requires_plugin DiscourseEngage::PLUGIN_NAME
    skip_before_action :check_xhr, only: [:export]

    def index
      surveys = DiscourseEngage::Store.list_surveys
      entry_counts =
        surveys.each_with_object({}) do |s, h|
          sid = s["id"] || s[:id]
          h[sid] = DiscourseEngage::Store.count_responses(sid)
        end
      render_json_dump(surveys: surveys, entry_counts: entry_counts)
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
      raise Discourse::InvalidParameters.new(:user_id) if params[:user_id].blank?
      raise Discourse::InvalidParameters.new(:response_id) if params[:response_id].blank?

      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      DiscourseEngage::Store.delete_response(params[:id], params[:user_id].to_i, params[:response_id])
      render json: success_json
    end

    def entries
      raise Discourse::InvalidParameters.new(:id) if params[:id].blank?

      survey = DiscourseEngage::Store.get_survey(params[:id])
      raise Discourse::NotFound if survey.blank?

      responses = DiscourseEngage::Store.list_responses(params[:id])
      user_ids = responses.map { |r| r["user_id"] || r[:user_id] }.compact.uniq
      users_by_id = User.where(id: user_ids).index_by(&:id)

      entries =
        responses.map do |r|
          uid = r["user_id"] || r[:user_id]
          user = users_by_id[uid]
          {
            entry_id: "#{uid || 'unknown'}:#{r["response_id"] || r[:response_id]}",
            response_id: r["response_id"] || r[:response_id],
            user_id: uid,
            username: user&.username || "unknown",
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
      user_ids = responses.map { |r| r["user_id"] || r[:user_id] }.compact.uniq
      users_by_id = User.where(id: user_ids).index_by(&:id)

      csv_data = CSV.generate do |csv|
        csv << ["Username", "Submitted At", "Answers"]

        responses.each do |r|
          uid = r["user_id"] || r[:user_id]
          user = users_by_id[uid]
          csv << [
            user&.username || "unknown",
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
  end
end
