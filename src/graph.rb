class Graph
    attr_accessor :number_of_vertices, :number_of_edges, :adjacency_list
    
    def initialize(number_of_vertices, number_of_edges, edges)
        @adjacency_list = Array.new(number_of_vertices) { Array.new }
        @number_of_vertices = number_of_vertices
        @number_of_edges = number_of_edges
        edges.each do |v1, v2|
            create_edge(v1, v2)
        end
    end

    def get_neighbors(v)
        @adjacency_list[v].to_set
    end

    def subgraph_is_connected?(vertices)
        visited = Array.new(@number_of_vertices, false)
        depth_search(vertices.first, visited, vertices)
        return visited.values_at(*(vertices.to_a)).uniq == [true]
    end

    def get_highest_degree_vertex
        @adjacency_list.map(&:count).each_with_index.max[1]
    end

    private
    def create_edge(v1, v2)
        @adjacency_list[v1] ||= []
        @adjacency_list[v2] ||= []
        @adjacency_list[v1] << v2
        @adjacency_list[v2] << v1
    end

    def depth_search(v, visited, vertices)
        visited[v] = true
        adjacents = get_neighbors(v) & vertices
        adjacents.each do |adj|
            depth_search(adj, visited, vertices) unless visited[adj]
        end
    end
end
