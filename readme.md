Aqui está um plano detalhado para configurar o cluster MariaDB com MaxScale no Ubuntu 24, levando em conta todos os requisitos.  

---

## 1. **Pacotes necessários para instalação**
Antes de começar, instale os pacotes necessários em todas as VMs:  

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y mariadb-server mariadb-client keepalived maxscale
```

---

## 2. **Configuração do MariaDB em cada VM**  
O banco de dados funcionará no modo **MASTER + SLAVE + SLAVE**, com replicação automática e failover via MaxScale.

### **Configuração do MariaDB no db1 (192.168.1.251 - Inicialmente MASTER)**
Edite o arquivo `/etc/mysql/mariadb.conf.d/50-server.cnf`:  

```ini
[mysqld]
server-id=1
log_bin=mysql-bin
binlog_do_db=mydatabase
bind-address=0.0.0.0
port=3308
gtid_domain_id=1
gtid_strict_mode=1
default_storage_engine=InnoDB
read_only=OFF
```

### **Configuração do MariaDB no db2 (192.168.1.252 - Inicialmente SLAVE)**
Edite `/etc/mysql/mariadb.conf.d/50-server.cnf`:  

```ini
[mysqld]
server-id=2
log_bin=mysql-bin
relay_log=relay-bin
binlog_do_db=mydatabase
bind-address=0.0.0.0
port=3307
gtid_domain_id=2
gtid_strict_mode=1
default_storage_engine=InnoDB
read_only=ON
```

### **Configuração do MariaDB no db3 (192.168.1.253 - Inicialmente SLAVE)**
Edite `/etc/mysql/mariadb.conf.d/50-server.cnf`:  

```ini
[mysqld]
server-id=3
log_bin=mysql-bin
relay_log=relay-bin
binlog_do_db=mydatabase
bind-address=0.0.0.0
port=3307
gtid_domain_id=3
gtid_strict_mode=1
default_storage_engine=InnoDB
read_only=ON
```

Reinicie o MariaDB em todas as VMs:
```bash
sudo systemctl restart mariadb
```

#### **Criar usuário de replicação no MASTER (db1)**
No `db1`, execute:
```sql
CREATE USER 'repl'@'%' IDENTIFIED BY 'SenhaForteAqui';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
```

No **db2** e **db3**, conecte-se ao MariaDB e execute:
```sql
CHANGE MASTER TO MASTER_HOST='192.168.1.251', MASTER_USER='repl', MASTER_PASSWORD='SenhaForteAqui', MASTER_PORT=3308, MASTER_USE_GTID=slave_pos;
START SLAVE;
```

Verifique o status:
```sql
SHOW SLAVE STATUS\G
```

---

## 3. **Configuração do Keepalived para VRRP**  
Cada VM terá uma configuração específica para o `keepalived`.

### **Arquivo `/etc/keepalived/keepalived.conf` para db1 (192.168.1.251 - MASTER Inicial)**
```ini
vrrp_instance VI_1 {
    state MASTER
    interface enp0s3
    virtual_router_id 51
    priority 150
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass senhaSegura
    }
    virtual_ipaddress {
        192.168.1.250
    }
    notify_master "/etc/keepalived/scripts/failover_master.sh"
    notify_backup "/etc/keepalived/scripts/failover_backup.sh"
}
```

### **Arquivo `/etc/keepalived/keepalived.conf` para db2 (192.168.1.252 - SLAVE)**
```ini
vrrp_instance VI_1 {
    state BACKUP
    interface enp0s3
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass senhaSegura
    }
    virtual_ipaddress {
        192.168.1.250
    }
}
```

### **Arquivo `/etc/keepalived/keepalived.conf` para db3 (192.168.1.253 - SLAVE)**
```ini
vrrp_instance VI_1 {
    state BACKUP
    interface enp0s3
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass senhaSegura
    }
    virtual_ipaddress {
        192.168.1.250
    }
}
```

Reinicie o `keepalived` em todas as VMs:
```bash
sudo systemctl restart keepalived
```

---

## 4. **Configuração do MaxScale**  
Ajuste os arquivos em cada VM:

### **Arquivo `/etc/maxscale.cnf` em todas as VMs**
```ini
[maxscale]
threads=auto

[server1]
type=server
address=192.168.1.251
port=3308
protocol=MariaDBBackend

[server2]
type=server
address=192.168.1.252
port=3307
protocol=MariaDBBackend

[server3]
type=server
address=192.168.1.253
port=3307
protocol=MariaDBBackend

[Master-Slave-Service]
type=service
router=readwritesplit
servers=server1,server2,server3
user=maxscale
password=SenhaForteAqui
enable_root_user=true

[Master-Slave-Monitor]
type=monitor
module=mariadbmon
servers=server1,server2,server3
user=maxscale
password=SenhaForteAqui
monitor_interval=10000
auto_failover=true
auto_rejoin=true
failcount=3
notify_script=/etc/maxscale/failover.sh

[CLI]
type=service
router=cli
```

Crie o usuário para o MaxScale:
```sql
CREATE USER 'maxscale'@'%' IDENTIFIED BY 'SenhaForteAqui';
GRANT ALL PRIVILEGES ON *.* TO 'maxscale'@'%';
FLUSH PRIVILEGES;
```

Reinicie o MaxScale em todas as VMs:
```bash
sudo systemctl restart maxscale
```

---

## 5. **Script de Failover (`/etc/maxscale/failover.sh`)**
Crie esse script para reconfigurar os serviços em caso de failover:

```bash
#!/bin/bash
logger "Failover detectado! Reconfigurando MariaDB."

if [ "$1" == "master" ]; then
    mysql -u root -p'SenhaForteAqui' -e "SET GLOBAL read_only=OFF;"
elif [ "$1" == "slave" ]; then
    mysql -u root -p'SenhaForteAqui' -e "SET GLOBAL read_only=ON;"
fi
```

Dê permissão de execução:
```bash
chmod +x /etc/maxscale/failover.sh
```

---

## 6. **Testando o Cluster**
1. Verifique se o VIP está ativo:
   ```bash
   ip addr show enp0s3
   ```
2. Teste a conexão ao VIP:
   ```bash
   mysql -u maxscale -p -h 192.168.1.250 -P 3308
   ```
3. Derrube o db1 e veja se um SLAVE assume como MASTER:
   ```bash
   sudo systemctl stop mariadb
   ```
4. Restaure o nó e veja se ele volta como SLAVE corretamente.

---

Isso garante alta disponibilidade e failover automático com MariaDB, MaxScale e Keepalived. Se precisar de ajustes, me avise! 🚀



