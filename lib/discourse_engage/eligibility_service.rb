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

        return true if truthy_custom_field?(user, completed_field(survey_id))
        return true if truthy_custom_field?(user, declined_field(survey_id))
        return true if state[:status] == "completed"
        return true if state[:status] == "declined"

        deferred_until =
          state[:next_eligible_at].presence || user.custom_fields[next_field(survey_id)].presence
        return false if deferred_until.blank?

        parse_time(deferred_until) > Time.zone.now
      rescue StandardError
        false
      end

      def parse_time(value)
        return nil if value.blank?

        value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
      end

      def truthy_custom_field?(user, key)
        value = user.custom_fields[key]
        value == true || value == "true"
      end

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
end
