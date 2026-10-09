package Koha::Plugin::HKS3::UploadedAssetURL;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use Mojo::JSON qw(encode_json);

our $VERSION = '0.91.0';

our $metadata = {
    name            => 'Uploaded asset URL',
    author          => 'HKS3',
    description     => 'Adds asset URLs to the uploaded-files list in the staff interface.',
    date_authored   => '2026-10-09',
    date_updated    => '2026-10-09',
    minimum_version => '21.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;
    $args ||= {};

    $args->{metadata} = { %{$metadata}, class => $class };
    return $class->SUPER::new($args);
}

sub configure {
    my ($self) = @_;
    my $cgi = $self->{cgi};

    if ( defined $cgi->param('save') ) {
        $self->store_data( { asset_path => $self->_asset_path( $cgi->param('asset_path') ) } );
        $self->go_home;
        return;
    }

    my $template = $self->get_template( { file => 'configure.tt' } );
    $template->param( asset_path => $self->_asset_path );
    $self->output_html( $template->output );
}

sub intranet_js {
    my ( $self, $args ) = @_;

    # Recent Koha versions supply the controller path. The JavaScript below
    # retains its own path check so the plugin remains safe on older versions.
    return q{}
        if $args
        && $args->{page}
        && $args->{page} ne '/cgi-bin/koha/tools/upload.pl';

    my $opac_base_url = C4::Context->preference('OPACBaseURL') // q{};
    my $opac_base_url_json = _json_for_script($opac_base_url);
    my $asset_path_json    = _json_for_script( $self->_asset_path );

    return <<"JAVASCRIPT";
<script>
(() => {
    "use strict";

    const opacBaseUrl = $opac_base_url_json;
    const assetPath = $asset_path_json;

    const addAssetUrlButtons = () => {
        if (window.location.pathname !== "/cgi-bin/koha/tools/upload.pl") return;

        const table = document.querySelector("#uploadresults");
        if (!table || !table.tBodies.length) return;

        table.tBodies[0].querySelectorAll("tr").forEach(row => {
            const cells = row.cells;
            const actions = row.querySelector("td.actions");

            // Filename and hashvalue are respectively the first and third
            // columns, regardless of the staff-interface language.
            if (!actions || cells.length < 3 || actions.querySelector(".show-asset-url")) return;

            const button = document.createElement("button");
            button.type = "button";
            button.className = "btn btn-default btn-xs show-asset-url";
            button.textContent = "Show asset URL";

            button.addEventListener("click", () => {
                const filename = cells[0].textContent.trim();
                const hashvalue = cells[2].textContent.trim();
                const assetUrl = opacBaseUrl + assetPath + "/" + encodeURIComponent(hashvalue + "_" + filename);

                // prompt() displays a selectable value, making it straightforward
                // to copy into a configuration or an HTML link.
                window.prompt("Asset URL", assetUrl);
            });

            actions.append(" ", button);
        });
    };

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", addAssetUrlButtons);
    } else {
        addAssetUrlButtons();
    }
})();
</script>
JAVASCRIPT
}

sub _asset_path {
    my ( $self, $asset_path ) = @_;
    $asset_path = $self->retrieve_data('asset_path') unless defined $asset_path;
    $asset_path //= q{};
    $asset_path =~ s/\A\s+|\s+\z//g;
    return '/assets' unless length $asset_path;

    $asset_path = "/$asset_path" unless $asset_path =~ m{\A/};
    $asset_path =~ s{/+\z}{} if length($asset_path) > 1;
    return $asset_path;
}

sub _json_for_script {
    my ($value) = @_;
    my $json = encode_json($value);

    # Values are emitted inside a script element. Keep JSON safe even if an
    # administrator puts unexpected characters in a configuration value.
    $json =~ s/</\\u003C/g;
    $json =~ s/>/\\u003E/g;
    $json =~ s/&/\\u0026/g;
    return $json;
}

1;
