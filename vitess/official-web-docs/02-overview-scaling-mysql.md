# scaling-mysql 用Vitess扩展MySQL
## Contents 内容
传统上，很难将基于MySQL的数据库扩展为任意大小。由于MySQL缺乏真正扩展应用程序所需的开箱即用的多实例支持，因此这个过程可能很复杂且模糊。

随着应用程序的增长，出现了脚本来备份数据，迁移主数据库或运行一些离线数据处理。复杂性蔓延到应用程序层，越来越需要知道数据库的细节。在我们知道它之前，任何变化都需要一个大的工程努力，所以我们可以继续扩展。

Vitess源自YouTube试图打破这个循环，而YouTube在意识到这是一个非常普遍的问题后决定开源Vitess。Vitess简化了管理MySQL集群的各个方面，可以轻松扩展到任何大小，而不会使应用程序层复杂化。它可确保您的数据库在应用程序启动时保持运行状态，从而为您提供灵活，安全且易于挖掘的数据库。

本文档讨论从单个小型数据库迁移到无限数据库群集的过程。它解释了该过程中的步骤如何影响了Vitess的设计，并一路链接到Vitess文档的相关部分。它总结了设计新的高度可扩展的应用程序和数据库模式的技巧。

## Getting started  入门
Vitess位于你的应用程序和你的MySQL数据库之间。它查看传入的查询并正确地路由它们。因此，不是直接从您的应用程序向您的数据库发送查询，而是通过Vitess发送它，该Vitess可以理解您的数据库拓扑并持续监控各个数据库实例的运行状况。

虽然Vitess设计用于管理大型多实例数据库，但它提供的功能可简化产品生命周期各个阶段的数据库设置和管理。

首先，我们的第一步是通过一个主实例和一对副本获得一个简单，可靠，持久的数据库集群。在Vitess术语中，这是一个单分片，单键空间数据库。一旦该构建块就位，我们就可以专注于将其扩展。

### Planning for scale 规划规模
我们推荐一些最佳实践来帮助您的数据库随着产品的发展而扩展。您可能不会立即体验到这些行为的好处，但从第一天开始采用这些做法将使您的数据库和产品的扩展变得更容易：

- 始终将数据库架构保持在源代码控制之下，并提供该架构的单元测试覆盖率。还检查模式更改到源代码管理中，并针对新修改的模式运行单元测试。
- 考虑可以从副本中读取的代码路径，并总是选择从主服务器读取。这会让您通过添加更多副本来扩展您的读取。此外，这将使其可以轻松扩展到世界各地的其他数据中心。
- 避免复杂的数据关系。虽然RDBMS系统可以很好地处理它们，但这种关系阻碍了未来的扩展。到时候，分割数据会更容易。
- 避免将过多的逻辑以存储过程，外键或触发器的形式推入数据库。这些操作会过度征税数据库并阻碍扩展。

## Step 1: Setting up a database cluster 设置数据库集群
从一开始，计划创建一个具有主实例和一对只读副本（或从属）的数据库集群。如果主服务器不可用，副本将能够接管，并且他们也可能处理只读流量。你也想安排定期的数据备份。

值得注意的是，主管理是数据可靠性的一个复杂和关键的挑战。在任何给定时间，分片只有一个主实例，并且所有副本实例都从中复制。您的应用程序（如果您使用的是应用程序层中的组件或Vitess）需要能够轻松识别用于写入操作的主实例，并认识到主服务器可能会随时更改。同样，无论有无Vitess，您的应用程序都应该能够无缝地适应新上线的新副本或旧副本不可用。
### Keep routing logic out of your application 保证路由逻辑不在您的应用程序中
Vitess设计的核心原则是您的数据库和数据管理实践应随时准备好支持您的应用程序的增长。因此，您可能还没有立即需要将数据存储到多个数据中心，分割数据库，甚至定期进行备份。但是当这些需求出现时，你想确保你有一个简单的途径来实现它们。请注意，您可以在Kubernetes群集中或本地硬件上运行Vitess。

考虑到这一点，你想有一个计划，允许你的数据库增长，而不会复杂的应用程序代码。例如，如果您重新使用数据库，则不需要更改应用程序代码以识别特定查询的目标碎片。

Vitess有几个组件可以让你的应用程序避免这种复杂性：
- 每个MySQL实例都与一个vttablet进程配对，该进程提供连接池，查询重写和查询重复等功能。
- 您的应用程序向vtgate发送查询，vtgate是一种将流量路由到正确vttablet的轻型代理，然后将合并结果返回给应用程序。
- 该拓扑服务 - Vitess支持动物园管理员，ETCD和领事-数据库系统维护配置数据。Vitess依靠服务来知道在哪里根据分片方案和各个MySQL实例的可用性来路由查询。
- 该vtctl和vtctld工具提供了命令行和Web界面的系统。

![image](https://github.com/mds1455975151/tools/blob/master/vitess/official-web-docs/images/VitessOverview.png)

直接设置这些组件 - 例如，编写自己的拓扑服务或自己的vtgate实现 - 将需要大量特定于给定配置的脚本。这也会产生一个系统，这个系统很难支持而且代价高昂。此外，虽然任何一个组件本身都可用于限制复杂性，但您需要全部组件来尽可能简化应用程序，同时优化性能。
#### 可选的功能来实现
- 推荐。Vitess拥有识别或更改主人的基本支持，但并不打算完全解决此功能。因此，我们建议使用其他程序（如Orchestrator）来监视服务器的运行状况，并在必要时更改主数据库。（在分片数据库中，每个分片都有一个主分片。）

- 推荐。您应该有一种方法来监视数据库拓扑并根据需要设置警报。Vitess组件通过导出大量运行时变量（如过去几分钟内的QPS），错误率和查询延迟来促进此监控。变量以JSON格式导出，Vitess也支持InfluxDB插件。

- 可选。使用Kubernetes脚本作为基础，您可以使用其他配置管理系统（如Puppet）或框架（如Mesos或AWS映像）运行Vitess组件。
#### 其他相关的Vitess文档
- 在Kubernetes上运行Vitess
- 在本地服务器上运行Vitess
- 备份数据
- 重新分配 - Vitess中主要实例的基本分配
## Step 2: Connect your application to your database 将您的应用程序连接到您的数据库
显然，你的应用程序需要能够调用你的数据库。因此，我们将直接解释如何修改应用程序以通过vtgate连接到数据库。

从2.1版开始，VTGate支持MySQL协议。所以，应用程序只需要改变它连接的地方。对于那些使用Java或Go的用户，我们另外提供了可以使用gRPC与VTGate进行通信的库。使用提供的库允许您使用绑定变量发送查询，这在MySQL协议中本质上是不可能的。

### Unit testing database interactions 单元测试数据库交互
vttest库和可执行文件提供了一个单元测试环境，使您可以启动一个假群集，充当生产环境的精确副本以用于测试目的。在假群集中，单个数据库实例承载所有碎片。

### Migrating production data to Vitess 将生产数据迁移到Vitess
将数据迁移到Vitess数据库的最简单方法是对现有数据进行备份，在Vitess集群上进行恢复，然后从那里开始。但是，这需要一些停机时间。

另一个更复杂的方法是实时迁移，它需要你的应用程序支持直接的MySQL访问和Vitess访问。在这种方法中，您可以启用从源数据库到Vitess主数据库的MySQL复制。这将使您能够快速迁移并几乎不会停机。

请注意，此路径高度依赖于源设置。因此，尽管Vitess提供了辅助工具，但它并未提供支持此类迁移的通用方法。

最后的选择是将Vitess直接部署到现有的MySQL实例上，并慢慢迁移应用程序流量以转移到使用Vitess。

相关的Vitess文档：
- 模式管理
- 运输安全模型
## Step 3: Vertical sharding (scaling to multiple keyspaces) 垂直分片(缩放到多个keyspaces)
通常，放大的第一步是垂直分区，在这个分区中可以识别属于一组的表并将它们移动到不同的密钥空间中。密钥空间是一个分布式数据库，通常，此时数据库是未分层的。也就是说，在扩展到多个密钥空间之前，您可能需要水平分割数据（步骤4）。

将表分成多个密钥空间的好处是并行访问数据（提高性能），并为每个较小的密钥空间准备水平分片。而且，在将数据分成多个密钥空间时，您应该着眼于以下几点：

- 密钥空间内的所有表共享一个公用密钥。这将使步骤4中描述的未来水平分割更加方便。
- 连接主要在密钥空间内。（密钥间的连接代价很高。）
- 涉及多个密钥空间中数据的事务也很昂贵，这种事务并不常见。

### Scaling keyspaces with Vitess 使用Vitess缩放keyspaces
几个vtctl函数 - vtctl是用于管理数据库拓扑的Vitess命令行工具 - 支持垂直分割密钥空间的功能。在此过程中，可以将一组表从一个现有的密钥空间移动到一个新的密钥空间，而不需要读取停机时间并且只需几秒钟就可以写入停机时间。
相关的Vitess文档：
- vtctl参考指南

## Step 4: Horizontal sharding (partitioning your data) 水平分割（分割你的数据）
扩展数据的下一步是水平分区，即对数据进行分区以提高可伸缩性和性能的过程。分片是密钥空间内数据的水平分区。每个分片都有一个主实例和副本实例，但数据在分片之间不重叠。

为了执行水平分片，您需要确定将用于决定每个表的目标分片的列。这被称为主Vindex，它类似于NoSQL分片密钥，但提供了额外的灵活性。关于这种主要vindexes和其他分片元数据的决定存储在VSchema中。

Vitess提供强大的重新分片支持，包括更新密钥空间的分片方案和动态重组数据以匹配新方案。在重新分片期间，Vitess会复制，验证并保持数据在新分片上保持最新，而现有分片将继续提供实时读取和写入流量。当您准备好切换时，只需几秒钟的只读停机时间即可进行迁移。

相关的Vitess文档：
- VSchema参考指南
- 拆分
- 水平分片（Codelab）
- 分解在Kubernetes（Codelab）
## Related tasks 相关任务
除了上面讨论的四个步骤之外，随着应用程序的成熟，您可能还需要完成以下部分或全部内容。

### Data processing input / output 数据输入/输出
Hadoop是一个框架，可以使用简单的编程模型在计算机集群中分布式处理大型数据集。

Vitess提供了一个Hadoop InputSource，可用于任何Hadoop MapReduce作业甚至连接到Spark。Vitess InputSource接受简单的SQL查询，将查询拆分为小块，并尽可能跨数据库实例，分片等并行化数据读取。

### Query log analysis 查询日志分析
数据库查询日志可以帮助您监视和提高应用程序的性能。

为此，每个vttablet实例都提供运行时统计信息，可通过平板电脑的网页访问平板电脑正在运行的查询。这些统计信息可以很容易地检测到缓慢的查询，这些查询通常会由于缺少或不匹配的表索引而受到阻碍。定期查看这些查询有助于维护大型数据库安装的整体运行状况。

每个vttablet实例还可以提供所有正在运行的查询的流。如果Vitess集群与日志集群共处一处，则可以实时转储此数据，然后运行更高级的查询分析。