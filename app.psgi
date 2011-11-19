use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;
use Amon2::Lite;

our $VERSION = '0.01';

# put your configuration here
sub config {
    my $c = shift;
    my $mode = $c->mode_name || 'development';
    +{
        'DBI' => [
            "dbi:SQLite:dbname=$mode.db",
            '',
            ''
        ]
    }
}

{
    package MyTinyURL::Storage;

    sub _random_string {
        my $length = shift;
        my @chars = ( 'A' .. 'Z', 'a' .. 'z', '0' .. '9' );
        my $ret;
        for ( 1 .. $length ) {
            $ret .= $chars[ int rand @chars ];
        }
        return $ret;
    }

    sub setup_schema {
        my ($class, $c) = @_;

        $c->dbh->do(q{
            CREATE TABLE IF NOT EXISTS url (
                key VARCHAR(10) NOT NULL PRIMARY KEY,
                url TEXT
            );
        });
        $c->dbh->do(q{
            CREATE INDEX IF NOT EXISTS url_url ON url (url);
        });
    }

    sub get_url {
        my ($class, $c, $key) = @_;
        $class->setup_schema($c);
        return $c->dbh->selectrow_array(q{SELECT url FROM url WHERE key=?}, {}, $key);
    }

    sub find_or_create_key {
        my ($class, $c, $url) = @_; $url || die;

        $class->setup_schema($c);

        my $guard = $c->dbh->txn_scope;
        {
            my $key = $c->dbh->selectrow_array(
                q{SELECT key FROM url WHERE url=?},
                {}, $url );
            $guard->commit;
            return $key if $key;
        }

        my $key = sub {
            for (1..16) {
                my $key = _random_string(10);
                my $cnt = $c->dbh->selectrow_array(q{SELECT COUNT(*) FROM url WHERE key=?}, {}, $key);
                return $key if $cnt==0;
            }
            die "FATAL";
        }->();
        $c->dbh->do_i(q{INSERT INTO url }, {url => $url, key => $key});
        $guard->commit();

        return $key;
    }
}

get '/' => sub {
    my $c = shift;
    return $c->render('index.tt');
};
get '/t/{key}' => sub {
    my ($c, $args) = @_;
    my $url = MyTinyURL::Storage->get_url($c, $args->{key});
    return $url ? $c->redirect($url) : $c->res_404();
};

post '/api/create' => sub {
    my $c = shift;

    my $url = $c->req->param('url') || die "Missing mandatory parameter: url";
       $url =~ m{^https?://} or die "Invalid url: $url";

    my $key = MyTinyURL::Storage->find_or_create_key($c, $url);

    my $res_url = URI->new_abs($c->uri_for('/t/' . $key), $c->req->base);
    return $c->create_response(
        200,
        [
            'Content-Type'   => 'text/plain; charset=utf8',
            'Content-Length' => length($res_url)
        ],
        $res_url
    );
};

# load plugins
__PACKAGE__->load_plugin('DBI');

__PACKAGE__->to_app(handle_static => 1);

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
    <met charst="utf-8">
    <title>MyTinyURL</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.0/jquery.min.js"></script>
    <script type="text/javascript" src="[% uri_for('/static/js/main.js') %]"></script>
    <link rel="stylesheet" href="http://twitter.github.com/bootstrap/1.4.0/bootstrap.min.css">
</head>
<body>
    <div class="container">
        <header><h1>MyTinyURL</h1></header>
        <section>
            <form method="post" action="/create" id="TinyURLForm">
                <input type="url" name="url" size="40" pattern="^https?://.+" required />
                <input type="submit" value="Make Tiny URL" class="btn primary" />
            </form>
            <div id="Result"></div>
        </section>
        <footer>Powered by <a href="http://amon.64p.org">Amon2::Lite</a></footer>
    </div>
</body>
</html>

@@ /static/js/main.js
$(function () {
    $('#TinyURLForm').submit(function () {
        $('#Result').hide();

        $.ajax({
            type: 'POST',
            url: '/api/create',
            data: $(this).serialize()
        }).success(function (res) {
            $('#Result').text("Result url is : " + res).show();
        }).error(function (res) {
            alert("ERROR");
        });
        return false;
    });
});

