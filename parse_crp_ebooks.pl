use strict;
use warnings;
use Text::CSV::Hashify;
use DBI;
use Data::Dumper;

my $input_files = '.';
my $ebooks_file = $input_files. '/crp_ebook_csv.csv';
my $ebooks_format = 'aoh';

my $ebooks = Text::CSV::Hashify->new({
	file        => $ebooks_file,
	format      => $ebooks_format
});

#print Dumper $ebooks->{'all'};

my %attr = ( RaiseError=> 1,  # error handling enabled 
	HandleError=>\&handle_error);

my $dsn = "DBI:mysql:database=crp;host=localhost;port=3306";
my $dbh = DBI->connect(
						$dsn, 
						'root', 
						'gunslinger',
						\%attr,
) or die $DBI::errstr;

sub handle_error {
    my $error = shift;
    print "An error occurred in the script\n";
    print "Message: $error\n";
    return 1;
}

sub authors{
	my ($author_name) = @_;
	if($author_name){
		my $sth = $dbh->prepare('SELECT author_id FROM oc_author_description WHERE name like ?');
		$sth->execute('%' . $author_name . '%') 
            or die "Couldn't execute statement: " . $sth->errstr;
        my ($author_id) = $sth->fetchrow_array();
		return $author_id;
	}else{
		return undef;
	}
}

sub downloads{
	my ($title) = @_;
	my $sth = $dbh->prepare('SELECT download_id FROM oc_download_description WHERE name like ?');
	$sth->execute('%' . $title . '%') 
		or die "Couldn't execute statement: " . $sth->errstr;
	my ($download_id) = $sth->fetchrow_array();
	return $download_id;
}

my $product = $dbh->prepare("INSERT INTO oc_product (model, price, isbn, book_language, stock_status_id, status,
format, quantity, shipping) 
							VALUES(?,?,?,?,?,?,?,?,?)");
my $product_description = $dbh->prepare("INSERT INTO oc_product_description (product_id, language_id, name, description, meta_title, meta_description) 
							VALUES(?,?,?,?,?,?)");					
my $product_store = $dbh->prepare("INSERT INTO oc_product_to_store (product_id) 
							VALUES(?)");
my $product_author = $dbh->prepare("INSERT INTO oc_product_to_author (product_id, author_id) 
							VALUES(?,?)");
my $product_download = $dbh->prepare("INSERT INTO oc_product_to_download (product_id, download_id) 
							VALUES(?,?)");

foreach(@{$ebooks->all}){
	my @authors;
	my $download_id;
	my $product_id;
	
	push(@authors, authors($_->{'Author 1'})) if(defined);
	push(@authors, authors($_->{'Author 2'})) if(defined);
	push(@authors, authors($_->{'Author 3'})) if(defined);
	$download_id = downloads($_->{'Title'}) if(defined);
	
	my $ebook_price = $_->{'e book price'};
	$ebook_price =~ s/\$//g;
	my $ebook_description = $_->{'Description'};
	
	$product->execute(
		"$_->{'Title'} $_->{'Subtitle'}",
		$ebook_price,
		$_->{'ebook ISBN 13'},
		my $product_language_id = '1',
		my $stock_status = '7',
		my $status = '1',
		my $format = 'E Book',
		my $quantity = 999,
		my $shipping = 0
	);
	
	my $product_insert_id = $dbh->last_insert_id(undef, undef, qw/oc_product/, undef) or die "no insert id?";
	$product_description->execute(
		$product_insert_id,
		my $product_desc_language_id = '1',
		"$_->{'Title'} $_->{'Subtitle'}",
		$ebook_description,
		"E Book $_->{'Title'} $_->{'Subtitle'}",
		"E Book $_->{'Title'} $_->{'Subtitle'}"
	);
	
	$product_store->execute(
		$product_insert_id
	);
	
	foreach(@authors){
		if(defined($_)){
			$product_author->execute(
				$product_insert_id,
				my $author_id = $_
			);
		}
	}
	
	if(defined($download_id)){
		$product_download->execute(
			$product_insert_id,
			$download_id
		);
	}
}

$dbh->disconnect();
