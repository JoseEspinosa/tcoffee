#!/usr/bin/env perl
#Version 1.01 (25/02/03)
use Cwd;
use File::Path;
use FileHandle;
#$CP="cp -d "; was causing mac osx to fail
$CP="cp ";
$INTERNET=0;
$MIRROR="http://www.tcoffee.org/Packages/mirrors/source/";
$SILENT=">/dev/null 2>/dev/null";
$WEB_BASE="http://www.tcoffee.org";
$TCLINKDB_ADDRESS="$WEB_BASE/Resources/tclinkdb.txt";
$OS=get_os();
$ROOT=&get_root();
###########   DEFINITIONS ##############################
#
#
$CXX="g++";
$CXXFLAGS="";

$CPP="g++";
$CPPFLAGS="";

$CC="gcc";
$CFLAGS="";

$FC="f77";
$FFLAGS="";

$install="all";
$default_update_action="no_update";
########################################################
@required_applications=("wget");
########### Mode Definitions ##############################
#
#
@smode=("all", "clean", "install");

########################################################
&initialize_PG();

#Parse The Command Line
$cl=join( " ", @ARGV);
if ($#ARGV==-1 || ($cl=~/-h/) ||($cl=~/-H/) )
  {
     print "\n!!!!!!! ./install  t_coffee             --> installs t_coffee only";
     print "\n!!!!!!! ./install  all                  --> installs all the modes [mcoffee, expresso, psicoffee,rcoffee..]";
     print "\n!!!!!!! ./install  [mcoffee|rcoffee|..] --> installs the specified mode";
     print "\n!!!!!!! ./install  -h                   --> print usage\n\n";
     if ( $#ARGV==-1){exit (EXIT_FAILURE);}
   }
     
if (($cl=~/-h/) ||($cl=~/-H/) )
  {
    print "\n\n!!!!!!! advanced mode\n";
    foreach $m ((keys (%MODE)),(@smode_list))
      {
	print "!!!!!!!       ./install $m\n";
      }
    
    print "!!!!!!! ./install [target:package|mode|download_only] [-update|-force|-no_question|-path=dir|-dis=dir|-email=your@email|-no_root|-tclinkdb=file] [CC=|FCC=|CXX=|CFLAGS=|CXXFLAGS=]\n";
    print "!!!!!!! ./install clean    [removes all executables]\n";
    print "!!!!!!! ./install [optional:target] -update               [updates package already installed]\n";
    print "!!!!!!! ./install [optional:target] -force                [Forces recompilation over everything]\n";
    print "!!!!!!! ./install [optional:target] -no_question          [Do everything without question]\n";
    print "!!!!!!! ./install [optional:target] -root                 [Never ask the root password]\n";
    print "!!!!!!! ./install [optional:target] -path=/foo/bar/       [Final address for the distribution dir]\n";
    print "!!!!!!! ./install [optional:target] -dis=/foo/bar/        [Address where executables should be installed]\n";
    print "!!!!!!! ./install [optional:target] -tclinkdb=foo|update  [file containing all the packages to be installed]\n";
    
    print "!!!!!!! ./install [optional:target] -tclinkdb=update      [download: www.tcoffee.org/resources/tclinkdb.txt]\n";
    print "!!!!!!! ./install [optional:target] -email                [specifies your e-mail]\n";
    print "!!!!!!! ./install install   [-path=/your/install/dir] [/usr/local/bin]\n";
    print "!!!!!!! mode:";
    foreach $m (keys(%MODE)){print "$m ";}
    print "\n";
    print "!!!!!!! Packages:";
    foreach $m (keys (%PG)){print "$m ";}
    print "\n";
    
    print "\n\n";
    exit (EXIT_FAILURE);
  }



# parse compiler flags
(@argl)=($cl=~/(\S+=[^=]+)\s\w+=/g);
push (@argl, ($cl=~/(\S+=[^=]+\S)\s*$/g));

foreach $a (@argl)
  {
    if ( ($cl=~/CXX=(.*)/)){$CXX=$1;}
    if ( ($cl=~/-CC=(.*)/    )){$CC=$1;}
    if ( ($cl=~/-FC=(.*)/    )){$FC=$1;}
    if ( ($cl=~/-CFLAGS=(.*)/)){$CFLAGS=$1;}
    if ( ($cl=~/-CXXFLAGS=(.*)/)){$CXXFLAGS=$1;}
  }
#parse install flags
if ( ($cl=~/-root/)){$ROOT_INSTALL=1;}
if ( ($cl=~/-no_question/)){$NO_QUESTION=1;}
if ( ($cl=~/-update/)){$default_update_action="update";}
if ( ($cl=~/-binaries/)){$BINARIES_ONLY=1;}
if ( ($cl=~/-force/)){$force=1;$default_update_action="update"}
if ( ($cl=~/-exec=\s*(\S+)/)){$INSTALL_DIR=$1;}
if ( ($cl=~/-plugins=\s*(\S+)/)){$PLUGINS_DIR=$1;}
if ( ($cl=~/-distributions=\s*(\S+)/)){$DISTRIBUTIONS=$1;}
if ( ($cl=~/-email=\s*(\S+)/)){$email=$1;}
if ( ($cl=~/-tclinkdb=\s*(\S+)/)){$tclinkdb=$1;}

#automated update
if ($tclinkdb){&update_tclinkdb ($tclinkdb);}

#Prepare the T-Coffee directory structure
&add_dir ($TCDIR="$ENV{HOME}/.t_coffee");
&add_dir ($TCCACHE="$TCDIR/cache");
&add_dir ($TCTMP="$CDIR/tmp");
&add_dir ($TCM="$TCDIR/mcoffee");
&add_dir ($TCMETHODS="$TCDIR/methods");
&add_dir ($TCPLUGINS="$TCDIR/plugins/$OS");

#set the directory for the plugins 
if    (!$PLUGINS_DIR && !$ROOT_INSTALL){$PLUGINS_DIR=$TCPLUGINS;}
elsif (!$PLUGINS_DIR &&  $ROOT_INSTALL){$PLUGINS_DIR="/usr/local/bin/";}

#set the directory for t_coffee
if    (!$INSTALL_DIR && !$ROOT_INSTALL){$INSTALL_DIR="$HOME/bin/";mkpath ($installation_directory);}
elsif (!$INSTALL_DIR &&  $ROOT_INSTALL){$INSTALL_DIR="/usr/local/bin/";}

#prepare mcoffee files
if (-d "./mcoffee")
  {
    `$CP mcoffee/* $TCM`;
  }

#prepare the environement
$ENV_FILE="$TCDIR/t_coffee_env";
&env_file2putenv ($ENV_FILE);

#$proxy=&get_proxy($ENV_FILE,$ENV{"http_proxy_4_TCOFFEE"});
#&set_proxy($proxy);
#$email=&get_email($ENV_FILE, $email);

#set the target mode
if ( $ARGV[0] eq "download_only")
  {
    $target="download_only";
  }
else
  {
    $target="";
    foreach $p (  ((keys (%PG)),(keys(%MODE)),(@smode)) )
      {
	if ($ARGV[0] eq $p && $target eq ""){$target=$p;}
      }
  }
if ($target eq ""){exit (EXIT_FAILURE);}


# Check the basic requirements are met
foreach $r (@required_applications)
  {
    &exit_if_pg_not_installed ($r);
  }


# Set the mains paths and create directories
# distrib_dir/install/bin
# distrib_dir/install/Downloads
# distrib_dir/install/Downloads/Files
# distrib_dir/install/Downloads/Distributions
# distrib_dir/tmp

#Directory structure of the installation WITHIN the distribution dir

$CD=$CDIR=cwd();
&add_dir($BASE="$CD/install");
&add_dir($BIN="$BASE/bin/$OS");
&add_dir($DOWNLOAD_DIR="$BASE/download");
&add_dir($DOWNLOAD_FILE="$DOWNLOAD_DIR/files");
if (!$DISTRIBUTIONS){$DISTRIBUTIONS="$DOWNLOAD_DIR/distributions";}
&add_dir ($DISTRIBUTIONS);
&add_dir ($TMP="$BASE/tmp");

#sign the license
&sign_license_ni();


#Configure the copilers and their optins
$PG{C}{compiler}=get_C_compiler($CC);
$PG{Fortran}{compiler}=get_F_compiler($FC);
$PG{CXX}{compiler}=$PG{CPP}{compiler}=$PG{GPP}{compiler}=get_CXX_compiler($CXX);
if ($CXXFLAGS){$PG{CPP}{options}=$PG{GPP}{options}=$PG{CXX}{options}=$CXXFLAGS;}
if ($CFLAGS){$PG{C}{options}=$CFLAGS;}
foreach $c (keys(%PG))
  {
    my $arguments;
    if ($PG{$c}{compiler})
      {
	$arguments="$PG{$c}{compiler_flag}=$PG{$c}{compiler} ";
	if ($PG{$c}{options})
	  {
	    $arguments.="$PG{$c}{options_flag}=$PG{$c}{options} ";
	  }
	$PG{$c}{arguments}=$arguments;
      }
  }

# If target download: download all the packages
if ($target eq "download_only")
  {
    foreach my $pg (sort (keys(%PG)))
      {
	
	my $download=$PG{$pg}{source};
	
	if ($download ne "" && $download ne "empty")
	  {
	    print "!!!!!! Download : [$download]\n";
	    my ($address,$name,$ext)=download_pkg($download);
	    if (!$address){die;}
	  }
      }
    die;
  }


# select the list of packages to update
if ($PG{$target}){$PG{$target}{install}=1;}
else
  {
    foreach my $pg (sort (keys(%PG)))
      {
	if ( $target eq "all" || ($PG{$pg}{mode}=~/$target/))
	  {
	    $PG{$pg} {install}=1;
	  }
      }
  }

foreach my $pg (sort (keys(%PG)))
  {
    if (!$PG{$pg}{update_action}){$PG{$pg}{update_action}=$default_update_action;}
    elsif ($PG{$pg}{update_action} eq "never"){$PG{$pg}{install}=0;}
    if ( $force && $PG{$pg}{install})
      {
	`rm $BIN/$pg $BIN/$pg.exe $SILENT`;
      }
    if ($PG{$pg}{update_action} eq "update" && $PG{$pg}{install}){$PG{$pg}{update}=1;}
  }

#Execute the target: install/remove all the selected components
if (($target=~/clean/))
  {
    print "------- cleaning executables -----\n";
    `rm bin/* $SILENT`;
    `rm $TCDIR/email.txt $SILENT`;
    `rm $TCDIR/signature_license.txt`;
    `rm ./signature_flag.txt`;
    exit (EXIT_SUCCESS);
  }

if ( !$PG{$target}){print "------- Installing T-Coffee Modes\n";}

#1 - Installing various modes
foreach $m (sort (keys(%MODE)))
  {
    if ( $target eq "all" || $target eq $m)
      {
	print "\n------- The installer will now install the $m components $MODE{$m}{description}\n";
	foreach $pg (sort (keys(%PG)))
	  {
	    if ( $PG{$pg}{mode} =~/$m/ && $PG{$pg}{install})
	      {
		if ($PG{$pg}{touched}){print "------- $PG{$pg}{dname}: already processed\n";}
		else {$PG{$pg}{success}=&install_pg($pg);$PG{$pg}{touched}=1;}
	      }
	  }
      }
  }

#2 - Installing Various Packages
if ( $PG{$target}){print "------- Installing Individual Package\n";}
foreach $pg (sort (keys (%PG)))
  {
    if ( $PG{$pg}{install} && !$PG{$pg}{touched}){$PG{$pg}{success}=&install_pg($pg);$PG{$pg}{touched}=1;}
  }
print "------- Finishing The installation\n";
$final_report=&install ($installation_directory);

print "\n";
print "*********************************************************************\n";
print "********              INSTALLATION SUMMARY          *****************\n";
print "*********************************************************************\n";
print "------- SUMMARY package Installation:\n";
foreach $pg (sort (keys(%PG)))
  {
    if ( $PG{$pg}{install})
      {
	my $bin_status=($PG{$pg}{from_binary} && $PG{$pg}{success})?"[from binary]":"";
	if     ( $PG{$pg}{new} && !$PG{$pg}{old})                     {print "*------        $PG{$pg}{dname}: installed $bin_status\n"; $PG{$pg}{status}=1;}
	elsif  ( $PG{$pg}{new} &&  $PG{$pg}{old})                     {print "*------        $PG{$pg}{dname}: updated $bin_status\n"  ; $PG{$pg}{status}=1;} 
	elsif  (!$PG{$pg}{new} &&  $PG{$pg}{old} && !$PG{$pg}{update}){print "*------        $PG{$pg}{dname}: previous\n" ; $PG{$pg}{status}=1;}
	elsif  (!$PG{$pg}{new} &&  $PG{$pg}{old} &&  $PG{$pg}{update}){print "*------        $PG{$pg}{dname}: failed update (previous installation available)\n";$PG{$pg}{status}=0;}
	else                                                          {print "*------        $PG{$pg}{dname}: failed installation";$PG{$pg}{status}=0;}
      }
  }

if ( !$PG{$target}){print "*------ SUMMARY mode Installation:\n";}
foreach $m (sort (keys(%MODE)))
  {
    if ( $target eq "all" || $target eq $m)
      {
	my $succesful=1;
	foreach $pg (sort (keys(%PG)))
	  {
	    if (($PG{$pg}{mode}=~/$m/) && $PG{$pg}{install} && $PG{$pg}{status}==0)
	      {
		$succesful=0;
		print "*!!!!!!       $PG{$pg}{dname}: Missing\n";
	      }
	  }
	if ( $succesful)
	  {
	    $MODE{$m}{status}=1;
	    print "*------       MODE $MODE{$m}{dname} SUCCESFULY installed\n";
	  }
	else
	  {
	    $MODE{$m}{status}=0;
	    print "*!!!!!!       MODE $MODE{$m}{dname} UNSUCCESFULY installed\n";
	  }
      }
  }
print "$final_report";
print "\n\n";
print "*------ You can now try to run the following commands:\n";
print "*------         t_coffee <foo.seq>\n";

foreach $m (sort (keys (%MODE)))
  {
    if ( $MODE {$m}{status})
      {
	print "*------         t_coffee <foo.seq> -mode $m\n";
      }
  }

#failure if one program was not well installed
foreach $pg (sort (keys(%PG))){if ( $PG{$pg}{status}==0){exit (EXIT_FAILURE);}}
exit (EXIT_SUCCESS);  

#################################################################################
#                                                                               #
#                                                                               #
#                                                                               #
#                   GENERIC INSTALLATION                                        #
#                                                                               #
#                                                                               #
#                                                                               #
#################################################################################
sub get_CXX_compiler
  {
    my $c=@_[0];
    my (@clist)=("g++");
    
    return get_compil ($c, @clist);
 }
sub get_C_compiler
  {
    my $c=@_[0];
    my (@clist)=("gcc", "cc", "icc");
    
    return get_compil ($c, @clist);
 }

sub get_F_compiler
  {
    my ($c)=@_[0];
    my @clist=("f77", "g77", "gfortran", "ifort");
    return get_compil ($c, @clist);
  } 
       
sub get_compil
  {
    my ($fav,@clist)=(@_);
    
    #return the first compiler found installed in the system. Check first the favorite
    foreach $c ($fav,@clist)
      {
	if  (&pg_is_installed ($c)){return $c;}
      }
    return "";
  }
sub exit_if_pg_not_installed
  {
    my (@arg)=(@_);
    if ( !&pg_is_installed (@arg))
      {
	print "!!!!!!!! The $pg utility must be installed for this installation to proceed [FATAL]\n";
	die;
      }
    return 1;
  }

sub check_internet 
  {
    my $internet;
    &exit_if_pg_not_installed ("wget");
    if ( -e "x"){unlink ("x");}
    
    system ("wget www.google.com -Ox -o/dev/null");
    if ( !-e "x" || -s "x" < 10){$internet=0;}
    else {$internet=1;}
    if (-e "x"){unlink "x";}
    return $internet;
  }
sub my_wget 
  {
    my ($cmd, $file)=(@_);
    my $exit;

    if (!$PROXY)
      {
	$PROXY=&get_proxy($ENV_FILE,$ENV{"http_proxy_4_TCOFFEE"});
	&set_proxy($PROXY);
      }
    if (!$file){$exit=system ("wget $cmd --no-check-certificate >/dev/null 2>/dev/null");}
    else 
      {
	my $n;
	
	if (-e $file){unlink($file);}
	$exit=system "wget $cmd -O$file --no-check-certificate >/dev/null 2>/dev/null";
      }
    return $exit;
  }
sub pg_is_installed
  {
    my ($p, $dir)=(@_);
    my ($r,$m);
    my ($supported, $language, $compil);
    
    if ( $PG{$p})
      {
	$language=$PG{$p}{language2};
	$compil=$PG{$language}{compiler};
      }
    
    if ( $compil eq "CPAN")
      {
	if ( system ("perl -M$p -e 1")==EXIT_SUCCESS){return 1;}
	else {return 0;}
      }
    elsif ($dir)
      {
	if (-e "$dir/$p" || -e "$dir/$p\.exe"){return 1;}
	else {return 0;}
      }
    else
      {
	$r=`which $p 2>/dev/null`;
	if ($r eq ""){return 0;}
	else {return 1;}
      }
    return 0;
  }
sub install
  {
    my ($new_bin)=(@_);
    my $copied;

    
    if (!$ROOT_INSTALL)
      {
	
	if (-e "$BIN/t_coffee"){`$CP $BIN/t_coffee $INSTALL_DIR`};
	`mv $BIN/* $PLUGINS_DIR`;
	&add2env_file ($ENV, "MAFFT_BINARIES", $PLUGINS_DIR);
	&add2env_file ($ENV, "PATH", "\$PATH:$PLUGINS_DIR");
	$copied=1;
      }
    else
      {
	$copied=&root_run ("You must be root to finalize the installation", "$CP $BIN/* $INSTALL_DIR $SILENT");
      }
    
     
  if ( !$copied)
    {
      $report="*!!!!!! Installation unsuccesful. The executables have been left in $BASE/bin\n";
    }
  elsif ( $copied && $ROOT)
    {
      $report="*------ Installation succesful. Your executables have been copied in $new_bin and are on your PATH\n";
    }
  elsif ( $copied && !$ROOT)
    {
      $report= "*!!!!!! T-Coffee and associated packages have been copied in: $new_bin\n";
      $report.="*!!!!!! This address is NOT in your PATH sytem variable\n";
      $report.="*!!!!!! You can do so by adding the following line in your ~/.bashrc file:\n";
      $report.="*!!!!!! export PATH=$new_bin:\$PATH\n";
    }
  return $report;
}

sub sign_license_ni
  {
    open (F, "license.txt");
    while (<F>)
      {
	print "$_";
      }
    close (F);
    
    return;
  }
sub sign_license 
  {
    my ($signature_file,$signature_flag, $email)=(@_);
    #&sign_license ("$TCDIR/signature_license.txt","$BASE/signature_flag.txt", $email);
    if (!-e $signature_file || !-e $signature_flag)
      {
	open (F, "license.txt");
	while (<F>)
	  {
	    print "$_";
	  }
	close (F);
	print "------- Scroll up to read the entire license --- Type y(es) if you agree, or n(o) if you do not\n";
	
	if ( !&input_yes())
	  {
	    print "--------- You have NOT accepted the terms of the license -----\n";
	    print "--------- Please Delete the tar file from yours system   -----\n";
	    print "--------- Now, Concentrate very hard to forget about it  -----\n";
	    print "--------- A bit more, we know you can                    -----\n";
	    print "--------- Interruption of the installation               -----\n";
	    exit (EXIT_FAILURE)
	  }
	else
	  {
	    my $date = `date`;
	    chomp ($date);
	    `echo $email On $date >$signature_file`;
	    `echo $email On $date >$signature_flag`;
	    print "--------- You have accepted the terms of the license -----\nProceeding with the installation\n";
	    
	  }
      }
  }
sub is_valid_email
  {
    my $email=@_[0];
    if (($email=~/@/)){return 1;}
    
    return 0;
  }
sub is_valid_proxy
  {
    my $proxy=@_[0];
    return 1;
  }     
sub get_email
  {
    my ($env_file, $email)=(@_);
    my $answer;
    
  
    if ( $email)
      {
	&add_env ($env_file,"EMAIL_4_TCOFFEE", $email);
      }
    
    if ($ENV{"EMAIL_4_TCOFFEE"})
      {
	$email=$ENV{"EMAIL_4_TCOFFEE"};
	print "------- Default Email: $email\n";
	print "------- Edit the file $env_file to change this setting\n";
	return $email;
      }
	
    
    printf (  "\n\n");
    print (  "*************************************************************************************************\n");
    print (  "*                        IMPORTANT: Please Read Carefuly                                        *\n");
    print (  "*                                                                                               *\n");
    print (  "* You have the possibility to use the EBI BLAST webservices (webblast, dalilite).     The EBI   *\n");
    print (  "* Requires a valid E-mail address for this service (www.ebi.ac.uk/Tools/webservices/) to be used*\n");
    print (  "* T-Coffee will keep it for further run but it will use it only use it when contacting the EBI  *\n");
    print (  "*                                                                                               *\n");
    print (  "* !!!!!!!!!!!!!!!!!! Your Email will not be sent to us, ONLY to the EBI !!!!!!!!!!!!!!!!!!!!!!!!*\n");
    print (  "*                                                                                               *\n");
    print (  "* -blast_server=EBI is the default mode of T-Coffee. If you do NOT want to provide your E-mail  *\n");
    print (  "* you can use:                                                                                  *\n");
    print (  "*    -blast_server=NCBI     (NCBI netblast)                                                     *\n");
    print (  "*    -blast_server=LOCAL     Local NCBI BLAST                                                   *\n");
    print (  "*                                                                                               *\n");
    print (  "*The address you provide can be changed anytime by editing the file:                            *\n");
    print (  "*    $envfile                                   \n");
    print (  "*                                                                                               *\n");
    print (  "*If you do not want to provide your E-mail, Hit the [Return key]                                *\n");    
    print (  "*************************************************************************************************\n");
    print ("Enter your Email: ");
    chomp ($email=<STDIN>);
    while ($email ne "" && !is_valid_email ($email))

	  {
	    print "\nEnter your Email: ";
	    chomp($email=<STDIN>);
	    if ( $email eq ""){return "";}
	  }
    if ( $email ne "")
      {
	print "You have entered : $email\n Is this correct [yes/no]: ";
	while (!&input_yes()){return &get_email(@_);}
      }
    &add2env_file ($env_file,"EMAIL_4_TCOFFEE", $email);
    return $email;
  }
sub set_proxy 
  {
    my $proxy=@_[0];
    $ENV{"http_proxy"}=$proxy;
    $ENV{"HTTP_proxy"}=$proxy;
    $ENV{"http_proxy_4_TCOFFEE"}=$proxy;
  }

sub get_proxy
  {
    my ($env_file, $proxy)=(@_);
    
    if ($INTERNET){return "";}
    elsif (&check_internet())
      {
	print "!!!!!!! Internet access OK\n";
	if ( $proxy eq "") {print "------- Default Proxy: No Proxy (Direct Access)\n";}
	else {print "------- Default Proxy: [$proxy]\n";}
	print "------- Edit the file $env_file to change this setting\n";
	$INTERNET=1;
	return "";
      }
    else
      {

	print (  "\n");
	print (  "*                         No Internet Access: Set The Proxy                                      \n");
	print (  "*************************************************************************************************\n");
	print (  "*                        IMPORTANT: Please Read Carefuly                                        *\n");
	print (  "*                                                                                               *\n");
	print (  "* If you are behind a firewall, you must enter your proxy address to use webservices.           *\n");
	print (  "* If you are not sure what is a proxy, here are 3 Tips:                                         *\n");   
	print (  "* ----It is an address that often reads like: http://some.place.somewhere:8080                  *\n");            
	print (  "* ----It is often an address you have had to set in your browser for Internet access            *\n");                                                          
	print (  "* ----If you work from home (ADSL) you probably do no need a proxy.                             *\n");
	print (  "\n* The proxy you will provide can be changed anytime by editing the file: $env_file*\n");
	printf ( "*************************************************************************************************\n");
	$proxy=-1;
	while ($proxy==-1 && !&is_valid_proxy ($proxy) && &check_internet()==0)
	  {
	    print "\nEnter your Proxy (Type return if you do not need a proxy): ";
	    chomp($proxy=<STDIN>);
	    &set_proxy($proxy);
	  }
	&add2env_file ($env_file,"http_proxy_4_TCOFFEE", $proxy);
      }
    
    return &get_proxy($env_file, $proxy);
  }
#################################################################################
#                                                                               #
#                                                                               #
#                                                                               #
#                   INDIVIDUAL MULTIPLE SEQUENCE ALIGNMNT PACKAGES INSTALLATION #
#                                                                               #
#                                                                               #
#                                                                               #
#################################################################################
sub download_pkg
    {
      my $download=shift;
      my ($address,$name,$ext);
      my $wget_tmp="$TMP/wget.tmp";
      
      
      if (($download =~/tgz/))
	{
	  ($address,$name,$ext)=($download=~/(.+\/)([^\/]+)(\.tgz)/);
	}
      elsif (($download=~/tar\.gz/))
	{
	  ($address,$name,$ext)=($download=~/(.+\/)([^\/]+)(\.tar\.gz)/);
	}
      elsif (($download=~/tar/))
	{
	  ($address,$name,$ext)=($download=~/(.+\/)([^\/]+)(\.tar)/);
	}
      elsif (($download=~/zip/))
	{
	  ($address,$name,$ext)=($download=~/(.+\/)([^\/]+)(\.zip)/);
	}
      else
	{
	  ($address,$name)=($download=~/(.+\/)([^\/]+)/);
	  $ext="";
	}
      if ($download=~/github/){$download="$address/master.zip";}
      
      $distrib="$name$ext";
      if ( -e $distrib)
	{;}
      elsif ( -e "$DOWNLOAD_DIR/$distrib")
	{
	  `$CP $DOWNLOAD_DIR/$distrib .`;
	}
      else
	{
	  check_rm ($wget_tmp);
	  if (my_wget ("$download", "$wget_tmp")==EXIT_SUCCESS)
	    {
	      `mv $wget_tmp $distrib`;
	    }
	  elsif (my_wget ("$MIRROR/$distrib", "$wget_tmp")==EXIT_SUCCESS)
	    {
	      print "!!!!!!! Warning Download from Mirror: $MIRROR\n";
	      `mv $wget_tmp $distrib`;
	    }
	  else
	    {
	      
	      print "!!!!!!! Download of $pg distribution failed\n";
	      print "!!!!!!! Check Address: $PG{$pg}{source}\n";
	      return 0;
	    }
	}
      
      return ($address,$name,$ext)
    }
sub install_pg
  {
    my ($pg)=(@_);
    my ($report, $previous, $language, $compiler, $return);
    
    if (!$PG{$pg}{install}){return 1;}
    
    $previous=&pg_is_installed ($pg);
    
    if ($PG{$pg}{update_action} eq "no_update" && $previous)
      {
	$PG{$pg}{old}=1;
	$PG{$pg}{new}=0;
	$return=1;
      }
    else
      {
	$PG{$pg}{old}=$previous;
	
	if ($PG{$pg} {language2} eq "Perl"){&install_perl_package ($pg);}
	elsif ($BINARIES_ONLY && &install_binary_package ($pg)){$PG{$pg}{from_binary}=1;}
	elsif (&install_source_package ($pg)){;}
	else 
	  {
	    
	    if (!&supported_os($OS))
	      {
		print "!!!!!!!! $pg compilation failed, binary unsupported for $OS\n"; 
	      }
	    elsif (!($PG{$pg}{from_binary}=&install_binary_package ($pg)))
	      {
		print "!!!!!!!! $pg compilation and  binary installation failed\n";
	      }
	  }
	$PG{$pg}{new}=$return=&pg_is_installed ($pg,$BIN);
      }

    
    return $return;
  }
sub install_perl_package
  {
    my ($pg)=(@_);
    my ($report, $language, $compiler);
    
    $language=$PG{$pg} {language2};
    $compiler=$PG{$language}{compiler};
    
    if (!&pg_is_installed ($pg))
      {
	if ( $OS eq "windows"){`perl -M$compiler -e 'install $pg'`;}
	elsif ( $ROOT eq "sudo"){system ("sudo perl -M$compiler -e 'install $pg'");}
	else {system ("su root -c perl -M$compiler -e 'install $pg'");}
      }
    return &pg_is_installed ($pg);
  }



sub install_source_package
  {
    my ($pg)=(@_);
    my ($report, $download, $arguments, $language);
    
    
    if ( -e "$BIN/$pg" || -e "$BIN/$pg.exe"){return 1;}
    
    if ($pg eq "t_coffee")  {return   &install_t_coffee ($pg);}
    elsif ($pg eq "TMalign"){return   &install_TMalign ($pg);}
    
    chdir $DISTRIBUTIONS;
    if ( !-d $pg){mkdir $pg;}
    chdir $pg;
    
    print "\n------- Downloading/Installing $pg\n";
    my $download=$PG{$pg}{source};
    my ($address, $name, $ext)=download_pkg($download);
    if (!$address){return 0;}
    
    $distrib="$name$ext";
    `$CP $distrib $DOWNLOAD_DIR/`;
    
    #UNTAR and Prepare everything
    if (!-e "$name.tar" && !-e "$name")
      {
	
	print "\n------- unzipping/untaring $name\n";
	if (($ext =~/z/))
	  { 
	    &flush_command ("gunzip $name$ext");
	  }
	
	if (($ext =~/tar/) || ($ext =~/tgz/))
	  {
	    &flush_command("tar -xvf $name.tar");
	  }
      }
    #Guess and enter the distribution directory
    @fl=ls($p);
    foreach $f (@fl)
      {
	if (-d $f)
	  {
	    $main_dir=$f;
	  }
      }
    if (-d $main_dir)
	  {chdir $main_dir;}
    
    print "\n------- Compiling/Installing $pg\n";
    `make clean $SILENT`;
    #sap
    if ($pg eq "sap")
      {
	`rm *.o sap  sap.exe ./util/aa/*.o  ./util/wt/.o $SILENT`;
	&flush_command ("make $arguments sap");
	&check_cp ($pg, "$BIN");
      }
    elsif ($pg eq "clustalw2")
      {
	&flush_command("./configure");
	&flush_command("make $arguments");
	&check_cp ("./src/$pg", "$BIN");
	
      }
    elsif ($pg eq "clustalw")
      {
	&flush_command("make $arguments clustalw");
	`$CP $pg $BIN $SILENT`;
      }
    
    elsif ($pg eq "mafft")
      {
	my $base=cwd();
	my $c;
	
	#compile core
	mkpath ("./mafft/bin");
	mkpath ("./mafft/lib");
	chdir "$base/core";
	`make clean $SILENT`;
	&flush_command ("make $arguments");
	&flush_command ("make install LIBDIR=../mafft/lib BINDIR=../mafft/bin");
	
	#compile extension
	chdir "$base/extensions";
	`make clean $SILENT`;
	&flush_command ("make $arguments");
	&flush_command ("make install LIBDIR=../mafft/lib BINDIR=../mafft/bin");
	
	#put everything in mafft and copy the coompiled stuff in bin
	chdir "$base";
	if ($ROOT_INSTALL)
	  {
	    &root_run ("You Must be Roor to Install MAFFT\n", "mkdir /usr/local/mafft/;$CP mafft/lib/* /usr/local/mafft;$CP mafft/lib/mafft* /usr/local/bin ;$CP mafft/bin/mafft /usr/local/bin/; ");
	  }
	else
	  {
	    `$CP mafft/lib/*  $BIN`;
	    `$CP mafft/bin/mafft  $BIN`;
	  }
	`tar -cvf mafft.tar mafft`;
	`gzip mafft.tar`;
	`mv mafft.tar.gz $BIN`;
      }
    elsif ( $pg eq "dialign-tx")
      {
	my $f;
	my $base=cwd();

	chdir "./source";
	&flush_command (" make CPPFLAGS='-O3 -funroll-loops' all");
	
	chdir "..";
	&check_cp ("./source/$pg", "$BIN");
	&check_cp ("./source/$pg", "$BIN/dialign-t");
      }
    elsif ($pg eq "poa")
      {
	&flush_command ("make $arguments poa");
	&check_cp ("$pg", "$BIN");
      }
    elsif ( $pg eq "probcons")
      {
	`rm *.exe $SILENT`;
	&flush_command ("make $arguments probcons");
	&check_cp("$pg", "$BIN/$pg");
      }
    elsif ( $pg eq "probcons" || $pg eq "probconsRNA")
      {
	`rm *.exe $SILENT`;
	&flush_command ("make $arguments probcons");
	&check_cp("probcons", "$BIN/$pg");
      }

    elsif (  $pg eq "muscle")
      {
	`rm *.o muscle muscle.exe $SILENT`;
	&flush_command ("make $arguments all");
	&check_cp("$pg", "$BIN");
      }
    elsif ( $pg eq "pcma")
      {
	&flush_command ("make $arguments pcma");
	&check_cp("$pg", "$BIN");
      }
    elsif ($pg eq "kalign")
      {
	&flush_command ("./configure");
	&flush_command("make $arguments");
	&check_cp ("$pg",$BIN);
      }
    elsif ( $pg eq "amap")
      {
	chdir "align";
	`make clean $SILENT`;
	&flush_command ("make $arguments all");
	&check_cp ("$pg", $BIN);
      }
    elsif ( $pg eq "proda")
      {
	&flush_command ("make $arguments all");
	&check_cp ("$pg", $BIN);
      }
    elsif ( $pg eq "prank")
      {
	&flush_command ("make $arguments all");
	&check_cp ("$pg", $BIN);
      }
    elsif ( $pg eq "mustang")
      {
	&flush_command ("make $arguments all");
	if ( $OS=~/windows/){&check_cp("./bin/MUSTANG_v.3", "$BIN/mustang.exe");}
	else {&check_cp("./bin/MUSTANG_v.3", "$BIN/mustang");}
      }
    elsif ( $pg eq "RNAplfold")
      {
	&flush_command("./configure");
	&flush_command ("make $argument all");
	&check_cp("./Progs/RNAplfold", "$BIN");
      }
    chdir $CDIR;
    return &pg_is_installed ($pg, $BIN);
  }

sub install_t_coffee
  {
    my ($pg)=(@_);
    my ($report,$cflags, $arguments, $language, $compiler) ;
    #1-Install T-Coffee
    chdir "t_coffee_source";
    &flush_command ("make clean");
    print "\n------- Compiling T-Coffee\n";
    $language=$PG{$pg} {language2};
    $arguments=$PG{$language}{arguments};
    if (!($arguments =~/CFLAGS/)){$arguments .= " CFLAGS=-O2 ";}

    if ( $CC ne ""){&flush_command ("make -i $arguments t_coffee");}
    &check_cp ($pg, $BIN);
    
    chdir $CDIR;
    return &pg_is_installed ($pg, $BIN);
  }
sub install_TMalign
  {
    my ($pg)=(@_);
    my $report;
    chdir "t_coffee_source";
    print "\n------- Compiling TMalign\n";
    `rm TMalign TMalign.exe $SILENT`;
    if ( $FC ne ""){&flush_command ("make -i $PG{Fortran}{arguments} TMalign");}
    &check_cp ($pg, $BIN);
    if ( !-e "$BIN/$pg" && pg_has_binary_distrib ($pg))
      {
	print "!!!!!!! Compilation of $pg impossible. Will try to install from binary\n";
	return &install_binary_package ($pg);
      }
    chdir $CDIR;
    return &pg_is_installed ($pg, $BIN); 
  }

sub pg_has_binary_distrib
  {
    my ($pg)=(@_);
    if ($PG{$pg}{windows}){return 1;}
    elsif ($PG{$pg}{osx}){return 1;}
    elsif ($PG{$pg}{linux}){return 1;}
    return 0;
  }
sub install_binary_package
  {
    my ($pg)=(@_);
    my ($base,$report,$name, $download, $arguments, $language, $dir);
    my $isdir;
    &input_os();
    
    if (!&supported_os($OS)){return 0;}
    if ( $PG{$pg}{binary}){$name=$PG{$pg}{binary};}
    else 
      {
	$name=$pg;
	if ( $OS eq "windows"){$name.=".exe";}
      }
    
    $download="$WEB_BASE/Packages/Binaries/$OS/$name";
    
    $base=cwd();
    chdir $TMP;
    
    if (!-e $name)
      {
	`rm x $SILENT`;
	if ( my_wget("$download -Ox --tries=10")==EXIT_SUCCESS)
	  {
	    `mv x $name`;
	  }
      }
    
    if (!-e $name)
      {
	print "!!!!!!! $PG{$pg}{dname}: Download of $pg binary failed\n";
	print "!!!!!!! $PG{$pg}{dname}: Check Address: $download\n";
	return 0;
      }
    print "\n------- Installing $pg\n";
    
    if ($name =~/tar\.gz/)
      {
	`gunzip  $name`;
	`tar -xvf $pg.tar`;
	chdir $pg;
	if ( $pg eq "mafft")
	  {
	    if ($ROOT_INSTALL)
	      {
		&root_run ("You Must be Roor to Install MAFFT\n", "$CP mafft/bin/* /usr/local/mafft;mkdir /usr/local/mafft/; $CP mafft/lib/* /usr/local/bin/");
	      }
	    else
	      {
		`$CP $TMP/$pg/bin/* $BIN $SILENT`;
		`$CP $TMP/$pg/lib/* $BIN $SILENT`;
	      }
	  }
	else
	  {
	    if (-e "$TMP/$pg/data"){`$CP $TMP/$pg/data/* $TCM $SILENT`;}
	    if (!($pg=~/\*/)){`rm -rf $pg`;}
	  }
      }
    else
      {
	&check_cp ("$pg", "$BIN");
	`chmod u+x $BIN/$pg`; 
	unlink ($pg);
      }
    chdir $base;
    $PG{$pg}{from_binary}=1;
    return &pg_is_installed ($pg, $BIN);
  }

################################################################################
#                                                                               #
#                                                                               #
#                                                                               #
#                   Simple Utilities                                            #
#                                                                               #
#                                                                               #
#                                                                               #
#################################################################################
sub add_dir 
  {
    my $dir=@_[0];
    
    if (!-e $dir && !-d $dir)
      {
	return mkpath ($dir);
      }
    else
      {
	return 0;
      }
  }
sub check_rm 
  {
    my ($file)=(@_);
    
    if ( -e $file)
      {
	return unlink($f);
      }
    return 0;
  }
sub check_cp
  {
    my ($from, $to)=(@_);
    if ( !-e $from && -e "$from\.exe"){$from="$from\.exe";}
    if ( !-e $from){return 0;}
        
    `$CP $from $to`;
    return 1;
  }
sub check_file_list_exists 
  {
    my ($base, @flist)=(@_);
    my $f;

    foreach $f (@flist)
      {
	if ( !-e "$base/$f"){return 0;}
      }
    return 1;
  }
sub ls
  {
    my $f=@_[0];
    my @fl;
    chomp(@fl=`ls -1 $f`);
    return @fl;
  }
sub flush_command
  {
    my $command=@_[0];
    open (COMMAND, "$command|");
    while (<COMMAND>){print "    --- $_";}
    close (COMMAND);
  }    

sub input_installation_directory
  {
    my $dir=@_[0];
    my $new;
    
    print "------- The current installation directory is: [$dir]\n";
    print "??????? Return to keep the default or new value:";
   
    if ($NO_QUESTION==0)
      {
	chomp ($new=<stdin>);
	while ( $new ne "" && !input_yes ("You have entered $new. Is this correct? ([y]/n):"))
	  {
	    print "???????New installation directory:";
	    chomp ($new=<stdin>);
	  }
	$dir=($new eq "")?$dir:$new;
	$dir=~s/\/$//;
      }
    
    if ( -d $dir){return $dir;}
    elsif (&root_run ("You must be root to create $dir","mkdir $dir")==EXIT_SUCCESS){return $dir;}
    else
      {
	print "!!!!!!! $dir could not be created\n";
	if ( $NO_QUESTION)
	  {
	    return "";
	  }
	elsif ( &input_yes ("??????? Do you want to provide a new directory([y]/n)?:"))
	  {
	    return input_installation_directory ($dir);
	  }
	else
	  {
	    return "";
	  }
      }
    
  }
sub input_yes
  {
    my $question =@_[0];
    my $answer;

    if ($NO_QUESTION==1){return 1;}
    
    if ($question eq ""){$question="??????? Do you wish to proceed ([y]/n)?:";}
    print $question;
    chomp($answer=lc(<STDIN>));
    if (($answer=~/^y/) || $answer eq ""){return 1;}
    elsif ( ($answer=~/^n/)){return 0;}
    else
      {
	return input_yes($question);
      }
  }
sub root_run
  {
    my ($txt, $cmd)=(@_);
    
    if ( system ($cmd)==EXIT_SUCCESS){return EXIT_SUCCESS;}
    else 
      {
	print "------- $txt\n";
	if ( $ROOT eq "sudo"){return system ("sudo $cmd");}
	else {return system ("su root -c \"$cmd\"");}
      }
  }
#analyze environement
sub get_root
  {
    if (&pg_is_installed ("sudo")){return "sudo";}
    else {return "su";}
  }

sub get_os
  {
    my $raw_os=`uname`;

    $raw_os=lc ($raw_os);
    
    if ($raw_os =~/cygwin/){$os="windows";}
    elsif ($raw_os =~/linux/){$os="linux";}
    elsif ($raw_os =~/osx/){$os="macosx";}
    elsif ($raw_os =~/darwin/){$os="macosx";}
    else
      {
	$os=$raw_os;
      }
    return $os;
  }
sub input_os
  {
    my $answer;
    if ($OS) {return $OS;}
    
    print "??????? which os do you use: [w]indows, [l]inux, [m]acosx:?";
    $answer=lc(<STDIN>);

    if (($answer=~/^m/)){$OS="macosx";}
    elsif ( ($answer=~/^w/)){$OS="windows";}
    elsif ( ($answer=~/^linux/)){$OS="linux";}
    
    else
      {
	return &input_os();
      }
    return $OS;
  }

sub supported_os
  {
    my ($os)=(@_[0]);
    return $SUPPORTED_OS{$os};
  }
    
    
################################################################################
#                                                                               #
#                                                                               #
#                                                                               #
#                  update/initialize links                                      #
#                                                                               #
#                                                                               #
#                                                                               #
#################################################################################


sub update_tclinkdb 
  {
    my $file =@_[0];
    my $name;
    
    if ( $file eq "update"){$file=$TCLINKDB_ADDRESS;}
    
    if ( $file =~/http:\/\// || $file =~/ftp:\/\//)
      {
	($address, $name)=($download=~/(.*)\/([^\/]+)$/);
	`rm x $SILENT`;
	if (my_wget ("$file -Ox")==EXIT_SUCCESS)
	  {
	    print "------- Susscessful upload of $name";
	    `mv x $name`;
	    $file=$name;
	  }
      }
    open (F, "$file");
    while (<F>)
      {
	my $l=$_;
	if (($l =~/^\/\//) || ($db=~/^#/)){;}
	elsif ( !($l =~/\w/)){;}
	else
	  {
	    my @v=split (/\s+/, $l);
	    if ( $l=~/^MODE/)
	      {
		$MODE{$v[1]}{$v[2]}=$v{3};
	      }
	    elsif ($l=~/^PG/)
	      {
		$PG{$v[1]}{$v[2]}=$v[3];
	      }
	  }
      }
    close (F);
    &post_process_PG();
    return;
  }



sub initialize_PG
  {
    
#TclinkdbStart start of the tag for updating the list
    #MSA
$PG{t_coffee}{source}="http://wwww.tcoffee.org/Packages/T-Coffee_distribution.tar.gz";
$PG{t_coffee} {language2}="C";
$PG{t_coffee}{update_action}="update";
$PG{t_coffee}{mode}="t_coffee always";

$PG{clustalw2}{source}="http://www.clustal.org/download/2.0.10/clustalw-2.0.10-src.tar.gz";
$PG{clustalw2} {language2}="CXX";
$PG{clustalw2}{mode}="mcoffee rcoffee";

$PG{"dialign-tx"}{source}="http://dialign-tx.gobics.de/DIALIGN-TX_1.0.1.tar.gz";
$PG{"dialign-tx"} {language2}="C";
$PG{"dialign-tx"}{mode}="mcoffee";


$PG{"poa"}{source}="http://downloads.sourceforge.net/poamsa/poaV2.tar.gz";
$PG{"poa"} {language2}="C";
$PG{"poa"}{mode}="mcoffee";

$PG{"probcons"}{source}="http://probcons.stanford.edu/probcons_v1_12.tar.gz";
$PG{"probcons"} {language2}="CXX";
$PG{"probcons"}{mode}="mcoffee";

$PG{mafft}{source}="http://align.bmr.kyushu-u.ac.jp/mafft/software/mafft-6.603-with-extensions-src.tgz";
$PG{mafft}{cygwin}="http://align.bmr.kyushu-u.ac.jp/mafft/software/mafft-6.603-mingw.tar";
$PG{mafft} {language2}="C/CXX";
$PG{mafft}{mode}="mcoffee rcoffee";

$PG{muscle}{source}="http://www.drive5.com/muscle/downloads3.7/muscle3.7_src.tar.gz";
$PG{muscle}{windows}="http://www.drive5.com/muscle/downloads3.52/muscle3.52_win32.zip";
$PG{muscle}{linux}="http://www.drive5.com/muscle/downloads3.6/muscle3.6_linux_ia32.tar.gz";
$PG{muscle} {language2}="GPP";
$PG{muscle}{mode}="rcoffee mcoffee";

$PG{pcma}{source}="ftp://iole.swmed.edu/pub/PCMA/pcma.tar.gz";
$PG{pcma} {language2}="C";
$PG{pcma}{mode}="mcoffee";

$PG{"kalign"}{source}="http://msa.cgb.ki.se/downloads/kalign/current.tar.gz";
$PG{"kalign"} {language2}="C";
$PG{"kalign"}{mode}="mcoffee";

$PG{"amap"}{source}="http://baboon.math.berkeley.edu/amap/download/amap.2.2.tar.gz";
$PG{"amap"} {language2}="CXX";
$PG{"amap"}{mode}="mcoffee";

$PG{"proda"}{source}="http://proda.stanford.edu/proda_1_0.tar.gz";
$PG{"proda"} {language2}="CXX";
$PG{"proda"}{mode}="mcoffee";

$PG{prank}{source}="http://www.ebi.ac.uk/goldman-srv/prank/src/old/prank.src.080715.tgz";
$PG{prank} {language2}="CXX";
$PG{prank}{mode}="mcoffee";

#Protein Structure
$PG{sap}{source}="http://mathbio.nimr.mrc.ac.uk/download/SAP-1.0.0.tgz";
$PG{sap} {language2}="C";
$PG{sap}{mode}="expresso 3dcoffee";

$PG{TMalign}{source}="http://zhang.bioinformatics.ku.edu/TM-align/TMalign.f";
$PG{TMalign}{linux}="http://zhang.bioinformatics.ku.edu/TM-align/TMalign_32.gz";
$PG{TMalign} {language2}="Fortran";
$PG{TMalign}{mode}="expresso 3dcoffee";

$PG{"mustang"}{source}="http://www.cs.mu.oz.au/~arun/mustang/mustang_v.3.tgz";
$PG{"mustang"} {language2}="CXX";
$PG{"mustang"}{mode}="expresso 3dcoffee";

#RNA Structure
$PG{"probconsRNA"}{source}="http://probcons.stanford.edu/probconsRNA.tar.gz";
$PG{"probconsRNA"} {language2}="CXX";
$PG{"probconsRNA"}{mode}="rcoffee";

$PG{"RNAplfold"}{source}="http://www.tbi.univie.ac.at/~ivo/RNA/ViennaRNA-1.7.2.tar.gz";
$PG{"RNAplfold"} {language2}="C";
$PG{"RNAplfold"}{mode}="rcoffee";

#Perl Libraries
$PG{"SOAP::Lite"}{source}="http://www.tbi.univie.ac.at/~ivo/RNA/ViennaRNA-1.7.2.tar.gz";
$PG{"SOAP::Lite"} {language2}="Perl";
$PG{"SOAP::Lite"}{mode}="psicoffee expresso";
#TclinkdbEnd End tag for the list updating

########### Compilers ##############################
#
#

$PG{C}{compiler}="gcc";
$PG{C}{compiler_flag}="CC";
$PG{C}{options}="";
$PG{C}{options_flag}="CFLAGS";
$PG{C}{type}="compiler";

$PG{"CXX"}{compiler}="g++";
$PG{"CXX"}{compiler_flag}="CXX";
$PG{"CXX"}{options}="";
$PG{"CXX"}{options_flag}="CXXFLAGS";
$PG{CXX}{type}="compiler";

$PG{"CPP"}{compiler}="g++";
$PG{"CPP"}{compiler_flag}="CPP";
$PG{"CPP"}{options}="";
$PG{"CPP"}{options_flag}="CPPFLAGS";
$PG{CPP}{type}="compiler";

$PG{"GPP"}{compiler}="g++";
$PG{"GPP"}{compiler_flag}="GPP";
$PG{"GPP"}{options}="";
$PG{"GPP"}{options_flag}="CFLAGS";
$PG{GPP}{type}="compiler";

$PG{Fortran}{compiler}="g77";
$PG{Fortran}{compiler_flag}="FCC";
$PG{Fortran}{type}="compiler";

$PG{Perl}{compiler}="CPAN";
$PG{Perl}{type}="compiler";

$SUPPORTED_OS{macox}="Macintosh";
$SUPPORTED_OS{linux}="Linux";
$SUPPORTED_OS{windows}="Cygwin";



$MODE{t_coffee}{description}=" for regular multiple sequence alignments";
$MODE{rcoffee} {description}=" for RNA multiple sequence alignments";

$MODE{psicoffee} {description}=" for Homology Extended multiple sequence alignments";
$MODE{expresso}{description}=" for very accurate structure based multiple sequence alignments";
$MODE{"3dcoffee"}{description}=" for multiple structure alignments";
$MODE{mcoffee} {description}=" for combining alternative multiple sequence alignment packages\n------- into a unique meta-package. The installer will upload several MSA packages and compile them\n
";


&post_process_PG();
return;
}

sub post_process_PG
  {
    my $p;
    
    %PG=&name2dname (%PG);
    %MODE=&name2dname(%MODE);
    foreach $p (sort (keys(%PG))){if ( $PG{$p}{type} eq "compiler"){$PG{$p}{update_action}="never";}}
    
  }

sub name2dname
  {
    my (%L)=(@_);
    my $l, $ml;
    
    foreach $pg (sort (keys(%L)))
      {
	$l=length ($pg);
	if ( $l>$ml){$ml=$l;}
      }
    $ml+=1;
    foreach $pg (sort (keys(%L)))
      {
	my $name;
	$l=$ml-length ($pg);
	$name=$pg;
	for ( $b=0; $b<$l; $b++)
	  {
	    $name .=" ";
	  }
	$L{$pg}{dname}=$name;
      }
    return %L;
  }

sub env_file2putenv
  {
    my $f=@_[0];
    my $F=new FileHandle;
    my $n;
    
    open ($F, "$f");
    while (<$F>)
      {
	my $line=$_;
	print "******************* $line\n";
	my($var, $value)=($_=~/(\S+)\=(\S+)/);
	$ENV{$var}=$value;
	print "-------------------$var $value\n";
	$n++;
      }
    close ($F);
    return $n;
  }

sub add2env_file
  {
    my ($env, $var, $value)=(@_);
    my $F = new FileHandle;
    my $t;
    #make sure new variables do not get added
    if ( -e $env)
      {
	open ($F, "$env");
	while (<$F>)
	  {
	    
	    my $line=$_;
	    if (!($line=~/$var/)){$t.=$line;}
	  }
	close ($F);
      }
    $t.="$var=$value\n";
    open ($F, ">$env");
    print $F "$t";
    $ENV{$var}=$value;
    close ($F);
  }
    
