#!/usr/bin/env raku
use v6;
use DBIish;

# 命令行处理 {{{1
# 第一个参数决定子命令
if @*ARGS[0] ∈ <create insert update drop replace view> {
    @*ARGS[0] = "--sub={@*ARGS[0]}";
} else {
    die "The first augment must be create insert update drop view or replace"
}

# 环境变量处理 {{{1
my $data-engine = %*ENV<SRDM_DATA_MANAGER_ENGINE> //
    die "Need set environment variable SRDM_DATA_MANAGER_ENGINE first";
my $data-manager-path = %*ENV<SRDM_DATA_MANAGER_PATH> //
    die "Need set environment variable SRDM_DATA_MANAGER_FILE first";
die "$data-manager-path must be a directore" 
    unless $data-manager-path.IO.d;
die "$data-manager-path must be readable and writable"
    unless $data-manager-path.IO.rw;
my $data-manager-file =
    $data-manager-path.IO.add('variable_description.db').resolve.Str;

# 定义函数 {{{1
sub database-connect() {
    DBIish.connect($data-engine, :database«$data-manager-file»)
}

# 创建数据库 {{{1
multi MAIN (Str:D :$sub! where * eq "create")
{
    my $dbh = database-connect();
    # 数据库表格
    my $sth = $dbh.do(qq:to/CREATE_TABLE/);
        create table if not exists database (
            name            varchar primary key,
            description     varchar,
            path            varchar,
            engine          varchar not null default "$data-engine",
            create_at       timestamp not null default current_timestamp,
            modify_time     timestamp not null default current_timestamp
        )
    CREATE_TABLE
}

# 查询 {{{2
multi MAIN (
    Str:D :$sub! where * eq "view",
    Str   :$database,
    Str   :$table,
    *@query-terms,
) {
    my $dbh = database-connect();
    if none($database, $table) && @query-terms.elems == 0 {
        my $sth = $dbh.prepare(qq:to/STATEMENT/);
            select *
            from database
            STATEMENT
        $sth.execute();
        my @database-all = $sth.allrows();
        say @database-all.join: "\n";
    }
}

# 插入数据 {{{2
multi MAIN (
    Str:D :$sub! where * eq "insert",
    Str:D :$type! where * eq "database",
    Str:D :$name!,
    Str   :$description,
    Str   :$path,
    Str   :$engine,
) {
    my $dbh = database-connect();
    my $sth = $dbh.prepare(q:to/STATEMENT/);
        INSERT INTO database (name, description, path, engine)
        VALUES (?, ?, ?, ?)
    STATEMENT 

    $sth.execute($name, $description // "", $path // "", $engine // $data-engine);
}

# 删除条目 {{{1

# 替换条目 {{{1

