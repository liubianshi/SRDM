use DBIish;
unit class DataRepository;

# constant and regex {{{1
constant $TABLE           = 'data_table';
constant $VARIABLE        = 'data_variable';
constant @TABLE-FIELD     = <name path engine source description script_file
                             script_tag desc_file desc_tag log_file create_at
                             modify_time>;
constant @VARIABLE-FIELD  = <name type source label description nubmer missing
                             unique script_file script_tag desc_file desc_tag
                             log_file create_at modify_time>;
constant @TABLE-SEARCH    = <name path source>;
constant @VARIABLE-SEARCH = <name label path source>;

my regex database-name { ^ $<database> = [\w+] $ };
my regex table-name { ^ $<database> = [\w+] ':' $<table> = [\w+] $ };
my regex variable-name { ^ $<database> = [\w+] ':' $<table> = [\w+] ':' $<variable> = [\w+] $ };

# attributes {{{1
has Str $.data-manager-file is required;
has $!db;

# initiate database {{{1
method !create-schema() {
    $!db.do(qq:to/SCHEMA/);
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
            modify_time     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        SCHEMA
    $!db.do(qq:to/INDEX/);
        CREATE INDEX IF NOT EXISTS {$TABLE}_name ON
        $TABLE (name);
        INDEX

    $!db.do(qq:to/SCHEMA/);
        CREATE TABLE IF NOT EXISTS $VARIABLE (
            name            VARCHAR PRIMARY KEY,
            type            VARCHAR NOT NULL,
            source          VARCHAR,
            label           VARCHAR,
            description     VARCHAR,
            nubmber         INT,
            missing         INT,
            unique          INT,
            script_file     VARCHAR,
            script_tag      VARCHAR,
            desc_file       VARCHAR,
            desc_tag        VARCHAR,
            log_file        VARCHAR,
            create_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            modify_time     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        SCHEMA
    $!db.do(qq:to/INDEX/);
        CREATE INDEX IF NOT EXISTS {$VARIABLE}_name ON
        $VARIABLE (name);
        INDEX
}

method !db() {
    return $!db if $!db;
    $!db = DBIish.connect('SQLite', :database($.data-manager-file));
    self!create-schema();
    return $!db;
}

# get element {{{1
multi method get(Str:D $name where /<database-name>/) {
    my @tables = self!search-name-multi($name);
    return Nil unless @tables;
    @tables = @tables.map: { self!get-table(%($_)<name>) };
    return @tables;
}

multi method get(Str:D $name where /<table-name>/ --> Table) {
    my %result = self!search-name-unique($name);
    return Nil unless %result;
    my $table = self!result-to-table(%result);
    my @fields = self!search-name-multi($name);
    $table.fields = @fields ?? @fields.map({ self!result-to-variable(%($_)) }) !! [];
    return $table;
}

multi method get(Str:D $name where /<variable-name>/ --> Variable) {
    my %result = self!search-name-unique($name);
    return %result ?? self!result-to-variable(%result) !! Nil;
}

# translate result to object {{{1
method !result-to-table(%result --> Table) {
    my $name := m/<table-name>/ with %result<name>;
    die "result format is wrong!" unless $name and all %result{@TABLE-FIELD}:exists

    my %attr = @TABLE-FIELD.map: { slip $_, %result{$_} };
    %attr<database> = $names<table-name><database>;
    %attr<name>     = $names<table-name><table>;
    return Table.new(|%attr);
}

method !result-to-variable(%result --> Variable) {
    my $name := m/<variable-name>/ with %result<name>;
    die "result format is wrong!" unless $name and all %result{@VARIABLE-FIELD}:exists

    my %attr = @VARIABLE-FIELD.map: { slip $_, %result{$_} };
    %attr<database> = $names<variable-name><database>;
    %attr<table>    = $names<variable-name><table>;
    %attr<name>     = $names<variable-name><variable>;

    return Variable.new(|%field);
}

# search result {{{1
method !search-name-multi(Str:D $name where /<database-name>/ || /<table-name>/) {
    my $table = ($<table-name>:exists) ?? "$TABLE" !! "$VARIABLE";
    my $sth = $!db.prepare(qq:to/STATEMENT/);
        SELECT * FROM $table WHERE name LIKE {$name}%
        STATEMENT
    $sth.execute();
    my @results := $sth.allrows(:array-of-hash);
    return $results == 0 ?? [] !! @results;
}

method !search-name-unique( Str:D $name where /<variable-name>/ || /<table-name>/) {
    my $table = ($<table-name>:exists) ?? "$TABLE" !! "$VARIABLE";
    my $sth = $!db.prepare(qq:to/STATEMENT/);
        SELECT * FROM $table WHERE name = ?
        STATEMENT
    $sth.execute($name);
    my @result = $sth.allrows(:array-of-hash);
    die "Multi rows!!!" if @result > 1;
    return $result == 0 ?? %() !! %(@result[0]);
}

method !search($filter, Bool :$table = False, Str:D :$where, *%conditions)
{
    if %conditions {
        die "Contain wrong condition set!" unless %conditions.keys ⊆ @VARIABLE-FIELD;
        $where = [$where].unshift(%condition.map({
            .key ~ " = " ~ (.value.^name eq ''.^name ?? "'{.value}'" !! "{.value}")
        })).join(" AND ");
    }

    my $search-table = $table ?? "$TABLE" !! "$VARIABLE";
    my $sth = $!db.prepare(« SELECT * FROM $search-table WHERE $where »);
    $sth.execute();
    my @results = $sth.allrows(:array-of-hash);

    my @search-keys  = $table ?? @TABLE-SEARCH !! @VARIABLE-SEARCH;
    my $filter-regex = /$filter/ unless $filter.isa: Regex;
    return do given @results.grep({any($_{@search-keys}) ~~ $filter-regex}) {
        when $table { .map(&result-to-table)    }
        default     { .map(&result-to-variable) }
    }
}

# insert new item {{{1
multi method !insert(Table:D $table-item, Bool :$update = False, Bool :$replace = False)
{
    my $name   = $table-item.fullname;
    my %keys-values = @TABLE-FIELD.map: {
        slip $_, $table-item."$_"() if $_ ne 'name' and $table-item."$_"();
    }

    my $table-old = self.get($name);
    if $table-old {
        die "record already exists!" unless $update || $replace;
        if $replace {
            my $sth-del = $!db.do(qq:to/STATEMENT/);
                DELETE FROM $TABLE WHERE

            my $sth = $!db.prepare(qq:to/STATEMENT/);
                INSERT INTO $TABLE ({@TABLE-FIELD.join(", ")})
                VALUES ({('?' xx @TABLE-FIELD).join(", ")})
                STATEMENT
            my $sth.execute(|@values);
        }
        if $update {
            my @update-columns;
            for %keys-values.keys.grep({ !$table-old."$k"() }) -> $k {
                @update-columns.push:
                    "$_ =" ~ ($_.isa(Str) ?? qq/"$_"/ !! $_) with %keys-values{$k}
            }
            return unless @set-columns;
            my $sth = $!db.do(qq:to/STATEMENT/);
                UPDATE $TABLE SET @update.join(", ") where name = $name;
                STATEMENT
        }
    }

    my @values = @TABLE-FIELD.map: { $_ eq "name" ?? $name !! $table-item."$_"() }
}

multi !insert(Table $table-item) {
    my $name   = $table-item.fullname;
    my %keys-values = @TABLE-FIELD.map: {
        slip $_, $table-item."$_"() if $_ ne 'name' and $table-item."$_"();
    }
    my @keys   = %keys-values.keys;
    my @values = %keys-values{@keys};

    my $sth = $!db.do(qq:to/STATEMENT/);
        INSERT INTO $TABLE (name, {@keys.join(', ')})
        VALUES ($name, {@values.join(", ")})
        STATEMENT

    if $table-item.variables {
        $table-item.variables.map: { self!insert($_) };
    }
}

multi !update(Table $table-item) {
    my $name   = $table-item.fullname;
    my $table-old = self.get($name);
    return self!insert($table-item) unless $table-old;

    my %keys-values = @TABLE-FIELD.map: {
        slip $_, $table-item."$_"() if $_ ne 'name' and $table-item."$_"();
    }
    my @update-columns;
    for %keys-values.keys.grep({ !$table-old."$k"() }) -> $k {
        @update-columns.push:
            "$_ =" ~ ($_.isa(Str) ?? qq/"$_"/ !! $_) with %keys-values{$k}
    }

    return unless @set-columns;
    my $sth = $!db.do(qq:to/STATEMENT/);
        UPDATE $TABLE SET @update-columns.join(", ") where name = $name;
        STATEMENT

    if $table-item.variables {
        $table-item.variables.map: { self!updat($_) };
    }

}



