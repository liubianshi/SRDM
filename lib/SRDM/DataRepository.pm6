use DBIish;
use SRDM::DataTable;
use SRDM::DataRecord;

unit class DataRepository;

# constant and regex 常数和正则表达式 {{{1
our constant $TABLE         = 'data_table';
our constant @TABLE-FIELD   = <name keys path engine source description script_file
                               script_tag desc_file desc_tag log_file create_at
                               modify_at>;
our constant @TABLE-SEARCH  = <name keys path source>;
our constant $RECORD        = 'data_record';
our constant @RECORD-FIELD  = <name type source label description number missNumber
                               uniqueNumber script_file script_tag desc_file desc_tag
                               log_file create_at modify_at>;
our constant @RECORD-SEARCH = <name label path source>;

our regex database-name { ^ $<database> = [\w+] $                        };
our regex table-name    { ^ $<database> = [\w+] ':' $<table> = [\w+] $   };
our regex record-name   { ^ $<database> = [\w+] ':' $<table> = [\w+] ':'
                            $<record>   = [\w+] $                        };

# attributes 对象属性 {{{1
has Str $.dataRepoFile is required;
has $!db;

# initiate database 初始化数据库 {{{1
method !create-schema() {
    self!db.do(qq:to/SCHEMA/);
        CREATE TABLE IF NOT EXISTS $TABLE (
            name            VARCHAR PRIMARY KEY,
            keys            VARCHAR NOT NULL,
            path            VARCHAR NOT NULL,
            engine          VARCHAR NOT NULL DEFAULT "SQLite3",
            source          VARCHAR,
            description     VARCHAR,
            script_file     VARCHAR,
            script_tag      VARCHAR,
            desc_file       VARCHAR,
            desc_tag        VARCHAR,
            log_file        VARCHAR,
            create_at       TIMESTAMP NOT NULL DEFAULT (DATETIME('NOW', 'LOCALTIME')),
            modify_at       TIMESTAMP NOT NULL DEFAULT (DATETIME('NOW', 'LOCALTIME'))
        );
        SCHEMA

    self!db.do(qq:to/INDEX/);
        CREATE INDEX IF NOT EXISTS {$TABLE}_name ON
        $TABLE (name);
        INDEX

    self!db.do(qq:to/SCHEMARECORD/);
        CREATE TABLE IF NOT EXISTS $RECORD (
            name         VARCHAR PRIMARY KEY,
            type         VARCHAR NOT NULL,
            source       VARCHAR NOT NULL DEFAULT 'unknown',
            label        VARCHAR NOT NULL,
            description  VARCHAR,
            number       INTEGER,
            missNumber   INTEGER,
            uniqueNumber INTEGER,
            script_file  VARCHAR,
            script_tag   VARCHAR,
            desc_file    VARCHAR,
            desc_tag     VARCHAR,
            log_file     VARCHAR,
            create_at    TIMESTAMP NOT NULL DEFAULT (DATETIME('NOW', 'LOCALTIME')),
            modify_at    TIMESTAMP NOT NULL DEFAULT (DATETIME('NOW', 'LOCALTIME'))
        );
        SCHEMARECORD

    self!db.do(qq:to/INDEX/);
        CREATE INDEX IF NOT EXISTS {$RECORD}_name ON
        $RECORD (name);
        INDEX
}

method !db() {
    return $!db if $!db;
    $!db = DBIish.connect('SQLite', :database($!dataRepoFile));
    self!create-schema();
    return $!db;
}

# delete 根据名称删除删除记录或表格 {{{1
method delete(Str:D $name where /<record-name>/ || /<table-name>/,
              Bool:D :$force = False)
{
    my $table = $<table-name>:exists ?? $TABLE !! $RECORD;
    my $item = self.get($name);
    return Nil unless $item;

    if $<table-name>:exists {
        die "$name is a table, delete with force" unless $force;
        self.delete($_.fullname) for $item.records;
    }
    my $sth = self!db.prepare(qq/DELETE FROM $table where name = ?/);
        $sth.execute($name);
    return $item
}

# extract non-empty fields 从记录中提取除名称以外的非空字段 {{{1
sub extract-fields( $item where Table | Record ) {
    my @fields := $item ~~ Table ?? @TABLE-FIELD !! @RECORD-FIELD;
    my %fields;
    for @fields -> $f {
        next if $f eq 'name';
        next unless $item."$f"().defined;
        %fields{$f} = $item."$f"();
    }
    return %fields;
}

# get element 根据名称从数据库中获取相应的对象 {{{1
multi method get(Str:D $name where /<database-name>/) {
    my @tables = self!search-name-multi($name);
    return Nil unless @tables;
    @tables = @tables.map: { self.get(%($_)<name>) };
    return @tables;
}

multi method get(Str:D $name where /<table-name>/ --> Table) {
    my %result = self!search-name-unique($name);
    return Nil unless %result;
    my $table = result-to-table(%result);
    my @records = self!search-name-multi($name);
    $table.records = @records ?? @records.map({ result-to-record(%($_)) }) !! [];
    return $table;
}

multi method get(Str:D $name where /<record-name>/ --> Record) {
    my %result = self!search-name-unique($name);
    return %result ?? result-to-record(%result) !! Nil;
}

# insert new item 将对象插入到数据库 {{{1
method insert($item where Table | Record) {
    my $table       = $item ~~ Table ?? $TABLE !! $RECORD;
    my $name        = $item.fullname;
    my %keys-values = extract-fields($item);
    my @keys        = %keys-values.keys;
    my @values      = %keys-values{@keys};

    # 在插入普通记录时，先确定表格是否存在
    if $item ~~ Record {
        my $table-name = $item.database ~ ":" ~ $item.table;
        my $table-item = self.get($table-name);
        die "$table-name is not exists, please insert $table-name first!" unless $table-item;
    }

    my $sth = self!db.prepare(qq:to/STATEMENT/);
        INSERT INTO $table (name, {@keys.join(', ')})
        VALUES (?{", ?" x @keys})
        STATEMENT
    $sth.execute($name, |(@values».Str));

    if $item ~~ Table {
        self.insert($_) for $item.?records;
    }
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
sub result-to-table(%result --> Table) {
    my $name := m/<table-name>/ with %result<name>;
    die "result format is wrong!"
        unless $name && all %result{@TABLE-FIELD}:exists;
    my %attr;
    %attr<database> = $name<table-name><database>.Str;
    %attr<name>     = $name<table-name><table>.Str;
    for @TABLE-FIELD -> $f {
        next if $f eq 'name';
        with %result{$f} {
            if $f eq 'create_at'|'modify_at' {
                %attr{$f} = DateTime.new: .subst(' ', 'T'), :timezone(28800);
            } else {
                %attr{$f} = $_ with %result{$f};
            }
        }
    }
    return Table.new(|%attr);
}

sub result-to-record(%result --> Record) {
    my $name := m/<record-name>/ with %result<name>;
    die "result format is wrong!"
        unless $name and all %result{@RECORD-FIELD}:exists;
    my %attr;
    %attr<database> = $name<record-name><database>.Str;
    %attr<table>    = $name<record-name><table>.Str;
    %attr<name>     = $name<record-name><record>.Str;
    for @RECORD-FIELD -> $f {
        next if $f eq 'name';
        with %result{$f} {
            if $f eq 'create_at'|'modify_at' {
                %attr{$f} = DateTime.new: .subst(' ', 'T'), :timezone(28800);
            } else {
                %attr{$f} = $_ with %result{$f};
            }
        }
    }
    return Record.new(|%attr);
}

# search result 从数据库中查询 {{{1
method search(*@names, :$filter, Bool :$table = False, Str :$where, *%conditions)
{
    my $search-table = $table ?? "$TABLE" !! "$RECORD";
    my ($con, @keys, @values, $sth);

    if %conditions {
        die "Contain wrong condition set!" unless
            ($table && %conditions.keys ⊆ @TABLE-FIELD) ||
            (!$table && %conditions.keys ⊆ @RECORD-FIELD);
        @keys   = %conditions.keys;
        @values = %conditions{@keys};
        $con    = @keys.map({$_ ~ " = ?"}).join(" AND ");
        $con ~= " AND " ~ $_ with $where;
        $sth = self!db.prepare(qq:to/SELECT/);
            SELECT * FROM $search-table WHERE $con --case-insensitive;
            SELECT
        $sth.execute(|@values);
    } else {
        $sth = self!db.prepare(qq:to/SELECT/);
            SELECT * FROM $search-table
                {$where ?? "WHERE $where" !! ''} --case-insensitive
            SELECT
        $sth.execute;
    }

    my @results = $sth.allrows(:array-of-hash);

    if $filter {
        my @search-keys  = $table ?? @TABLE-SEARCH !! @RECORD-SEARCH;
        my $filter-regex = $filter.isa(Regex) ?? $filter !! /<$filter>/;
        my @temp = @results.grep: {
            so any $_{@search-keys}.grep(?*).map({ $_ ~~ $filter-regex })
        }
        @results = @temp;
    }

    if @names {
        my @temp = @results.grep: { so $_<name>.contains(any(@names), :i) }
        @results = @temp;
    }

    return do given @results {
        when $table { .map(&result-to-table)  }
        default     { .map(&result-to-record) }
    }
}

method !search-name-multi(Str:D $name where /<database-name>/ || /<table-name>/) {
    my $table = ($<database-name>:exists) ?? "$TABLE" !! "$RECORD";
    my $sth = self!db.prepare(qq:to/STATEMENT/);
        SELECT * FROM $table WHERE name LIKE ?
        STATEMENT
    $sth.execute("{$name}%");
    my @results = $sth.allrows(:array-of-hash);
    return @results == 0 ?? [] !! @results;
}

method !search-name-unique(
    Str:D $name where /<record-name>/ || /<table-name>/
) {
    my $table = ($<table-name>:exists) ?? "$TABLE" !! "$RECORD";
    my $sth = self!db.prepare(qq:to/STATEMENT/);
        SELECT * FROM $table WHERE name = ?
        STATEMENT
    $sth.execute($name);
    my @result = $sth.allrows(:array-of-hash);
    die "Multi rows!!!" if @result > 1;
    return @result == 0 ?? %() !! %(@result[0]);
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
        next if $item-old."$k"().defined;
        @update-list.push:
            "$k = " ~ ($_.isa(Str) ?? qq/"$_"/ !! $_) with %keys-values{$k};
    }

    return unless @update-list;
    my $sth = self!db.do(qq:to/STATEMENT/);
        UPDATE $table SET @update-list.join(", ") where name = $name;
        STATEMENT
    self.update($_) for $item.?records;
}

# test {{{1
method test {
    my $sth = self!db.prepare(qq:to/TEST/);
    SELECT * FROM $RECORD;
    TEST
    $sth.execute;
    my @results = $sth.allrows(:array-of-hash);
    for @results -> %r {
        say "=" x 45;
        for @RECORD-FIELD -> $key {
            say sprintf "%-12s %-30s", "$key", "$_" with %r{$key};
        }
    };
}
