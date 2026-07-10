# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::ViteDevServer do
  subject { described_class.new }

  before do
    allow(Inertia::Frontend).to receive(:root).and_return("test-frontend-root")
    allow(Inertia::Frontend).to receive(:package_runner).and_return("pnpx")
  end

  it "starts the Vite server" do
    expect(Process).to receive(:spawn).with(/pnpx vite dev/, chdir: "test-frontend-root").and_return("vite-test-pid")
    expect(Process).to receive(:wait).with("vite-test-pid")

    subject.perform
  end

  it "respects dev server configuration" do
    allow(Inertia.config).to receive(:dev_server).and_return(double(host: "testhost", port: 1234))
    allow(Process).to receive(:wait)

    expect(Process).to receive(:spawn).with(/--host testhost --port 1234/, anything).and_return("vite-test-pid")

    subject.perform
  end
end
