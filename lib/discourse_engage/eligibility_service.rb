# frozen_string_literal: true

module ::DiscourseEngage
  class EligibilityService
    class << self
      def first_eligible_for(user)
        active_surveys =
          DiscourseEngage::Store
            .list_surveys
            .select { |survey| survey["status"] == "active" }
            .sort_by { |survey| -survey["priority"].to_i }

        active_surveys.find { |survey| eligible_for_survey?(survey, user) }
      end

      def eligible_for_survey?(survey, user)
        return false unless within_schedule?(survey)
        return false unless DiscourseEngage::RuleEvaluator.matches?(survey["rules"], user)
        return false if suppressed?(survey["id"], user)

        true
      end

      private

      def within_schedule?(survey)
        now = Time.zone.now
        starts_at = parse_time(survey["start_at"])
        ends_at = parse_time(survey["end_at"])

        return false if starts_at && now < starts_at
        return false if ends_at && now > ends_at

        true
      end

      def suppressed?(survey_id, user)
        state = DiscourseEngage::Store.get_state(survey_id, user.id).with_indifferent_access

        return true if state[:status] == "completed"
        return true if state[:status] == "declined"

        deferred_until = state[:next_eligible_at].presence
        return false if deferred_until.blank?

        parse_time(deferred_until) > Time.zone.now
      rescue StandardError
        false
      end

      def parse_time(value)
        return nil if value.blank?

        value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
      end

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
end
