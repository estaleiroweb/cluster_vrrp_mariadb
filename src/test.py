import pymysql
import time
from pprint import pprint


class Test:
    nodeIni = 0
    node = 0
    nodeV = {
        "host": "192.168.1.250",
        "port": 3306,
        "user": "admin",
        "password": "Presente1!",
        "database": "test",
    }
    nodes = [
        {
            "host": "192.168.1.251",
            "port": 3306,
            "user": "admin",
            "password": "Presente1!",
            "database": "test",
        }, {
            "host": "192.168.1.252",
            "port": 3306,
            "user": "admin",
            "password": "Presente1!",
            "database": "test",
        }, {
            "host": "192.168.1.253",
            "port": 3306,
            "user": "admin",
            "password": "Presente1!",
            "database": "test",
        },
    ]
    flags = []
    erros = []

    def __init__(self) -> None:
        self.exec('CREATE OR REPLACE DATABASE test;')
        self.tst_engines()
        self.tst_objs()
        self.tst_main()
        self.report()

    def tst_engines(self):
        print("#### ENGINES")

        for i in ['InnoDB', 'Aria', 'MyISAM', 'MEMORY']:
            self.tst_engine(i)

        self.tst_engine_connect()

    def tst_objs(self):
        print("#### OBJECTS")
        self.tst_view()
        self.tst_pc()
        self.tst_fn()
        self.tst_trigger()
        self.tst_servers()
        self.tst_ev()
        self.tst_sequence()
        self.tst_calc_field()

    def report(self):
        print("#### REPORT OK")
        pprint(self.flags)
        print("#### REPORT ERRORS")
        pprint(self.erros)

    def check(self, grp, key, ret):
        k = f'{grp}:{key}'
        if ret:
            self.flags.append(k)
        else:
            self.erros.append(k)
        return ret

    def wait(self, t):
        print(f'- Wait {t} seconds')
        time.sleep(t)

    def connectMain(self):
        return pymysql.connect(
            host=self.nodeV["host"],
            port=self.nodeV["port"],
            user=self.nodeV["user"],
            password=self.nodeV["password"],
            database=self.nodeV["database"],
            cursorclass=pymysql.cursors.DictCursor,
        )

    def connect(self, node):
        return pymysql.connect(
            host=self.nodes[node]["host"],
            port=self.nodes[node]["port"],
            user=self.nodes[node]["user"],
            password=self.nodes[node]["password"],
            database=self.nodes[node]["database"],
            cursorclass=pymysql.cursors.DictCursor,
        )

    def connect_all(self):
        print("Connect")
        for i in range(len(self.nodes)):
            try:
                self.nodes[i]['conn'] = self.connect(i)
            except Exception as e:
                print('ERRO connect node ',
                      self.nodes[i]['host'], f': {e}')

    def exec(self, sql):
        try:
            with self.connect(self.nodeIni) as connection:
                with connection.cursor() as cursor:
                    cursor.execute(sql)
                    connection.commit()
            return True
        except Exception as e:
            print(f"ERRO Exec {self.nodes[self.nodeIni]['host']}: {e}")
            return False

    def query(self, sql):
        try:
            with self.connect(self.node) as connection:
                with connection.cursor() as cursor:
                    cursor.execute(sql)
                    return cursor.fetchall()
        except Exception as e:
            print(f"ERRO Query {self.nodes[self.node]['host']}: {e}")
            return False

    def sql(self, sql):
        ret = True
        old = None
        for i in range(len(self.nodes)):
            self.node = i
            rows = self.query(sql)
            if not rows or (old and old != rows):
                ret = False
            print(f'   - Node {i}: ', end='')
            print(rows)
            old = rows
        return ret

    def select(self, nm, limit=100, grp='select'):
        print(f'- Data {nm}')
        sql = f'SELECT * FROM {nm} LIMIT {limit};'
        return self.check(grp, nm, self.sql(sql))

    def insert(self, nm, grp='insert'):
        print(f'- Insert {nm}')
        sql = f"""
            INSERT {nm} (name) VALUES
                (CONCAT('T1-',ROUND(RAND()*100))),
                (CONCAT('T2-',ROUND(RAND()*100)));
        """
        return self.check(grp, nm, self.exec(sql))

    def create_tbl(self, nm, engine='Aria', ddl='''
            id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            u CHAR(36) NOT NULL DEFAULT uuid(),
            name VARCHAR(50) NOT NULL,
            dt TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
            UNIQUE INDEX (u)
        '''):
        print(f'- Create Table {nm}')
        grp = 'table'
        sql = f'''
            CREATE OR REPLACE TABLE {nm} ({ddl})
            ENGINE={engine};
        '''
        return self.check(grp, nm, self.exec(sql))

    def create_view(self, nm='vw_all',
                    sql='SELECT * FROM tb_Aria a UNION ALL \nSELECT * FROM tb_MyISAM i UNION ALL\nSELECT * FROM tb_MEMORY m'
                    ):
        print(f'- Create View {nm}')
        grp = 'table'
        sql = f'CREATE OR REPLACE VIEW {nm} AS {sql}'
        return self.check(grp, nm, self.exec(sql))

    def create_pc(self, nm='pc_test', ddl='''
            BEGIN
                SELECT * FROM tb_InnoDB;
            END
        '''):
        print(f'- Create Procedure {nm}')
        grp = 'routine'
        sql = f"""
            CREATE OR REPLACE PROCEDURE {nm}()
            NOT DETERMINISTIC {ddl}
        """
        return self.check(grp, nm, self.exec(sql))

    def create_fn(self, nm='fn_test', returns='timestamp', ddl='''
            BEGIN
                RETURN NOW();
            END
        '''):
        print(f'- Create Function{nm}')
        grp = 'routine'
        sql = f'''
            CREATE OR REPLACE FUNCTION {nm}()
            RETURNS {returns}
            NOT DETERMINISTIC {ddl}
        '''
        return self.check(grp, nm, self.exec(sql))

    def create_trigger(self, tbl='tb_Aria', when='before', event='insert', ddl='BEGIN \nEND;'):
        nm = f'{tbl}_{when}_{event}'
        print(f'- Create Trigger {nm}')
        grp = 'trigger'
        sql = f"""
            CREATE OR REPLACE TRIGGER {nm}
            {when} {event}
            ON {tbl} FOR EACH ROW {ddl}
        """
        return self.check(grp, nm, self.exec(sql))

    def create_event(self, nm='ev_Tst', when='EVERY 1 SECOND', status='ENABLE', ddl='''
            BEGIN
                INSERT IGNORE tb_Tst SET `name`=CONCAT('Event ',ROUND(RAND()*100));
            END
        '''):
        print(f'- Create Event {nm}')
        grp = 'event'
        sql = f'''
            CREATE OR REPLACE EVENT {nm}
                ON SCHEDULE {when}
            ON COMPLETION PRESERVE
            {status}
            DO {ddl}
        '''
        return self.check(grp, nm, self.exec(sql))

    def create_server(self, nm, db='test', user='admin', passwd='Presente1!'):
        print(f'- Create Server {nm}')
        grp = 'server'
        sql = f"""
            CREATE OR REPLACE SERVER {nm} FOREIGN DATA WRAPPER mariadb OPTIONS (
                HOST '{nm}',
                DATABASE '{db}',
                USER '{user}',
                PASSWORD '{passwd}',
                OWNER 'admin',
                PORT 3306
            );
        """
        return self.check(grp, nm, self.exec(sql))

    def create_sequence(self, nm, start=1, inc=1, min=1, cache=10):
        print(f'- Create Sequence {nm}')
        grp = 'sequence'
        sql = f"""
            CREATE OR REPLACE SEQUENCE {nm}
            START WITH {start}
            INCREMENT BY {inc}
            MINVALUE {min}
            NO MAXVALUE
            CACHE {cache};
        """
        return self.check(grp, nm, self.exec(sql))

    def tst_engine(self, engine):
        tbl = f'tb_{engine}'
        self.create_tbl(tbl, engine)
        self.insert(tbl)
        # self.wait(3)
        return self.select(tbl)

    def tst_engine_connect(self):
        self.node = self.nodeIni

        tbl = 'ln_ibge_distritos'

        print(f'- Create Table {tbl}')
        self.exec(f"""
            CREATE OR REPLACE TABLE {tbl} (
                id INT field_format='id',
                nome VARCHAR(255) field_format='nome',
                estado VARCHAR(255) field_format='municipio.regiao-imediata.nome',
                uf CHAR(2) field_format='municipio.regiao-imediata.sigla'
            )
            ENGINE = CONNECT
            COLLATE='utf8mb4_general_ci'
            TABLE_TYPE = JSON
            -- FILE_NAME='/tmp/distritos.json'
            HTTP='https://servicodados.ibge.gov.br'
            URI='/api/v1/localidades/distritos';
        """)

        return self.select(tbl, 2)

    def tst_view(self):
        nm = 'vw_all'
        self.create_view(nm)
        return self.select(nm, 2)

    def tst_pc(self):
        nm = 'pc_test'
        self.create_pc(nm)
        print(f'- Data {nm}')
        sql = f'CALL {nm};'
        return self.check('selectPC', nm, self.sql(sql))

    def tst_fn(self):
        nm = 'fn_test'
        self.create_fn(nm)
        print(f'- Data {nm}')
        sql = f'SELECT {nm}()'
        return self.check('selectFN', nm, self.sql(sql))

    def tst_trigger(self):
        tbl = 'tb_Tst'
        self.create_tbl(tbl)
        for i in ['tb_Aria', 'tb_MyISAM', 'tb_InnoDB']:
            self.create_trigger(i, ddl=f'''
                BEGIN
                    INSERT IGNORE {tbl} SET
                        u=NEW.u,
                        `name`=CONCAT(NEW.id,':{i}'),
                        `dt`=NEW.`dt`;
                END;''')
            self.insert(i, grp='insertTR')
        return self.select(tbl, grp='selectTR')

    def tst_servers(self):
        for i in ['db1', 'db2', 'db3']:
            self.create_server(i)
        return self.select('mysql.servers')

    def tst_ev(self):
        tbl = 'tb_Tst'
        nm = 'ev_Tst'
        print(f'- Size Event {nm}/{tbl} before')
        self.sql(f'SELECT COUNT(1) FROM {tbl}')
        self.create_event(nm)
        self.wait(4)
        print(f'- Disable Event {nm} ')
        self.exec(f'ALTER EVENT {nm} DISABLE;')
        print(f'- Size Event {nm}/{tbl} after')
        self.sql(f'SELECT COUNT(1) FROM {tbl}')

    def tst_sequence(self):
        nm = 'sq_Tst'
        tbl = 'tb_Tst'
        self.create_sequence(nm)

        grp = 'selectAllSQ'
        sql = "SELECT * FROM information_schema.TABLES t WHERE t.TABLE_TYPE='SEQUENCE'"
        self.check(grp, nm, self.sql(sql))

        grp = 'alterSQ'
        sql = f'ALTER TABLE {tbl} ADD COLUMN n INT UNSIGNED;'
        self.check(grp, nm, self.exec(sql))

        print(f'- Insert {tbl}/{nm}')
        grp = 'insertSQ'
        sql = f"""
            INSERT {tbl} (name,n) VALUES
                (CONCAT('SQ1-',ROUND(RAND()*100)),NEXTVAL({nm})),
                (CONCAT('SQ2-',ROUND(RAND()*100)),NEXTVAL({nm}));
        """
        self.check(grp, nm, self.exec(sql))

        grp = 'selectSQ'
        sql = f'SELECT n FROM {tbl} LIMIT 11,10'
        self.check(grp, nm, self.sql(sql))

    def tst_calc_field(self):
        print(f'- Specials Persistent Calc Field')
        nm = 'tb_Tst'
        sql = f'''
        ALTER TABLE {nm}
            ADD COLUMN c VARCHAR(50) AS (CONCAT('#',name)) PERSISTENT;
        '''
        grp = 'calc'
        return self.check(grp, nm, self.exec(sql))

    def query_main(self,sql):
        try:
            with self.connectMain() as connection:
                with connection.cursor() as cursor:
                    cursor.execute(sql)
                    rows=cursor.fetchall()
        
                    print(f'   - Node Main: ', end='')
                    print(rows)
                    return rows
        except Exception as e:
            print(f"   - Node Main: ERRO Query Main: {e}")
            return False
        
    def tst_main(self):
        sql='SELECT @@hostname, @@server_id'
        ok=True
        for i in range(0,6):
            if not self.query_main(sql):
                ok=False

        return self.check('main', 'id', ok)
        

if __name__ == "__main__":
    Test()
