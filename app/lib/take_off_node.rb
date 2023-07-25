class TakeOffNode
  attr_accessor :nodes

  def initialize
    @nodes = {}
  end

  def start_node(port)
    add_node(port)
  end

  def start_nodes(ports)
    ports.each { |port| add_node(port) }
  end

  def stop_node(name)
    `kill $(lsof -s TCP:LISTEN -ti:#{nodes[name]})`
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

    client = TakeOffClient.new("http://localhost:#{port}")

    10.times do
      client.health_check
      puts "Node #{name} started"
      return
    rescue StandardError => e
      puts e
      sleep(1)
    end

    raise StandardError, "Node #{name} could not be started"
  end
end