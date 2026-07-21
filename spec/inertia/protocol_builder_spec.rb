# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::ProtocolBuilder do
  def build_page(props, headers = {}, fullpath: "/deeply_nested_props")
    request = Struct.new(:fullpath, :env).new(fullpath, headers)
    context = Inertia::RequestContext.new(request, component: "TestComponent")

    described_class.new("TestComponent", props, context:).call
  end

  before do
    allow(Inertia::Frontend).to receive(:version)
  end

  describe "page object shape" do
    it "includes the component name, request URL, and version" do
      page = build_page({ name: "Jonathan" }, {}, fullpath: "/users?active=true")

      expect(page).to include(
        component: "TestComponent",
        url: "/users?active=true",
        version: nil,
        props: { name: "Jonathan", errors: {} },
      )
    end

    context "with asset version" do
      before do
        allow(Inertia::Frontend).to receive(:version).and_return("version-123456")
      end

      it "includes version" do
        page = build_page({})

        expect(page[:version]).to eq("version-123456")
      end
    end

    # Adapted from inertia-rails/spec/inertia/rendering_spec.rb "with a non matching partial component header".
    it "ignores partial headers when the partial component does not match" do
      page = build_page(
        {
          name: "Jonathan",
          sport: -> { "hockey" },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "OtherComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "sport",
        },
      )

      expect(page[:props]).to eq(
        name: "Jonathan",
        sport: "hockey",
        errors: {}
      )
    end
  end

  describe "lazy props" do
    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb "closure resolution".
    it "resolves top-level and nested closures" do
      page = build_page(
        {
          auth: -> { { user: "Jonathan" } },
          nested: {
            sport: -> { "hockey" },
          },
        },
      )

      expect(page[:props]).to eq(
        auth: { user: "Jonathan" },
        nested: { sport: "hockey" },
        errors: {}
      )
    end

    # Adapted from inertia-rails/spec/inertia/rendering_spec.rb "lazy prop rendering" partial reload.
    it "only resolves requested lazy props on partial reload" do
      grit_resolved = false

      page = build_page(
        {
          name: "Brian",
          sport: -> { "basketball" },
          level: -> { "worse than he believes" },
          grit: lambda {
            grit_resolved = true
            "intense"
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "sport,level",
        },
      )

      expect(page[:props]).to eq(
        sport: "basketball",
        level: "worse than he believes",
        errors: {}
      )
      expect(grit_resolved).to be(false)
    end

    # Adapted from inertia-rails/spec/inertia/rendering_spec.rb
    # "with only props that target transformed data".
    it "includes all children from a closure-returned hash when a nested child path is requested" do
      page = build_page(
        {
          nested: {
            evaluated: lambda {
              {
                first: "first evaluated nested param",
                second: "second evaluated nested param",
              }
            },
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested.evaluated.first",
        },
      )

      expect(page[:props]).to eq(
        nested: {
          evaluated: {
            first: "first evaluated nested param",
            second: "second evaluated nested param",
          },
        },
        errors: {}
      )
    end

    it "includes on-demand props from a closure-returned hash when a sibling path is requested" do
      page = build_page(
        {
          auth: lambda {
            {
              user: "Jonathan",
              permissions: Inertia.optional { ["admin"] },
              notifications: Inertia.deferred { ["msg"] },
            }
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "auth.user",
        },
      )

      expect(page[:props]).to eq(
        auth: {
          user: "Jonathan",
          permissions: ["admin"],
          notifications: ["msg"],
        },
        errors: {}
      )
      expect(page).not_to have_key(:deferredProps)
    end

    # Adapted from inertia-rails/spec/inertia/rendering_spec.rb
    # "with except props that target transformed data".
    it "does not prune children from a closure-returned hash when except targets one child" do
      page = build_page(
        {
          flat: "flat param",
          nested: {
            evaluated: lambda {
              {
                first: "first evaluated nested param",
                second: "second evaluated nested param",
              }
            },
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.evaluated.first",
        },
      )

      expect(page[:props]).to eq(
        flat: "flat param",
        nested: {
          evaluated: {
            first: "first evaluated nested param",
            second: "second evaluated nested param",
          },
        },
        errors: {}
      )
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb "closure returning prop type".
    it "treats a closure-returned deferred prop as a deferred prop" do
      resolved = false

      page = build_page(
        {
          notifications: lambda {
            Inertia.deferred(group: "alerts") do
              resolved = true
              []
            end
          },
        },
      )

      expect(page[:props]).not_to have_key(:notifications)
      expect(page[:deferredProps]).to eq("alerts" => ["notifications"])
      expect(resolved).to be(false)
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb "closure returning prop type".
    it "treats a closure-returned once prop as a once prop" do
      page = build_page({ locale: -> { Inertia.once { "en" } } })

      expect(page[:props][:locale]).to eq("en")
      expect(page[:onceProps]).to eq(
        "locale" => { prop: "locale", expiresAt: nil },
      )
    end
  end

  describe "nested partial except props" do
    # Adapted from inertia-rails/spec/inertia/rendering_spec.rb nested dot-notation partial reload specs.
    it "keeps sibling props when except excludes a nested child" do
      page = build_page(
        {
          flat: "flat param",
          nested: {
            first: "first nested param",
            second: "second nested param",
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.first",
        },
      )

      expect(page[:props]).to eq(
        nested: {
          second: "second nested param",
        },
        errors: {}
      )
    end

    it "keeps nested siblings when only and except both use dot notation" do
      page = build_page(
        {
          flat: "flat param",
          lazy: -> { "lazy param" },
          nested: {
            first: "first nested param",
            deeply_nested: {
              first: "first deeply nested param",
              second: false,
              what_about_nil: nil,
              what_about_empty_hash: {},
            },
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "lazy,nested.deeply_nested",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.deeply_nested.first",
        },
      )

      expect(page[:props]).to eq(
        lazy: "lazy param",
        nested: {
          deeply_nested: {
            second: false,
            what_about_nil: nil,
            what_about_empty_hash: {},
          },
        },
        errors: {}
      )
    end
  end

  describe "array props" do
    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb indexed array cases.
    it "preserves plain scalar arrays" do
      page = build_page({ tags: ["ruby", "rails", false, nil, {}] })

      expect(page[:props]).to eq(tags: ["ruby", "rails", false, nil, {}], errors: {})
    end

    it "resolves lazy values inside array hash items" do
      page = build_page({ items: [{ name: -> { "First" } }, "plain"] })

      expect(page[:props]).to eq(
        items: [
          { name: "First" },
          "plain",
        ],
        errors: {}
      )
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb
    # "optional props inside indexed arrays are excluded from initial load".
    it "excludes optional props inside indexed arrays on initial load" do
      resolved = false

      page = build_page(
        {
          foos: [
            {
              foo: "bar-1",
              bar: Inertia.optional do
                resolved = true
                "expensive-data-1"
              end,
            },
            {
              foo: "bar-2",
              bar: Inertia.optional { "expensive-data-2" },
            },
          ],
        },
      )

      expect(page[:props]).to eq(
        foos: [
          { foo: "bar-1" },
          { foo: "bar-2" },
        ],
        errors: {}
      )
      expect(resolved).to be(false)
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb
    # "optional props inside indexed arrays are resolved on partial request".
    it "includes optional props inside indexed arrays when the array parent is requested" do
      page = build_page(
        {
          foos: [
            { foo: "bar-1", bar: Inertia.optional { "expensive-data-1" } },
            { foo: "bar-2", bar: Inertia.optional { "expensive-data-2" } },
          ],
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "foos",
        },
      )

      expect(page[:props][:foos][0][:foo]).to eq("bar-1")
      expect(page[:props][:foos][0][:bar]).to eq("expensive-data-1")
      expect(page[:props][:foos][1][:foo]).to eq("bar-2")
      expect(page[:props][:foos][1][:bar]).to eq("expensive-data-2")
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb
    # "optional prop inside indexed array is resolved by indexed path".
    it "filters array hash items by indexed partial paths" do
      page = build_page(
        {
          foos: [
            { name: "First", bar: Inertia.optional { "expensive-1" } },
            { name: "Second", bar: Inertia.optional { "expensive-2" } },
          ],
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "foos.0.bar",
        },
      )

      expect(page[:props][:foos].length).to eq(1)
      expect(page[:props][:foos][0]).not_to have_key(:name)
      expect(page[:props][:foos][0][:bar]).to eq("expensive-1")
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb
    # "non-indexed field path does not match inside indexed array".
    it "does not match non-indexed partial paths inside indexed arrays" do
      page = build_page(
        {
          foos: [
            { name: "First", bar: Inertia.optional { "expensive-1" } },
          ],
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "foos.bar",
        },
      )

      expect(page[:props]).to eq(foos: [], errors: {})
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb closure-returned array cases.
    it "includes all children from a closure-returned array when a nested child path is requested" do
      page = build_page(
        {
          foos: lambda {
            [
              {
                name: "First",
                details: {
                  first: "first detail",
                  second: "second detail",
                },
              },
            ]
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "foos.0.details.first",
        },
      )

      expect(page[:props]).to eq(
        foos: [
          {
            name: "First",
            details: {
              first: "first detail",
              second: "second detail",
            },
          },
        ],
        errors: {}
      )
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb
    # "deferred prop inside indexed array uses indexed path in metadata".
    it "uses indexed paths for deferred metadata inside arrays" do
      resolved = false

      page = build_page(
        {
          foos: [
            {
              name: "First",
              notifications: Inertia.deferred do
                resolved = true
                ["msg"]
              end,
            },
          ],
        },
      )

      expect(page[:props]).to eq(foos: [{ name: "First" }], errors: {})
      expect(page[:deferredProps]).to eq("default" => ["foos.0.notifications"])
      expect(resolved).to be(false)
    end
  end

  describe "optional props" do
    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb "OptionalProp".
    it "excludes optional props from initial load without resolving them" do
      resolved = false

      page = build_page(
        {
          user: "Jonathan",
          permissions: Inertia.optional do
            resolved = true
            ["admin"]
          end,
        },
      )

      expect(page[:props]).to eq(user: "Jonathan", errors: {})
      expect(resolved).to be(false)
    end

    it "includes optional props on exact partial request" do
      page = build_page(
        {
          user: "Jonathan",
          permissions: Inertia.optional { ["admin"] },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "permissions",
        },
      )

      expect(page[:props].keys).to match_array([:permissions, :errors])
      expect(page[:props][:permissions]).to eq(["admin"])
    end

    it "does not include optional props for a component-only partial header" do
      resolved = false

      page = build_page(
        {
          user: "Jonathan",
          permissions: Inertia.optional do
            resolved = true
            ["admin"]
          end,
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
        },
      )

      expect(page[:props]).to eq(user: "Jonathan", errors: {})
      expect(resolved).to be(false)
    end

    # Adapted from inertia-rails/spec/inertia/rendering_spec.rb
    # "when except without X-Inertia-Partial-Data".
    it "includes optional props on except-only partial reloads unless excepted" do
      page = build_page(
        {
          flat: "flat param",
          optional: Inertia.optional { "optional param" },
          nested: {
            first: "first nested param",
          },
          nested_optional: Inertia.optional { { first: "first nested optional param" } },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested",
        },
      )

      expect(page[:props][:flat]).to eq("flat param")
      expect(page[:props][:optional]).to eq("optional param")
      expect(page[:props][:nested_optional]).to eq({ first: "first nested optional param" })
      expect(page[:props]).not_to have_key(:nested)
    end
  end

  describe "deferred props" do
    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb "DeferProp".
    it "excludes deferred props from initial load without resolving them" do
      resolved = false

      page = build_page(
        {
          name: "Jonathan",
          notifications: Inertia.deferred do
            resolved = true
            []
          end,
        },
      )

      expect(page[:props]).to eq(name: "Jonathan", errors: {})
      expect(page[:deferredProps]).to eq("default" => ["notifications"])
      expect(resolved).to be(false)
    end

    it "does not resolve deferred props for a component-only partial header" do
      resolved = false

      page = build_page(
        {
          name: "Jonathan",
          notifications: Inertia.deferred do
            resolved = true
            ["msg"]
          end,
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
        },
      )

      expect(page[:props]).to eq(name: "Jonathan", errors: {})
      expect(page[:deferredProps]).to eq("default" => ["notifications"])
      expect(resolved).to be(false)
    end

    it "preserves deferred groups in metadata" do
      page = build_page(
        {
          sport: Inertia.deferred(group: "sidebar") { "hockey" },
          level: Inertia.deferred { "pro" },
        },
      )

      expect(page[:props]).to eq({ errors: {} })
      expect(page[:deferredProps]).to eq(
        "sidebar" => ["sport"],
        "default" => ["level"],
      )
    end

    it "omits parent hashes that become empty after deferred children are excluded" do
      page = build_page(
        {
          app: {
            auth: {
              notifications: Inertia.deferred(group: "alerts") { [] },
            },
          },
        },
      )

      expect(page[:props]).to eq({ errors: {} })
      expect(page[:deferredProps]).to eq("alerts" => ["app.auth.notifications"])
    end

    it "includes deferred props on exact partial request" do
      page = build_page(
        {
          auth: {
            user: "Jonathan",
            notifications: Inertia.deferred { ["msg"] },
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "auth.notifications",
        },
      )

      expect(page[:props][:auth].keys).to eq([:notifications])
      expect(page[:props][:auth][:notifications]).to eq(["msg"])
      expect(page).not_to have_key(:deferredProps)
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb
    # "multiple deferred props inside closure are excluded from initial load".
    it "collects metadata for deferred props inside closure-returned hashes" do
      notifications_resolved = false
      roles_resolved = false

      page = build_page(
        {
          auth: lambda {
            {
              user: "Jonathan",
              notifications: Inertia.deferred do
                notifications_resolved = true
                ["msg"]
              end,
              roles: Inertia.deferred do
                roles_resolved = true
                ["admin"]
              end,
            }
          },
        },
      )

      expect(page[:props]).to eq(auth: { user: "Jonathan" }, errors: {})
      expect(page[:deferredProps]).to eq("default" => ["auth.notifications", "auth.roles"])
      expect(notifications_resolved).to be(false)
      expect(roles_resolved).to be(false)
    end

    # Adapted from inertia-rails/spec/inertia/props_resolver_spec.rb
    # "multiple deferred props inside closure are resolved on partial request".
    it "resolves deferred props inside closure-returned hashes on partial request" do
      page = build_page(
        {
          auth: lambda {
            {
              user: "Jonathan",
              notifications: Inertia.deferred { ["msg"] },
              roles: Inertia.deferred { ["admin"] },
            }
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "auth.notifications,auth.roles",
        },
      )

      expect(page[:props][:auth][:user]).to eq("Jonathan")
      expect(page[:props][:auth][:notifications]).to eq(["msg"])
      expect(page[:props][:auth][:roles]).to eq(["admin"])
      expect(page).not_to have_key(:deferredProps)
    end
  end

  describe "once props" do
    # Adapted from inertia-rails/spec/inertia/rendering_spec.rb and props_resolver_spec.rb once prop cases.
    it "includes once props and compact metadata on initial load" do
      page = build_page(
        {
          cached_data: Inertia.once { "expensive data" },
          regular: "regular prop",
        },
      )

      expect(page[:props][:cached_data]).to eq("expensive data")
      expect(page[:props][:regular]).to eq("regular prop")
      expect(page[:onceProps]).to eq(
        "cached_data" => { prop: "cached_data", expiresAt: nil },
      )
    end

    it "uses custom keys in once metadata" do
      page = build_page({ cached_data: Inertia.once(key: "my_custom_key") { "expensive data" } })

      expect(page[:onceProps]).to eq(
        "my_custom_key" => { prop: "cached_data", expiresAt: nil },
      )
    end

    it "includes expiresAt when once props have an expiration" do
      page = build_page({ cached_data: Inertia.once(expires_in: 60) { "expensive data" } })

      expect(page[:onceProps]["cached_data"]).to include(prop: "cached_data")
      expect(page[:onceProps]["cached_data"][:expiresAt]).to be_a(Integer)
      expect(page[:onceProps]["cached_data"][:expiresAt]).to be > (Time.now.to_f * 1_000).to_i
    end

    it "excludes cached once props from props but keeps metadata" do
      page = build_page(
        {
          cached_data: Inertia.once { "expensive data" },
          regular: "regular prop",
        },
        {
          "HTTP_X_INERTIA_EXCEPT_ONCE_PROPS" => "cached_data",
        },
      )

      expect(page[:props]).to eq(regular: "regular prop", errors: {})
      expect(page[:onceProps]).to eq(
        "cached_data" => { prop: "cached_data", expiresAt: nil },
      )
    end

    it "excludes cached once props by custom key" do
      page = build_page(
        {
          cached_data: Inertia.once(key: "my_custom_key") { "expensive data" },
          regular: "regular prop",
        },
        {
          "HTTP_X_INERTIA_EXCEPT_ONCE_PROPS" => "my_custom_key",
        },
      )

      expect(page[:props]).to eq(regular: "regular prop", errors: {})
      expect(page[:onceProps]).to eq(
        "my_custom_key" => { prop: "cached_data", expiresAt: nil },
      )
    end

    it "returns cached once props when explicitly requested by partial reload" do
      page = build_page(
        {
          cached_data: Inertia.once { "expensive data" },
          regular: "regular prop",
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "cached_data",
          "HTTP_X_INERTIA_EXCEPT_ONCE_PROPS" => "cached_data",
        },
      )

      expect(page[:props].keys).to match_array([:cached_data, :errors])
      expect(page[:props][:cached_data]).to eq("expensive data")
      expect(page[:onceProps]).to eq(
        "cached_data" => { prop: "cached_data", expiresAt: nil },
      )
    end

    it "only includes requested once metadata on partial reloads" do
      page = build_page(
        {
          cached_one: Inertia.once { "first cached" },
          cached_two: Inertia.once { "second cached" },
          regular: "regular prop",
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "cached_one",
        },
      )

      expect(page[:props].keys).to match_array([:cached_one, :errors])
      expect(page[:onceProps]).to eq(
        "cached_one" => { prop: "cached_one", expiresAt: nil },
      )
    end

    it "excludes partial-excepted once metadata inside resolved lazy parents" do
      page = build_page(
        {
          dashboard: lambda {
            {
              summary: "ready",
              cached: Inertia.once { "cached data" },
            }
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "dashboard.summary",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "dashboard.cached",
        },
      )

      expect(page[:props]).to eq(
        dashboard: {
          summary: "ready",
          cached: "cached data",
        },
        errors: {}
      )
      expect(page).not_to have_key(:onceProps)
    end

    it "does not resolve cached once props inside resolved lazy parents unless explicitly requested" do
      page = build_page(
        {
          dashboard: lambda {
            {
              summary: "ready",
              cached: Inertia.once { "cached data" },
            }
          },
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_DATA" => "dashboard.summary",
          "HTTP_X_INERTIA_EXCEPT_ONCE_PROPS" => "dashboard.cached",
        },
      )

      expect(page[:props]).to eq(
        dashboard: {
          summary: "ready",
        },
        errors: {}
      )
      expect(page).not_to have_key(:onceProps)
    end

    it "excludes once metadata for props excluded by partial except" do
      page = build_page(
        {
          cached_one: Inertia.once { "first cached" },
          cached_two: Inertia.once { "second cached" },
          regular: "regular prop",
        },
        {
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "TestComponent",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "cached_two",
        },
      )

      expect(page[:props][:cached_one]).to eq("first cached")
      expect(page[:props][:regular]).to eq("regular prop")
      expect(page[:props]).not_to have_key(:cached_two)
      expect(page[:onceProps]).to eq(
        "cached_one" => { prop: "cached_one", expiresAt: nil },
      )
    end

    it "includes fresh once props even when the client has them cached" do
      page = build_page(
        {
          fresh_data: Inertia.once(fresh: true) { "fresh data" },
          stale_data: Inertia.once { "stale data" },
        },
        {
          "HTTP_X_INERTIA_EXCEPT_ONCE_PROPS" => "fresh_data,stale_data",
        },
      )

      expect(page[:props][:fresh_data]).to eq("fresh data")
      expect(page[:props]).not_to have_key(:stale_data)
      expect(page[:onceProps]).to eq(
        "fresh_data" => { prop: "fresh_data", expiresAt: nil },
        "stale_data" => { prop: "stale_data", expiresAt: nil },
      )
    end
  end

  describe "errors" do
    it "includes the errors object" do
      page = build_page({ name: "Jonathan" })

      expect(page[:props][:errors]).to eq({})
    end

    it "doesn't overwrite user-submitted errors" do
      page = build_page({ errors: { name: "is required" } })

      expect(page[:props][:errors]).to eq({ name: "is required" })
    end
  end
end
