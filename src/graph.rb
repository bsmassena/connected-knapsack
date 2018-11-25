class Graph
    attr_accessor :number_of_vertices, :number_of_edges, :adjacency_list
    
    def initialize(number_of_vertices, number_of_edges, edges)
        @adjacency_list = []
        @number_of_vertices = number_of_vertices
        @number_of_edges = number_of_edges
        edges.each do |v1, v2|
            create_edge(v1, v2)
        end
    end

    def get_neighbors(v)
        @adjacency_list[v]
    end

    private
    def create_edge(v1, v2)
        @adjacency_list[v1] ||= []
        @adjacency_list[v2] ||= []
        @adjacency_list[v1] << v2
        @adjacency_list[v2] << v1
    end
end
