#!/usr/bin/perl

# Test retrieval of HTTP request body.
use strict;
use warnings;
use Test::More tests => 7;
use Test::WWW::Mechanize::CGI;
use REST::Utils qw( get_body );

my $mech = Test::WWW::Mechanize::CGI->new;
$mech->cgi( sub {
    require CGI;    
    my $q = CGI->new;    

    my $title = q{};

    my $content = get_body($q);
    my $content_length = length $content;

    if (!defined $content) {
        $title = 'Content too big';
    }
    elsif ($content eq q{}) {
        $title = 'No content';
    }
    else {
        $title = length $content;
    }
    
    print $q->header,
        $q->start_html($title),
        $q->end_html;
});

my $mech2 = Test::WWW::Mechanize::CGI->new;
$mech2->cgi( sub {

    require CGI;    
    $CGI::POST_MAX = 10;
    my $q = CGI->new;    

    my $title = q{};

    my $content = get_body($q) || undef;
    my $content_length = defined $content ? length $content : 0;

    if (!defined $content) {
        $title = 'Content too big';
    }
    elsif ($content_length == 0) {
        $title = 'No content';
    }
    else {
        $title = $content_length;
    }
    
    print $q->header,
        $q->start_html($title),
        $q->end_html;
});

$mech->post('http://localhost/');
$mech->title_is('No content', 'POST with no content body');

$mech->put('http://localhost/');
$mech->title_is('No content', 'PUT with no content body');

$mech->get('http://localhost/');
$mech->title_is('No content', 'GET with no content body');

$mech->post('http://localhost/', content_type => 'text/plain',
    content => 'x' x 100);
$mech->title_is('100', 'POST with content body');

$mech->post('http://localhost/', content_type => 'text/plain',
    content => 'x' x 5000);
$mech->title_is('5000', 'POST with large content body');

$mech2->post('http://localhost/', content_type => 'text/plain',
    content => 'x' x 100);
$mech2->title_is('Content too big', 'POST with content_length > POST_MAX');

$mech2->post('http://localhost/', content_type => 'text/plain',
    content => 'x' x 10);
$mech2->title_is('10', 'POST with content_length < POST_MAX');
