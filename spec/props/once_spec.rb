# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "active_support/testing/time_helpers"

RSpec.describe Inertia::Props::Once do
  include ActiveSupport::Testing::TimeHelpers

  describe "#expires_at" do
    subject { described_class.new(key: "test", fresh: false, expires_in: expires_in, block: -> {}) }

    let(:now) { Time.utc(2025, 1, 15, 12, 0, 0) }

    around { |example| travel_to(now) { example.run } }

    context "when expires_in is nil" do
      let(:expires_in) { nil }

      it "returns nil" do
        expect(subject.expires_at).to be_nil
      end
    end

    context "when expires_in is an Integer" do
      let(:expires_in) { 60 }

      it "returns a timestamp in milliseconds" do
        expected = ((now + 60).to_f * 1_000).to_i

        expect(subject.expires_at).to eq(expected)
      end
    end

    context "when expires_in is an ActiveSupport::Duration" do
      let(:expires_in) { 1.day }

      it "returns a timestamp 30 minutes in the future" do
        expected = ((now + 1.day).to_f * 1_000).to_i

        expect(subject.expires_at).to eq(expected)
      end
    end
  end
end
