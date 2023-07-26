class TakeOffClient
  attr_reader :connection

  def initialize(url)
    @connection = establish_connection(url)
  end

  def health_check
    make_request(:get, "/health-check")
  end

  def flights_create(flight)
    make_request(:post, "/flights", flight.to_json)
  end

  def flights_list()
    make_request(:get, "/flights")
  end

  def flights_subscribe(flight_id, user)
    make_request(:post, "/flights/#{flight_id}/subscriptions", {
      user: user,
      webhook_uri: "http://localhost:8080/webhooks"
    }.to_json)
  end

  def flights_subscriptions_list(flight_id)
    make_request(:get, "/flights/#{flight_id}/subscriptions")
  end

  def flights_get_coordinator_node(flight_id)
    make_request(:get, "/flights/#{flight_id}/coordinator")
  end

  def bookings_create(booking)
    make_request(:post, "/reservations", booking.to_json)
  end

  def bookings_list()
    make_request(:get, "/reservations")
  end

  def alerts_create(alert)
    make_request(:post, "/alerts", alert.to_json)
  end

  def alerts_list()
    make_request(:get, "/alerts")
  end

  private

  def make_request(method, path, body = nil)
    response = connection.send(method, path, body)
    JSON.parse(response.body)
  rescue => e
    raise e
  end

  def establish_connection(url)
    Faraday.new(
      url: url,
      headers: {'Content-Type' => 'application/json'}
    ) 
  end
end