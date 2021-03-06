# supervisor知识总结

## supervisor概述
- 官网文档：http://supervisord.org/installing.html

## 部署安装
- [install_supervisor.sh]()

## 日常管理
- supervisord
  ``` text
  supervisorctl stop programxxx：停止某一个进程(programxxx)，programxxx为[program:chatdemon]里配置的值，这个示例就是chatdemon。
  supervisorctl start programxxx：启动某个进程
  supervisorctl restart programxxx：重启某个进程
  supervisorctl stop groupworker：重启所有属于名为groupworker这个分组的进程(start,restart同理)
  supervisorctl stop all：停止全部进程，注：start、restart、stop都不会载入最新的配置文件。
  supervisorctl reload：载入最新的配置文件，停止原有进程并按新的配置启动、管理所有进程。
  supervisorctl update：根据最新的配置文件，启动新配置或有改动的进程，配置没有改动的进程不会受影响而重启。
  注意：显示用stop停止掉的进程，用reload或者update都不会自动重启。
  ```
- supervisorctl
- web管理界面(inet_http_server)

## supervisor集中管理的方案
``` text
较成熟且靠谱的方案
1）Django-Dashvisor（功能简陋，项目更新不及时）
    Web-based dashboard written in Python. Requires Django 1.3 or 1.4.
2）Nodervisor
Web-based dashboard written in Node.js.
项目地址：https://github.com/TAKEALOT/nodervisor

3）Supervisord-Monitor
    Web-based dashboard written in PHP.
    
4）SupervisorUI
Another Web-based dashboard written in PHP.
supervisord-monitor（改进版）
https://github.com/mlazarov/supervisord-monitor

supervisord-monitor（改进版）界面效果
1）安装
git clone https://github.com/mlazarov/supervisord-monitor.git
修改配置文件supervisord.conf
[inet_http_server]
port=*:9001

2）编写supervisord-monitor配置文件
```
## Ansible + Supervisor
- [ansible supervisor](http://docs.ansible.com/ansible/latest/modules/supervisorctl_module.html#supervisorctl-module)

## 参考资料
