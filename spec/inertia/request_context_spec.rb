# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::RequestContext do
  subject(:context) { described_class.new(request, component:) }

  let(:headers) { {} }
  let(:component) { "TestComponent" }
  let(:fullpath) { "/deeply_nested_props?filter=active&page=2" }
  let(:request) { double(fullpath:, env: headers) }

  describe "#url" do
    it "returns the request full path including query string" do
      expect(context.url).to eq(fullpath)
    end
  end

  describe "#partial_render?" do
    context "when X-Inertia-Partial-Component matches the rendered component" do
      let(:headers) { { "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component } }

      it "returns true" do
        expect(context.partial_render?).to be(true)
      end
    end

    context "when X-Inertia-Partial-Component is absent" do
      it "returns false" do
        expect(context.partial_render?).to be(false)
      end
    end

    context "when X-Inertia-Partial-Component does not match the rendered component" do
      let(:headers) { { "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "OtherComponent" } }

      it "returns false" do
        expect(context.partial_render?).to be(false)
      end
    end
  end

  describe "#once_prop_excluded?" do
    context "without X-Inertia-Except-Once-Props" do
      it "does not exclude once props" do
        expect(context.once_prop_excluded?("cached_data")).to be(false)
      end
    end

    context "with X-Inertia-Except-Once-Props" do
      let(:headers) { { "HTTP_X_INERTIA_EXCEPT_ONCE_PROPS" => "cached_data,my_custom_key,config.locale" } }

      # Adapted from inertia-rails/spec/inertia/rendering_spec.rb once prop cache header specs.
      it "excludes exact cached once prop keys" do
        expect(context.once_prop_excluded?("cached_data")).to be(true)
        expect(context.once_prop_excluded?("my_custom_key")).to be(true)
        expect(context.once_prop_excluded?("config.locale")).to be(true)
      end

      it "does not exclude partial key matches" do
        expect(context.once_prop_excluded?("config")).to be(false)
        expect(context.once_prop_excluded?("config.locale.name")).to be(false)
        expect(context.once_prop_excluded?("cached")).to be(false)
      end
    end
  end

  describe "#prop_status" do
    def expect_prop_statuses(expected)
      expected.each do |prop_name, status|
        expect(context.prop_status(prop_name)).to eq(status), "expected #{prop_name.inspect} to be #{status.inspect}"
      end
    end

    context "without partial headers" do
      it "leaves props unspecified" do
        expect_prop_statuses(
          "flat" => :unspecified,
          "nested" => :unspecified,
          "nested.first" => :unspecified,
        )
      end
    end

    context "when X-Inertia-Partial-Component is absent" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested.first",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.second",
        }
      end

      it "ignores partial reload filtering" do
        expect_prop_statuses(
          "flat" => :unspecified,
          "nested" => :unspecified,
          "nested.first" => :unspecified,
          "nested.second" => :unspecified,
        )
      end
    end

    context "when X-Inertia-Partial-Component does not match the rendered component" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested.first",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.second",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => "OtherComponent",
        }
      end

      it "ignores partial reload filtering" do
        expect_prop_statuses(
          "flat" => :unspecified,
          "nested" => :unspecified,
          "nested.first" => :unspecified,
          "nested.second" => :unspecified,
        )
      end
    end

    context "with X-Inertia-Partial-Data" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested.first,nested.deeply_nested.second,nested.deeply_nested.what_about_nil",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      # Adapted from inertia-rails/spec/inertia/rendering_spec.rb "with dot notation".
      it "requests exact paths and their ancestors" do
        expect_prop_statuses(
          "nested" => :requested,
          "nested.first" => :requested,
          "nested.deeply_nested" => :requested,
          "nested.deeply_nested.second" => :requested,
          "nested.deeply_nested.what_about_nil" => :requested,
        )
      end

      it "excludes sibling and unrelated paths" do
        expect_prop_statuses(
          "flat" => :excluded,
          "nested.second" => :excluded,
          "nested.deeply_nested.first" => :excluded,
          "nested.deeply_nested.what_about_empty_hash" => :excluded,
        )
      end
    end

    context "when X-Inertia-Partial-Data targets a parent path" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      it "requests descendants of the requested parent" do
        expect_prop_statuses(
          "nested" => :requested,
          "nested.first" => :requested,
          "nested.deeply_nested" => :requested,
          "nested.deeply_nested.second" => :requested,
          "flat" => :excluded,
        )
      end
    end

    context "when X-Inertia-Partial-Data shares prefixes with other props" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested.deep",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      it "matches only exact path segments" do
        expect_prop_statuses(
          "nested" => :requested,
          "nested.deep" => :requested,
          "nested.deep.value" => :requested,
          "nestedness" => :excluded,
          "nested.deeply" => :excluded,
          "nested.deeply.value" => :excluded,
          "nested.deep_extra" => :excluded,
        )
      end
    end

    context "when X-Inertia-Partial-Except shares prefixes with other props" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.deep",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      it "excludes only exact excepted path segments and descendants" do
        expect_prop_statuses(
          "flat" => :requested,
          "nested" => :requested,
          "nested.deep" => :excluded,
          "nested.deep.value" => :excluded,
          "nestedness" => :requested,
          "nested.deeply" => :requested,
          "nested.deeply.value" => :requested,
          "nested.deep_extra" => :requested,
        )
      end
    end

    context "with X-Inertia-Partial-Except and no X-Inertia-Partial-Data" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      # Adapted from inertia-rails/spec/inertia/rendering_spec.rb
      # "when except without X-Inertia-Partial-Data".
      it "requests all non-excepted props" do
        expect_prop_statuses(
          "flat" => :requested,
          "optional" => :requested,
          "nested_optional" => :requested,
          "nested_optional.first" => :requested,
        )
      end

      it "excludes exact excepted paths and their descendants" do
        expect_prop_statuses(
          "nested" => :excluded,
          "nested.first" => :excluded,
          "nested.deeply_nested" => :excluded,
        )
      end
    end

    context "with both X-Inertia-Partial-Data and X-Inertia-Partial-Except" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "lazy,nested.deeply_nested",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.deeply_nested.first",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      # Adapted from inertia-rails/spec/inertia/rendering_spec.rb
      # "with both partial and except dot notation".
      it "requests selected paths that are not excepted" do
        expect_prop_statuses(
          "lazy" => :requested,
          "nested" => :requested,
          "nested.deeply_nested" => :requested,
          "nested.deeply_nested.second" => :requested,
        )
      end

      it "excludes excepted paths and descendants even when their parent is requested" do
        expect_prop_statuses(
          "nested.deeply_nested.first" => :excluded,
          "nested.deeply_nested.first.name" => :excluded,
        )
      end

      it "excludes paths that are not selected by partial data" do
        expect_prop_statuses(
          "flat" => :excluded,
          "nested.first" => :excluded,
        )
      end
    end

    context "when the same path is in X-Inertia-Partial-Data and X-Inertia-Partial-Except" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "lazy",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "lazy",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      # Adapted from inertia-rails/spec/inertia/rendering_spec.rb
      # "with partial data that includes and excludes the same prop".
      it "lets except take precedence" do
        expect_prop_statuses(
          "lazy" => :excluded,
          "lazy.value" => :excluded,
          "flat" => :excluded,
        )
      end
    end

    context "when X-Inertia-Partial-Except has an unknown prop" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested_optional",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "unknown",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      # Adapted from inertia-rails/spec/inertia/rendering_spec.rb "when except unknown prop".
      it "does not affect requested partial data" do
        expect_prop_statuses(
          "nested_optional" => :requested,
          "nested_optional.first" => :requested,
          "unknown" => :excluded,
          "unknown.child" => :excluded,
          "flat" => :excluded,
        )
      end
    end

    context "when X-Inertia-Partial-Except excludes nested children" do
      let(:headers) do
        {
          "HTTP_X_INERTIA_PARTIAL_DATA" => "nested,nested_optional",
          "HTTP_X_INERTIA_PARTIAL_EXCEPT" => "nested.first,nested_optional.first",
          "HTTP_X_INERTIA_PARTIAL_COMPONENT" => component,
        }
      end

      # Adapted from inertia-rails/spec/inertia/rendering_spec.rb "when excludes with dot notation".
      it "keeps ancestors and siblings of excepted nested props" do
        expect_prop_statuses(
          "nested" => :requested,
          "nested.first" => :excluded,
          "nested.first.name" => :excluded,
          "nested.second" => :requested,
          "nested_optional" => :requested,
          "nested_optional.first" => :excluded,
        )
      end
    end
  end
end
