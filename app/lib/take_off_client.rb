class TakeOffClient
  attr_reader :connection

  def initialize(url)
    @connection = establish_connection(url)
  end

  def health_check
    response = connection.get("/health-check")
    JSON.parse(response.body)
  end

  def flights_create(flight)
    response = connection.post("/flights", flight.to_json)
    JSON.parse(response.body)
  end

  def flights_list()
    response = connection.get("/flights")
    JSON.parse(response.body)
  end

  def flights_subscribe(flight_id, user)
    response = connection.post(
      "/flights/#{flight_id}/subscriptions",
      {
        user: user,
        webhook_uri: "http://localhost:8080/webhooks"
      }.to_json
    )
    JSON.parse(response.body)
  end

  def flights_subscriptions_list(flight_id)
    response = connection.get("/flights/#{flight_id}/subscriptions")
    JSON.parse(response.body)
  end

  def bookings_create(booking)
    make_request(:post, "/reservations", booking.to_json)
    # response = connection.post("/reservations", booking.to_json)
    # JSON.parse(response.body)
  end

  def bookings_list()
    response = connection.get("/reservations")
    JSON.parse(response.body)
  end

  def alerts_create(alert)
    response = connection.post("/alerts", alert.to_json)
    JSON.parse(response.body)
  end

  def alerts_list()
    response = connection.get("/alerts")
    JSON.parse(response.body)
  end

  private

  def make_request(method, path, body = nil)
    response = connection.send(method, path, body)
    JSON.parse(response.body)
  rescue => e
    binding.pry
    puts "Error. Response: #{response.inspect}"
    raise e
  end

  def establish_connection(url)
    Faraday.new(
      url: url,
      headers: {'Content-Type' => 'application/json'}
    ) 
  end
end