#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;

use Git::Class;
use Path::Class;
use Perl6::Say;

# 同時にコミットされる頻度から，ソースコードからテストファイルへの組を推測し，CSVに書き出す
# あるクラスと同時にコミットされる頻度の高いテストファイルはそのクラスのテストである確率が高い
# $0 リポジトリのパス ソースコードが置かれるディレクトリ テストファイルが置かれるディレクトリ CSVを出力するパス

if (@ARGV != 4) {
    die "$0 REPOSITORY_PATH LIBRARY_PATH TEST_PATH OUTPUT_PATH";
}
my ($REPOSITORY_PATH, $LIBRARY_PATH, $TEST_PATH, $OUTPUT_PATH) = @ARGV;

$LIBRARY_PATH = dir($LIBRARY_PATH)->relative($REPOSITORY_PATH);
$TEST_PATH = dir($TEST_PATH)->relative($REPOSITORY_PATH);

say "REPOSITORY_PATH: $REPOSITORY_PATH";
say "LIBRARY_PATH:    $LIBRARY_PATH";
say "TEST_PATH:       $TEST_PATH";

sub commit_list_for_file {
    my ($worktree, $file) = @_;

    [
        map {
            shift [split(' ', $_)];
        } $worktree->log('--format=oneline', $file)
    ];
}

sub file_list_for_commit {
    my ($worktree, $commit) = @_;

    [
        grep { $_ } $worktree->show('--pretty=format:', '--name-only', $commit)
    ];
}

sub get_most_similar_file {
    my ($worktree, $target_file) = @_;

    my $counts = {};

    my $commits = commit_list_for_file($worktree, $target_file);

    my $quoted_test_path = quotemeta $TEST_PATH;
    for my $commit (@$commits) {
        my $files = file_list_for_commit($worktree, $commit);
        for my $file (@$files) {
            next unless $file =~ qr(^$quoted_test_path/);
            $counts->{$file}++;
        }
    }

    my $max = 0;
    my $result = undef;

    for my $file (keys $counts) {
        next if $file eq $target_file;
        my $count = $counts->{$file};
        if ($max < $count || ! defined $result) {
            $max = $count;
            $result = $file;
        }
    }
    $result;
}

sub get_files_under_path {
    my ($worktree, $path) = @_;
    [ $worktree->git('ls-files', $path) ];
}

sub write_pair {
    my ($fh, $library, $test) = @_;
    print $fh "$library,$test\n";
}

my $output_file = file($OUTPUT_PATH);
my $output_fh = $output_file->open('w') or die "Can't open $output_file";

my $worktree = Git::Class::Worktree->new(path => $REPOSITORY_PATH);

my $all_library_files = get_files_under_path($worktree, $LIBRARY_PATH);

for my $library_file (@$all_library_files) {
    my $similar_file = get_most_similar_file($worktree, $library_file);
    unless ($similar_file) {
        say "not found for $library_file";
        next;
    }
    say "$library_file -> $similar_file";
    write_pair($output_fh, $library_file, $similar_file);
}

close($output_fh);
