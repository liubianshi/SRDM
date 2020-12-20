#!/usr/bin/env raku
use v6;
use lib </home/liubianshi/Repositories/SRDM/lib>;
use SRDM::DataRepository;
use SRDM::DataTable;
use SRDM::DataRecord;

# 提取子命令 {{{1
my $sub-commands := <insert update delete replace view get search export test file>;
@*ARGS[0] = "--sub={@*ARGS[0]}" if @*ARGS[0] ∈ $sub-commands;

# 环境变量处理 {{{1
my $dataRepoPath = %*ENV<SRDM_DATA_REPO_PATH> // $*HOME.add('Documents').add('SRDM');
my $dataRepoFile = $dataRepoPath.IO.add('srdm_dataRepo.sqlite').resolve.Str;
my $data-repo = DataRepository.new(:$dataRepoFile);
our $default-engine = "SQlite3";

our regex database-name { ^ $<database> = [\w+] $                        };
our regex table-name    { ^ $<database> = [\w+] ':' $<table> = [\w+] $   };
our regex record-name   { ^ $<database> = [\w+] ':' $<table> = [\w+] ':'
                            $<record>   = [\w+] $                        };

# insert one records {{{1
sub insert(Str :$name! where /<table-name>/ || /<record-name>/, *%fields) {
    my $item = do if $<table-name>:exists {  # 插入的记录是表格的情况
        die "When inserting a table, primary keys are necessary!" unless %fields<keys>;
        my $database = $<table-name><database>.Str;
        my $name     = $<table-name><table>.Str;
        my $keys     = %fields<keys>;
        my $engine   = %fields<engine> // $default-engine;
        my $path     = do with %fields<path> {
            die "database filename error!"
                unless .IO.basename ~~ /^ <$database> [\.\w+]? $/;
            $_;
        } else {
            with $*ENV<DATA_ARCHIVE> { .IO.add($database ~ ".sqlite").Str }
            else { %*ENV<HOME>.IO.add("DATA").add("DBMS").add($database ~ ".sqlite").Str }
        };
        say $path.raku;
        Table.new(:$database, :$name, :$keys, :$path, :$engine)
    } else {
        my $database = $<record-name><database>.Str;
        my $table    = $<record-name><table>.Str;
        my $name     = $<record-name><record>.Str;
        Record.new(:$database, :$table, :$name);
    }

    for %fields.keys -> $k {
        next if $k ∈ <database name keys path engine records>;
        next unless $k ∈ $item.all-fields;
        if ($k ∈ <number missNumber uniqueNumber>) {
            $item."$k"() = %fields{$k}.Int;
        } else {
            $item."$k"() = %fields{$k}
        }

    }

    $data-repo.insert($item);
    $item.say;
}


# 主函数——插入单条记录 {{{1
multi MAIN (
    Str :$sub   where * eq 'insert',
    Str :$name! where /<table-name>/ || /<record-name>/,
    *%fields
) {
    insert(:$name, |%fields);
}

# 主函数——插入文件记录 {{{1
multi MAIN (IO(Str) $file, Str :$sub where * eq 'file', :$replace = False) {
    my @records = gather for $file.lines -> $l {
        take $<attr>.split("\x[06]").map({ slip $_.split("\x[02]") }).Hash
            if $l ~~ /^\s* srdm\t$<attr> = [.*] $/;
    }

    for @records -> %r {
        say %r<name>.raku;
        my $exits-item = $data-repo.get(%r<name>);
        with $exits-item {
            die "%r<name> records already exits! Using '--replace'" unless $replace;
            my $delete-item = $data-repo.delete($exits-item.fullname, :force);
            try {
                insert(|%r);
                CATCH {
                    default {
                        say "Uncaught exception {.^name}";
                        $data-repo.insert($delete-item);
                    }
                }
            }
        } else {
            insert(|%r);
        }
    }
}


# 删除记录 {{{1
multi MAIN (
    Str:D :$sub where * eq 'delete',
    *@names,
    Bool :$table = False,
    :$filter,
    Str :$where,
    *%conditions,
) {
    my @delete-items;
    if @names {
        @delete-items.push: $data-repo.get($_) for @names;
    } else {
        @delete-items.push:
            slip $data-repo.search(:$table, :$filter, :$where, |%conditions)
    }
    return unless @delete-items;
    $_.des for @delete-items;
    my $confirm = prompt "confirm to delete the above records (y/n): ";
    return unless $confirm eq 'y'|'Y' ;
    $data-repo.delete(.fullname, :force) for @delete-items;
}

# 测试 {{{1
multi MAIN(Str:D :$sub where * eq 'test') {
    $data-repo.test;
}


# 查询并显示记录 {{{1
multi MAIN (Str:D :$sub where * eq 'search', *@names,
    Str  :$mode where any(<detail name-only oneline>) = 'detail',
    Str  :$output-file,
    Str  :$output-format where any(<json csv>) = 'json',
    Bool :$table = False,
    :$filter,
    Str :$where,
    *%conditions,
) {
    my @matched-items = $data-repo.search(
        |@names, :$table, :$filter, :$where, |%conditions);
    return unless any @matched-items;

    given $mode {
        when 'name-only' { .fullname.say for @matched-items }
        when 'detail'    { .say          for @matched-items }
        when 'oneline'   { .des          for @matched-items }
        default          { say "invalid mode"               }
    }

    if $output-file {
        my @matched-items-hash = @matched-items.map: *.Hash;
        given $output-format {
            when 'json'      { ... }
            when 'csv'       { ... }
            when 'table'     { ... }
            when 'markdown'  { ... }
            when 'pandoc'    { ... }
            default          { say "invalid output format" }
        }
    }
}

