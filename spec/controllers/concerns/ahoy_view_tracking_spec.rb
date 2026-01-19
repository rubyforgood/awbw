# spec/controllers/concerns/ahoy_view_tracking_spec.rb
require "rails_helper"

RSpec.describe AhoyViewTracking, type: :controller do
  include Devise::Test::ControllerHelpers

  controller(ApplicationController) do
    include AhoyViewTracking

    def index
      @workshop = Workshop.find(params[:id])
      track_view(@workshop)
      head :ok
    end

    def print
      @workshop = Workshop.find(params[:id])
      track_print(@workshop)
      head :ok
    end

    def download
      @resource = Resource.find(params[:id])
      track_download(@resource)
      head :ok
    end
  end

  let(:user) { create(:user) }
  let(:workshop) { create(:workshop, :published) }
  let(:resource) { create(:resource) }

  before do
    sign_in user
    routes.draw do
      get "index" => "anonymous#index"
      post "print" => "anonymous#print"
      post "download" => "anonymous#download"
    end
    
    # Mock the ahoy tracker to properly create events
    visit = create(:ahoy_visit)
    tracker = instance_double("Ahoy::Tracker")
    allow(controller).to receive(:ahoy).and_return(tracker)
    allow(tracker).to receive(:track) do |event_name, properties|
      create(:ahoy_event, visit: visit, name: event_name, properties: properties)
    end
  end

  describe "#track_view" do
    it "creates an Ahoy event with the correct name format" do
      expect {
        get :index, params: { id: workshop.id }
      }.to change(Ahoy::Event, :count).by(1)

      event = Ahoy::Event.last
      expect(event.name).to eq("view.workshop")
      expect(event.properties["resource_type"]).to eq("Workshop")
      expect(event.properties["resource_id"]).to eq(workshop.id)
      expect(event.properties["resource_title"]).to eq(workshop.title)
    end

    it "does not create duplicate events in the same session" do
      expect {
        get :index, params: { id: workshop.id }
        get :index, params: { id: workshop.id }
      }.to change(Ahoy::Event, :count).by(1)
    end

    it "creates events for different resources in the same session" do
      workshop2 = create(:workshop, :published)

      expect {
        get :index, params: { id: workshop.id }
        get :index, params: { id: workshop2.id }
      }.to change(Ahoy::Event, :count).by(2)
    end
  end

  describe "#track_print" do
    it "creates an Ahoy event with the correct name format" do
      expect {
        post :print, params: { id: workshop.id }
      }.to change(Ahoy::Event, :count).by(1)

      event = Ahoy::Event.last
      expect(event.name).to eq("print.workshop")
      expect(event.properties["resource_type"]).to eq("Workshop")
      expect(event.properties["resource_id"]).to eq(workshop.id)
    end

    it "does not create duplicate print events in the same session" do
      expect {
        post :print, params: { id: workshop.id }
        post :print, params: { id: workshop.id }
      }.to change(Ahoy::Event, :count).by(1)
    end
  end

  describe "#track_download" do
    it "creates an Ahoy event with the correct name format" do
      expect {
        post :download, params: { id: resource.id }
      }.to change(Ahoy::Event, :count).by(1)

      event = Ahoy::Event.last
      expect(event.name).to eq("download.resource")
      expect(event.properties["resource_type"]).to eq("Resource")
      expect(event.properties["resource_id"]).to eq(resource.id)
    end

    it "does not create duplicate download events in the same session" do
      expect {
        post :download, params: { id: resource.id }
        post :download, params: { id: resource.id }
      }.to change(Ahoy::Event, :count).by(1)
    end
  end

  describe "session tracking" do
    it "uses separate session keys for different actions" do
      get :index, params: { id: workshop.id }
      post :print, params: { id: workshop.id }

      expect(Ahoy::Event.count).to eq(2)
      expect(Ahoy::Event.pluck(:name)).to contain_exactly("view.workshop", "print.workshop")
    end

    it "maintains session state across requests" do
      get :index, params: { id: workshop.id }
      
      session_key = :"ahoy_tracked_view_Workshop_ids"
      expect(controller.session[session_key]).to include(workshop.id)
    end
  end
end
