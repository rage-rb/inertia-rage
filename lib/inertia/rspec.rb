# frozen_string_literal: true

require "rage/rspec"

module Inertia
  module RSpec
    # Wraps an Inertia response for test assertions.
    #
    # @example Accessing response data
    #   require "inertia/rspec"
    #
    #   RSpec.describe UsersController, type: :request do
    #     it "renders user posts" do
    #       get "posts"
    #
    #       expect(inertia.component).to eq("Posts/Index")
    #       expect(inertia.props).to have_key(:posts)
    #     end
    #   end
    class TestResponse
      # @param data [Hash] the raw Inertia response data
      def initialize(data)
        @data = data
      end

      # Returns the props with symbolized keys.
      # @note To comply with the Inertia protocol, props always include the `errors` object.
      #
      # @return [Hash{Symbol => Object}] the props hash
      def props
        sybmolize_keys(@data[:props])
      end

      # Returns the component name.
      #
      # @return [String] the Inertia component name
      def component
        @data[:component]
      end

      # Returns the deferred props configuration.
      #
      # @return [Hash] the deferred props, or an empty hash if none
      def deferred_props
        @data[:deferredProps] || {}
      end

      private

      def sybmolize_keys(data)
        data.each_with_object({}).each do |(k, v), memo|
          transformed_value = if v.is_a?(Hash)
            sybmolize_keys(v)
          elsif v.is_a?(Array)
            v.map { |el| el.is_a?(Hash) ? sybmolize_keys(el) : el }
          else
            v
          end

          memo[k.to_sym] = transformed_value
        end
      end
    end

    module TestHelpers
      # Returns the Inertia response from the last request.
      #
      # @return [TestResponse, nil] the wrapped Inertia response, or nil if the last
      #   request was not an Inertia response
      #
      # @example
      #   get "/users/1"
      #   expect(inertia.component).to eq("Users/Show")
      #   expect(inertia.props[:user]).to include(name: "John")
      def inertia
        inertia_response = Fiber.current.instance_variable_get(:@__inertia_current_response)
        return unless inertia_response

        TestResponse.new(inertia_response)
      end
    end

    module RequestHelpers
      # Performs a GET request with optional Inertia partial reload headers.
      #
      # @param inertia [Hash] partial reload options
      # @option inertia [String, Symbol, Array<String, Symbol>] :only request only these props
      # @option inertia [String, Symbol, Array<String, Symbol>] :except request all props except these
      # @param headers [Hash] additional request headers
      # @raise [ArgumentError] if unknown options are passed in the inertia hash
      #
      # @example Request only specific props
      #   get "/users/1", inertia: { only: [:user, :permissions] }
      #
      # @example Request all props except some
      #   get "/users/1", inertia: { except: :audit_log }
      def get(*, inertia: {}, headers: {}, **)
        if inertia.except(:only, :except).any?
          raise ArgumentError, "Unknown :inertia option. Supported values are :only and :except"
        end

        if inertia.any?
          headers = headers.merge({
            "X-Inertia" => "true",
            "X-Inertia-Partial-Component" => self.inertia&.component || double(:== => true)
          })

          if only = inertia[:only]
            headers["X-Inertia-Partial-Data"] = Array(only).join(",")
          elsif except = inertia[:except]
            headers["X-Inertia-Partial-Except"] = Array(except).join(",")
          end
        end

        super(*, headers:, **)
      end
    end
  end
end

RSpec::Matchers.matcher :redirect_to do |expected, external: false|
  failure_message do |response|
    header = external ? "x-inertia-location" : "location"
    actual = response.headers[header]

    if expected.is_a?(Regexp)
      "expected response to be a redirect to /#{expected.source}/ but was a redirect to \"#{actual}\""
    else
      "expected response to be a redirect to \"#{expected}\" but was a redirect to \"#{actual}\""
    end
  end

  failure_message_when_negated do |response|
    if expected.is_a?(Regexp)
      "expected not to redirect to /#{expected.source}/, but did"
    else
      "expected not to redirect to \"#{expected}\", but did"
    end
  end

  match do |response|
    header = external ? "x-inertia-location" : "location"
    actual = response.headers[header]

    if expected.is_a?(Regexp)
      actual&.match?(expected)
    else
      actual == expected
    end
  end
end

RSpec.configure do |config|
  config.include(Inertia::RSpec::TestHelpers, type: :request)
  config.prepend(Inertia::RSpec::RequestHelpers, type: :request)

  config.before(:each) do
    Fiber.current.instance_variable_set(:@__inertia_current_response, nil)
  end

  config.before(:each) do
    test_fiber = Fiber.current

    allow_any_instance_of(Inertia::ProtocolBuilder).to receive(:call).and_wrap_original do |m, *args, **kwargs|
      data = m.call(*args, **kwargs)
      test_fiber.instance_variable_set(:@__inertia_current_response, data)
    end
  end
end
