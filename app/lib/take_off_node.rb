class TakeOffNode
  attr_accessor :nodes
  attr_reader :base_port
  attr_reader :created_nodes

  def initialize(base_port = 27700)
    @base_port = base_port
    @created_nodes = 0
    @nodes = {}
  end

  def start_node
    port = base_port + created_nodes
    name = add_node(port)
    validate_node_alive(name)
    name
  end

  def start_nodes(count)
    ports = count.times.map { |i| base_port + created_nodes + i }
    node_names = ports.map { |port| add_node(port) }
    node_names.each do |name|
      validate_node_alive(name)
    end
  end

  def stop_node(name)
    `kill -9 $(lsof -s TCP:LISTEN -ti:#{nodes[name][:port]})`
    nodes.delete(name)
  end

  def stop_all
    nodes.each { |name, _| stop_node(name) }
  end

  def client(name)
    nodes[name][:client]
  end

  def some_client
    nodes.values.sample[:client]
  end

  def node_names
    nodes.keys
  end

  def clients
    nodes.values.map { |node| node[:client] }
  end

  private

  def add_node(port)
    name = "node-#{port}"
    `cd ../iasc-take-off && PORT=#{port} elixir --erl "-detached" --name #{name}@127.0.0.1 -S mix phx.server`
    nodes[name] = {port: port, client: TakeOffClient.new("http://localhost:#{port}")}
    @created_nodes += 1
    name
  end

  def validate_node_alive(name)
    10.times do
      puts "Validating health of node #{name}"
      client(name).health_check
      puts "Node #{name} ready"
      return
    rescue StandardError => e
      sleep(2)
    end

    raise StandardError, "Node #{name} could not be started"
  end
end