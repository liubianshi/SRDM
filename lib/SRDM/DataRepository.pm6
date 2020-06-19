use DBIish;
use SRDM::DataTable;
use SRDM::DataRecord;

unit class DataRepository;

# constant and regex 常数和正则表达式 {{{1
constant $TABLE         = 'data_table';
constant @TABLE-FIELD   = <name path engine source description script_file
                           script_tag desc_file desc_tag log_file create_at
                           modify_at>;
constant @TABLE-SEARCH  = <name path source>;
constant $RECORD        = 'data_record';
constant @RECORD-FIELD  = <name type source label description number missing
                           unique script_file script_tag desc_file desc_tag
                           log_file create_at modify_at>;
constant @RECORD-SEARCH = <name label path source>;

my regex database-name { ^ $<database> = [\w+] $                        };
my regex table-name    { ^ $<database> = [\w+] ':' $<table> = [\w+] $   };
my regex record-name   { ^ $<database> = [\w+] ':' $<table> = [\w+] ':'
                           $<record>   = [\w+] $                        };

# attributes 对象属性 {{{1
has Str $.data-manager-file is required;
has $!db;

# initiate database 初始化数据库 {{{1
method !create-schema() {
    self!db.do(qq:to/SCHEMA/);
        CREATE TABLE IF NOT EXISTS $TABLE (
            name            VARCHAR PRIMARY KEY,
            path            VARCHAR NOT NULL,
            engine          VARCHAR NOT NULL default "$data-engine",
            source          VARCHAR,
            description     VARCHAR,
            script_file     VARCHAR,
            script_tag      VARCHAR,
            desc_file       VARCHAR,
            desc_tag        VARCHAR,
            log_file        VARCHAR,
            create_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            modify_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        SCHEMA
    self!db.do(qq:to/INDEX/);
        CREATE INDEX IF NOT EXISTS {$TABLE}_name ON
        $TABLE (name);
        INDEX

    self!db.do(qq:to/SCHEMA/);
        CREATE TABLE IF NOT EXISTS $RECORD (
            name            VARCHAR PRIMARY KEY,
            type            VARCHAR NOT NULL,
            source          VARCHAR,
            label           VARCHAR,
            description     VARCHAR,
            number          INT,
            missing         INT,
            unique          INT,
            script_file     VARCHAR,
            script_tag      VARCHAR,
            desc_file       VARCHAR,
            desc_tag        VARCHAR,
            log_file        VARCHAR,
            create_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            modify_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        SCHEMA
    self!db.do(qq:to/INDEX/);
        CREATE INDEX IF NOT EXISTS {$RECORD}_name ON
        $RECORD (name);
        INDEX
}

method !db() {
    return $!db if $!db;
    $!db = DBIish.connect('SQLite', :database($!data-manager-file));
    self!create-schema();
    return $!db;
}

# delete 根据名称删除删除记录或表格 {{{1
method delete(Str:D $name where /<record-name>/ || /<table-name>/,
              Bool:D :$force = False)
{
    my $table = $<table-name>:exists ?? $TABLE !! $RECORD;
    my $item = self!get($name);
    return unless $item;

    if $<record-name>:exists {
        self!db.do(qq:/ DELETE FROME $RECORD where name = $name /);
    } else {
        die "$name is a table, delete with force" unless $force;
        self!db.do(qq:/ DELETE FROME $TABLE where name = $name /);
        self!delete($_.fullname) for $item.records;
    }

    return $item
}

# extract non-empty fields 从记录中提取除名称以外的非空字段 {{{1
sub extract-fields( $item where Table | Record ) {
    my @fields := $item ~~ Table ?? @TABLE-FIELD !! @RECORD-FIELD;
    my %fields;
    for @fields -> $f{
        next if $f eq 'name';
        next unless $item.^look: $f;
        %fields{$f} = $item."$f"();
    }
    return %fields;
}

# get element 根据名称从数据库中获取相应的对象 {{{1
multi method get(Str:D $name where /<database-name>/) {
    my @tables = self!search-name-multi($name);
    return Nil unless @tables;
    @tables = @tables.map: { self!get(%($_)<name>) };
    return @tables;
}

multi method get(Str:D $name where /<table-name>/ --> Table) {
    my %result = self!search-name-unique($name);
    return Nil unless %result;
    my $table = self!result-to-table(%result);
    my @records = self!search-name-multi($name);
    $table.records = @records ?? @records.map({ self!result-to-record(%($_)) }) !! [];
    return $table;
}

multi method get(Str:D $name where /<record-name>/ --> Record) {
    my %result = self!search-name-unique($name);
    return %result ?? self!result-to-record(%result) !! Nil;
}

# insert new item 将对象插入到数据库 {{{1
method insert($item where Table | Record) {
    my $table       = $item ~~ Table ?? $TABLE !! $RECORD;
    my $name        = $item.fullname;
    my %keys-values = extract-fields($item);
    my @keys        = %keys-values.keys;
    my @values      = %keys-values{@keys};

    my $sth = self!db.prepare(qq:to/STATEMENT/);
        INSERT INTO $table (name, {@keys.join(', ')})
        VALUES (?{", ?" x @keys})
        STATEMENT
    $sth.execute($name, |@values);
    self.insert($_) for $item.?records;
    return $item;
}

# replace 用对象替换数据库同名记录 {{{1
method replace($item where Table | Record) {
    my $name      = $item.fullname;
    my $item-old  = self.delete($name, :force);
    return self.insert($item) unless $item-old;
    try {
        self.insert($item);
        CATCH {
            default {
                say "replace unsuccessful";
                self.insert($item-old);
                return Nil;
            }
        }
    }
    return $item-old;
}

# translate result to object 将查询结果转换为数据表或数据记录对象 {{{1
method !result-to-table(%result --> Table) {
    my $name := m/<table-name>/ with %result<name>;
    die "result format is wrong!" unless $name and all %result{@TABLE-FIELD}:exists

    my %attr = @TABLE-FIELD.map: { slip $_, %result{$_} };
    %attr<database> = $names<table-name><database>;
    %attr<name>     = $names<table-name><table>;
    return Table.new(|%attr);
}

method !result-to-record(%result --> Record) {
    my $name := m/<record-name>/ with %result<name>;
    die "result format is wrong!" unless $name and all %result{@RECORD-FIELD}:exists

    my %attr = @RECORD-FIELD.map: { slip $_, %result{$_} };
    %attr<database> = $names<record-name><database>;
    %attr<table>    = $names<record-name><table>;
    %attr<name>     = $names<record-name><record>;
    return Record.new(|%attr);
}

# search result 从数据库中查询 {{{1
method search($filter, Bool :$table = False, Str:D :$where, *%conditions)
{
    if %conditions {
        die "Contain wrong condition set!" unless %conditions.keys ⊆ @RECORD-FIELD;
        $where = [$where].unshift(%condition.map({
            .key ~ " = " ~ (.value.^name eq ''.^name ?? "'{.value}'" !! "{.value}")
        })).join(" AND ");
    }

    my $search-table = $table ?? "$TABLE" !! "$RECORD";
    my $sth = self!db.prepare(« SELECT * FROM $search-table WHERE $where »);
    $sth.execute();
    my @results = $sth.allrows(:array-of-hash);

    my @search-keys  = $table ?? @TABLE-SEARCH !! @RECORD-SEARCH;
    my $filter-regex = /$filter/ unless $filter.isa: Regex;
    return do given @results.grep({any($_{@search-keys}) ~~ $filter-regex}) {
        when $table { .map(&result-to-table)  }
        default     { .map(&result-to-record) }
    }
}

method !search-name-multi(Str:D $name where /<database-name>/ || /<table-name>/) {
    my $table = ($<table-name>:exists) ?? "$TABLE" !! "$RECORD";
    my $sth = self!db.prepare(qq:to/STATEMENT/);
        SELECT * FROM $table WHERE name LIKE {$name}%
        STATEMENT
    $sth.execute();
    my @results := $sth.allrows(:array-of-hash);
    return $results == 0 ?? [] !! @results;
}

method !search-name-unique( Str:D $name where /<record-name>/ || /<table-name>/) {
    my $table = ($<table-name>:exists) ?? "$TABLE" !! "$RECORD";
    my $sth = self!db.prepare(qq:to/STATEMENT/);
        SELECT * FROM $table WHERE name = ?
        STATEMENT
    $sth.execute($name);
    my @result = $sth.allrows(:array-of-hash);
    die "Multi rows!!!" if @result > 1;
    return $result == 0 ?? %() !! %(@result[0]);
}

# update 更新数据库 {{{1
method update($item where Table | Record) {
    my $name        = $item.fullname;
    my $item-old    = self.get($name);
    return self.insert($item) unless $item-old;

    my $table       = $item ~~ Table ?? $TABLE !! $RECORD;
    my %keys-values = extract-fields($item);
    my @update-list;
    for %keys-values.keys -> $k {
        next if $item-old."$k"();
        @update-list.push:
            "$k = " ~ ($_.isa(Str) ?? qq/"$_"/ !! $_) with %keys-values{$k};
    }

    return unless @update-list;
    my $sth = self!db.do(qq:to/STATEMENT/);
        UPDATE $table SET @update-list.join(", ") where name = $name;
        STATEMENT
    self.update($_) for $item.?records;
}


