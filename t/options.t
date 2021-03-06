#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;
use Test::More tests => 25;
#use Test::More 'no_plan';
use Test::MockModule;
use Capture::Tiny ':all';

my $CLASS;

BEGIN {
    $CLASS = 'App::Sqitch';
    use_ok $CLASS or die;
}

##############################################################################
# Test _split_args.
can_ok $CLASS, '_split_args';

is_deeply [ $CLASS->_split_args('help') ], [[], 'help', []],
    'Split on command-only';

is_deeply [ $CLASS->_split_args('--help', 'help') ], [
    ['--help'],
    'help',
    [],
], 'Split on core option plus command';

is_deeply [ $CLASS->_split_args('--help', 'help', '--foo') ], [
    ['--help'],
    'help',
    ['--foo'],
], 'Split on core option plus command plus command option';

is_deeply [ $CLASS->_split_args('--plan-file', 'foo', 'help', '--foo') ], [
    ['--plan-file', 'foo'],
    'help',
    ['--foo'],
], 'Option with arg should work';

is_deeply [$CLASS->_split_args(qw(
    --plan-file
    foo
    help
    --foo
))], [
    ['--plan-file', 'foo'],
    'help',
    ['--foo'],
], 'Option with arg should work';

is_deeply [ $CLASS->_split_args('--help') ], [['--help'], undef, []],
    'Should handle no command';

# Make sure an invalid option is caught.
INVALID: {
    my $mocker = Test::MockModule->new($CLASS);
    $mocker->mock(_pod2usage => sub {  pass '_pod2usage should be called' });
    is capture_stderr { $CLASS->_split_args('--foo', 'foo', 'help', '--bar') },
        "Unknown option: foo\n", 'Should exit for invalid option';
}

##############################################################################
# Test _parse_core_opts
can_ok $CLASS, '_parse_core_opts';

is_deeply $CLASS->_parse_core_opts([]), {},
    'Should have default config for no options';

# Make sure we can get help.
HELP: {
    my $mock = Test::MockModule->new($CLASS);
    my @args;
    $mock->mock(_pod2usage => sub { @args = @_} );
    ok $CLASS->_parse_core_opts(['--help']), 'Ask for help';
    is_deeply \@args, [ $CLASS, 'sqitchcommands', '-exitval', 0, '-verbose', 2 ],
        'Should have been helped';
    ok $CLASS->_parse_core_opts(['--man']), 'Ask for man';
    is_deeply \@args, [ $CLASS, 'sqitch', '-exitval', 0, '-verbose', 2 ],
        'Should have been manned';
}

##############################################################################
# Try lots of options.
my $opts = $CLASS->_parse_core_opts([
    '--plan-file'  => 'plan.txt',
    '--engine'     => 'pg',
    '--client'     => 'psql',
    '--db-name'    => 'try',
    '--username'   => 'bob',
    '--host'       => 'local',
    '--port'       => 2020,
    '--top-dir'    => 'ddl',
    '--deploy-dir' => 'dep',
    '--revert-dir' => 'rev',
    '--test-dir'   => 'tst',
    '--extension'  => 'ext',
    '--uri'        => 'https://github.com/theory/sqitch/',
    '--verbose', '--verbose',
    '--quiet'
]);

is_deeply $opts, {
    'plan_file'  => 'plan.txt',
    'engine'     => 'pg',
    'client'     => 'psql',
    'db_name'    => 'try',
    'username'   => 'bob',
    'host'       => 'local',
    'port'       => 2020,
    'top_dir'    => 'ddl',
    'deploy_dir' => 'dep',
    'revert_dir' => 'rev',
    'test_dir'   => 'tst',
    'extension'  => 'ext',
    'uri'        => 'https://github.com/theory/sqitch/',
    verbosity    => 2,
    quiet        => 1,
}, 'Should parse lots of options';

# Make sure objects are created.
isa_ok $opts->{uri}, 'URI', 'URI option';

for my $dir (qw(top_dir deploy_dir revert_dir test_dir)) {
    isa_ok $opts->{$dir}, 'Path::Class::Dir', $dir;
}

##############################################################################
# Try short options.
is_deeply $CLASS->_parse_core_opts([
  '-d' => 'mydb',
  '-u' => 'fred',
]), {
    db_name  => 'mydb',
    username => 'fred',
}, 'Short options should work';

USAGE: {
    my $mock = Test::MockModule->new('Pod::Usage');
    my %args;
    $mock->mock(pod2usage => sub { %args = @_} );
    ok $CLASS->_pod2usage('sqitch-add', foo => 'bar'), 'Run _pod2usage';
    is_deeply \%args, {
        '-sections' => '(?i:(Usage|Synopsis|Options))',
        '-verbose'  => 2,
        '-input'    => Pod::Find::pod_where({'-inc' => 1 }, 'sqitch-add'),
        '-exitval'  => 2,
        'foo'       => 'bar',
    }, 'Proper args should have been passed to Pod::Usage';
}
