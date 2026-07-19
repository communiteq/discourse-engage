# frozen_string_literal: true

module ::DiscourseEngage
  class Store
    SURVEY_KEY_PREFIX = "survey:".freeze
    RESPONSE_KEY_PREFIX = "response:".freeze
    STATE_KEY_PREFIX = "state:".freeze
    STATE_COUNTS_CACHE_KEY = "discourse_engage:state_counts".freeze

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
        # Only apply defaults if the keys were not explicitly passed in `survey`
        payload[:allow_decline] = true unless survey.key?(:allow_decline) || survey.key?("allow_decline")
        payload[:allow_defer] = true unless survey.key?(:allow_defer) || survey.key?("allow_defer")
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

      def delete_response(survey_id, participant_type, participant_id, response_id)
        PluginStore.remove(
          DiscourseEngage::PLUGIN_NAME,
          response_key(survey_id, participant_type, participant_id, response_id),
        )

        if participant_type.to_s == "user"
          PluginStore.remove(
            DiscourseEngage::PLUGIN_NAME,
            legacy_response_key(survey_id, participant_id, response_id),
          )
        end
      end

      def reset_user_state(survey_id, participant_type, participant_id)
        # Clear PluginStore state
        PluginStore.remove(
          DiscourseEngage::PLUGIN_NAME,
          state_key(survey_id, participant_type, participant_id),
        )

        if participant_type.to_s == "user"
          PluginStore.remove(
            DiscourseEngage::PLUGIN_NAME,
            legacy_state_key(survey_id, participant_id),
          )
        end

        invalidate_state_counts_cache
      end

      def count_responses(survey_id)
        prefix = "#{RESPONSE_KEY_PREFIX}#{survey_id}:"
        PluginStoreRow
          .where(plugin_name: DiscourseEngage::PLUGIN_NAME, type_name: "JSON")
          .where("key LIKE ?", "#{prefix}%")
          .count
      end

      # One SQL query across all state rows; result cached for 5 minutes and
      # explicitly invalidated on every state write.
      # Returns { survey_id => { deferred: N, declined: N } }.
      def count_states_by_status
        Rails.cache.fetch(STATE_COUNTS_CACHE_KEY, expires_in: 5.minutes) do
          rows =
            PluginStoreRow
              .where(plugin_name: DiscourseEngage::PLUGIN_NAME, type_name: "JSON")
              .where("key LIKE ?", "#{STATE_KEY_PREFIX}%")
              .pluck(:key, :value)

          counts = {}
          rows.each do |key, raw_value|
            # key: state:{survey_id}:{participant_type}:{participant_id}
            without_prefix = key.sub(STATE_KEY_PREFIX, "")
            parts = without_prefix.split(":")
            survey_id = parts.first
            next if survey_id.blank?
            data = decode_json(raw_value)
            next if data.nil?
            status = data["status"] || data[:status]
            counts[survey_id] ||= { deferred: 0, declined: 0 }
            counts[survey_id][:deferred] += 1 if status == "deferred"
            counts[survey_id][:declined] += 1 if status == "declined"
          end
          counts
        end
      end

      def invalidate_state_counts_cache
        Rails.cache.delete(STATE_COUNTS_CACHE_KEY)
      end

      def store_response(survey_id:, participant_type:, participant_id:, answers:, metadata: {}, user_id: nil)
        response_id = next_response_id(survey_id, participant_type, participant_id)
        payload = {
          response_id: response_id,
          survey_id: survey_id,
          participant_type: participant_type,
          participant_id: participant_id,
          participant_key: DiscourseEngage::Participant.key_for(participant_type, participant_id),
          user_id: user_id,
          answers: answers,
          metadata: metadata,
          submitted_at: Time.zone.now.iso8601,
        }

        PluginStore.set(
          DiscourseEngage::PLUGIN_NAME,
          response_key(survey_id, participant_type, participant_id, response_id),
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

      def get_state(survey_id, participant_type, participant_id)
        PluginStore.get(
          DiscourseEngage::PLUGIN_NAME,
          state_key(survey_id, participant_type, participant_id),
        ) || legacy_state(survey_id, participant_type, participant_id) || {}
      end

      def set_state(survey_id, participant_type, participant_id, attrs)
        current = get_state(survey_id, participant_type, participant_id)
        payload = current.merge(attrs).with_indifferent_access
        payload[:updated_at] = Time.zone.now.iso8601
        PluginStore.set(
          DiscourseEngage::PLUGIN_NAME,
          state_key(survey_id, participant_type, participant_id),
          payload,
        )
        invalidate_state_counts_cache
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

      def next_response_id(survey_id, participant_type, participant_id)
        counter_key = "response_id:#{survey_id}:#{participant_type}:#{participant_id}"
        DistributedMutex.synchronize("discourse_engage_#{counter_key}") do
          next_id = PluginStore.get(DiscourseEngage::PLUGIN_NAME, counter_key) || 1
          PluginStore.set(DiscourseEngage::PLUGIN_NAME, counter_key, next_id + 1)
          next_id.to_s
        end
      end

      def response_key(survey_id, participant_type, participant_id, response_id)
        "#{RESPONSE_KEY_PREFIX}#{survey_id}:#{participant_type}:#{participant_id}:#{response_id}"
      end

      def state_key(survey_id, participant_type, participant_id)
        "#{STATE_KEY_PREFIX}#{survey_id}:#{participant_type}:#{participant_id}"
      end

      def legacy_response_key(survey_id, participant_id, response_id)
        "#{RESPONSE_KEY_PREFIX}#{survey_id}:#{participant_id}:#{response_id}"
      end

      def legacy_state_key(survey_id, participant_id)
        "#{STATE_KEY_PREFIX}#{survey_id}:#{participant_id}"
      end

      def decode_json(raw)
        raw.is_a?(String) ? JSON.parse(raw) : raw
      rescue JSON::ParserError
        nil
      end

      def legacy_state(survey_id, participant_type, participant_id)
        return nil unless participant_type.to_s == "user"

        PluginStore.get(DiscourseEngage::PLUGIN_NAME, legacy_state_key(survey_id, participant_id))
      end
    end
  end
end
