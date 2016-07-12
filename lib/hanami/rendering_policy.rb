require 'hanami/utils/class'
require 'hanami/views/default'
require 'hanami/views/null_view'

module Hanami
  # Rendering policy
  #
  # @since 0.1.0
  # @api private
  class RenderingPolicy
    STATUS  = 0
    HEADERS = 1
    BODY    = 2

    HANAMI_ACTION = 'hanami.action'.freeze

    SUCCESSFUL_STATUSES = (200..201).freeze
    RENDERABLE_FORMATS = [:all, :html].freeze

    def initialize(configuration)
      @controller_pattern = %r{#{ configuration.controller_pattern.gsub(/\%\{(controller|action)\}/) { "(?<#{ $1 }>(.*))" } }}
      @view_pattern       = configuration.view_pattern
      @namespace          = configuration.namespace
      @templates          = configuration.templates
    end

    def render(env, response)
      body = _render(env, response)

      response[BODY] = Array(body) unless body.nil? || body.respond_to?(:each)
      response
    end

    private
    def _render(env, response)
      if action = renderable?(env, response)
        _render_action(action, response) ||
          _render_status_page(action, response)
      end
    end

    def _render_action(action, response)
      view_for(action, response).render(
        action.exposures
      )
    end

    def _render_status_page(action, response)
      if render_status_page?(action, response)
        Hanami::Views::Default.render(@templates, response[STATUS], response: response, format: :html)
      end
    end

    def renderable?(env, response)
      !has_response_body?(response) && has_hanami_action?(env)
    end

    def has_hanami_action?(env)
      ((action = env.delete(HANAMI_ACTION)) && action.renderable?) and action
    end

    def has_response_body?(response)
      response[BODY].respond_to?(:empty?) && !response[BODY].empty?
    end

    def render_status_page?(action, response)
      RENDERABLE_FORMATS.include?(action.format) && !SUCCESSFUL_STATUSES.include?(response[STATUS])
    end

    def view_for(action, response)
      view = unless has_response_body?(response)
        captures = @controller_pattern.match(action.class.name)
        Utils::Class.load(@view_pattern % { controller: captures[:controller], action: captures[:action] }, @namespace)
      end

      view || Views::NullView.new
    end
  end
end
