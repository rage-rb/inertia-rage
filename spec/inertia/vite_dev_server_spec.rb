# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::ViteDevServer do
  before do
    allow(Inertia::Frontend).to receive(:root).and_return("test-frontend-root")
    allow(Inertia::Frontend).to receive(:package_runner).and_return("pnpx")
  end

  it "starts the Vite server" do
    expect(Process).to receive(:spawn).with(/pnpx vite dev/, chdir: "test-frontend-root").and_return("vite-test-pid")
    expect(Process).to receive(:wait).with("vite-test-pid")

    described_class.new.perform
  end
end
