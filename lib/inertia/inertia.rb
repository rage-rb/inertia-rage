# frozen_string_literal: true

require "rage"

require_relative "props"
require_relative "request_context"
require_relative "protocol_builder"
require_relative "controller_helpers"
require_relative "version"

module Inertia
  # Creates a deferred prop that will be loaded in a subsequent request after the initial page load.
  #
  # @param group [String] the group name for batching deferred props together
  # @yield the block that returns the prop value when evaluated
  # @return [Props::Deferred] a deferred prop wrapper
  # @example
  #   render inertia: "Users/Index", props: {
  #     users: Inertia.deferred { User.all }
  #   }
  def self.deferred(group: "default", &block)
    Props::Deferred.new(group:, block:)
  end

  # Creates a prop that is evaluated only once and cached by the frontend.
  #
  # @param key [String, nil] a unique cache key for the prop (auto-generated if `nil`)
  # @param fresh [Boolean] forces re-evaluation when `true`
  # @param expires_in [Integer, ActiveSupport::Duration, nil] cache expiration time in seconds
  # @yield the block that returns the prop value when evaluated
  # @return [Props::Once] a once-evaluated prop wrapper
  # @example
  #   render inertia: "Dashboard", props: {
  #     stats: Inertia.once(expires_in: 300) { Stats.calculate }
  #   }
  def self.once(key: nil, fresh: false, expires_in: nil, &block)
    Props::Once.new(key:, fresh:, expires_in:, block:)
  end

  # Creates a prop that is only included when explicitly requested by the client.
  #
  # @yield the block that returns the prop value when evaluated
  # @return [Props::Optional] an optional prop wrapper
  # @example
  #   render inertia: "Users/Show", props: {
  #     user: user,
  #     permissions: Inertia.optional { user.permissions }
  #   }
  def self.optional(&block)
    Props::Optional.new(block:)
  end
end
