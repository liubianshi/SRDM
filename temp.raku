use lib $*PROGRAM.IO.parent.add: 'lib';
use SRDM::Field;

my $test = Field.new(
    :database<database>,
    :table<table>,
    :name<test>,
    :label<测试>,
    :type<string>,
    :number(1000),
    :missing(100),
    :unique(8),
);
say $test.gist(:!header);
 


