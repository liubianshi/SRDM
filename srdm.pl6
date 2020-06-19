#!/usr/bin/env raku
use v6;
use SRDM::DataRepository;
use SRDM::DataTable;
use SRDM::DataRecord;


# 提取子命令 {{{1
my $sub-commands := <insert update delete replace view get search export>;
@*ARGS[0] = "--sub={@*ARGS[0]}" if @*ARGS[0] ∈ $sub-commands;

# 环境变量处理 {{{1
my $dataEngine := %*ENV<SRDM_DATA_MANAGER_ENGINE> // 'SQLite';
my $dataRepoPath = %*ENV<SRDM_DATA_REPO_PATH> // 
    $*HOME.add('Documents').add('SRDM');
die "$data-manager-path must be a directore" 
    unless $data-manager-path.IO.d;
die "$data-manager-path must be readable and writable"
    unless $data-manager-path.IO.rw;
my $data-manager-file =
    $data-manager-path.IO.add('variable_description.db').resolve.Str;
my $data-repo = DataRepository.new: :$data-manager-file;

# 主函数 {{{1
sub MAIN (Str:D :$sub!, %*options, @*args) {
    given $sub {
        when 'delete' { insert(|%options, |@args) }
        when 'insert' { insert(|%options, |@args) }
        when 'replace' { insert(|%options, |@args) }
        when 'update' { insert(|%options, |@args) }
        when 'get' { insert(|%options, |@args) }
        when 'view' { insert(|%options, |@args) }
        when 'search' { insert(|%options, |@args) }
        when 'export' { insert(|%options, |@args) }
        default { help }
    }
    if $sub eq 'insert'

}

my $data-repo = DataRepository


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

