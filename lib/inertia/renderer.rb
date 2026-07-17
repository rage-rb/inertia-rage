# frozen_string_literal: true

module Inertia
  ##
  # Renders Inertia responses from controller actions.
  #
  # This class enables the `render inertia:` DSL in controllers:
  #
  #   # Explicit component name
  #   render inertia: "Users/Index", props: { users: User.all }
  #
  #   # Inferred component name
  #   render inertia: { users: User.all } # => "UsersController#index" infers "Users/Index"
  #
  # For XHR requests with the `X-Inertia` header, returns a JSON response
  # containing the Inertia page object. For standard requests, delegates to
  # {Frontend.render_layout} to embed the page data in an HTML shell.
  #
  class Renderer
    # Renders an Inertia response for the given component and props.
    #
    # This is the entry point for Inertia's custom rendering. It wires together
    # {RequestContext} (partial reload filtering) and {ProtocolBuilder} (page object
    # construction), and handles both XHR and initial page load responses.
    #
    # @param component [String, Hash] the Inertia component name, or props hash when using component name inference
    # @param props [Hash] the props to pass to the component (ignored when `component` is a Hash)
    # @param controller [RageController::API] the controller instance handling the request
    # @return [String] JSON response for XHR requests, HTML for initial loads
    def self.call(component, props, controller:)
      request, headers = controller.request, controller.headers

      unless component.is_a?(String)
        props = component

        component_path = controller.class.name.delete_suffix("Controller")
        component_path.gsub!("::", "/")
        component_name = controller.action_name.capitalize

        component = "#{component_path}/#{component_name}"
      end

      if shared_data = controller.inertia_shared_data
        props = shared_data.merge(props)
      end

      context = RequestContext.new(request, component:)
      data = ProtocolBuilder.new(component, props, context:).call

      if request.env["HTTP_X_INERTIA"]
        headers["vary"] = "x-inertia"
        headers["x-inertia"] = "true"
        headers["content-type"] = "application/json; charset=utf-8"
        data.to_json
      else
        headers["content-type"] = "text/html; charset=utf-8"
        Frontend.render_layout(data)
      end
    end
  end
end
