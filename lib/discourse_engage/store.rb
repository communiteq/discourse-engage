# frozen_string_literal: true

module ::DiscourseEngage
  class Store
    SURVEY_KEY_PREFIX = "survey:".freeze
    RESPONSE_KEY_PREFIX = "response:".freeze
    STATE_KEY_PREFIX = "state:".freeze

    class << self
      def list_surveys
        PluginStoreRow
          .where(plugin_name: DiscourseEngage::PLUGIN_NAME, type_name: "JSON")
          .where("key LIKE ?", "#{SURVEY_KEY_PREFIX}%")
          .order(id: :desc)
          .map { |row| decode_json(row.value) }
          .compact
      end

      def get_survey(survey_id)
        PluginStore.get(DiscourseEngage::PLUGIN_NAME, survey_key(survey_id))
      end

      def upsert_survey(attrs)
        survey = attrs.with_indifferent_access
        survey_id = survey[:id].presence || next_survey_id

        stored = get_survey(survey_id) || {}
        payload = stored.merge(survey)

        payload[:id] = survey_id
        payload[:status] ||= "draft"
        payload[:priority] = payload[:priority].to_i
        payload[:rules] ||= {}
        payload[:survey_json] ||= {}
        payload[:created_at] ||= Time.zone.now.iso8601
        payload[:updated_at] = Time.zone.now.iso8601

        PluginStore.set(DiscourseEngage::PLUGIN_NAME, survey_key(survey_id), payload)
        payload
      end

      def delete_survey(survey_id)
        PluginStore.remove(DiscourseEngage::PLUGIN_NAME, survey_key(survey_id))
      end

      def store_response(survey_id:, user_id:, answers:, metadata: {})
        response_id = next_response_id(survey_id, user_id)
        payload = {
          response_id: response_id,
          survey_id: survey_id,
          user_id: user_id,
          answers: answers,
          metadata: metadata,
          submitted_at: Time.zone.now.iso8601,
        }

        PluginStore.set(
          DiscourseEngage::PLUGIN_NAME,
          response_key(survey_id, user_id, response_id),
          payload,
        )

        payload
      end

      def list_responses(survey_id)
        prefix = "#{RESPONSE_KEY_PREFIX}#{survey_id}:"
        PluginStoreRow
          .where(plugin_name: DiscourseEngage::PLUGIN_NAME, type_name: "JSON")
          .where("key LIKE ?", "#{prefix}%")
          .order(id: :asc)
          .map { |row| decode_json(row.value) }
          .compact
      end

      def get_state(survey_id, user_id)
        PluginStore.get(DiscourseEngage::PLUGIN_NAME, state_key(survey_id, user_id)) || {}
      end

      def set_state(survey_id, user_id, attrs)
        current = get_state(survey_id, user_id)
        payload = current.merge(attrs).with_indifferent_access
        payload[:updated_at] = Time.zone.now.iso8601
        PluginStore.set(DiscourseEngage::PLUGIN_NAME, state_key(survey_id, user_id), payload)
        payload
      end

      def survey_key(survey_id)
        "#{SURVEY_KEY_PREFIX}#{survey_id}"
      end

      private

      def next_survey_id
        DistributedMutex.synchronize("discourse_engage_survey_id") do
          next_id = PluginStore.get(DiscourseEngage::PLUGIN_NAME, "survey_id") || 1
          PluginStore.set(DiscourseEngage::PLUGIN_NAME, "survey_id", next_id + 1)
          next_id.to_s
        end
      end

      def next_response_id(survey_id, user_id)
        counter_key = "response_id:#{survey_id}:#{user_id}"
        DistributedMutex.synchronize("discourse_engage_#{counter_key}") do
          next_id = PluginStore.get(DiscourseEngage::PLUGIN_NAME, counter_key) || 1
          PluginStore.set(DiscourseEngage::PLUGIN_NAME, counter_key, next_id + 1)
          next_id.to_s
        end
      end

      def response_key(survey_id, user_id, response_id)
        "#{RESPONSE_KEY_PREFIX}#{survey_id}:#{user_id}:#{response_id}"
      end

      def state_key(survey_id, user_id)
        "#{STATE_KEY_PREFIX}#{survey_id}:#{user_id}"
      end

      def decode_json(raw)
        raw.is_a?(String) ? JSON.parse(raw) : raw
      rescue JSON::ParserError
        nil
      end
    end
  end
end
