ansible部署apisix步骤

  部署结构：apisix单独1台机器，apisix依赖etcd，使用3台机器部署etcd集群；
  部署步骤：
    1. 修改hosts文件内机器IP
    2. 运行剧本 install_etcd_01.yml
    3. 运行剧本 install_apisix_02.yml
    完成第3步后其实apisix就已经安装完成了，后面如果需要替换apisix配置文件，运行剧本 replace_config_03.yml
  
  ps: Centos 7操作系统镜像可能默认开启firewalld服务，etcd集群使用的2380端口被拦截，所以这里关掉了防火墙服务。
