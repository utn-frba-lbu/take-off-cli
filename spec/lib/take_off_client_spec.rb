require 'rails_helper'

RSpec.describe TakeOffClient do
  context 'when all goes good' do
    before(:all) do
      @node_manager = TakeOffNode.new(27220)
      sleep(5)
    end

    after(:all) do
      @node_manager.stop_all
    end

    it 'creates a flight' do
      @node_manager.start_nodes(2)

      # Create an alert
      alert = FactoryBot.build(:alert, :with_date, date: "2025-06-24")
      response = @node_manager.some_client.alerts_create(alert)
      expect(response).to eq("status" => "ok")

      # The alert should exist in all nodes
      @node_manager.clients.each do |client|
        response = client.alerts_list()
        expect(response['value'].first['user']).to eq(alert[:user])
      end

      # Create a flight
      flight = FactoryBot.build(:flight, datetime: "2025-06-24T00:00:00Z", seats: { window: 25, aisle: 25, between_seats: 25 })
      response = @node_manager.some_client.flights_create(flight)
      expect(response).to include("status" => "ok")

      # The flight should exist in all nodes
      @node_manager.clients.each do |client|
        response = client.flights_list()
        expect(response['value'].values.first['origin']).to eq(flight[:origin])
      end

      # Start a new node and check if it has the flight
      new_node_name = @node_manager.start_node
      response = @node_manager.client(new_node_name).flights_list()
      expect(response['value'].values.first['origin']).to eq(flight[:origin])

      # Subscribe to the flight
      flight_id = response['value'].values.first['id']
      response = @node_manager.some_client.flights_subscribe(flight_id, "user")
      expect(response).to eq("status" => "ok")

      # The subscription exists in all nodes
      @node_manager.clients.each do |client|
        response = client.flights_subscriptions_list(flight_id)
        expect(response['value'].first['user']).to eq("user")
      end

      # Delete a node to check everything keeps working
      @node_manager.stop_node(@node_manager.node_names.first)

      # Create a booking
      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 1, aisle: 0, between_seats: 0 })
      response = @node_manager.some_client.bookings_create(booking)
      expect(response).to include("status" => "booking_accepted")

      # The booking exists in all nodes
      @node_manager.clients.each do |client|
        response = client.bookings_list()
        expect(response['value'].first['user']).to eq(booking[:user])
      end

      # The subscription is deleted
      response = @node_manager.some_client.flights_subscriptions_list(flight_id)
      expect(response['value']).to be_empty

      # Other user creates a subscription
      response = @node_manager.some_client.flights_subscribe(flight_id, "other_user")
      expect(response).to eq("status" => "ok")

      # Buy all the available seats
      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 24, aisle: 25, between_seats: 25 })
      response = @node_manager.some_client.bookings_create(booking)
      expect(response).to include("status" => "booking_accepted")

      # The flight is closed
      response = @node_manager.some_client.flights_list()
      expect(response['value'].values.first['status']).to eq("closed")

      # The subscription of 'other_user' is deleted
      response = @node_manager.some_client.flights_subscriptions_list(flight_id)
      expect(response['value']).to be_empty
    end
  end

  context 'when the coordinator node goes down' do
    before(:all) do
      sleep(5)
      @node_manager = TakeOffNode.new(27240)
    end

    after(:all) do
      @node_manager.stop_all
    end

    it 'other coordintor is created to confirm bookings' do
      @node_manager.start_nodes(2)

      # Create a flight and validate it is created
      flight = FactoryBot.build(:flight, datetime: "2025-06-24T00:00:00Z", seats: { window: 2, aisle: 0, between_seats: 0 })
      response = @node_manager.some_client.flights_create(flight)
      flight_id = response['value']['id']
      expect(response).to include("status" => "ok")

      sleep(2)

      # Create a booking
      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 1, aisle: 0, between_seats: 0 })
      response = @node_manager.some_client.bookings_create(booking)
      expect(response).to include("status" => "booking_accepted")

      # Get the coordinator node and validate the name is correct
      response = @node_manager.clients.first.flights_get_coordinator_node(flight_id)
      coordinator_node_name = response['value'].split('@').first
      expect(coordinator_node_name).to include("node")

      # Stop the coordinator node
      @node_manager.stop_node(coordinator_node_name)

      sleep(1)

      # Get the new coordinator node. It should be different from the previous one
      response = @node_manager.some_client.flights_get_coordinator_node(flight_id)
      new_coordinator_node_name = response['value'].split('@').first
      expect(new_coordinator_node_name).to_not eq(coordinator_node_name)

      # Create two new bookings, one should be accepted and the other one denied
      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 1, aisle: 0, between_seats: 0 })
      response = @node_manager.some_client.bookings_create(booking)
      expect(response).to include("status" => "booking_accepted")

      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 1, aisle: 0, between_seats: 0 })
      response = @node_manager.some_client.bookings_create(booking)
      expect(response).to include("status" => "flight_closed")
    end
  end

  context 'when multiple people try to book the same seats' do
    before(:all) do
      sleep(5)
      @node_manager = TakeOffNode.new(27260)
    end

    after(:all) do
      @node_manager.stop_all
    end

    it 'only valid bookings are accepted' do
      @node_manager.start_nodes(10)

      # Create a flight
      flight = FactoryBot.build(:flight, datetime: "2025-06-24T00:00:00Z", seats: { window: 2, aisle: 0, between_seats: 0 })
      response = @node_manager.some_client.flights_create(flight)
      expect(response).to include("status" => "ok")
      flight_id = response['value']['id']

      sleep(2)

      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 1, aisle: 0, between_seats: 0 })

      # Try to create 10 bookings in parallel
      responses = Parallel.map(@node_manager.clients, in_processes: 16) do |client|
        client.bookings_create(booking)
      end

      # Only 2 bookings should be accepted
      expect( responses.count{ |r| r["status"] == "booking_accepted"} ).to eq(2)
      expect( responses.count{ |r| ["booking_denied", "flight_closed"].include?(r["status"]) }).to eq(8)
    end
  end
end