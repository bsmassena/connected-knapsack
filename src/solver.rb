require_relative 'moc.rb'
require 'set'

class Solver
    attr_accessor :instance, :solution, :cost, :value, :solution_adjacent_vertices, :solution_adjacency_count

    def initialize(file_name)
        @instance = Moc.new(file_name)
        @solution = Set.new
        @cost = 0
        @value = 0

        vertices = @instance.graph.number_of_vertices
        @solution_adjacency_count = Array.new(vertices, 0)
        @solution_adjacent_vertices = (0...vertices).to_set
    end

    def solve
        start = Time.now
        generate_initial_solution
        time = Time.now - start

        puts "Solved in #{time.round(2)} seconds"
        puts "Cost: #{@cost}/#{@instance.max_weight}"
        puts "Value: #{@value}"
    end

    private
    def sort_by_cost_benefit
        weights = @instance.weights
        values = @instance.values
        cost_benefit = values.zip(weights).map { |val, cost| val / cost }
        cost_benefit.map.with_index.sort.map(&:last).reverse
    end

    def update_cost
        @cost = @instance.weights
                         .values_at(*solution)
                         .inject(0, :+)
    end

    def generate_initial_solution
        cb_sorted = sort_by_cost_benefit
        v = cb_sorted.find { |v| can_be_added(v) }
        @solution_adjacent_vertices = Set[v]
        while !v.nil? do
            add_to_solution v
            v = cb_sorted.find { |v| can_be_added(v) }
        end
    end

    def can_be_added(v)
        fit_on_knapsack = @instance.weights[v] + @cost <= @instance.max_weight
        is_adjacent_to_solution = @solution_adjacent_vertices.include?(v)

        fit_on_knapsack && is_adjacent_to_solution
    end

    def add_to_solution(v)
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
    
    # Methods used to save object state. It's useful for making new solutions and rollback if they're trash
    def begin
        @solution_dump = @solution.clone
        @cost_dump = @cost
        @value_dump = @value
        @solution_adjacent_vertices_dump = @solution_adjacent_vertices.clone
        @solution_adjacency_count_dump = @solution_adjacency_count.clone
    end

    def rollback
        @solution = @solution_dump.clone
        @cost = @cost_dump
        @value = @value_dump
        @solution_adjacent_vertices = @solution_adjacent_vertices_dump.clone
        @solution_adjacency_count = @solution_adjacency_count_dump.clone
    end
end