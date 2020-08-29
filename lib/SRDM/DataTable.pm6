use Terminal::ANSIColor;
use SRDM::DataRecord;

unit class Table;

has Str      $.database    is required; #= 所在数据库
has Str      $.name        is required; #= 表格名
has Str      $.keys        is required; #= 表格的主 key
has Str      $.path        is required; #= 数据位置
has Str      $.engine      is required; #= 数据库文件管理引擎
has Str      $.source      is rw;       #= 记录的数据来源
has Str      $.description is rw;       #= 记录描述
has Str      $.script_file is rw;       #= 记录创建脚本
has Str      $.script_tag  is rw;       #= 记录创建脚本的标签
has Str      $.desc_file   is rw;       #= 记录描述文件
has Str      $.desc_tag    is rw;       #= 记录描述的标签
has Str      $.log_file    is rw;       #= 记录的使用记录
has DateTime $.create_at   is rw;       #= 记录创建时间
has DateTime $.modify_at   is rw;       #= 记录修改时间
has Record   @.records     is rw;       #= 包含的记录


method fullname() {
    return $!database ~ ":" ~ $!name;
}

method all-fields() {
    return <database name keys path engine source description
            script_file script_tag desc_file desc_tag log_file
            create_at modify_at records>
}

#| 打印记录的基本信息
method Str( --> Str ) {
    self.gist;
}

method gist( Bool :$header = True --> Str ) {
    my $lines = qq:to/LINES/;
    { colored("{$!name}", "bold 9") }
    | source      { colored(Str($!source  // 'Unknow'), "11") }
    | description { colored(Str($!description // 'Unknow'), "11") }
    LINES
    return do if $header {
        colored("{$!database}", "underline") ~ "\n" ~ $lines
    } else {
        $lines
    };
}

method des {
      my @oneline = self.all-fields[0..*-2].map({self."$_"() // ''});
      @oneline.push: (gather take $_.name for @!records).join("|");
      say @oneline[0..*-1].join: "\t";
}

method Hash {
    ...
}
