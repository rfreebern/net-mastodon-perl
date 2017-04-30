package Net::Mastodon;
$Net::Mastodon::VERSION = '0.20170430';
use fields qw/instance token api_path use_ssl ua/;
use vars qw/$AUTOLOAD/;
use strict;
use Carp;
use URI::Escape;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use LWP::UserAgent;
use LWP::Protocol::https;

sub new {
    my $class = shift;
    croak '"new" is not an instance method' if ref $class;
    my %args = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_; # Allows passing arguments as list or hash

    croak 'token argument is required' if !$args{token};

    my Net::Mastodon $self = fields::new(ref $class || $class);
    $self->{token} = $args{token};
    $self->{instance} = $args{instance} ? $args{instance} : 'mastodon.social';
    $self->{api_path} = $args{api_path} ? $args{api_path} : '/api/v1/';
    $self->{use_ssl} = $args{use_ssl} ? $args{use_ssl} : 0;
    $self->{ua} = LWP::UserAgent->new(agent => "Net::Mastodon/${ \($Net::Mastodon::VERSION || 1) } (Perl)");
    return $self;
}

sub AUTOLOAD {
    my $self = shift or return undef;
    (my $method = uc($AUTOLOAD)) =~ s{.*::}{};

    if (grep {$_ eq $method} qw/GET POST PATCH DELETE/) {
        return $self->_parse_response($self->_send_request($self->_add_auth_header($self->_build_request($method, @_))));
    }
}

sub _build_request {
    my ($self, $method, $endpoint, $parameters) = @_;
    my $req;
    my $uri = URI->new('http' . ($self->{use_ssl} ? 's' : '') . '://' . $self->{instance} . $self->{api_path} . $endpoint);
    $uri->query_form($parameters);

    if ($method eq 'GET') {
        $req = GET($uri);
    } elsif ($method eq 'POST') {
        $req = POST($uri);
    } elsif ($method eq 'PATCH') {
        $req = PATCH($uri);
    } elsif ($method eq 'DELETE') {
        $req = DELETE($uri);
    } else {
        croak "unexpected HTTP method $method";
    }

    return $req;
}

sub _add_auth_header {
    my ($self, $req) = @_;
    $req->header('Authorization', "Bearer $self->{token}");
    return $req;
}

sub _send_request {
    my $self = shift or return undef;
    return $self->{ua}->request(shift);
}

sub _parse_response {
    my ($self, $response) = @_;
    if ($response->is_success) {
        my $content = $response->decoded_content;
        my $obj = length $content ? decode_json($content) : {};
        return $obj;
    }
    return {};
}

sub DESTROY {};

1;
