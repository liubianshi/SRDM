# Simple Research Data Manager (SRDM)

## 提供的功能

- 插入 insert
- 更新 update
- 删除 delete
- 替换 replace
- 查看 view
- 提取 get
- 查询 search
- 导出 export
- 测试 test

## 插入

Usage:

    srdm insert <--name=<name>> [--field=<field> [...]]

name
:   插入记录的名称

field
:   记录的属性，随记录类似的不同而有所不同。

对于表格类 `table` 记录，必须属性如下：

- `--keys`, 数据表格的主键

可选属性

- `--engine`，数据的管理引擎，默认是 `SQLite3`
- `--path`，数据的存储位置，默认是 `$DATA/<databalse.db>`，其中 `$DATA` 为
    指示数据存放位置的环境变量
- `--source`, 数据来源
- `--description`，数据描述
- `--script_file`，处理数据的脚本文件
- `--script_tag`，处理数据的脚本文件版本
- `--desc_file`, 数据的分析文件
- `--desc_tag`, 数据的分析文件版本
- `--log_file`, 数据使用记录文件
- `--create_at`, 数据创建时间，默认为当前时间，通常无需自行设置
- `--modify_at`, 数据最新修改时间，默认为当前时间，通常无需自行设置

对于普通记录 `record`，除名字外，没有其他必选属性，可选属性包括:

- `--type`, 记录类型
- `--source`, 数据来源
- `--label`, 数据标签
- `--description`, 数据描述
- `--number`, 数据记录数量
- `--missNumber`, 缺失值数量
- `--uniqueNumber`, 唯一值数量
- `--script_tag`，处理数据的脚本文件版本
- `--desc_file`, 数据的分析文件
- `--desc_tag`, 数据的分析文件版本
- `--log_file`, 数据使用记录文件
- `--create_at`, 数据创建时间，默认为当前时间，通常无需自行设置
- `--modify_at`, 数据最新修改时间，默认为当前时间，通常无需自行设置

## 查询记录

Usage:

    srdm search [--table] [--mode=detail|name-only|oneline] \
    [--output-file] [--output-format=Str] \
    [--where=str] [--<conditions>] [--filter=str] [<names>]

参数说明:

- `--table`, 搜索表格记录, 如不加此选项, 默认检索普通记录
- `--mode`, 显示模式, 目前接受 `name-only`, `detail` 和 `oneline`, 默认为
  `detail`
- `--output-file`, 将结果输出到指定的文件, `-` 表示输出到 `stdout`, 目前尚不支
  持
- `--output-format`, 输出文件的格式, 如 `json`, `csv`, `table`, `markdown`,
  `pandoc` 等, 目前尚不支持
- `--where`, SQL-style `where` 语句
- `--<conditions>`, 参数选择语句, 可以根据记录的字段进行筛选
- `--filter`, 正则表达式, 对于表格记录, 基于 `name`, `keys`, `path`
  和 `source` 匹配, 对于普通记录, 基于 `name`, `label`, `path`, `source` 匹配.
  目前只支持 raku-style 正则表达式, 后续可能增加文本模式, 和 perl-style 正则。
  `--filter` 用于对 `--where` 和 `--<conditions>` 检索出来的数据作进一步筛选
- `<names>`, 记录名称, 用于直接提取制定名称的记录, 如果输入了名称, 那么
  `--filter`, `--where` 和 `--<conditions>` 选项将失效。

## 删除记录

Usage:

    srdm delete [--table]
    [--where=str] [--<conditions>] [--filter=str] [<names>]

参数说明:

- `--table`, 搜索表格记录, 如不加此选项, 默认检索普通记录
- `--mode`, 显示模式, 目前接受 `name-only`, `detail` 和 `oneline`, 默认为
  `detail`
- `--where`, SQL-style `where` 语句
- `--<conditions>`, 参数选择语句, 可以根据记录的字段进行筛选
- `--filter`, 正则表达式, 对于表格记录, 基于 `name`, `keys`, `path`
  和 `source` 匹配, 对于普通记录, 基于 `name`, `label`, `path`, `source` 匹配.
  目前只支持 raku-style 正则表达式, 后续可能增加文本模式, 和 perl-style 正则。
  `--filter` 用于对 `--where` 和 `--<conditions>` 检索出来的数据作进一步筛选
- `<names>`, 记录名称, 用于直接提取制定名称的记录, 如果输入了名称, 那么
  `--filter`, `--where` 和 `--<conditions>` 选项将失效。




