# encoding: utf-8
require 'bundler'
require 'set'

# repository to gdf https://gephi.org/users/supported-graph-formats/gdf-format/
# ruby 6.rb ~/co/rubygems.org master | tee rubygems.gdf

Bundler.require

REPOSITORY_PATH = ARGV.first or raise "usage: #{$0} REPOSITORY_PATH (BRANCH) (FILTER)"

BRANCH = ARGV[1] || 'master'
FILTER = ARGV[2] && Regexp.new('^' + ARGV[2])

class IdsGenerator
    def initialize
        @table = { }
    end

    def id_for(string)
        if @table[string]
            return @table[string]
        end

        @table[string] = @table.keys.length + 1
    end
end

def all_commits(repository, branch = 'master')
    index = 0
    max_count = 10
    commits = [true]
    while commits.any?
        commits = repository.commits(BRANCH, max_count, index)
        commits.each{ |commit|
            yield commit
        }
        index += max_count
    end
end

def each_unique_pair(list)
    list.each_with_index{ |a, index_a|
        list.each_with_index{ |b, index_b|
            next unless index_a < index_b
            yield a, b
        }
    }
end

def get_rate_for_pair(commits, a, b)
    a_or_b = commits.count{ |commit|
        commit.include?(a) || commit.include?(b)
    }
    a_and_b = commits.count{ |commit|
        commit.include?(a) && commit.include?(b)
    }
    a_and_b.to_f / a_or_b
end

def get_count_for_pair(commits, a, b)
    a_and_b = commits.count{ |commit|
        commit.include?(a) && commit.include?(b)
    }
end

def get_rate_for_file(commits, name)
    commits.count{ |commit|
        commit.include? name
    }.to_f / commits.length
end

def get_commit_count_for_file(commits, name)
    commits.count{ |commit|
        commit.include? name
    }
end

def csv(*values)
    values.join ","
end


# create summary
all_file_names = Set.new
commits = []
repository = Grit::Repo.new(REPOSITORY_PATH)
all_commits(repository, BRANCH) { |commit|
    filenames = Set.new(commit.stats.to_diffstat.map(&:filename))
    next if filenames.empty?

    commits.push filenames
    all_file_names.merge(filenames)

    warn commit.date
}
ids = IdsGenerator.new

all_file_names = Set.new(all_file_names.select{ |name| name =~ /^app/ }


puts "nodedef>" + csv("name varchar", "rate DOUBLE", "commit_count INTEGER")
all_file_names.to_a.sort.each{ |name|
    puts csv(name, get_rate_for_file(commits, name), get_commit_count_for_file(commits, name))
}

puts "edgedef>" +csv("node1 VARCHAR", "node2 VARCHAR", "directed BOOLEAN", "rate DOUBLE", "count INTEGER")
each_unique_pair(all_file_names.to_a.sort) { |a, b|
    rate = get_rate_for_pair(commits, a, b)
    next if rate < 0.01
    puts csv(a,b,false, rate, get_count_for_pair(commits, a, b))
}
