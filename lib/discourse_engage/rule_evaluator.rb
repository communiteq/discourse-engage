# frozen_string_literal: true

module ::DiscourseEngage
  class RuleEvaluator
    class << self
      def matches?(rules, participant)
        return true if rules.blank?

        evaluate_node(rules.with_indifferent_access, participant)
      rescue StandardError
        false
      end

      private

      def evaluate_node(node, participant)
        return true if node.blank?

        if node.key?(:all)
          return Array(node[:all]).all? do |child|
            evaluate_node(child.with_indifferent_access, participant)
          end
        end

        if node.key?(:any)
          return Array(node[:any]).any? do |child|
            evaluate_node(child.with_indifferent_access, participant)
          end
        end

        if node.key?(:not)
          return !evaluate_node(node[:not].with_indifferent_access, participant)
        end

        evaluate_atomic(node, participant)
      end

      def evaluate_atomic(node, participant)
        if node.key?(:logged_in)
          return participant.logged_in? == coerce_bool(node[:logged_in], default: true)
        end

        user = participant.user

        if node.key?(:account_age_days_gte)
          return false if user.blank?

          required_days = node[:account_age_days_gte].to_i
          return (Time.zone.now.to_date - user.created_at.to_date).to_i >= required_days
        end

        if node.key?(:topics_viewed_gte)
          return false if user.blank?

          required_topics = node[:topics_viewed_gte].to_i
          return user.user_stat&.topics_entered.to_i >= required_topics
        end

        if node.key?(:in_group)
          return false if user.blank?

          return user_in_group?(user, node[:in_group])
        end

        false
      end

      def coerce_bool(value, default: true)
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

      def user_in_group?(user, requirement)
        values = Array(requirement).map(&:to_s)
        user_group_ids = user.groups.pluck(:id).map(&:to_s)
        user_group_names = user.groups.pluck(:name)

        values.any? { |value| user_group_ids.include?(value) || user_group_names.include?(value) }
      end
    end
  end
end
