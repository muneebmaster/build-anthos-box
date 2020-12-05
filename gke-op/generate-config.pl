#!/usr/bin/perl
=head1 changelog
2020/11/26 - 1.3
Changelog:
- Updated for Anthos 1.5.x and tested with Anthos 1.5.2

TODO: 
[WARNING] The hostConfig section in ipBlock file (admin-lb-ipblock.yaml) is being deprecated, please use network.hostConfig directly in your cluster config.yaml.



2020/08/10 - 1.2
Changelog:
- Updating for Anthos 1.4.1, to intake 2 config files and generate 2 config files, i.e.
  one for admin cluster and one for user cluster
- Modified CLI options and usage message

2020/04/14 - 1.1
Changelog:
- CLI option to set the clusterlocation for stackdriver configuration (-region)
- CLI option to specify the output file (-output)
- CLI option for help message (-help)

2020/04/06 - 1.0
Initial version
=cut

use strict;
use Getopt::Long;

# Constants And Global Variables
my $PROGRAM             = "generate-config"; 
my $adminConfigTemplate = "/home/ubuntu/admin-cluster.yaml";
my $userConfigTemplate  = "/home/ubuntu/user-cluster.yaml";
my $adminConfigOutput   = "admin-cluster-gen.yaml";
my $userConfigOutput    = "user-cluster-gen.yaml";
my $datadisk            = "gke-on-prem-data-disk.vmdk";
my $bundleDir           = "/var/lib/gke/bundles";
my $defaultBundle       = "gke-onprem-vsphere-1.5.2-gke.3.tgz";
my $gcpRegion           = "us-central1";

my $help = 0;
GetOptions("region=s" => \$gcpRegion,
           "admin-output=s" => \$adminConfigOutput,
           "user-output=s" => \$userConfigOutput,
           "help" => \$help);

if ($help)
{
    usage();
    exit(0);
}

if (! -e $adminConfigTemplate)
{
    die "ERROR: admin-cluster.yaml not found in /home/ubuntu! Was gkeadm used to create the Admin Workstation?\n";
}
if (! -e $userConfigTemplate)
{
    die "ERROR: user-cluster.yaml not found in /home/ubuntu! Was gkeadm used to create the Admin Workstation?\n";
}

### Generate the admin cluster configuration
open (CONFIG, $adminConfigTemplate) or die "ERROR: Failed to open admin-cluster.yaml: $!\n";
open (CONFIG_OUT, ">" . $adminConfigOutput) or die "ERROR: Failed to open '$adminConfigOutput' to write to: $!\n";

while (my $line = <CONFIG>)
{
    chomp($line);
    
    if ($line =~ /^bundlePath:/)
    {
        opendir (BUNDLE_DIR, $bundleDir) or do
            {
                print "WARNING: Failed to open bundle directory '$bundleDir': $!\n";
                print "WARNING: Using default bundle value: '$defaultBundle'\n";
                $line =~ s/:\s+.*$/: ${bundleDir}\/${defaultBundle}/;
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
            $line =~ s/:\s+.*$/: ${bundleDir}\/${defaultBundle}/;
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
        $line =~ s/:\s+.*$/: ${bundleDir}\/${bundleFile}/;
        print CONFIG_OUT $line . "\n";
    }
    elsif ($line =~ /^vCenter:/)
    {
        print CONFIG_OUT $line . "\n";

        while (my $innerLine = <CONFIG>)
        {
            chomp($innerLine);
            #$innerLine =~ s/:\s+.*?$/: internal vm network/ if ($innerLine =~ /^\s+network:/);
            $innerLine =~ s/:\s+.*$/: vcenter-creds.yaml/ if ($innerLine =~ /^\s+path:/);
            $innerLine =~ s/:\s+.*$/: vcenter-creds/ if ($innerLine =~ /^\s+entry:/);
            $innerLine =~ s/:\s+.*$/: gke-on-prem-data-disk.vmdk/ if ($innerLine =~ /^\s+dataDisk:/);

            print CONFIG_OUT $innerLine . "\n";

            last if ($innerLine =~ /^\s+dataDisk:/);
        }
    }
    elsif ($line =~ /^loadBalancer:/)
    {
        print CONFIG_OUT $line . "\n";

        while (my $innerLine = <CONFIG>)
        {
            chomp($innerLine);
            $innerLine =~ s/:\s+.*$/: 172.16.20.10/ if ($innerLine =~ /^\s+controlPlaneVIP:/);
            #$innerLine =~ s/^\s+\#\s+(.*?):\s+.*?$/$1: 172.16.20.12/ if ($innerLine =~ /^\s+\#\s+addonsVIP:/);
            $innerLine =~ s/:\s+.*$/: admin-lb-ipblock.yaml/ if ($innerLine =~ /^\s+ipBlockFilePath:/);
            $innerLine =~ s/:\s+.*$/: 4/ if ($innerLine =~ /^\s+vrid:/);
            $innerLine =~ s/:\s+.*$/: 172.16.20.4/ if ($innerLine =~ /^\s+masterIP:/);
            $innerLine =~ s/:\s+.*$/: internal vm network/ if ($innerLine =~ /^\s+networkName:/);
            #$innerLine =~ s/:\s+.*$/: true/ if ($innerLine =~ /^\s+enableHA:/);

            print CONFIG_OUT $innerLine . "\n";

            last if ($innerLine =~ /^\s+enableHA:/);
        }
    }
    elsif ($line =~ /^antiAffinityGroups:/)
    {
        print CONFIG_OUT $line . "\n";

        while (my $innerLine = <CONFIG>)
        {
            chomp($innerLine);
            $innerLine =~ s/:\s+.*$/: false/ if ($innerLine =~ /^\s+enabled:/);

            print CONFIG_OUT $innerLine . "\n";

            last if ($innerLine =~ /^\s+enabled:/);
        }
    }
    else
    {
        #$line =~ s/:\s+.*?$/: Bundled/ if ($line =~ /^lbmode:/);
        $line =~ s/:\s+.*$/: internal vm network/ if ($line =~ /^\s+networkName:/);
        $line =~ s/:\s+.*$/: $gcpRegion/ if ($line =~ /^\s+clusterLocation:/);

        print CONFIG_OUT $line . "\n";
    }
}

close(CONFIG);
close(CONFIG_OUT);

print "Generated admin cluster configuration $adminConfigOutput based on $adminConfigTemplate\n";

### Generate the user cluster configuration
open (CONFIG, $userConfigTemplate) or die "ERROR: Failed to open user-cluster.yaml: $!\n";
open (CONFIG_OUT, ">" . $userConfigOutput) or die "ERROR: Failed to open '$userConfigOutput' to write to: $!\n";

while (my $line = <CONFIG>)
{
    chomp($line);

    if ($line =~ /^antiAffinityGroups:/)
    {
        print CONFIG_OUT $line . "\n";

        while (my $innerLine = <CONFIG>)
        {
            chomp($innerLine);
            $innerLine =~ s/:\s+.*$/: false/ if ($innerLine =~ /^\s+enabled:/);

            print CONFIG_OUT $innerLine . "\n";

            last if ($innerLine =~ /^\s+enabled:/);
        }
    }
    else
    {
        $line =~ s/:\s+.*$/: user-cluster1/ if ($line =~ /^name:/);
        $line =~ s/:\s+.*$/: internal vm network/ if ($line =~ /^\s+networkName:/);
        $line =~ s/:\s+.*$/: 172.16.20.13/ if ($line =~ /^\s+controlPlaneVIP:/);
        $line =~ s/:\s+.*$/: 172.16.20.14/ if ($line =~ /^\s+ingressVIP:/);
        $line =~ s/:\s+.*$/: usercluster-1-lb-ipblock.yaml/ if ($line =~ /^\s+ipBlockFilePath:/);
        $line =~ s/:\s+.*$/: 7/ if ($line =~ /^\s+vrid:/);
        $line =~ s/:\s+.*$/: 172.16.20.7/ if ($line =~ /^\s+masterIP:/);
        #$line =~ s/:\s+.*$/: true/ if ($line =~ /^\s+enableHA:/);
        $line =~ s/:\s+.*$/: $gcpRegion/ if ($line =~ /^\s+clusterLocation:/);

        print CONFIG_OUT $line . "\n";
    }
}

close(CONFIG);
close(CONFIG_OUT);

print "Generated user cluster configuration $userConfigOutput based on $userConfigTemplate\n";

sub usage
{
    print <<END_USAGE;
Usage:
    $PROGRAM

Optional Arguments:
    -region
        The GCP region where Stackdriver logs and metrics will be stored for this Anthos cluster.
        Default: us-central1

    -admin-output
        Full path of the admin cluster's configuration file for output. 
        Default: admin-cluster-gen.yaml

    -user-output
        Full path of the user cluster's configuration file for output. 
        Default: user-cluster-gen.yaml

    -help
        Displays this usage message.

Program Description:
    Simple tool that reads the admin cluster (admin-cluster.yaml) and user cluster (user-cluster.yaml)
    sample configuration files generated by gkeadm and generates modified versions for the build-anthos-box demo.
    It assumes that gkeadm was used to generate the admin workstation, so expects to find
    /home/ubuntu/admin-cluster.yaml, /home/ubuntu/user-cluster.yaml and gke-op install bundles in 
    /var/lib/gke/bundles. By default, the output configuration files are generated in cwd named 
    admin-cluster-gen.yaml and user-cluster-gen.yaml unless otherwise specified using optional cli parameters.

Usage Examples:
    $PROGRAM
    $PROGRAM -region northamerica-northeast1

Author:
    Muneeb Master
    Google, Inc.

END_USAGE

}
