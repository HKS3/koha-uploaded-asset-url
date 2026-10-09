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
    sub retrieve_data { return $main::plugin_data->{ $_[1] }; }
    sub store_data { $main::plugin_data = { %{ $main::plugin_data }, %{ $_[1] } }; }
    sub go_home { $main::went_home = 1; }
    sub get_template { return bless {}, 'Local::Template'; }
    sub output_html { $main::output_html = $_[1]; }

    package Local::Template;
    sub param { shift; $main::template_params = { @_ }; }
    sub output { return 'rendered configuration'; }

    package Local::Request;
    sub new {
        my ( $class, %params ) = @_;
        return bless \%params, $class;
    }
    sub param { return $_[0]->{ $_[1] }; }

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
our $plugin_data = {};
our ( $template_params, $output_html, $went_home );
use Koha::Plugin::HKS3::UploadedAssetURL;

my $plugin = Koha::Plugin::HKS3::UploadedAssetURL->new({});
is $plugin->{metadata}{class}, 'Koha::Plugin::HKS3::UploadedAssetURL', 'new module namespace is registered';
is $plugin->{metadata}{version}, $Koha::Plugin::HKS3::UploadedAssetURL::VERSION, 'metadata has module version';

my $script = $plugin->intranet_js({ page => '/cgi-bin/koha/tools/upload.pl' });
like $script, qr{const opacBaseUrl = "https://catalog\.example\.test/";}, 'OPACBaseURL is injected server-side';
like $script, qr{const assetPath = "/assets";}, 'default asset path is injected';
like $script, qr{cells\[0\].*cells\[2\]}s, 'filename and hash use fixed first and third columns';
like $script, qr{encodeURIComponent\(hashvalue \+ "_" \+ filename\)}, 'stored filename is encoded as one URL segment';
like $script, qr{window\.prompt\("Asset URL", assetUrl\)}, 'generated URL is selectable';
unlike $script, qr{Koha\.prefs}, 'browser preference API is not used';

is $plugin->intranet_js({ page => '/cgi-bin/koha/catalogue/detail.pl' }), q{}, 'no JavaScript returned for other pages';

$plugin->{cgi} = Local::Request->new();
$plugin->configure;
is $template_params->{asset_path}, '/assets', 'configuration uses the default asset path';
is $output_html, 'rendered configuration', 'configuration form is rendered';

$plugin->{cgi} = Local::Request->new( save => 1, asset_path => 'uploaded-assets/' );
$plugin->configure;
is $plugin_data->{asset_path}, '/uploaded-assets', 'configured path is normalized and stored';
ok $went_home, 'configuration save returns to plugin home';

$script = $plugin->intranet_js({ page => '/cgi-bin/koha/tools/upload.pl' });
like $script, qr{const assetPath = "/uploaded-assets";}, 'configured asset path is injected';

$opac_base_url = '</script>&';
$script = $plugin->intranet_js({ page => '/cgi-bin/koha/tools/upload.pl' });
unlike $script, qr{</script>&}, 'embedded preference cannot close the script element';
like $script, qr{\\u003C/script\\u003E\\u0026}, 'unsafe HTML characters are escaped in injected JSON';

done_testing;
