use strict;
use warnings;
use Text::CSV::Hashify;
use DBI;
use Data::Dumper;

my $input_files = './files';
my $authors_file = $input_files. '/authors.csv';
my $authos_format = 'aoh';
my $book_file = $input_files . '/books.csv';
my $book_format = 'aoh';

my $authors = Text::CSV::Hashify->new({
	file        => $authors_file,
	format      => $authos_format
});
my $books = Text::CSV::Hashify->new({
	file        => $book_file,
	format      => $book_format
});

my @author_photos = &{sub{ 
	opendir(DIR, $input_files. "/author_photos");
	return grep(/\.*$/,readdir(DIR));
	closedir(DIR);
}}();

my $dsn = "DBI:mysql:database=crp;host=localhost;port=3306";
my $dbh = DBI->connect(
						$dsn, 
						'root', 
						'gunslinger',
						{ RaiseError => 1, HandleError=>\&handle_error },
) or die $DBI::errstr;
						
sub handle_error {
    my $error = shift;
    print "An error occurred in the script\n";
    print "Message: $error\n";
    return 1;
}

my $clean_sql = [
				"delete from oc_product;",
				"delete from oc_product_attribute;",
				"delete from oc_product_description;",
				"delete from oc_product_discount;",
				"delete from oc_product_filter;",
				"delete from oc_product_image;",
				"delete from oc_product_option;",
				"delete from oc_product_option_value;",
				"delete from oc_product_recurring;",
				"delete from oc_product_related;",
				"delete from oc_product_reward;", 
				"delete from oc_product_special;",
				"delete from oc_product_to_author;",
				"delete from oc_product_to_category;",
				"delete from oc_product_to_download;",
				"delete from oc_product_to_layout;",
				"delete from oc_product_to_store;",
				"delete from oc_author;",
				"delete from oc_author_description;",
				"delete from oc_author_description;",
				"delete from oc_author_attribute;",
				"delete from oc_author_to_store;",
				"delete from oc_author_to_layout;"
				];
				
foreach (@{$clean_sql}){
	print "$_\n";
	my $q_clean_sql = $dbh->prepare($_);
	$q_clean_sql->execute();
	$q_clean_sql->finish;
}

my $product = $dbh->prepare("INSERT INTO oc_product (page, model, price, isbn, book_language, stock_status_id, quantity, status,
format) 
							VALUES(?,?,?,?,?,?,?,?,?)");
my $product_description = $dbh->prepare("INSERT INTO oc_product_description (product_id, language_id, name, description, meta_title, meta_description) 
							VALUES(?,?,?,?,?,?)");
my $product_cat = $dbh->prepare("INSERT INTO oc_product_to_category (product_id, category_id) 
							VALUES(?,?)");						
my $product_store = $dbh->prepare("INSERT INTO oc_product_to_store (product_id) 
							VALUES(?)");							
my $author = $dbh->prepare("INSERT INTO oc_author (status, image) 
							VALUES(?,?)");							
my $author_description = $dbh->prepare("INSERT INTO oc_author_description (author_id, language_id, name, description) 
							VALUES(?,?,?,?)");							
my $product_author = $dbh->prepare("INSERT INTO oc_product_to_author (product_id, author_id) 
							VALUES(?,?)");							
my $author_store = $dbh->prepare("INSERT INTO oc_author_to_store (author_id, store_id) 
							VALUES(?,?)");

my %authors;							
foreach my $amap (@{$authors->all}) {
	$authors{$amap->{'First Name'}} = $amap->{'Author Bio'};
}

foreach my $auth (sort keys %authors){
	if($auth ne ''){
		my $auth_check_query = "SELECT author_id FROM oc_author_description WHERE name like \'%" . $auth . "%\'";
		my $auth_check_sth = $dbh->prepare($auth_check_query);
		$auth_check_sth->execute();
		my $author_photo;
		foreach my $photo (@author_photos){
			if($photo =~ m/$auth/ig){
				$author_photo = "catalog/$photo";
			}
		}
		
		if($auth_check_sth->rows == 0){
			$author->execute(
				my $status = '1',
				$author_photo
			);
			my $author_id = $dbh->last_insert_id(undef, undef, qw/oc_author/, undef) or die "no insert id?";
			$author_description->execute(
				$author_id,
				my $author_desc_language_id = '1',
				$auth,
				$authors{$auth}
			);
			$author_store->execute(
				$author_id,
				my $store_id = '0'
			);
		}
	}
}

foreach my $bmap (@{$books->all}) {
	my $price = $bmap->{'Price'};
	$price =~ s/\$//gi;
	
	if($bmap->{'Title'} ne ''){
		#print "$bmap->{'Page'},$bmap->{'Title'} $bmap->{'Subtitle'},$price,$bmap->{'ISBN 13'},'1','6','1','1'\n";
		$product->execute(
			$bmap->{'Page'},
			"$bmap->{'Title'} $bmap->{'Subtitle'}",
			$price,
			$bmap->{'ISBN 13'},
			my $product_language_id = '1',
			my $stock_status = '6',
			my $quantity = '1',
			my $status = '1',
			$bmap->{'Format'},
		);
		my $product_id = $dbh->last_insert_id(undef, undef, qw/oc_product/, undef) or die "no insert id?";
		$product_description->execute(
			$product_id,
			my $product_desc_language_id = '1',
			"$bmap->{'Title'} $bmap->{'Subtitle'}",
			"$bmap->{'About the Book'} <br><br> $bmap->{'Sales Handle'}",
			"$bmap->{'Title'} $bmap->{'Subtitle'}",
			"$bmap->{'About the Book'} $bmap->{'Sales Handle'}"
		);
		$product_cat->execute(
			$product_id,
			my $category_id = '57'
		);
		$product_store->execute(
			$product_id
		);
		
		my $auth_check_query = "SELECT author_id FROM oc_author_description WHERE name like \'%" . $bmap->{'Author 1'} . "%\'";
		my $auth_check_sth = $dbh->prepare($auth_check_query);
		$auth_check_sth->execute();
		my @author_ids = $auth_check_sth->fetchrow_array();
		my $author_id = $author_ids[0];
		if(defined($author_id)){
			$product_author->execute(
				$product_id,
				$author_id
			);
		}
	}
}

=comment
foreach my $map (@{$books->all}) {
	print "title: $map->{'Title'}\n";
}
=comment
