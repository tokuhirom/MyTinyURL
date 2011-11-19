use strict;
use warnings;
use utf8;
use Test::More;
use LWP::UserAgent;
use LWP::Protocol::PSGI;
use Plack::Util;

my $app = Plack::Util::load_psgi('app.psgi');
LWP::Protocol::PSGI->register($app);

my $ua = LWP::UserAgent->new(max_redirect => 0);

subtest 'normal' => sub {
    my $first_tiny = do {
        my $res = $ua->post('http://localhost/api/create?url=http://mixi.jp/');
        is($res->code, 200) or diag($res->as_string);
        like($res->content, qr{^http://[^/]+/t/[^/]+$});
        $res->content;
    };
    my $second_tiny = do {
        my $res = $ua->post('http://localhost/api/create?url=http://mixi.jp/');
        is($res->code, 200);
        like($res->content, qr{^http://[^/]+/t/[^/]+$});
        $res->content;
    };
    is($first_tiny, $second_tiny);

    my $res = $ua->get($first_tiny);
    is($res->code, 302) or diag($res->as_string);
    is($res->header('Location'), 'http://mixi.jp/');
};

subtest 'XHR' => sub {
    my $res = $ua->post('http://localhost/api/create?url=http://mixi.jp/', 'X-Requested-With' => 'XMLHTTPRequest');
    is($res->code, 200) or diag($res->as_string);
    is($res->content_type, 'text/plain') or diag($res->as_string);
    like($res->content, qr{^http://[^/]+/t/[^/]+$});
    $res->header('Location');
};

done_testing;

