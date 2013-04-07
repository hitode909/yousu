require 'bundler'

Bundler.require

REPOSITORY_PATH = ARGV.first or raise "repository_path required"

class Yousu
end

class Yousu::Node
    attr_accessor :name, :parent
    def full_name
        if @parent
            @parent.full_name + '/' + @name
        else
            @name || ''
        end
    end
end

class Yousu::Entry < Yousu::Node
    attr_reader :size
    def initialize(name, content)
        @name = name
        @size = content.split(/\n/).length
    end
end

class Yousu::Directory < Yousu::Node
    attr_reader :children
    def initialize(name)
        @name = name
        @children = []
    end
    def add_child(child)
        @children << child
        child.parent = self
    end
    def entries
        @children.select{ |c| c.kind_of? Yousu::Entry }
    end
    def directories
        @children.select{ |c| c.kind_of? Yousu::Directory }
    end
end

def process_tree(tree)
    directory = Yousu::Directory.new(tree.name || '')

    tree.blobs.each{ |blob|
        directory.add_child Yousu::Entry.new(blob.name, blob.data)
    }
    tree.trees.each{ |tree|
        directory.add_child process_tree(tree)
    }
    directory
end

repo = Grit::Repo.new(REPOSITORY_PATH)
root = process_tree(repo.commits.first.tree / 'lib')

def plot_directory(g, directory)
    p "directory #{directory.full_name}"
    parent_node = g.add_nodes directory.full_name, label: directory.name, shape: 'square', fontsize: 8
    directory.entries.each{ |child|
        p "entry #{child.full_name}"
        label = child.size > 100 ? "#{child.name}(#{child.size})" : ''
        label = label.gsub(/([a-z])([A-Z])/){|m| m[0]+"\n"+m[1]}
        child_node = g.add_nodes child.full_name, shape: 'circle', label: label, fixedsize: true, width: [Math.sqrt(child.size / 100), 0.1].max, fontsize: 8
        g.add_edges child_node, parent_node
    }
    directory.directories.each{ |child|
        child_node = plot_directory g, child
        g.add_edges child_node, parent_node
    }
    parent_node
end

g = GraphViz.new :G, type: :graph, rankdir: 'BT'
plot_directory g, root
g.output png: 'out.png'
