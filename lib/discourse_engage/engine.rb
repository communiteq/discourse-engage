# frozen_string_literal: true

module ::DiscourseEngage
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseEngage
  end
end
