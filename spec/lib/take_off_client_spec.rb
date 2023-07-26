require 'rails_helper'

RSpec.describe TakeOffClient do
  def client(port)
    described_class.new("http://localhost:#{port}")
  end

  context 'when all goes good' do
    before(:all) do
      @node_manager = TakeOffNode.new
      @node_manager.start_nodes([27001, 27002])
    end

    after(:all) do
      @node_manager.stop_all
    end

    it 'creates a flight' do
      clients = @node_manager.nodes.values.map { |port| [port, client(port)] }.to_h

      # Create an alert
      alert = FactoryBot.build(:alert, :with_date, date: "2025-06-24")
      response = clients[27001].alerts_create(alert)
      expect(response).to eq("status" => "ok")

      # The alert exists in all nodes
      clients.values.each do |client|
        response = client.alerts_list()
        expect(response['value'].first['user']).to eq(alert[:user])
      end

      # Create a flight
      flight = FactoryBot.build(:flight, datetime: "2025-06-24T00:00:00Z", seats: { window: 25, aisle: 25, between_seats: 25 })
      response = clients[27001].flights_create(flight)
      expect(response).to include("status" => "ok")

      # The flight exists in all nodes
      clients.values.each do |client|
        response = client.flights_list()
        expect(response['value'].values.first['origin']).to eq(flight[:origin])
      end

      # Start a new node and check to see if it has the flight
      @node_manager.start_node(27004)
      clients[27004] = client(27004)
      response = clients[27004].flights_list()
      expect(response['value'].values.first['origin']).to eq(flight[:origin])

      # Subscribe to the flight
      flight_id = response['value'].values.first['id']
      response = clients.values.sample.flights_subscribe(flight_id, "user")
      expect(response).to eq("status" => "ok")

      # The subscription exists in all nodes
      clients.values.each do |client|
        response = client.flights_subscriptions_list(flight_id)
        expect(response['value'].first['user']).to eq("user")
      end

      # Delete a node to check everything keeps working
      @node_manager.stop_node("node-27001")
      clients.delete(27001)

      # Create a booking
      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 1, aisle: 0, between_seats: 0 })
      response = clients.values.sample.bookings_create(booking)
      expect(response).to include("status" => "booking_accepted")

      # The booking exists in all nodes
      clients.values.each do |client|
        response = client.bookings_list()
        expect(response['value'].first['user']).to eq(booking[:user])
      end

      # The subscription was deleted
      response = clients.values.sample.flights_subscriptions_list(flight_id)
      expect(response['value']).to be_empty

      # Other user creates a subscription
      response = clients.values.sample.flights_subscribe(flight_id, "other_user")
      expect(response).to eq("status" => "ok")

      # Buy all the available seats
      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 24, aisle: 25, between_seats: 25 })
      response = clients.values.sample.bookings_create(booking)
      expect(response).to include("status" => "booking_accepted")

      # The flight was closed
      response = clients.values.sample.flights_list()
      expect(response['value'].values.first['status']).to eq("closed")

      # The subscription of 'other_user' was deleted
      response = clients.values.sample.flights_subscriptions_list(flight_id)
      expect(response['value']).to be_empty

      # TODOs
      # - Stop a coordinator and check everything keeps working
    end
  end

  context 'when multiple people try to book the same seats' do
    before(:all) do
      @node_manager = TakeOffNode.new
      @node_manager.start_nodes(10.times.map { |i| 27400 + i } )
    end

    after(:all) do
      @node_manager.stop_all
    end

    it 'only valid bookings are accepted' do
      n = 30
      test_clients = n.times.map do |i|
        client(@node_manager.nodes.values.sample)
      end

      # Create a flight
      flight = FactoryBot.build(:flight, datetime: "2025-06-24T00:00:00Z", seats: { window: 2, aisle: 0, between_seats: 0 })
      response = test_clients.first.flights_create(flight)
      expect(response).to include("status" => "ok")
      flight_id = response['value']['id']

      sleep(2)

      booking = FactoryBot.build(:booking, flight_id: flight_id, user: "user", seats: { window: 1, aisle: 0, between_seats: 0 })

      responses = Parallel.map(test_clients, in_processes: n) do |client|
        client.bookings_create(booking)
      end

      expect( responses.count{ |r| r["status"] == "booking_accepted"} ).to eq(2)
      expect( responses.count{ |r| ["booking_denied", "flight_closed"].include?(r["status"]) }).to eq(n-2)
    end
  end
end