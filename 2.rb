require 'bundler'

Bundler.require

REPOSITORY_PATH = ARGV.first or raise "repository_path required"

BRANCH = ARGV[1] || 'master'

class Yousu
    def self.each_commits(repository, branch = 'master', index = 0, &block)
        max_count = 10
        commits = repository.commits(BRANCH, max_count, index)
        return unless commits.length > 0
        commits.each{ |commit|
            yield commit
        }
        each_commits(repository, branch, index + max_count, &block)
    end

    def self.parse_directory(tree)
        directory = Yousu::Directory.new(tree.name || '')

        tree.blobs.each{ |blob|
            directory.add_child Yousu::Entry.new(blob.name, blob.data)
        }
        tree.trees.each{ |tree|
            directory.add_child process_tree(tree)
        }
        directory
    end
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

repository = Grit::Repo.new(REPOSITORY_PATH)
Yousu.each_commits(repository, BRANCH) { |commit|
    puts commit.date
    directory = Yousu.parse_directory(commit.tree)
    directory.each_entries{ |entry|
        puts entry.full_name + "\t" + entry.size.to_s
    }
}
