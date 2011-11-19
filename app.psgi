use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;
use Amon2::Lite;

# put your configuration here
sub config {
    +{
    }
}

get '/' => sub {
    my $c = shift;
    return $c->render('index.tt');
};

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;
        $res->header( 'X-Content-Type-Options' => 'nosniff' );
        $res->header( 'X-Frame-Options' => 'DENY' );
    },
);

# load plugins
__PACKAGE__->load_plugin('Web::CSRFDefender');
# __PACKAGE__->load_plugin('Web::FillInFormLite');
# __PACKAGE__->load_plugin('Web::JSON');

use Plack::Session::State::Cookie;
builder {
    enable 'Plack::Middleware::Session',
        state => Plack::Session::State::Cookie->new(
            httponly => 1,
        );

    __PACKAGE__->to_app(handle_static => 1);
};

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
    <met charst="utf-8">
    <title>MyTinyURL</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
    MyTinyURL
</body>
</html>
