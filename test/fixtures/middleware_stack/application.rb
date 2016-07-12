module MiddlewareStack
  class Application < Hanami::Application
    configure do
      # Test lazy loading with relative class name
      middleware.use 'Middlewares::Runtime'
      middleware.use 'Middlewares::Legacy404'

      # Test lazy loading with absolute class name and arguments
      middleware.use 'MiddlewareStack::Middlewares::Custom', 'OK'

      # Test already loaded middleware
      middleware.use ::Rack::ETag

      routes do
        get '/', to: 'home#index'
        patch '/', to: 'home#update'
      end
    end

    load!
  end

  module Middlewares
    class Runtime
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        headers['X-Runtime']  = '50ms'

        [status, headers, body]
      end
    end

    class Custom
      def initialize(app, value)
        @app   = app
        @value = value
      end

      def call(env)
        status, headers, body = @app.call(env)
        headers['X-Custom']   = @value

        [status, headers, body]
      end
    end

    class Legacy404
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)

        if status == 404
          req = Rack::Request.new(env)
          if req.path == '/legacy'
            headers['X-Legacy-404'] = 'true'
            body = 'legacy URL 404'
            return [status, headers, [body]]
          end
        end

        [status, headers, body]
      end
    end
  end

  module Controllers::Home
    class Index
      include MiddlewareStack::Action

      def call(params)
        self.body = 'Hello'
      end
    end

    class Update
      include MiddlewareStack::Action

      def call(params)
        self.body = 'Update successful'
      end
    end
  end
end
