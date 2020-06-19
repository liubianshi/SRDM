use Terminal::ANSIColor;

unit class Record;

has Str      $.database    is required; #= 所在数据库
has Str      $.table       is required; #= 所在表格
has Str      $.name        is required; #= 记录名
has Str      $.type        is rw;       #= 记录类型
has Str      $.source      is rw;       #= 记录的数据来源
has Str      $.label       is rw;       #= 记录标签
has Str      $.description is rw;       #= 记录描述
has Int      $.number      is rw;       #= 记录数量
has Int      $.missing     is rw;       #= 缺失值数量
has Int      $.unique      is rw;       #= 唯一值数量
has Str      $.script_file is rw;       #= 记录创建脚本
has Str      $.script_tag  is rw;       #= 记录创建脚本的标签
has Str      $.desc_file   is rw;       #= 记录描述文件
has Str      $.desc_tag    is rw;       #= 记录描述的标签
has Str      $.log_file    is rw;       #= 记录的使用记录
has DateTime $.create_at   is rw;       #= 记录创建时间
has DateTime $.modify_at   is rw;       #= 记录修改时间

method fullname() {
    return $!database ~ ":" $!table ~ ":" ~ $!name;
}

#| 打印记录的基本信息
method Str( --> Str ) {
    self.gist;
}

method gist( Bool :$header = True --> Str ) {
    my $lines = qq:to/LINES/;
    { colored("{$!name}", "bold 9") }
    | label     { colored("$!label", "11") }
    | type      { colored($!type, "11") }
    | number    { colored(Str($!number  // ''), "10") }
    | missing   { colored(Str($!missing // ''), "10") }
    | unique    { colored(Str($!unique  // ''), "10") }
    LINES
    return do if $header {
        colored("{$!database}::{$!table}", "underline") ~ "\n" ~ $lines
    } else {
        $lines
    };
}

# 将数据写入数据库
