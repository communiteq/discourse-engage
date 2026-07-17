# frozen_string_literal: true

module ::DiscourseEngage
  class RuleEvaluator
    class << self
      def matches?(rules, user)
        return true if rules.blank?

        evaluate_node(rules.with_indifferent_access, user)
      rescue StandardError
        false
      end

      private

      def evaluate_node(node, user)
        return true if node.blank?

        if node.key?(:all)
          return Array(node[:all]).all? { |child| evaluate_node(child.with_indifferent_access, user) }
        end

        if node.key?(:any)
          return Array(node[:any]).any? { |child| evaluate_node(child.with_indifferent_access, user) }
        end

        if node.key?(:not)
          return !evaluate_node(node[:not].with_indifferent_access, user)
        end

        evaluate_atomic(node, user)
      end

      def evaluate_atomic(node, user)
        if node.key?(:account_age_days_gte)
          required_days = node[:account_age_days_gte].to_i
          return (Time.zone.now.to_date - user.created_at.to_date).to_i >= required_days
        end

        if node.key?(:topics_viewed_gte)
          required_topics = node[:topics_viewed_gte].to_i
          return user.user_stat&.topics_entered.to_i >= required_topics
        end

        if node.key?(:in_group)
          return user_in_group?(user, node[:in_group])
        end

        false
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
