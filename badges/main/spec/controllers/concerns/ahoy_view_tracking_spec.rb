require "rails_helper"

RSpec.describe AhoyTracking, type: :controller do
  controller(ApplicationController) do
    include AhoyTracking

    def index
      workshop = Workshop.find(params[:id])
      track_view(workshop)
      head :ok
    end

    def print
      workshop = Workshop.find(params[:id])
      track_print(workshop)
      head :ok
    end

    def download
      resource = Resource.find(params[:id])
      track_download(resource)
      head :ok
    end
  end

  let(:workshop) { create(:workshop, :published) }
  let(:resource) { create(:resource) }
  let(:visit)    { create(:ahoy_visit) }
  let(:session_hash) { {} }

  before do
    routes.draw do
      get  "index"    => "anonymous#index"
      post "print"    => "anonymous#print"
      post "download" => "anonymous#download"
    end

    # Give the controller a persistent session hash
    allow(controller).to receive(:session).and_return(session_hash)

    tracker = instance_double(Ahoy::Tracker)
    allow(controller).to receive(:ahoy).and_return(tracker)
    allow(tracker).to receive(:set_visitor_cookie)
    allow(tracker).to receive(:set_visit_cookie)
    allow(tracker).to receive(:new_visit?).and_return(false)
    allow(tracker).to receive(:visit_token).and_return("test-visit-token")

    allow(tracker).to receive(:track) do |name, properties|
      create(
        :ahoy_event,
        visit: visit,
        name: name,
        properties: properties
      )
    end
  end

  describe "#track_view" do
    xit "creates a view event with correct properties" do
      expect {
        get :index, params: { id: workshop.id }
      }.to change(Ahoy::Event, :count).by(1)

      event = Ahoy::Event.last
      expect(event.name).to eq("view.workshop")
      expect(event.properties["resource_type"]).to eq("Workshop")
      expect(event.properties["resource_id"]).to eq(workshop.id)
    end

    xit "deduplicates views in the same session" do
      expect {
        2.times { get :index, params: { id: workshop.id } }
      }.to change(Ahoy::Event, :count).by(1)
    end
  end

  describe "#track_print" do
    xit "creates a print event" do
      expect {
        post :print, params: { id: workshop.id }
      }.to change(Ahoy::Event, :count).by(1)

      expect(Ahoy::Event.last.name).to eq("print.workshop")
    end
  end

  describe "#track_download" do
    xit "creates a download event" do
      expect {
        post :download, params: { id: resource.id }
      }.to change(Ahoy::Event, :count).by(1)

      expect(Ahoy::Event.last.name).to eq("download.resource")
    end

    xit "deduplicates downloads per session" do
      expect {
        2.times { post :download, params: { id: resource.id } }
      }.to change(Ahoy::Event, :count).by(1)
    end
  end

  describe "#track_index_intent" do
    it "handles a plain count (integer)" do
      scope = double("scope", respond_to?: false)
      allow(scope).to receive(:respond_to?).with(:total_entries).and_return(false)
      allow(scope).to receive(:respond_to?).with(:count).and_return(true)
      allow(scope).to receive(:unscope).with(:select, :order).and_return(scope)
      allow(scope).to receive(:count).and_return(42)

      expect(Analytics::AhoyTracker).to receive(:track_index_intent).with(
        controller, Workshop, params: anything, result_count: 42
      )

      controller.send(:track_index_intent, Workshop, scope, {})
    end

    it "handles a grouped count (hash) from scopes with GROUP BY" do
      scope = double("scope", respond_to?: false)
      allow(scope).to receive(:respond_to?).with(:total_entries).and_return(false)
      allow(scope).to receive(:respond_to?).with(:count).and_return(true)
      allow(scope).to receive(:unscope).with(:select, :order).and_return(scope)
      allow(scope).to receive(:count).and_return({ 1 => 3, 2 => 5, 3 => 1 })

      expect(Analytics::AhoyTracker).to receive(:track_index_intent).with(
        controller, Workshop, params: anything, result_count: 3
      )

      controller.send(:track_index_intent, Workshop, scope, {})
    end

    it "handles a will_paginate scope" do
      scope = double("scope")
      allow(scope).to receive(:respond_to?).with(:total_entries).and_return(true)
      allow(scope).to receive(:total_entries).and_return(15)

      expect(Analytics::AhoyTracker).to receive(:track_index_intent).with(
        controller, Workshop, params: anything, result_count: 15
      )

      controller.send(:track_index_intent, Workshop, scope, {})
    end

    it "handles a popularity-sorted scope with virtual bookmarks_count column" do
      create(:workshop, :published)
      scope = Workshop.with_bookmarks_count.published.order(bookmarks_count: :desc, title: :asc)

      expect(Analytics::AhoyTracker).to receive(:track_index_intent).with(
        controller, Workshop, params: anything, result_count: 1
      )

      controller.send(:track_index_intent, Workshop, scope, {})
    end

    it "returns 0 when scope has no count method" do
      scope = double("scope")
      allow(scope).to receive(:respond_to?).with(:total_entries).and_return(false)
      allow(scope).to receive(:respond_to?).with(:count).and_return(false)

      expect(Analytics::AhoyTracker).to receive(:track_index_intent).with(
        controller, Workshop, params: anything, result_count: 0
      )

      controller.send(:track_index_intent, Workshop, scope, {})
    end
  end

  describe "session isolation" do
    xit "tracks different actions separately" do
      get  :index, params: { id: workshop.id }
      post :print, params: { id: workshop.id }

      expect(Ahoy::Event.pluck(:name))
        .to contain_exactly("view.workshop", "print.workshop")
    end
  end
end
