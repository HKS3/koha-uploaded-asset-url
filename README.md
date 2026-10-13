# Koha Uploaded Asset URL

Adds a **Show asset URL** button to every row on **Tools → Uploads**
(`tools/upload.pl`) in the Koha staff interface. It displays a selectable,
absolute URL in this form:

```text
<OPACBaseURL>/assets/<hashvalue>_<filename>
```

Version 0.91.0; targets Koha 21.05 and later.

## Requirements

- Enable plugins `<enable_plugins>1</enable_plugins>` in your koha-conf.xml file.  
  Allow plugin upload in the admin interface. Set `<plugins_restricted>0</plugins_restricted>`  
  Activate changes `systemctl restart koha-common.service`
- `OPACBaseURL` set to the public base URL.
- A web-server `/assets/` alias that serves Koha's permanent upload directory.

The plugin reads `OPACBaseURL` server-side with `C4::Context->preference` and
injects the value safely into its page-specific JavaScript. It does not depend
on `Koha.prefs` and does not require the `IntranetUserJS` system preference.

The asset path is configurable through **Configure** in Koha's plugin manager.
It defaults to `/assets`; enter another path snippet, such as `/uploaded-files`,
to generate URLs below that path instead.

The filename and hash are taken from the first and third table columns. Those
positions are stable even when the staff interface is translated. The complete
stored filename is URL-encoded as a single path segment, so punctuation and
spaces in uploaded filenames produce usable links.

## Install and use

1. Build the package:

   ```sh
   perl scripts/build-kpz.pl
   ```

2. In the staff interface, open **Administration → Manage plugins** and upload
   `dist/koha-uploaded-asset-url-0.90.2.kpz`.
3. Enable the plugin and reload **Tools → Uploads**.
4. Optionally select **Configure** for the plugin and set the asset path. It
   defaults to `/assets`.
5. Select **Show asset URL** for an upload, then copy the displayed URL.

The plugin creates no database tables. Its asset-path setting is stored through
Koha's normal plugin-data mechanism.

## Build and tests

```sh
prove -lr t
perl scripts/build-kpz.pl
unzip -t dist/koha-uploaded-asset-url-0.90.2.kpz
```

The unit tests use stubs and do not require a Koha installation or database.
Building requires Perl's `IO::Compress::Zip`; Koha supplies the runtime Perl
modules used by the plugin.

## GitHub and releases

`.github/workflows/ci.yml` runs the tests, builds and validates the KPZ, and
uploads it as an Actions artifact. A pushed tag named `v<version>` creates a
GitHub Release containing the KPZ and its SHA-256 checksum. The tag must match
`$VERSION` in `Koha/Plugin/HKS3/UploadedAssetURL.pm`.

Before a release, update the version/date, this README and `CHANGELOG.md`; run
the checks above; commit; then create and push the matching tag. Build output
in `dist/` is intentionally not committed.

License: GPL-3.0-or-later.
