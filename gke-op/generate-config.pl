#!/usr/bin/perl
=head1 changelog
2020/04/14 - 1.1
Changelog:
- CLI option to set the clusterlocation for stackdriver configuration (--region)
- CLI option for help message (--help)

2020/04/06 - 1.0
Initial version
=cut

use strict;
use Getopt::Long;

# Constants And Global Variables
my $PROGRAM = "generate-config"; 
my $help = 0;
my $configTemplate = "/home/ubuntu/config.yaml";
my $configOutput   = "bundled-lb-gkeop-config.yaml";
my $datadisk       = "gke-on-prem-data-disk.vmdk";
my $bundleDir      = "/var/lib/gke/bundles";
my $defaultBundle  = "gke-onprem-vsphere-1.3.0-gke.16.tgz";
my $gcpRegion      = "us-central1";

GetOptions("region=s" => \$gcpRegion,
           "help" => \$help);

if ($help)
{
    usage();
    exit(0);
}

if (! -e $configTemplate)
{
    die "ERROR: config.yaml not found in /home/ubuntu! Was gkeadm used to create the Admin Workstation?";
}

open (CONFIG, $configTemplate) or die "ERROR: Failed to open config.yaml: $!\n";
open (CONFIG_OUT, ">" . $configOutput) or die "ERROR: Failed to open '$configOutput' to write to: $!\n";

my $vcenter = 0;
my $admincluster = 0;
my $usercluster = 0;

while (my $line = <CONFIG>)
{
    chomp($line);
    
    if ($line =~ /^bundlepath:/)
    {
        opendir (BUNDLE_DIR, $bundleDir) or do
            {
                print "WARNING: Failed to open bundle directory '$bundleDir': $!\n";
                print "WARNING: Using default bundle value: '$defaultBundle'\n";
                $line =~ s/:\s+.*?$/: ${bundleDir}\/${defaultBundle}/;
                print CONFIG_OUT $line . "\n";
                next;
            };
        
        my @bundles = ();
        foreach my $file (grep {/^gke-onprem.*?\.tgz$/} readdir(BUNDLE_DIR))
        {
            #print "file= $file\n";
            next if ($file =~ /full/); # skip the full bundle
            #print "pushing bundle= $file\n";
            push (@bundles, $file);
        }

        closedir(BUNDLE_DIR);
        #print "# bundles= " . scalar(@bundles) . "\n";

        if (! scalar(@bundles))
        {
            print "WARNING: Did not find any bundles in bundle directory '$bundleDir'\n";
            print "WARNING: Using default bundle value: '$defaultBundle'\n";
            $line =~ s/:\s+.*?$/: ${bundleDir}\/${defaultBundle}/;
            print CONFIG_OUT $line . "\n";
            next;
        }

        #print "Bundles before sort: "; print "@bundles\n";
        # Sort the bundles by the newest version first and use that
        @bundles = map {$_->[0]}
                   sort {$b->[1] cmp $a->[1]}
                   map {[$_, /\-(\d+\.\d+\.\d+)\-/]} @bundles;
        #print "Bundles after sort: "; print "@bundles\n";

        my $bundleFile = $bundles[0];
        # find the bundlepath in /var/lib/gke/
        $line =~ s/:\s+.*?$/: ${bundleDir}\/${bundleFile}/;
        print CONFIG_OUT $line . "\n";
    }
    elsif ($line =~ /^vcenter:/)
    {
        print CONFIG_OUT $line . "\n";

        while (my $innerLine = <CONFIG>)
        {
            chomp($innerLine);
            $innerLine =~ s/:\s+.*?$/: internal vm network/ if ($innerLine =~ /^\s+network:/);
            $innerLine =~ s/:\s+.*?$/: gke-on-prem-data-disk.vmdk/ if ($innerLine =~ /^\s+datadisk:/);

            print CONFIG_OUT $innerLine . "\n";

            last if ($innerLine =~ /^\s+datadisk:/);
        }
    }
    elsif ($line =~ /^admincluster:/)
    {
        print CONFIG_OUT <<ADMINCLUSTER;
$line
  loadbalancerconfig:
    ipblockfilepath: admin-lb-ipblock.yaml
    vrid: 4
    vip: 172.16.20.4
    cpus: 4
    memorymb: 8192
    enableha: true
    antiaffinitygroups:
      enabled: false
    network: internal vm network
ADMINCLUSTER

        my $skip = 1;
        while (my $innerLine = <CONFIG>)
        {
            # Skip lines up until either the comment or parameter VIPs
            $skip = 0 if ($innerLine =~ /vips/i);
            next if ($skip);
            chomp($innerLine);
            
            $innerLine =~ s/:\s+.*?$/: 172.16.20.10/ if ($innerLine =~ /^\s+controlplanevip:/);
            $innerLine =~ s/:\s+.*?$/: 172.16.20.11/ if ($innerLine =~ /^\s+ingressvip:/);
            #$innerLine =~ s/:\s+.*?$/: 172.16.20.12/ if ($innerLine =~ /^\s+addonsvip:/);

            print CONFIG_OUT $innerLine . "\n";

            last if ($innerLine =~ /^\s+ingressvip:/);           
        }
    }
    elsif ($line =~ /^usercluster:/)
    {
        print CONFIG_OUT <<USERCLUSTER;
$line
  loadbalancerconfig:
    ipblockfilepath: usercluster-1-lb-ipblock.yaml
    vrid: 7
    vip: 172.16.20.7
    cpus: 4
    memorymb: 8192
    enableha: true
    antiaffinitygroups:
      enabled: false  
    network: internal vm network
USERCLUSTER

        my $skip = 1;
        while (my $innerLine = <CONFIG>)
        {
            # Skip lines up until either the comment or parameter VIPs
            $skip = 0 if ($innerLine =~ /vips/i);
            next if ($skip);
            chomp($innerLine);
            
            $innerLine =~ s/:\s+.*?$/: 172.16.20.13/ if ($innerLine =~ /^\s+controlplanevip:/);
            $innerLine =~ s/:\s+.*?$/: 172.16.20.14/ if ($innerLine =~ /^\s+ingressvip:/);
            $innerLine =~ s/:\s+.*?$/: user-cluster1/ if ($innerLine =~ /^\s+clustername:/);

            print CONFIG_OUT $innerLine . "\n";

            last if ($innerLine =~ /^\s+clustername:/);           
        }
    }
    else
    {
        $line =~ s/:\s+.*?$/: Bundled/ if ($line =~ /^lbmode:/);
        $line =~ s/:\s+.*?$/: us-central1/ if ($line =~ /^\s+clusterlocation:/);

        print CONFIG_OUT $line . "\n";
    }
}

close(CONFIG);
close(CONFIG_OUT);

sub usage
{

}