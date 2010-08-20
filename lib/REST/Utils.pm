
=head1 NAME

REST::Utils - Utility functions for REST applications

=head1 SYNOPSIS

    use REST::Utils qw( :all );

=cut

package REST::Utils;

use base qw( Exporter );
use warnings;
use strict;
use Carp qw( croak );
use constant BUFSIZE        => 4096;
use constant POST_UNLIMITED => -1;

=head1 VERSION

This document describes REST::Utils Version 0.1

=cut

our $VERSION = '0.1';

=head1 DESCRIPTION

This module contains some functions that are useful for implementing REST 
applications.

=cut

our @EXPORT_OK = qw/ content_prefs get_body media_type request_method /;

our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

=head2 FUNCTIONS

The following functions are available. None of them are exported by default. 
You can give the tag :all to the C<use REST::Utils> statement to import all 
the functions at once.

=head3 content_prefs($cgi)

Returns a list of MIME media types given in the requests C<Accept> HTTP header 
sorted from most to least preferred.

Example:

    my @types = content_prefs($cgi);
    # @types = ('text/html'. 'text/plain', '*/*')

=cut

sub content_prefs {
    my ($cgi) = @_;

    my @types =
      reverse sort { $cgi->Accept($a) <=> $cgi->Accept($b) } $cgi->Accept;

    return @types;
}

=head3 get_body($cgi)

This function will retrieve the body of an HTTP request regardless of the
request method.  If the body is larger than L<CGI>.pms' POST_MAX variable
allows, C<get_body> will return undef.  If there is no body, it will return
an empty scalar.  Otherwise it will return a scalar containing the body as
a sequence of bytes.  It is up to you to turn this into something useful.

=cut

# bits of this taken from derby http://www.perlmonks.org/?node_id=609632
sub get_body {
    my ($cgi) = @_;

    my $content = undef;
    my $method  = request_method($cgi);

    my $type = $ENV{CONTENT_TYPE};
    my $len = $ENV{CONTENT_LENGTH} || 0;

    if (   $CGI::POST_MAX != POST_UNLIMITED && $len > $CGI::POST_MAX ) {
        return;
    }

    if ( $method eq 'POST' && defined $cgi->param('POSTDATA') ) {
        $content = $cgi->param('POSTDATA');
    }
    elsif ( $method eq 'PUT' && defined $cgi->param('PUTDATA') ) {
        $content = $cgi->param('PUTDATA');
    }
    else {
        # we may not get all the data we want with a single read on large
        # POSTs as it may not be here yet! Credit Jason Luther for patch
        # CGI.pm < 2.99 suffers from same bug -- derby
        my $buffersize = $len < BUFSIZE ? $len : BUFSIZE;
        while ( sysread STDIN, my $buffer, $buffersize ) {
            $content .= $buffer;
        }
    }

    return $content . q{};    # To make sure it is not undef at this point.
}

=head3 media_type($cgi, $types)

This function is given a L<CGI>.pm compatible object and a reference to a 
list of MIME media types and returns the one most preferred by the requestor. 

Example:

    my $preferred = media_type($cgi, ['text/html', 'text/plain', '*/*']);

If the incoming request is a C<HEAD> or C<GET>, the function will return 
the member of the C<types> listref which is most preferred based on the 
C<Accept> HTTP headers sent by the requestor. If the requestor wants a 
type which is not on the list, the function will return C<undef>. (HINT: 
you can specify ' */*' to match every MIME media type.)

For C<POST> or C<PUT> requests, the function will compare the MIME media 
type in the C<Content-type> HTTP header provided by the requestor with 
the list and return that type if it matches a member of the list or 
C<undef> if it doesn't.

For other HTTP requests (such as C<DELETE>) this function will always return
undef.

=cut

sub media_type {
    my ( $cgi, $types ) = @_;

    # Get the preferred MIME media type. Other HTTP verbs than the ones below
    # (and DELETE) are not covered. Should they be?
    my $req        = request_method($cgi);
    my $media_type = undef;
    if ( $req eq 'GET' || $req eq 'HEAD' ) {
        my @accepted = content_prefs($cgi);
        foreach my $type (@accepted) {
            if ( scalar grep { $type eq $_ } @{$types} ) {
                $media_type = $type;
                last;
            }
        }
    }
    elsif ( $req eq 'POST' || $req eq 'PUT' ) {
        my $ctype = $cgi->content_type || q{};
        foreach my $type ( @{$types} ) {
            if ( $ctype eq $type ) {
                $media_type = $type;
                last;
            }
        }
    }

    return $media_type;
}

=head3 request_method($cgi)

This function is given a L<CGI>.pm compatible object and returns the query's 
HTTP request method.  

Example 1:

    my $method = request_method($cgi);
    

Because many web sites don't allow the full set of HTTP methods needed 
for REST, you can "tunnel" methods through C<GET> or C<POST> requests in 
the following ways:

In the query with the C<_method> parameter.  This will work even with C<POST> 
requests where parameters are usually passed in the request body.

Example 2:

    http://localhost/index.cgi?_method=DELETE

Or with the C<X-HTTP-Method-Override> HTTP header.

Example 3:

    X-HTTP-METHOD-OVERRIDE: PUT
    
if more than one of these are present, the HTTP header will override the query
parameter, which will override the "real" method.

Any method can be tunneled through a C<POST> request.  Only C<GET> and C<HEAD> 
can be tunneled through a C<GET> request.  You cannot tunnel through a 
C<HEAD>, C<PUT>, C<DELETE>, or any other request.  If an invalid tunnel is 
attempted, it will be ignored.

=cut

sub request_method {
    my ($cgi) = @_;

    my $real_method = uc $cgi->request_method() || q{};
    my $tunnel_method =
      uc(    $cgi->http('X-HTTP-Method-Override')
          || $cgi->url_param('_method')
          || $cgi->param('_method') )
      || undef;

    return $real_method if !defined $tunnel_method;

    # POST can tunnel any method.
    return $tunnel_method if $real_method eq 'POST';

    # GET can only tunnel GET/HEAD
    if ( $real_method eq 'GET'
        && ( $tunnel_method eq 'GET' || $tunnel_method eq 'HEAD' ) )
    {
        return $tunnel_method;
    }

    return $real_method;
}

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Rest::Utils
    
You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=REST-Utils>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/REST-Utils>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/REST-Utils>

=item * Search CPAN

L<http://search.cpan.org/dist/REST-Utils/>

=back

=head1 BUGS

There are no known problems with this module.

Please report any bugs or feature requests to
C<bug-rest-Utils at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=REST-Utils>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 AUTHOR

Jaldhar H. Vyas, C<< <jaldhar at braincells.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Consolidated Braincells Inc. All rights reserved.

This distribution is free software; you can redistribute it and/or modify it
under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 2, or (at your option) any later version, or

b) the Artistic License version 2.0.

The full text of the license can be found in the LICENSE file included
with this distribution.

=cut

1;    # End of REST::Utils

__END__

