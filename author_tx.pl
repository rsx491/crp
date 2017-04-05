#use strict;
#use warnings;
use DBI;
use Data::Dumper;

my %attr = (RaiseError=> 1, HandleError=>\&handle_error);
my $dsn = "DBI:mysql:database=crp;host=localhost;port=3306";
my $dbh = DBI->connect(
	$dsn,
	'username',
	'password',
	\%attr,
) or die $DBI::errstr;

my $input_path = '/home/rsx491/Perl/authors';
my @author_files = &{sub{
	opendir(DIR, $input_path);
	return grep(!/^[.]/,readdir(DIR));
	closedir(DIR);
}}();

foreach(@author_files){
	my $file_name = $_;
	my $file = "$input_path/$file_name";
	open my $in,  '<',  $file      or die "Can't read old file: $!";
	open my $out, '>', "$file.new" or die "Can't write new file: $!";
	
	#print $out "# This file was generated from a script.\n";
	my $book_id = 'na';
	while( <$in> )
    {
		if(/alt="(.+)"/){
			#print "$1\n";
			#print "$file_name $_\n";
			$book_id = get_book_id($dbh, $1);
			#print $out "$file_name found\n";
			#s/\href="#\"/href=\"http:\/\/52\.27\.177\.253\/crp\/index.php?route=product\/product\&product_id=$book_id\"/;
			#s/#/http:\/\/52\.27\.177\.253\/crp\/index.php?route=product\/product\&product_id=$book_id/g;
		}
		
		if($book_id ne 'na'){
			#print "$file_name: $book_id\n";
			#s/"#"/"http:\/\/52\.27\.177\.253\/crp\/index.php?route=product\/product\&product_id=$book_id"/g;
			s/"#"/"http:\/\/shop\.centralrecoverypress\.com\/crp\/index.php?route=product\/product\&product_id=$book_id"/g;
			print $out $_;
		}else{
			print $out $_;
		}
		
		#print "book id: $book_id\n";
    }
	close $out;
}

sub handle_error {
	my $error = shift;
	print "An error occurred in the script\n";
	print "Message: $error\n";
	return 1;
}

sub get_book_id {
	my ($dbh, $book_search) = @_;
	my $sth = $dbh->prepare('SELECT product_id FROM `oc_product_description` WHERE name like ? limit 1');
	$sth->execute('%' . $book_search . '%') or die "Couldn't execute statement: " . $sth->errstr;
	my $product_id = $sth->fetchrow_array();
	return $product_id;
}


