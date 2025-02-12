Aqui está a estrutura detalhada para configurar o cluster conforme os requisitos:

### 1. Pacotes Necessários (Ubuntu 24.04):
```bash
# Em todas as VMs:
sudo apt update
sudo apt install -y mariadb-server maxscale keepalived socat
```

---

### 2. Configurações do MariaDB:

#### VM1 (192.168.1.251 - **Master Inicial**):
`/etc/mysql/mariadb.conf.d/99-replication.cnf`:
```ini
[mysqld]
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = row
gtid_strict_mode = ON
log_slave_updates = ON
read_only = OFF
```

#### VM2 (192.168.1.252 - Slave):
`/etc/mysql/mariadb.conf.d/99-replication.cnf`:
```ini
[mysqld]
server-id = 2
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = row
gtid_strict_mode = ON
log_slave_updates = ON
read_only = ON
```

#### VM3 (192.168.1.253 - Slave):
`/etc/mysql/mariadb.conf.d/99-replication.cnf`:
```ini
[mysqld]
server-id = 3
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = row
gtid_strict_mode = ON
log_slave_updates = ON
read_only = ON
```

---

### 3. Configurações do Keepalived:

#### VM1 (MASTER Priority 100):
`/etc/keepalived/keepalived.conf`:
```conf
vrrp_script chk_mariadb {
    script "/usr/bin/systemctl is-active mariadb"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface ens160  # Altere para a interface de rede correta
    virtual_router_id 51
    priority 100
    advert_int 1

    virtual_ipaddress {
        192.168.1.250
    }

    track_script {
        chk_mariadb
    }

    notify_master "/usr/local/bin/vip_master.sh"
    notify_backup "/usr/local/bin/vip_backup.sh"
}
```

#### VM2 (BACKUP Priority 90):
```conf
... (mesmo script acima)
vrrp_instance VI_1 {
    state BACKUP
    priority 90
    ...
}
```

#### VM3 (BACKUP Priority 80):
```conf
... (mesmo script acima)
vrrp_instance VI_1 {
    state BACKUP
    priority 80
    ...
}
```

---

### 4. Scripts de Notificação do Keepalived:

`/usr/local/bin/vip_master.sh` (em todas as VMs):
```bash
#!/bin/bash
# Promove o nó para Master
mysql -e "STOP SLAVE; RESET SLAVE ALL; SET GLOBAL read_only = OFF;"
systemctl restart maxscale
```

`/usr/local/bin/vip_backup.sh` (em todas as VMs):
```bash
#!/bin/bash
# Reconfigura como Slave
mysql -e "CHANGE MASTER TO MASTER_HOST='192.168.1.250', MASTER_USE_GTID=current_pos; START SLAVE; SET GLOBAL read_only = ON;"
```

---

### 5. Configuração do MaxScale (Idêntica em todas as VMs):

`/etc/maxscale.cnf`:
```ini
[maxscale]
threads = auto

# Servers
server1 = 192.168.1.251:3306
server2 = 192.168.1.252:3306
server3 = 192.168.1.253:3306

# Monitor
[MariaDB-Monitor]
type = monitor
module = mariadbmon
servers = server1,server2,server3
user = maxscale_monitor
password = SenhaSegura123
monitor_interval = 1000ms
auto_failover = true
auto_rejoin = true
failcount = 3

# Serviço ReadWrite (Master)
[RW-Service]
type = service
router = readwritesplit
servers = server1,server2,server3
user = maxscale_user
password = SenhaSegura123
max_slave_connections = 100%
enable_root_user = true

# Serviço ReadOnly (Slaves)
[RO-Service]
type = service
router = readconnroute
router_options = slave
servers = server1,server2,server3
user = maxscale_user
password = SenhaSegura123

# Listeners
[RW-Listener]
type = listener
service = RW-Service
protocol = MariaDBClient
port = 3308
address = 192.168.1.250

[RO-Listener]
type = listener
service = RO-Service
protocol = MariaDBClient
port = 3307
address = 192.168.1.250
```

---

### 6. Preparação do Ambiente:

1. **Criação de Usuários no MariaDB** (Execute no Master inicial):
```sql
CREATE USER 'maxscale_monitor'@'%' IDENTIFIED BY 'SenhaSegura123';
CREATE USER 'maxscale_user'@'%' IDENTIFIED BY 'SenhaSegura123';
GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'maxscale_monitor'@'%';
GRANT SELECT ON mysql.* TO 'maxscale_monitor'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO 'maxscale_user'@'%';
```

2. **Iniciar Replicação nos Slaves**:
```sql
CHANGE MASTER TO MASTER_HOST='192.168.1.251', MASTER_USE_GTID=current_pos;
START SLAVE;
```

3. **Reiniciar Serviços**:
```bash
sudo systemctl restart mariadb keepalived maxscale
```

---

### 7. Validação:

1. Verificar status do VIP:
```bash
ip addr show
```

2. Verificar status de replicação:
```sql
SHOW SLAVE STATUS\G
```

3. Testar failover (desligar VM1 e verificar promoção automática).

---

Esta configuração garante:
- Failover automático via MaxScale + Keepalived
- Reconexão do nó original após recuperação
- Separação de tráfego Read/Write (3307/3308)
- Alta disponibilidade do VIP (192.168.1.250)