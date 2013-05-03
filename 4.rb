# encoding: utf-8
require 'bundler'
require 'set'

# example: ruby 4.rb ~/projects/rubygems.org master | tee out.txt

Bundler.require

REPOSITORY_PATH = ARGV.first or raise "usage: #{$0} REPOSITORY_PATH (BRANCH) (FILTER)"

BRANCH = ARGV[1] || 'master'
FILTER = ARGV[2] && Regexp.new('^' + ARGV[2])

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

all_file_names = Set.new
commits = []
count = 0
repository = Grit::Repo.new(REPOSITORY_PATH)
all_commits(repository, BRANCH) { |commit|
    filenames = Set.new(commit.stats.to_diffstat.map(&:filename))
    next if filenames.empty?

    commits.push filenames
    all_file_names.merge(filenames)

    warn commit.date
}

all_file_names.each{ |member|
    columns = []
    columns << member
    puts [member,
        commits.map{ |commit|
            commit.include?(member) ? 1 : 0
        }
    ].join(",")
}
