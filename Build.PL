use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    dist_name           => 'REST-Utils',
    module_name         => 'REST-Utils',
    dist_abstract       => 'Utility functions for REST applications',
    dist_author         => 'Jaldhar H. Vyas <jaldhar@braincells.com>',
    license             => 'perl',
    dist_version        => '0.1',
    build_requires => {
        'Test::More'                    => 0,
        'Test::WWW::Mechanize::CGI'     => 0,
    },
    requires => {
        'perl'                          => 5.008,
    },
    add_to_cleanup      => [ 'REST-Utils-*' ],
    create_makefile_pl  => 'traditional',
    sign                => 1,
);

$builder->create_build_script();

