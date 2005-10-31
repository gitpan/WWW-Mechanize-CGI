package WWW::Mechanize::CGI;

use strict;
use warnings;
use base 'WWW::Mechanize';

use Carp;
use HTTP::Request;
use HTTP::Request::AsCGI;
use HTTP::Response;

our $VERSION = 0.1;

sub cgi {
    my $self = shift;

    if ( @_ ) {
        $self->{cgi} = shift;
    }

    return $self->{cgi};
}

sub fork {
    my $self = shift;

    if ( @_ ) {
        $self->{fork} = shift;
    }

    return $self->{fork};
}

sub env {
    my $self = shift;

    if ( @_ ) {
        $self->{env} = { @_ };
    }

    return %{ $self->{env} || {} };
}

sub _make_request {
    my ( $self, $request ) = @_;

    if ( $self->cookie_jar ) {
        $self->cookie_jar->add_cookie_header($request);
    }

    my ( $error, $kid, $response );

    my $c = HTTP::Request::AsCGI->new( $request, $self->env );

    $kid = CORE::fork() if $self->fork;

    if ( $self->fork && ! defined $kid ) {
        croak("Can't fork() kid: $!");
    }

    unless ( $kid ) {

        $c->setup;

        eval { $self->cgi->() };

        $c->restore;

        exit(1) if $self->fork && $@;
        exit(0) if $self->fork;
    }

    waitpid( $kid, 0 ) if $self->fork;

    $error = $self->fork ? $? >> 8 : $@;

    if ( $error ) {
        $response = HTTP::Response->new(500);
        $response->date( time() );
        $response->header( 'X-Error' => $error ) unless $self->fork;
        $response->content( $response->error_as_HTML );
        $response->content_type('text/html');
    }
    else {
        $response = $c->response;
    }

    $response->header( 'Content-Base', $request->uri );
    $response->request($request);

    if ( $self->cookie_jar ) {
        $self->cookie_jar->extract_cookies($response);
    }

    return $response;
}

1;

__END__

=head1 NAME

WWW::Mechanize::CGI - Use WWW::Mechanize with CGI applications.

=head1 SYNOPSIS

    use CGI;
    use WWW::Mechanize::CGI;

    my $mech = WWW::Mechanize::CGI->new;
    $mech->cgi( sub {
        
        my $q = CGI->new;
        
        print $q->header,
              $q->start_html('Hello World'),
              $q->h1('Hello World'),
              $q->end_html;
    });
    
    my $response = $mech->get('http://localhost/');

=head1 DESCRIPTION

Provides a convenient way of using CGI applications with L<WWW::Mechanize>.

=head1 METHODS

=over 4 

=item new

Behaves like, and calls, L<WWW::Mechanize>'s C<new> method. Any parms
passed in get passed to WWW::Mechanize's constructor.

=item cgi

Coderef to be used to execute the CGI application.

=item env( [, key => value ] )

Additional environment variables to be used in CGI.

    $mech->env( DOCUMENT_ROOT=> '/export/www/myapp' );

=back

=head1 SEE ALSO

=over 4

=item L<WWW::Mechanize>

=item L<LWP::UserAgent>

=item L<HTTP::Request::AsCGI>

=back

=head1 AUTHOR

Christian Hansen, C<ch@ngmedia.com>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut
