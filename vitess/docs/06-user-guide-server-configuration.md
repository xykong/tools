## Server Configuration 服务配置
### Contents 内容
略
### MySQL
Vitess对如何配置MySQL有一些要求。这些将在下面详述。
作为提醒，强烈建议使用半同步复制。它提供了比较依靠磁盘更好的耐用性故事。这也可以让你放松基于磁盘的耐用性设置。

#### Versions
MySQL versions supported are: MariaDB 10.0, MySQL 5.6 and MySQL 5.7. A number of custom versions based on these exist (Percona, …), Vitess most likely supports them if the version they are based on is supported.

#### Config files
#### my.cnf
The main my.cnf file is generated by mysqlctl init based primarily on $VTROOT/config/mycnf/default.cnf. Additional files will be appended to the generated my.cnf as specified in a colon-separated list of absolute paths in the EXTRA_MY_CNF environment variable. For example, this is typically used to include flavor-specific config files.

To customize the my.cnf, you can either add overrides in an additional EXTRA_MY_CNF file, or modify the files in $VTROOT/config/mycnf before distributing to your servers. In Kubernetes, you can use a ConfigMap to overwrite the entire $VTROOT/config/mycnf directory with your custom versions, rather than baking them into a custom container image.

#### init_db.sql
When a new instance is initialized with mysqlctl init (as opposed to restarting in a previously initialized data dir with mysqlctl start), the init_db.sql file is applied to the server immediately after executing mysql_install_db. By default, this file contains the equivalent of running mysql_secure_installation, as well as the necessary tables and grants for Vitess.

If you are running Vitess on top of an existing MySQL instance, rather than using mysqlctl, you can use this file as a sample of what grants need to be applied to enable Vitess.

Note that changes to this file will not be reflected in shards that have already been initialized and had at least one backup taken. New instances in such shards will automatically restore the latest backup upon vttablet startup, overwriting the data dir created by mysqlctl.

#### Statement-based replication (SBR) 基于声明的复制
#### Data types 数据类型
#### No side effects 无副本作用
#### Autocommit 自动提交
MySQL自动提交需要被打开。

VTTablet使用连接池到MySQL。如果自动提交被关闭，MySQL将为每个连接启动一个隐式事务（带有时间点快照），并且将非常努力地保持当前视图不变，这将会适得其反。

#### Safe startup 安全启动
我们建议，以使和启动时。第一个确保书面不会被意外接受，这可能会导致分裂的大脑或交替的期货。第二个确保从设备在连接到主设备之前不会连接到主设备，例如根据Vitess特定的逻辑，通过vttablet初始化像semisync这样的设置。read-onlyskip-slave-start

#### Binary logging 二进制日志记录
默认情况下，我们在任何地方启用二进制日志记录（），包括从服务器（）。在副本类型的平板电脑上，这对于确保他们在升级到主服务器时有必要的双向日志很重要。从站二进制日志还用于实现Vitess功能，如过滤复制（重新分片期间）以及即将到来的更新流和联机模式交换。log-binlog-slave-updates

#### Global Transaction ID (GTID)
Vitess的许多功能都需要完全基于GTID的MySQL复制拓扑，包括主管理，重新分片，更新流和联机模式交换。

对于MySQL 5.6+，这意味着您必须在所有服务器上使用。我们也强烈鼓励。gtid_mode=ONenforce_gtid_consistency

同样，对于MariaDB，您应该使用gtid_strict_mode以确保主控管理操作将失败，而不会由于外部干扰而导致从控制器与主控制器分离，从而导致数据丢失。

#### Monitoring 监控
In addition to monitoring the Vitess processes, we recommend to monitor MySQL as well. Here is a list of MySQL metrics you should monitor:
- QPS
- Bytes sent/received
- Replication lag 复制延迟
  - Threads running 线程运行
- Innodb buffer cache hit rate
- CPU, memory and disk usage. For disk, break into bytes read/written, latencies and IOPS.
#### Recap 概况
- 2-4 cores
- 100-300GB data size
- Statement based replication (required 必须)
- Semi-sync replication 半同步复制
  - rpl_semi_sync_master_timeout is huge (essentially never; there's no way to actually specify never)
  - rpl_semi_sync_master_wait_no_slave = 1
  - sync_binlog=0
  - innodb_flush_log_at_trx_commit=2
- STRICT_TRANS_TABLES
- auto-commit ON (required 必须)
- Additional parameters as mentioned in above sections.

### Vitess servers Vitess服务器
Vitess服务器是用Go编写的。有几个适用于所有服务器的Vitess专用旋钮。

#### Go version
Go是一种年轻的语言，倾向于在每个版本上增加重大改进。所以，几乎总是推荐最新的Go版本。请注意，最新的Go版本可能高于我们编译二进制文件所需的最低版本（请参阅“入门指南”中的“先决条件”部分）。

#### GOMAXPROCS
您通常不必设置此环境变量。默认的Go运行时将尽可能使用尽可能多的CPU。但是，如果要强制Go服务器不超过某个CPU限制，则将GOMAXPROCS设置为该值将在大多数情况下起作用。

#### GOGC
此变量的默认值为100.这意味着每次内存从基线增加一倍（100％增长）时都会收集垃圾。您通常不必更改此值。但是，如果您关心尾部延迟，增加此值将有助于您在该区域，但需要增加内存使用量。

#### Logging
Vitess服务器写入日志文件，并在达到最大大小时进行旋转。建议您在INFO级别日志记录中运行。打印在日志文件中的信息可用于故障排除。您可以通过运行定期清除或存档它们的cron作业来限制磁盘使用情况。

#### gRPC
Vitess使用gRPC进行客户端与Vitess之间以及Vitess服务器之间的通信。默认情况下，Vitess不使用SSL。

而且，即使不使用SSL，我们也允许使用应用程序提供的CallerID对象。它允许使用表ACL的不安全但易于使用的授权。

有关 如何设置这两个功能以及存在哪些命令行参数的更多信息，请参阅 Transport Security Model文档。

### Topology Service configuration
Vttablet，vtgate，vtctld需要正确的命令行参数来查找拓扑服务器。首先需要将topo_implementation标志设置为 zk2，etcd2或consul之一。然后他们都配置如下：

- 该topo_global_server_address包含全局拓扑服务器的服务器地址/地址。
- 该topo_global_root包含要使用的目录/路径。
请注意，平板电脑的本地单元格必须存在并在拓扑服务中正确配置，才能启动vttablet。本地单元是通过使用该命令在拓朴服务器内部配置的。有关更多信息，请参阅拓扑服务文档。vtctl AddCellInfo

### VTTablet
VTTablet has a large number of command line options. Some important ones will be covered here. In terms of provisioning these are the recommended values
- 2-4 cores (in proportion to MySQL cores)
- 2-4 GB RAM

#### Directory Configuration 目录配置
vttablet支持许多命令行选项和环境变量，以方便其设置。

该VTDATAROOT环境变量指定的所有数据文件，根目录。如果未设置，则默认为。/vt

默认情况下，vttablet将使用一个子目录VTDATAROOT命名的 vt_NNNNNNNNNN地方NNNNNNNNNN是平板电脑的ID。所述tablet_dir 命令行参数允许重写此相对路径。这在文件系统只包含一个vttablet的容器​​中很有用，以便拥有一个固定的根目录。

当启动并使用mysqlctl管理MySQL时，MySQL文件将位于数位板根目录的子目录中。例如，二进制日志，数据文件和中继日志。bin-logsdatarelay-logs

可以在不同的分区上托管MySQL服务器文件的不同部分。例如，数据文件可能驻留在闪存中，而bin日志和中继日志则位于主轴上。为了实现这一点，创建一个符号链接 到磁盘上的适当位置。当MySQL被mysqlctl配置时，它会意识到这个目录是存在的，并将它用于它原本放在平板电脑目录中的文件。例如，要在以下位置托管binlog ：$VTDATAROOT/<dir name>/mnt/bin-logs

从创建一个符号链接到。$VTDATAROOT/bin-logs/mnt/bin-logs

启动平板电脑时：

/mnt/bin-logs/vt_NNNNNNNNNN 将被创建。
$VTDATAROOT/vt_NNNNNNNNNN/bin-logs 将成为一个符号链接 /mnt/bin-logs/vt_NNNNNNNNNN

#### Initialization 初始化
Init_keyspace，init_shard，init_tablet_type：应在启动时使用keyspace / shard / tablet类型设置这些参数以启动平板电脑。请注意，'master'不允许在这里，而是使用'replica'，因为平板电脑在启动时会查明它是否为主设备（这样，所有副本平板电脑都以相同的命令行参数开始，与哪个主设备无关）。

#### Query server parameters  查询服务器参数
- queryserver-config-pool-size：通常应将此值设置为希望MySQL运行的最大并发查询数。这通常应该是分配的CPU数量的2-3倍。大约4-16。用这个价值提高价值并没有太大的损害，但是你可能没有看到额外的好处。
- queryserver-config-stream-pool-size：仅当您计划针对数据库运行流式查询时，此值才相关。建议您使用rdonly实例进行此类流式查询。此值取决于您计划运行的同时流式查询的数量。典型值在100左右。
- queryserver-config-transaction-cap：此值应该设置为您希望允许的并发事务数量。这应该是事务QPS和事务长度的函数。典型值在100左右。
- queryserver-config-query-timeout：这个值应该设置为你愿意允许查询运行的上限，在它被认为是太昂贵或者对系统的其他部分不利的情况下运行。VTTablet将杀死超过此超时的任何查询。这个值通常在15-30s左右。
- queryserver-config-transaction-timeout：此值旨在保护客户端未完成事务而崩溃的情况。此超时的典型值为30秒。
- queryserver-config-max-result-size：此参数可防止OLTP应用程序意外地请求太多的行。如果结果超过指定的行数，VTTablet将返回错误。默认值是10,000。
#### DB config parameters 数据库配置参数
VTTablet需要多个用户凭证才能执行其任务。由于需要在与MySQL相同的机器上运行，因此使用效率更高的unix套接字连接最为有利。

应用凭据用于提供应用查询：
- db-config-app-unixsocket：连接到的MySQL套接字名称。
- db-config-app-uname：应用程序用户名。
- db-config-app-pass：应用程序用户名的密码。如果您需要更安全的管理和提供密码的方式，VTTablet确实允许您插入可以安全地提供和刷新用户名和密码的“密码服务器”。如果您想编写这样的自定义插件，请联系Vitess团队寻求帮助。
- db-config-app-charset：唯一支持的字符集是utf8。Vitess仍然可以与latin1一起使用，但它已被弃用。

dba凭证将用于家务管理工作，如加载模式或查杀失控查询：
- db-config-dba-unixsocket
- db-config-dba-uname
- db-config-dba-pass
- db-config-dba-charset

repl凭证用于管理复制。由于可以跨机器使用repl连接，因此可以选择启用加密：
- db-config-repl-uname
- db-config-repl-pass
- db-config-repl-charset
- db-config-repl-flags: If you want to enable SSL, this must be set to 2048.
- db-config-repl-ssl-ca
- db-config-repl-ssl-cert
- db-config-repl-ssl-key

过滤后的凭证用于执行重新分解：
- db-config-filtered-unixsocket
- db-config-filtered-uname
- db-config-filtered-pass
- db-config-filtered-charset

#### Monitoring
VTTablet exports a wealth of real-time information about itself. This section will explain the essential ones:

- **/debug/status**
This page has a variety of human-readable information about the current VTTablet. You can look at this page to get a general overview of what’s going on. It also has links to various other diagnostic URLs below.

- **/debug/vars**
This is the most important source of information for monitoring. There are other URLs below that can be used to further drill down.

- **Queries (as described in /debug/vars section)**
Vitess has a structured way of exporting certain performance stats. The most common one is the Histogram structure, which is used by Queries:
``` bash
  "Queries": {
    "Histograms": {
      "PASS_SELECT": {
        "1000000": 1138196,
        "10000000": 1138313,
        "100000000": 1138342,
        "1000000000": 1138342,
        "10000000000": 1138342,
        "500000": 1133195,
        "5000000": 1138277,
        "50000000": 1138342,
        "500000000": 1138342,
        "5000000000": 1138342,
        "Count": 1138342,
        "Time": 387710449887,
        "inf": 1138342
      }
    },
    "TotalCount": 1138342,
    "TotalTime": 387710449887
  },
```
The histograms are broken out into query categories. In the above case, "PASS_SELECT" is the only category. An entry like "500000": 1133195 means that 1133195 queries took under 500000 nanoseconds to execute.

Queries.Histograms.PASS_SELECT.Count is the total count in the PASS_SELECT category.

Queries.Histograms.PASS_SELECT.Time is the total time in the PASS_SELECT category.

Queries.TotalCount is the total count across all categories.

Queries.TotalTime is the total time across all categories.

There are other Histogram variables described below, and they will always have the same structure.

Use this variable to track:

  - QPS
  - Latency
  - Per-category QPS. For replicas, the only category will be PASS_SELECT, but there will be more for masters.
  - Per-category latency
  - Per-category tail latency

- **Results**
``` bash
  "Results": {
    "0": 0,
    "1": 0,
    "10": 1138326,
    "100": 1138326,
    "1000": 1138342,
    "10000": 1138342,
    "5": 1138326,
    "50": 1138326,
    "500": 1138342,
    "5000": 1138342,
    "Count": 1138342,
    "Total": 1140438,
    "inf": 1138342
  }
```
Results is a simple histogram with no timing info. It gives you a histogram view of the number of rows returned per query.

Mysql
Mysql is a histogram variable like Queries, except that it reports MySQL execution times. The categories are "Exec" and “ExecStream”.

In the past, the exec time difference between VTTablet and MySQL used to be substantial. With the newer versions of Go, the VTTablet exec time has been predominantly been equal to the mysql exec time, conn pool wait time and consolidations waits. In other words, this variable has not shown much value recently. However, it’s good to track this variable initially, until it’s determined that there are no other factors causing a big difference between MySQL performance and VTTablet performance.

Transactions
Transactions is a histogram variable that tracks transactions. The categories are "Completed" and “Aborted”.

Waits
Waits is a histogram variable that tracks various waits in the system. Right now, the only category is "Consolidations". A consolidation happens when one query waits for the results of an identical query already executing, thereby saving the database from performing duplicate work.

This variable used to report connection pool waits, but a refactor moved those variables out into the pool related vars.

Errors
  "Errors": {
    "Deadlock": 0,
    "Fail": 1,
    "NotInTx": 0,
    "TxPoolFull": 0
  },
Errors are reported under different categories. It’s beneficial to track each category separately as it will be more helpful for troubleshooting. Right now, there are four categories. The category list may vary as Vitess evolves.

Plotting errors/query can sometimes be useful for troubleshooting.

VTTablet also exports an InfoErrors variable that tracks inconsequential errors that don’t signify any kind of problem with the system. For example, a dup key on insert is considered normal because apps tend to use that error to instead update an existing row. So, no monitoring is needed for that variable.

InternalErrors
  "InternalErrors": {
    "HungQuery": 0,
    "Invalidation": 0,
    "MemcacheStats": 0,
    "Mismatch": 0,
    "Panic": 0,
    "Schema": 0,
    "StrayTransactions": 0,
    "Task": 0
  },
An internal error is an unexpected situation in code that may possibly point to a bug. Such errors may not cause outages, but even a single error needs be escalated for root cause analysis.

Kills
  "Kills": {
    "Queries": 2,
    "Transactions": 0
  },
Kills reports the queries and transactions killed by VTTablet due to timeout. It’s a very important variable to look at during outages.

TransactionPool*
There are a few variables with the above prefix:

  "TransactionPoolAvailable": 300,
  "TransactionPoolCapacity": 300,
  "TransactionPoolIdleTimeout": 600000000000,
  "TransactionPoolMaxCap": 300,
  "TransactionPoolTimeout": 30000000000,
  "TransactionPoolWaitCount": 0,
  "TransactionPoolWaitTime": 0,
WaitCount will give you how often the transaction pool gets full that causes new transactions to wait.
WaitTime/WaitCount will tell you the average wait time.
Available is a gauge that tells you the number of available connections in the pool in real-time. Capacity-Available is the number of connections in use. Note that this number could be misleading if the traffic is spiky.
Other Pool variables
Just like TransactionPool, there are variables for other pools:

ConnPool: This is the pool used for read traffic.
StreamConnPool: This is the pool used for streaming queries.
There are other internal pools used by VTTablet that are not very consequential.

TableACLAllowed, TableACLDenied, TableACLPseudoDenied
The above three variables table acl stats broken out by table, plan and user.

QueryPlanCacheSize
If the application does not make good use of bind variables, this value would reach the QueryCacheCapacity. If so, inspecting the current query cache will give you a clue about where the misuse is happening.

QueryCounts, QueryErrorCounts, QueryRowCounts, QueryTimesNs
These variables are another multi-dimensional view of Queries. They have a lot more data than Queries because they’re broken out into tables as well as plan. This is a priceless source of information when it comes to troubleshooting. If an outage is related to rogue queries, the graphs plotted from these vars will immediately show the table on which such queries are run. After that, a quick look at the detailed query stats will most likely identify the culprit.

UserTableQueryCount, UserTableQueryTimesNs, UserTransactionCount, UserTransactionTimesNs
These variables are yet another view of Queries, but broken out by user, table and plan. If you have well-compartmentalized app users, this is another priceless way of identifying a rogue "user app" that could be misbehaving.

DataFree, DataLength, IndexLength, TableRows
These variables are updated periodically from information_schema.tables. They represent statistical information as reported by MySQL about each table. They can be used for planning purposes, or to track unusual changes in table stats.

DataFree represents data_free
DataLength represents data_length
IndexLength represents index_length
TableRows represents table_rows
/debug/health
This URL prints out a simple "ok" or “not ok” string that can be used to check if the server is healthy. The health check makes sure mysqld connections work, and replication is configured (though not necessarily running) if not master.

/queryz, /debug/query_stats, /debug/query_plans, /streamqueryz
/debug/query_stats is a JSON view of the per-query stats. This information is pulled in real-time from the query cache. The per-table stats in /debug/vars are a roll-up of this information.
/queryz is a human-readable version of /debug/query_stats. If a graph shows a table as a possible source of problems, this is the next place to look at to see if a specific query is the root cause.
/debug/query_plans is a more static view of the query cache. It just shows how VTTablet will process or rewrite the input query.
/streamqueryz lists the currently running streaming queries. You have the option to kill any of them from this page.
/querylogz, /debug/querylog, /txlogz, /debug/txlog
/debug/querylog is a never-ending stream of currently executing queries with verbose information about each query. This URL can generate a lot of data because it streams every query processed by VTTablet. The details are as per this function: https://github.com/vitessio/vitess/blob/master/go/vt/tabletserver/logstats.go#L202
/querylogz is a limited human readable version of /debug/querylog. It prints the next 300 queries by default. The limit can be specified with a limit=N parameter on the URL.
/txlogz is like /querylogz, but for transactions.
/debug/txlog is the JSON counterpart to /txlogz.
/consolidations
This URL has an MRU list of consolidations. This is a way of identifying if multiple clients are spamming the same query to a server.

/schemaz, /debug/schema
/schemaz shows the schema info loaded by VTTablet.
/debug/schema is the JSON version of /schemaz.
/debug/query_rules
This URL displays the currently active query blacklist rules.

/debug/health
This URL prints out a simple "ok" or “not ok” string that can be used to check if the server is healthy.

Alerting
Alerting is built on top of the variables you monitor. Before setting up alerts, you should get some baseline stats and variance, and then you can build meaningful alerting rules. You can use the following list as a guideline to build your own:

Query latency among all vttablets
Per keyspace latency
Errors/query
Memory usage
Unhealthy for too long
Too many vttablets down
Health has been flapping
Transaction pool full error rate
Any internal error
Traffic out of balance among replicas
Qps/core too high
#### Alerting
### VTGate
典型的VTGate应按如下方式进行配置。
- 2-4个核心
- 2-4 GB RAM

由于VTGate是无状态的，您可以根据需要添加更多的服务器来线性扩展它。除了推荐值之外，最好添加更多的VTGate，而不是像哲学部分所建议的那样，为现有服务器提供更多资源。

负载均衡器放在vtgate前面（不包括Vitess）。无状态，可以使用健康URL进行健康检查。

#### Parameters 参数
- cells_to_watch：哪个单元格vtgate处于并将从中监控平板电脑。跨小区主控访问需要多个单元。
- tablet_types_to_wait：在收听服务端口之前，VTGate在启动期间等待至少一个此处指定的平板电脑类型的服务平板电脑。所以VTGate不会发生错误。它应该与VTGate连接的可用平板电脑类型（主控，副本，rdonly）匹配。
- discovery_low_replication_lag：当特定分片和平板电脑类型中的所有VTTablet的复制滞后时间小于或等于标志（以秒为单位）时，VTGate不会通过复制滞后过滤它们，并使用全部来平衡流量。
- degraded_threshold（30s）：如果复制延迟超过此阈值，平板电脑将自行发布为已降级。这将导致VTGates选择更多最新的服务器。如果所有服务器都降级，VTGate会从所有服务器中提供服务。
- unhealthy_threshold（2h）：如果复制延迟超过此阈值，平板电脑将自行发布为不健康。
- transaction_mode（multi）：：single不允许多数据库事务，multi：允许多数据库事务尽最大努力提交，twopc：允许使用2pc提交的多数据库事务。
- normalize_queries（false）：打开此标志将导致vtgate用绑定变量重写查询。如果应用程序本身不发送规范化查询，这是有益的。

#### Monitoring
- /debug/status

  This is the landing page for a VTGate, which can gives you a status on how a particular server is doing. Of particular interest there is the list of tablets this vtgate process is connected to, as this is the list of tablets that can potentially serve queries.

- /debug/vars
  - VTGateApi
  This is the main histogram variable to track for vtgates. It gives you a break up of all queries by command, keyspace, and type.

  - HealthcheckConnections
  It shows the number of tablet connections for query/healthcheck per keyspace, shard, and tablet type.

- /debug/query_plans
  This URL gives you all the query plans for queries going through VTGate.

- /debug/vschema
  This URL shows the vschema as loaded by VTGate.

#### Alerting
For VTGate, here’s a list of possible variables to alert on:
- Error rate
- Error/query rate
- Error/query/tablet-type rate
- VTGate serving graph is stale by x minutes (lock server is down)
- Qps/core
- Latency

### External processes 外部过程
#### Periodic backup configuration 定期备份配置
#### Logs archiver/purger 记录存档器和清除器
#### Orchestrator
Orchestrator是管理MySQL复制拓扑的工具，包括自动故障转移。它可以检测到主站故障并在几秒内启动恢复。

在大部分情况下，Vitess对Orchestrator的操作时不可知的，Orchestrator在MySQL级别下运行在Vitess之下。这意味着你几乎可以 用正常的方式设置Orchestrator，只需添加一些内容，如下所述。

对于Kubernetes示例，我们提供了一个 示例脚本 来为您启动Orchestrator并应用这些设置。

##### Orchestrator配置
Orchestrator需要了解Vitess方面的一些事情，如平板电脑别名以及是否强制执行半同步（禁用异步回退）。我们通过告诉Orchestrator执行某些从非复制表返回本地元数据的查询来传递这些信息，如我们的示例 orchestrator.conf.json中所示：
``` bash
  "DetectClusterAliasQuery": "SELECT value FROM _vt.local_metadata WHERE name='ClusterAlias'",
  "DetectInstanceAliasQuery": "SELECT value FROM _vt.local_metadata WHERE name='Alias'",
  "DetectPromotionRuleQuery": "SELECT value FROM _vt.local_metadata WHERE name='PromotionRule'",
  "DetectSemiSyncEnforcedQuery": "SELECT @@global.rpl_semi_sync_master_wait_no_slave AND @@global.rpl_semi_sync_master_timeout > 1000000",
```
如果发生故障转移，Vitess还需要从Orchestrator中知道一件事，即每个分片的主服务器的身份。

根据我们在YouTube的经验，我们认为这个信号对于数据完整性来说太关键了，以至于依靠自下而上的检测，例如询问每个MySQL是否认为它是主控。相反，我们依靠Orchestrator成为真相的源泉，并期望它向Vitess发出自上而下的信号。

该信号通过确保Orchestrator服务器有权访问 vtctlclient，然后使用它发送RPC到vtctld，通过TabletExternallyReparented 命令通知Vitess主控权的变化 。
``` bash
  "PostMasterFailoverProcesses": [
    "echo 'Recovered from {failureType} on {failureCluster}. Failed: {failedHost}:{failedPort}; Promoted: {successorHost}:{successorPort}' >> /tmp/recovery.log",
    "vtctlclient -server vtctld:15999 TabletExternallyReparented {successorAlias}"
  ],
```

##### VTTablet配置
通常情况下，您需要为Orchestrator分配每个分片中的MySQL实例地址。如果你有很多碎片，这可能是单调乏味或容易出错的。

幸运的是，Vitess已经知道组成你的集群的所有MySQL实例的一切。因此，我们提供了一种平板电脑自动注册Orchestrator API的机制，由以下vttablet参数配置：

orc_api_url：Orchestrator HTTP API的地址（例如http：// host：port / api /）。保留空白以禁用Orchestrator集成。
orc_discover_interval：多长时间（例如60秒）可以ping Orchestrator的HTTP API端点来告诉它我们存在。0意味着从不。
这不仅可以帮助您将地址初始化到Orchestrator中，还可以立即发现新实例，即使Orchestrator的后备存储已被清除，拓扑也会自动重新填充。请注意，Orchestrator会在可配置的超时后忘记陈旧的实例。

## 2PC Guide  2PC指南
### Contents 内容
Vitess 2PC允许您执行原子分布式提交。该功能是使用传统的MySQL事务实现的，因此继承了相同的保证。有了这个补充，Vitess可以配置为支持如下三个原子级别：
- 单个数据库：在此级别，只允许单个数据库事务。任何尝试超越单个数据库的事务都将失败。
- 多个数据库：一个事务可以跨越多个数据库，但是提交将是尽力而为的。部分提交是可能的。
- 2PC: 这与多数据库相同，但提交将是原子的。

2PC提交比多数据库更昂贵，因为系统必须在启动提交过程之前将语句保存起来，并且在成功提交之后清理它们。这就是为什么它是一个单独的选项，而不是始终处于打开状态的原因。

### Isolation 隔离
2PC事务保证原子性：整个事务提交或完全回滚。它不保证隔离（在ACID意义上）。这意味着执行跨数据库读取的第三方可以在2PC事务正在进行时观察部分提交。

保证ACID隔离非常有争议并且成本很高。在默认情况下提供它会使最常见的用例变得不切实际。

### Configuring VTGate
原子性策略由transaction_mode标志控制。默认值是multi，并将其设置为多数据库模式。这与之前的传统行为相同。

为了执行单数据库事务，可以通过指定来启动VTGates 。transaction_mode=single

要启用2PC，VTGates需要启动。VTTablets将需要更多的标志，这将在下面解释。transaction_mode=twopc

VTGate transaction_mode标志决定允许的内容。应用程序可以独立地请求每个事务的特定原子性。只有在VTGate未超过允许范围的情况下，该请求才会被授予transaction_mode。例如，只会允许单数据库事务。另一方面，将允许所有三个层次的原子性。transacion_mode=singletransaction_mode=twopc

### Driver APIs
从应用程序请求原子性的方法是针对驱动程序的。

### Go driver Go驱动
### Python driver Python驱动
### Java & PHP (TODO)
### Adding support in a new driver 在新的驱动程序中添加支持

### Critical failures
### Alertable failures

## Troubleshooting  故障排除
### Contents 内容
如果系统出现问题，通常会触发一个或多个警报。如果通过警报以外的方式发现问题，则需要重复警报系统。

当警报触发时，您有以下信息来源来执行您的调查：

- 警报值
- 图表
- 诊断网址
- 日志文件

以下是一些可能的情况。
### Elevated query latency on master 主站上的查询延迟时间增加
诊断1：检查图表，看QPS是否已经升高。如果是，请在更详细的QPS图表上查看哪些表格或用户导致了增加。如果表已被识别，请查看/ debug / queryz以查找该表上的查询。

行动：通知工程师关于有毒的查询。如果它是一个特定的用户，您可以停止他们的工作或者扼杀他们以保持负载的可管理性。作为最后的手段，黑名单查询允许系统的其他部分保持健康。

诊断2：QPS没有升高，只有延迟。检查每个表的延迟图。如果它是一个特定的表，那么它很可能是一个长期运行的低QPS查询，它会使数字偏离。识别罪魁祸首查询并采取必要步骤使其得到优化。这样的查询通常不会导致中断。所以，可能没有必要采取极端措施。

诊断3：延迟似乎是全面的。检查交易延迟。如果这一点已经升高，那么会导致MySQL运行太多的并发事务，导致速度下降。看看是否有任何tx池完整的错误。如果增加，INFO日志将转储有关所有事务的信息。从那里，你应该能够，如果一个特定的语句序列造成的问题。一旦确定，找出根本原因。这可能是网络问题，也可能是最近的应用行为变化。

诊断4：没有特别的交易似乎是罪魁祸首。任何要求似乎都没有改变。查看系统变量以查看是否存在硬件故障。磁盘延迟是否过高？是否有内存奇偶校验错误？如果是这样，您可能不得不故障切换到新机器。

### Master starts up read-only 主启动只读
为防止意外接受写入，我们的默认设置告诉MySQL始终以只读方式启动。如果主MySQL重新启动，它将会回到只读状态，直到您介入确认它应该接受写入。你可以使用SetReadWrite 命令来做到这一点。my.cnf

但是，通常情况下，如果主人发生意外事件，最好使用EmergencyReparentShard重新备份到不同的副本。如果您需要对主服务器执行计划维护，最好先使用PlannedReparentShard重新备份到另一个副本。

### Vitess sees the wrong tablet as master
如果您手动执行故障转移（而不是通过Vitess），则需要告诉Vitess哪个平板电脑对应于新的主MySQL。在此之前，写入操作将失败，因为它们将被路由到只读副本（旧主控）。使用TabletExternallyReparented 命令告诉Vitess新的主平板电脑用于分片。

像Orchestrator这样的工具 可以配置为在发生故障转移时自动调用此功能。有关 此示例，请参阅我们的示例orchestrator.conf.json。

# Upgrading 升级
## Contents 内容
本文档重点介绍将Vitess生产安装升级到更新的Vitess版本时需要关注的事项。

一般来说，升级Vitess是一个安全且简单的过程，因为它明确地为它设计。这是因为在YouTube中，我们经常按照惯例发布新版本（通常从Git master分支的顶端）。
## Compatibility 兼容性
我们的版本控制策略基于语义版本控制。

Vitess版本号码遵循格式MAJOR.MINOR.PATCH。升级到较新的修补程序或次要版本时，我们保证兼容性。升级到更高主版本可能需要手动更改配置。

通常，请阅读发行说明的“升级”部分。它会提到任何不兼容的更改和必要的手动步骤。

## Upgrade Order 升级订单
我们建议按照自下而上的顺序升级组件，以便“旧”客户端在转换过程中与“新”服务器通信。

请使用此升级订单（除非发行说明中另有说明）：
- vtctld
- vttablet
- vtgate
- 链接客户端库的应用程序代码

首先列出vtctld，以确保您仍然可以管理Vitess - 或者尽快找到。

## Canary Testing 金丝雀测试
在vtgate和vttablet组件中，我们推荐使用金丝雀单个实例，密钥空间和单元格。升级的金丝雀实例可以“烘烤”几个小时或几天以验证升级没有引入回归。最终，您可以升级其余的实例。

## Rolling Upgrades 滚动升级
我们建议使用配置管理软件自动执行升级过程。它将减少人为错误的可能性并简化管理所有实例的过程。

截至2016年6月，我们没有用于任何主要开源配置管理软件的模板，因为我们的内部升级过程基于专有软件。因此，我们邀请开源用户提供此类模板。

任何升级应该是滚动版本，即通常在碎片内一次一个平板。这可确保剩余的平板电脑继续提供实时流量，并且不会中断。

## Upgrading the Master Tablet
每个分片的主平板应该总是按照以下方式最后更新：

- 验证碎片中的所有副本平板电脑都已升级
- 从当前主控制器复制到副本平板电脑
- 升级旧主人平板电脑
