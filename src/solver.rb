require_relative 'moc.rb'
require 'set'

class Solver
    attr_accessor :instance, :solution, :cost, :value, :solution_adjacent_vertices, :solution_adjacency_count, :non_articulation_points,
                             :best_solution, :best_value, :best_solution_adjacent_vertices, :best_solution_adjacency_count, :best_non_articulation_points

    def initialize(file_name, output_file_name, seed)
        @output_file_name = output_file_name
        @instance_name = file_name.split('/')[1]
        @instance = Moc.new(file_name)
        @solution = Set.new
        @non_articulation_points = Set.new
        @cost = 0
        @value = @best_value = 0
        @count = 0
        @seed = seed
        srand(@seed)

        vertices = @instance.graph.number_of_vertices
        @solution_adjacency_count = Array.new(vertices, 0)
        @solution_adjacent_vertices = (0...vertices).to_set
    end

    def solve
        start = Time.now
        generate_initial_solution
        pi = 0.9
        pf = 0.001
        i = 50 + (0.005 * @instance.graph.number_of_vertices).to_i
        r = 0.995
        sas = 3
        simulated_annealing(pi, pf, i, r, sas)
        final = Time.now        

        save_to_file(start, final)
    end

    def valid?
        @instance.graph.subgraph_is_connected?(@solution)
    end

    def best_valid?
        @instance.graph.subgraph_is_connected?(@best_solution)
    end

    def calc_val
        @instance.values
                 .values_at(*@solution)
                 .inject(0, :+)
    end

    def calc_best_val
        @instance.values
                 .values_at(*@best_solution)
                 .inject(0, :+)
    end

    private
    def simulated_annealing(pi, pf, iterations_per_temperature, cooling_factor, sas)
        @max_tries = (1 / pf).to_i
        temperature = calculate_initial_temp(pi)

        puts "Initial temperature: #{temperature}"
        puts "============================================"
        sleep 3

        @tries_left = @max_tries

        while @tries_left > 0 do
            iterations_per_temperature.times do
                @count += 1
                dump
                generate_random_neighbor 
                if new_solution_is_acceptable temperature
                    commit
                    @tries_left = @max_tries if @value != @value_dump && @tries_left > 0 # Se atualizou o valor, uma nova solução foi aceita, reseta o contador
                    update_best_solution
                    puts "Iteration: #{@count} | #{@value.to_i} / #{@best_value.to_i} / #{temperature.round(2)}" if @value > @value_dump
                else
                    rollback
                    @tries_left -= 1
                end
            end
            temperature *= cooling_factor
        end
    end

    def local_search
        @tries_left = @max_tries * 5

        puts "============================================"
        puts "Starting local search..."

        while @tries_left > 0 do
            @count += 1
            dump
            generate_random_neighbor 
            puts "Valor: #{@value} / #{@best_value} / #{@tries_left}" if @value.round(4) > @best_value.round(4)
            if @value.round(4) > @best_value.round(4)
                commit
                update_best_solution
                @tries_left = @max_tries * 5
            else
                rollback
                @tries_left -= 1
            end
        end
        rebuild_best_solution
    end

    def rebuild_best_solution
        @solution = @best_solution.clone
        @value = @best_value
        @solution_adjacent_vertices = @best_solution_adjacent_vertices.clone
        @solution_adjacency_count = @best_solution_adjacency_count.clone
        @non_articulation_points = @best_non_articulation_points.clone
        update_cost
    end

    def calculate_temperatures(pi, pf)
        puts "============================================"
        puts "Calculating temperatures..."
        ti = calculate_initial_temp(pi)
        delta = -Math.log(pi) * ti
        tf = -delta / Math.log(pf)
        puts "Inicial: #{ti} / Final: #{tf}"
        [ti, tf]
    end

    def calculate_initial_temp(pi)
        temperature = 50 + @best_value / 100
        prob = 0.0
        iterations = (50 / (1.1 - pi)).to_i

        while prob < pi
            tried = succeded = 0.0
            temperature *= 1.1
            iterations.times do
                dump
                generate_random_neighbor
                exponent = (@value - @value_dump) / temperature

                if exponent >= 0
                    acceptable = true
                else
                    acceptable = rand < Math.exp(exponent)
                    tried += 1
                    succeded += 1 if acceptable
                end

                if acceptable
                    commit
                else
                    rollback
                end
            end
            prob = succeded / tried
        end
        temperature
    end

    def save_to_file(start, final)
        time = final - start
        out = ''
        out += "Instance #{@instance_name} solved in #{time.round(2)} / #{start} - #{final}\n"
        out += "Cost: #{@cost.round(2)}/#{@instance.max_weight.round(2)}\n"
        out += "Value: #{@best_value.round(2)}\n"
        out += "Total Iterations: #{@count}\n"
        out += "Solution size: #{@best_solution.count}\n"
        out += "Solution: #{@best_solution.to_a.to_s}\n"
        out += "Seed: #{@seed}\n"

        File.open(@output_file_name, "w+") do |f|
            f.puts out
        end

        puts out
    end

    def generate_random_neighbor
        if rand > 0.5 # Add item
            add_random_item
            remove_items_while_needed
        else # Remove item
            remove_random_item
            add_items_while_possible
        end
    end

    def update_best_solution
        if @value > @best_value
            @best_solution = @solution.clone
            @best_value = @value
            @best_solution_adjacent_vertices = @solution_adjacent_vertices.clone
            @best_solution_adjacency_count = @solution_adjacency_count.clone
            @best_non_articulation_points = @non_articulation_points.clone
        end
    end

    def new_solution_is_acceptable(temperature)
        exponent = (@value - @value_dump) / temperature

        if exponent >= 0
            acceptable = true
        else
            acceptable = rand < Math.exp(exponent)
        end
    end

    def sort_items_by_cost_benefit
        weights = @instance.weights
        values = @instance.values
        cost_benefit = values.zip(weights).map { |val, cost| val / cost }
        cost_benefit.map.with_index.sort.map(&:last).reverse
    end

    def update_cost
        @cost = @instance.weights
                         .values_at(*@solution)
                         .inject(0, :+)
    end

    def generate_initial_solution
        puts "============================================"
        cb_sorted = sort_items_by_cost_benefit
        # v = @instance.graph.get_highest_degree_vertex
        v = cb_sorted.find { |v| can_be_added(v) }
        @solution_adjacent_vertices = Set[v]
        while !v.nil? do
            add_to_solution v
            v = cb_sorted.find { |v| can_be_added(v) }
        end
        calculate_articulation_points
        update_best_solution
        puts "Initial value: #{@value.to_i}"
    end

    def build_random_solution
        puts "============================================"
        puts "Generating random solution..."
        @solution = Set.new
        @non_articulation_points = Set.new
        @cost = 0
        @value = 0

        vertices = @instance.graph.number_of_vertices
        @solution_adjacency_count = Array.new(vertices, 0)
        @solution_adjacent_vertices = (0...vertices).to_set

        vertices = (0...@instance.graph.number_of_vertices).to_a.shuffle
        v = vertices.find { |v| can_be_added(v) }
        @solution_adjacent_vertices = Set[v]
        while !v.nil? do
            add_to_solution v
            v = vertices.find { |v| can_be_added(v) }
        end
        calculate_articulation_points
        puts "Done"
        puts "Value: #{@value}"
        puts "Solution count: #{@solution.count}"
    end

    def can_be_added(v)
        fit_on_knapsack = @instance.weights[v] + @cost <= @instance.max_weight
        is_adjacent_to_solution = @solution_adjacent_vertices.include?(v)

        fit_on_knapsack && is_adjacent_to_solution
    end

    def add_to_solution(v)
        # p @solution.include? v
        @solution.add v
        @solution_adjacent_vertices.delete v
        adjacent_vertices = @instance.graph.get_neighbors(v)
        adjacent_vertices.each do |adj|
            @solution_adjacency_count[adj] += 1
            @solution_adjacent_vertices.add adj unless @solution.include?(adj)
        end

        @cost += @instance.weights[v]
        @value += @instance.values[v]

    end

    def add_random_item
        index = rand @solution_adjacent_vertices.size
        add_to_solution @solution_adjacent_vertices.to_a[index]
        calculate_articulation_points
    end

    def add_items_while_possible
        items = @solution_adjacent_vertices.clone
        items.keep_if do |adj|
            @instance.weights[adj] + @cost <= @instance.max_weight
        end

        until items.empty?
            index = rand items.size
            add_to_solution items.to_a[index]
            items = items.keep_if do |adj|
                @instance.weights[adj] + @cost <= @instance.max_weight && @solution_adjacent_vertices.include?(adj)
            end
        end
        calculate_articulation_points
    end

    def remove_from_solution(v)
        @solution.delete v
        @solution_adjacent_vertices.add v
        adjacent_vertices = @instance.graph.get_neighbors(v)
        adjacent_vertices.each do |adj|
            @solution_adjacency_count[adj] -= 1
            @solution_adjacent_vertices.delete adj if @solution_adjacency_count[adj].zero?
        end

        @cost -= @instance.weights[v]
        @value -= @instance.values[v]
    end

    def remove_random_item
        index = rand @non_articulation_points.size
        remove_from_solution @non_articulation_points.to_a[index]
        calculate_articulation_points
    end

    def remove_items_while_needed
        while @cost > @instance.max_weight
            index = rand @non_articulation_points.size
            remove_from_solution @non_articulation_points.to_a[index]
            calculate_articulation_points
        end
    end

    # Method used to calculate articulation points of the actual solution,
    # useful for removing vertices without testing the connectivity of the graph.
    def calculate_articulation_points
        @non_articulation_points = @solution.clone
        initial_vertex = @solution.first
        visited = []
        depth = []
        low = []
        parent = []
        depth_search(initial_vertex, 0, visited, depth, low, parent) unless initial_vertex.nil?
        @non_articulation_points
    end

    def depth_search(v, d, visited, depth, low, parent)
        child_count = 0
        visited[v] = true
        depth[v] = d
        low[v] = d
        is_articulation = false
        adjacents = @instance.graph.get_neighbors(v) & @solution
        adjacents.each do |adj|
            unless visited[adj]
                parent[adj] = v
                depth_search(adj, d + 1, visited, depth, low, parent)
                child_count += 1
                is_articulation = true if low[adj] >= depth[v]
                low[v] = [low[v], low[adj]].min
            else
                low[v] = [low[v], depth[adj]].min unless adj == parent[v]
            end
        end
        @non_articulation_points.delete v if (!parent[v].nil? && is_articulation) || (parent[v].nil? && child_count > 1)
    end
    
    # Methods used to save object state. It's useful for making new solutions and rollback if they're trash
    def dump
        @solution_dump = @solution.clone
        @cost_dump = @cost
        @value_dump = @value
        @solution_adjacent_vertices_dump = @solution_adjacent_vertices.clone
        @solution_adjacency_count_dump = @solution_adjacency_count.clone
        @non_articulation_points_dump = @non_articulation_points.clone
        @in_transaction = true
    end

    def rollback
        @solution = @solution_dump.clone
        @cost = @cost_dump
        @value = @value_dump
        @solution_adjacent_vertices = @solution_adjacent_vertices_dump.clone
        @solution_adjacency_count = @solution_adjacency_count_dump.clone
        @non_articulation_points = @non_articulation_points_dump
        @in_transaction = false
    end

    def commit
        @in_transaction = false
    end

    def in_transaction?
        @in_transaction
    end
end