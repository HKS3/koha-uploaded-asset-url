#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Find;
use File::Path qw(make_path);
use FindBin;
use IO::Compress::Zip qw($ZipError ZIP_CM_DEFLATE);

my $root = abs_path("$FindBin::Bin/..");
chdir $root or die "Cannot enter project directory: $!";

my $module_path = 'Koha/Plugin/HKS3/UploadedAssetURL.pm';
open my $module, '<', $module_path or die "Cannot read $module_path: $!";
my $source = do { local $/; <$module> };
my ($version) = $source =~ /our \$VERSION = '([0-9.]+)'/;
die "Version missing from $module_path\n" unless $version;

my @files;
find(
    {
        no_chdir => 1,
        wanted   => sub { push @files, $File::Find::name if -f && !-l },
    },
    'Koha'
);
push @files, qw(README.md LICENSE CHANGELOG.md);
@files = sort @files;

make_path('dist');
my $target = "dist/koha-uploaded-asset-url-$version.kpz";
my $zip;
for my $path (@files) {
    if (!$zip) {
        $zip = IO::Compress::Zip->new(
            $target, Name => $path, Method => ZIP_CM_DEFLATE, Time => 315532800
        ) or die $ZipError;
    } else {
        $zip->newStream( Name => $path, Method => ZIP_CM_DEFLATE, Time => 315532800 )
            or die $ZipError;
    }
    open my $input, '<:raw', $path or die "Cannot read $path: $!";
    my $data = do { local $/; <$input> };
    $zip->print($data) or die $ZipError;
    close $input;
}
$zip->close or die $ZipError;
print "$root/$target\n";
