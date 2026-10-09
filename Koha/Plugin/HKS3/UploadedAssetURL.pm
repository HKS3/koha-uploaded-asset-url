package Koha::Plugin::HKS3::UploadedAssetURL;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use Mojo::JSON qw(encode_json);

our $VERSION = '0.90.2';

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

sub intranet_js {
    my ( $self, $args ) = @_;

    # Recent Koha versions supply the controller path. The JavaScript below
    # retains its own path check so the plugin remains safe on older versions.
    return q{}
        if $args
        && $args->{page}
        && $args->{page} ne '/cgi-bin/koha/tools/upload.pl';

    my $opac_base_url = C4::Context->preference('OPACBaseURL') // q{};
    my $opac_base_url_json = encode_json($opac_base_url);

    # The value is emitted inside a script element. Keep it JSON-safe even if
    # an administrator has put an unexpected character in the preference.
    $opac_base_url_json =~ s/</\\u003C/g;
    $opac_base_url_json =~ s/>/\\u003E/g;
    $opac_base_url_json =~ s/&/\\u0026/g;

    return <<"JAVASCRIPT";
<script>
(() => {
    "use strict";

    const opacBaseUrl = $opac_base_url_json;

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
                const assetUrl = opacBaseUrl + "/assets/" + encodeURIComponent(hashvalue + "_" + filename);

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

1;
