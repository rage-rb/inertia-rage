# frozen_string_literal: true

module Inertia
  ##
  # Builds the Inertia page object for a rendered component.
  #
  # ProtocolBuilder resolves the server-side props hash into the shape expected
  # by the Inertia protocol. It applies partial reload filtering, evaluates lazy
  # values, walks nested hashes and arrays, and collects protocol metadata such
  # as `deferredProps` and `onceProps`.
  #
  # Nested prop paths are tracked with dot notation, e.g. `auth.user.name`, so
  # request headers can target either a top-level prop or a nested value.
  #
  class ProtocolBuilder
    # Internal marker returned by resolver methods when a prop should be
    # left out of the page object.
    OMIT = Object.new
    private_constant :OMIT

    # Creates a new protocol builder.
    #
    # @param component [String] the Inertia component name being rendered
    # @param props [Hash] the props provided by the controller
    # @param context [RequestContext] request-specific partial reload context
    def initialize(component, props, context:)
      @props = props
      @context = context

      @response = { component:, url: context.url }
    end

    # Builds the page object hash.
    #
    # @return [Hash] the Inertia page object payload
    def call
      @response[:props] = resolve_props
      @response[:deferredProps] = @deferred_props_metadata if @deferred_props_metadata
      @response[:onceProps] = @once_props_metadata if @once_props_metadata

      @response
    end

    private

    # Resolves a hash of props into protocol-ready response props.
    #
    # `parent_was_resolved` is set when traversing a hash or array returned by a
    # lazy prop. In that case, the parent prop was already selected for this
    # response, so partial reload `only` filtering should not prune children from
    # the computed value.
    #
    # This flag does not mean every child was explicitly requested. Deferred and
    # optional props inside the computed value are included on matching partial
    # reloads, but remain deferred/omitted on initial loads. Once props still use
    # their own path/key for cache exclusion, so resolving a parent does not by
    # itself bypass `X-Inertia-Except-Once-Props`.
    #
    # @param props [Hash] props to resolve at the current nesting level
    # @param path [String, nil] dot-notated path prefix for nested props
    # @param parent_was_resolved [Boolean] whether this level came from a lazy prop
    # @return [Hash] resolved props for this nesting level
    def resolve_props(props = @props, path: nil, parent_was_resolved: false)
      props.each_with_object({}) do |(prop_name, prop), response|
        prop_name_with_path = prop_with_path(prop_name, path)

        prop_status = @context.prop_status(prop_name_with_path)
        next if prop_status == :excluded && !parent_was_resolved

        is_explicitly_requested = (prop_status == :requested)
        should_include_from_resolved_parent = parent_was_resolved && @context.partial_render?
        should_include_on_demand_prop = is_explicitly_requested || should_include_from_resolved_parent

        resolved = if prop.respond_to?(:call)
          # lazy props
          resolve_lazy_prop(prop, path: prop_name_with_path)

        elsif prop.is_a?(Inertia::Props::Deferred)
          if should_include_on_demand_prop
            # the deferred prop was requested
            prop.resolve
          else
            # let the client know there're deferred props
            deferred_props_metadata[prop.group] << prop_name_with_path
            OMIT
          end

        elsif prop.is_a?(Inertia::Props::Once)
          key = prop.key || prop_name_with_path

          # include metadata unless explicitly excluded (`parent_was_resolved` path)
          once_props_metadata[key] = { prop: prop_name_with_path, expiresAt: prop.expires_at } unless prop_status == :excluded
          # resolve the prop value only if requested
          is_explicitly_requested || prop.fresh || !@context.once_prop_excluded?(key) ? prop.resolve : OMIT

        elsif prop.is_a?(Inertia::Props::Optional)
          # excluded on initial page load
          should_include_on_demand_prop ? prop.resolve : OMIT

        elsif prop.is_a?(Hash)
          # nested hash props
          if prop.empty?
            prop
          else
            nested_prop = resolve_props(prop, path: prop_name_with_path, parent_was_resolved:)
            nested_prop.empty? ? OMIT : nested_prop
          end

        elsif prop.is_a?(Array)
          # nested array props
          resolve_array_prop(prop, path: prop_name_with_path, parent_was_resolved:)

        else
          # scalar prop
          prop
        end

        # chained props and props returned from lazy props
        if resolved.is_a?(Inertia::Props::Base)
          prop = resolved
          redo
        end

        response[prop_name] = resolved unless resolved.equal?(OMIT)
      end
    end

    # Evaluates a lazy prop and recursively resolves nested data it returns.
    #
    # A lazy prop can return a plain scalar value, a hash, or an array. Hashes and
    # arrays are traversed with `parent_was_resolved: true` so nested
    # optional/deferred props follow the resolved-parent rules described in `#resolve_props`.
    #
    # @param prop [#call] lazy value to evaluate
    # @param path [String] dot-notated path of the lazy prop
    # @return [Object] resolved value
    def resolve_lazy_prop(prop, path:)
      resolved = prop.call

      if resolved.is_a?(Hash)
        resolve_props(resolved, path:, parent_was_resolved: true)
      elsif resolved.is_a?(Array)
        resolve_array_prop(resolved, path:, parent_was_resolved: true)
      else
        resolved
      end
    end

    # Resolves arrays that may contain nested hashes or lazy values.
    #
    # Array indices are included in generated paths so metadata can still point
    # to the nested prop location, e.g. `items.0.author`.
    #
    # @param prop [Array] array value to resolve
    # @param path [String] dot-notated path of the array prop
    # @param parent_was_resolved [Boolean] whether the array came from a lazy prop
    # @return [Array] resolved array
    def resolve_array_prop(prop, path:, parent_was_resolved:)
      prop.each_with_index.each_with_object([]) do |(nested_prop, i), response|
        resolved = if nested_prop.is_a?(Hash)
          resolve_props(nested_prop, path: "#{path}.#{i}", parent_was_resolved:)
        elsif nested_prop.respond_to?(:call)
          resolve_lazy_prop(nested_prop, path: "#{path}.#{i}")
        else
          nested_prop
        end

        # drop hash items whose contents were fully filtered out
        next if nested_prop.is_a?(Hash) && !nested_prop.empty? && resolved.empty?

        response << resolved
      end
    end

    # Builds a dot-notated path for a prop at the current nesting level.
    #
    # @param prop_name [String, Symbol] prop key at the current level
    # @param path [String, nil] parent path
    # @return [String] full dot-notated prop path
    def prop_with_path(prop_name, path)
      if path
        "#{path}.#{prop_name}"
      else
        prop_name.to_s
      end
    end

    # Lazily initializes deferred prop metadata grouped by deferred group name.
    #
    # @return [Hash{String=>Array<String>}] deferred prop paths by group
    def deferred_props_metadata
      @deferred_props_metadata ||= Hash.new { |h, k| h[k] = [] }
    end

    # Lazily initializes once prop metadata keyed by once cache key.
    #
    # @return [Hash{String=>Hash}] once prop metadata
    def once_props_metadata
      @once_props_metadata ||= {}
    end
  end
end
