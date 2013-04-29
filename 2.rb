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

    def each_entries(&block)
        entries.each{ |entry|
            block.call entry
        }
        directories.each{ |directory|
            directory.each_entries &block
        }
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
root = process_tree(repo.commits.first.tree)#  / 'lib')

root.each_entries{ |entry|
    puts entry.full_name + "\t" + entry.size.to_s
}
