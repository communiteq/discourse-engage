# frozen_string_literal: true

require "securerandom"

module ::DiscourseEngage
  class Participant
    COOKIE_NAME = "discourse_engage_participant".freeze

    attr_reader :type, :id, :user

    class << self
      def from_request(controller)
        user = controller.current_user
        return new(type: "user", id: user.id.to_s, user: user) if user.present?

        cookie_jar = controller.request.cookie_jar
        anon_id = cookie_jar.signed[COOKIE_NAME]
        if anon_id.blank?
          anon_id = SecureRandom.alphanumeric(24).downcase
          cookie_jar.signed[COOKIE_NAME] = {
            value: anon_id,
            expires: 20.years.from_now,
            httponly: true,
            same_site: :lax,
            secure: SiteSetting.force_https,
          }
        end

        new(type: "anon", id: anon_id)
      end

      def key_for(type, id)
        return nil if type.blank? || id.blank?

        "#{type}-#{id}"
      end

      def parse_key(key)
        match = key.to_s.match(/\A(user|anon)-([A-Za-z0-9]+)\z/)
        return nil unless match

        { type: match[1], id: match[2] }
      end
    end

    def initialize(type:, id:, user: nil)
      @type = type.to_s
      @id = id.to_s
      @user = user
    end

    def logged_in?
      type == "user"
    end

    def anonymous?
      type == "anon"
    end

    def key
      self.class.key_for(type, id)
    end
  end
end