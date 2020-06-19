use Terminal::ANSIColor;
use SRDM::DataRecord;

unit class Record;

has Str      $.database    is required; #= 所在数据库
has Str      $.name        is required; #= 表格名
has Str      $.path        is rw;       #= 数据位置
has Str      $.engine      is rw;       #= 数据库文件管理引擎
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
    return $!database ~ ":" $!name;
}



