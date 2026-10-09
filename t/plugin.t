use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

# The plugin has no database behaviour. Stub Koha boundaries so this test can
# verify its generated page-specific JavaScript without a Koha installation.
BEGIN {
    $INC{'Modern/Perl.pm'} = 1;
    $INC{'Koha/Plugins/Base.pm'} = 1;
    $INC{'C4/Context.pm'} = 1;
    $INC{'Mojo/JSON.pm'} = 1;

    package Modern::Perl;
    sub import { strict->import; warnings->import; }

    package Koha::Plugins::Base;
    sub new {
        my ( $class, $args ) = @_;
        return bless { %{$args // {}} }, $class;
    }

    package C4::Context;
    sub preference { return $main::opac_base_url; }

    package Mojo::JSON;
    sub import {
        no strict 'refs';
        *{ caller() . '::encode_json' } = sub {
            my ($value) = @_;
            $value //= '';
            $value =~ s/\\/\\\\/g;
            $value =~ s/"/\\"/g;
            $value =~ s/\n/\\n/g;
            return qq{"$value"};
        };
    }
}

our $opac_base_url = 'https://catalog.example.test/';
use Koha::Plugin::HKS3::UploadedAssetURL;

my $plugin = Koha::Plugin::HKS3::UploadedAssetURL->new({});
is $plugin->{metadata}{class}, 'Koha::Plugin::HKS3::UploadedAssetURL', 'new module namespace is registered';
is $plugin->{metadata}{version}, '0.90.0', 'metadata has module version';

my $script = $plugin->intranet_js({ page => '/cgi-bin/koha/tools/upload.pl' });
like $script, qr{const opacBaseUrl = "https://catalog\.example\.test/";}, 'OPACBaseURL is injected server-side';
like $script, qr{cells\[0\].*cells\[2\]}s, 'filename and hash use fixed first and third columns';
like $script, qr{encodeURIComponent\(hashvalue \+ "_" \+ filename\)}, 'stored filename is encoded as one URL segment';
like $script, qr{window\.prompt\("Asset URL", assetUrl\)}, 'generated URL is selectable';
unlike $script, qr{Koha\.prefs}, 'browser preference API is not used';

is $plugin->intranet_js({ page => '/cgi-bin/koha/catalogue/detail.pl' }), q{}, 'no JavaScript returned for other pages';

$opac_base_url = '</script>&';
$script = $plugin->intranet_js({ page => '/cgi-bin/koha/tools/upload.pl' });
unlike $script, qr{</script>&}, 'embedded preference cannot close the script element';
like $script, qr{\\u003C/script\\u003E\\u0026}, 'unsafe HTML characters are escaped in injected JSON';

done_testing;
