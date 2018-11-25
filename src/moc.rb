require_relative 'graph.rb'

class Moc
    attr_accessor :graph, :weights, :values, :max_weight

    def initialize(file_name)
        instance = File.readlines file_name
        first_line = instance.shift.split
        second_line = instance.shift.split
        third_line = instance.shift.split

        @max_weight = first_line[2].to_f
        @weights = second_line.map(&:to_f)
        @values = third_line.map(&:to_f)
        
        number_of_vertices = first_line[0].to_i
        number_of_edges = first_line[1].to_i
        edges = []
        instance.each { |edge| edges << edge.split.map(&:to_i) }

        @graph = Graph.new(number_of_vertices, number_of_edges, edges)
    end


end