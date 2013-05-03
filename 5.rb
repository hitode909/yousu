# encoding: utf-8
require 'bundler'
require 'set'

## example: ruby 5.rb ~/projects/rubygems.org master app/models/user.rb
## test/unit/user_test.rb  38      0.5846153846153846
## app/models/rubygem.rb   14      0.2153846153846154
## app/views/profiles/show.html.erb        9       0.13846153846153847
## app/models/web_hook.rb  8       0.12307692307692308
## app/controllers/profiles_controller.rb  8       0.12307692307692308
## test/functional/profiles_controller_test.rb     8       0.12307692307692308

Bundler.require

REPOSITORY_PATH = ARGV.first or raise "usage: #{$0} REPOSITORY_PATH (BRANCH) (FILTER)"

BRANCH = ARGV[1] || 'master'
SUBJECT_FILE = ARGV[2]

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

scores = { }
repository = Grit::Repo.new(REPOSITORY_PATH)

all_commits(repository, BRANCH) { |commit|
    filenames = Set.new(commit.stats.to_diffstat.map(&:filename))
    next unless filenames.include? SUBJECT_FILE

    filenames.each{ |name|
        scores[name] ||= 0
        scores[name] += 1
    }

    warn commit.date
    # count += 1
    # break if count > 100
}

scores.map{ |k, v| [k, v]}.sort_by{ |pair| pair[1] }.reverse.each{ |pair|
    next if pair[0] == SUBJECT_FILE
    puts [pair[0],pair[1], pair[1].to_f / scores[SUBJECT_FILE]].join "\t"
}
