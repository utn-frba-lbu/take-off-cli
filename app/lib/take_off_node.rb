class TakeOffNode
  attr_accessor :nodes

  def initialize
    @nodes = {}
  end

  def start_node(port)
    add_node(port)
    validate_node_alive(port)
  end

  def start_nodes(ports)
    ports.each { |port| add_node(port) }
    ports.each do |port|
      validate_node_alive(port)
    end
  end

  def stop_node(name)
    `kill -9 $(lsof -s TCP:LISTEN -ti:#{nodes[name]})`
    nodes.delete(name)
  end

  def stop_all
    nodes.each { |name, _| stop_node(name) }
  end

  private

  def add_node(port)
    name = "node-#{port}"
    `cd ../iasc-take-off && PORT=#{port} elixir --erl "-detached" --name #{name}@127.0.0.1 -S mix phx.server`
    nodes[name] = port
  end

  def validate_node_alive(port)
    client = TakeOffClient.new("http://localhost:#{port}")

    10.times do
      puts "Validating health of node #{port}"
      client.health_check
      puts "Node #{port} ready"
      return
    rescue StandardError => e
      sleep(2)
    end

    raise StandardError, "Node #{port} could not be started"
  end
end