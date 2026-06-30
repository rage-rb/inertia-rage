# frozen_string_literal: true

module Inertia
  # Contains prop wrapper classes.
  module Props
    # Base class for all prop wrappers.
    class Base < Data
      def resolve
        block.call
      end
    end

    # A prop that is loaded in a subsequent request after the initial page load.
    Deferred = Base.define(:group, :block)

    # A prop that is evaluated only once.
    Once = Base.define(:key, :fresh, :expires_in, :block) do
      # Calculates the expiration timestamp in milliseconds.
      #
      # @return [Integer, nil] the expiration time as Unix timestamp in milliseconds, or nil if no expiration
      def expires_at
        return unless expires_in

        ((Time.now + expires_in).to_f * 1_000).to_i
      end
    end

    # A prop that is only included in the response when explicitly requested by the client.
    Optional = Base.define(:block)
  end
end
