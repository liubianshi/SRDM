use Terminal::ANSIColor;
use DBIish;

unit class Field;

has Str   $.database    is required;  #= 所在数据库
has Str   $.table       is required;  #= 所在表格
has Str   $.name        is required;  #= 变量名
has Str   $.type        is rw = '';   #= 变量类型
has Str   $.source      is rw = '';   #= 变量的数据来源
has Str   $.label       is rw = '';   #= 变量标签
has Str   $.description is rw = '';   #= 变量描述
has Int   $.number      is rw = Nil;  #= 变量数量
has Int   $.missing     is rw = Nil;  #= 缺失值数量
has Int   $.unique      is rw = Nil;  #= 唯一值数量
has Str   $.script_file is rw = '';   #= 变量创建脚本
has Str   $.script_tag  is rw = '';   #= 变量创建脚本的标签
has Str   $.desc_file   is rw = '';   #= 变量描述文件
has Str   $.desc_tag    is rw = '';   #= 变量描述的标签
has Str   $.log_file    is rw = '';   #= 变量的使用记录

#| 打印变量的基本信息
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
